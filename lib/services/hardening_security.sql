-- =====================================================
-- HARDENING SEGURIDAD — kiosco_app
-- Correr DESPUES de supabase_security.sql y first_login.sql
--
-- 1. is_admin() estricta (solo admin_profiles)
-- 2. Sin lectura anonima de `students` (todo pasa por RPC)
-- 3. RLS que faltaban (store_config, categories)
-- 4. RPCs de capturas/historial validados por qr_token
-- =====================================================

-- 1. is_admin() ESTRICTA
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid())
$$;

-- 2. Sacar lectura anonima de students
DROP POLICY IF EXISTS "students_anon_read" ON public.students;

-- 3. RLS de tablas que no tenian
ALTER TABLE store_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "store_config_anon_read" ON public.store_config;
CREATE POLICY "store_config_anon_read" ON public.store_config
  FOR SELECT TO anon, authenticated
  USING (true);
DROP POLICY IF EXISTS "store_config_admin_all" ON public.store_config;
CREATE POLICY "store_config_admin_all" ON public.store_config
  FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "categories_anon_read" ON public.categories;
CREATE POLICY "categories_anon_read" ON public.categories
  FOR SELECT TO anon, authenticated
  USING (true);
DROP POLICY IF EXISTS "categories_admin_all" ON public.categories;
CREATE POLICY "categories_admin_all" ON public.categories
  FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- 4. Helper de validacion de token (privado, uso interno)
CREATE OR REPLACE FUNCTION public._student_token_ok(p_student_id UUID, p_token TEXT)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.students
    WHERE id = p_student_id
      AND qr_token = p_token
      AND qr_token IS NOT NULL
      AND qr_token <> ''
  )
$$;

-- 5. get_student_by_code — reemplaza el SELECT directo previo
DROP FUNCTION IF EXISTS public.get_student_by_code(TEXT);
CREATE OR REPLACE FUNCTION public.get_student_by_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_s RECORD;
BEGIN
  SELECT id, name, role, grade, code INTO v_s
  FROM students
  WHERE code = trim(p_code) AND deleted IS NOT TRUE
  LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN jsonb_build_object(
    'id', v_s.id::text,
    'name', v_s.name,
    'role', v_s.role,
    'grade', v_s.grade,
    'code', v_s.code
  );
END;
$$;

-- 6. get_student_sales — historial del alumno (requiere su qr_token)
DROP FUNCTION IF EXISTS public.get_student_sales(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.get_student_sales(p_name TEXT, p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_s RECORD;
  v_rows JSONB;
BEGIN
  SELECT id INTO v_s
  FROM students
  WHERE lower(name) = lower(trim(p_name)) AND deleted IS NOT TRUE
  LIMIT 1;
  IF NOT FOUND THEN RETURN '[]'::jsonb; END IF;

  IF NOT is_admin() AND NOT (SELECT public._student_token_ok(v_s.id, p_token)) THEN
    RAISE EXCEPTION 'Token invalido';
  END IF;

  SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO v_rows
  FROM (
    SELECT
      sale.id,
      p.name AS product,
      sale.quantity,
      sale.total,
      sale.date,
      sale.time,
      sale.recreo,
      sale.payment_method
    FROM sales sale
    JOIN products p ON p.id = sale.product_id
    WHERE sale.student_id = v_s.id
    ORDER BY sale.date DESC, sale.time DESC
  ) t;

  RETURN v_rows;
END;
$$;

-- 7. get_student_debt — deuda del alumno (requiere su qr_token)
DROP FUNCTION IF EXISTS public.get_student_debt(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.get_student_debt(p_name TEXT, p_token TEXT)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_s RECORD;
  v_result NUMERIC;
  v_pending RECORD;
BEGIN
  SELECT id INTO v_s
  FROM students
  WHERE lower(name) = lower(trim(p_name)) AND deleted IS NOT TRUE
  LIMIT 1;
  IF NOT FOUND THEN RETURN 0; END IF;

  IF NOT is_admin() AND NOT (SELECT public._student_token_ok(v_s.id, p_token)) THEN
    RAISE EXCEPTION 'Token invalido';
  END IF;

  SELECT amount, paid INTO v_pending
  FROM pending
  WHERE student_id = v_s.id AND paid_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN RETURN 0; END IF;
  v_result := COALESCE(v_pending.amount, 0) - COALESCE(v_pending.paid, 0);
  IF v_result < 0 THEN v_result := 0; END IF;
  RETURN v_result;
END;
$$;

-- 8. submit_payment_capture — ahora valida identidad con qr_token
DROP FUNCTION IF EXISTS public.submit_payment_capture(TEXT, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.submit_payment_capture(
  p_student_id TEXT,
  p_token TEXT,
  p_message TEXT,
  p_image_path TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_id UUID;
  v_s RECORD;
BEGIN
  IF p_image_path IS NULL OR p_image_path = '' THEN
    RAISE EXCEPTION 'La captura de pago es obligatoria';
  END IF;

  SELECT id INTO v_s
  FROM students
  WHERE id = p_student_id::UUID AND deleted IS NOT TRUE
  LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Estudiante no encontrado';
  END IF;

  IF NOT is_admin() AND NOT (SELECT public._student_token_ok(v_s.id, p_token)) THEN
    RAISE EXCEPTION 'Token invalido';
  END IF;

  INSERT INTO payment_captures (student_id, message, image_url, status)
  VALUES (v_s.id, p_message, p_image_path, 'pendiente')
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('id', v_id, 'status', 'ok');
END;
$$;

-- 9. get_student_captures — solo las propias y con qr_token
DROP FUNCTION IF EXISTS public.get_student_captures(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.get_student_captures(p_student_id TEXT, p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_s RECORD;
  v_result JSONB;
BEGIN
  SELECT id INTO v_s
  FROM students
  WHERE id = p_student_id::UUID AND deleted IS NOT TRUE
  LIMIT 1;
  IF NOT FOUND THEN RETURN '[]'::jsonb; END IF;

  IF NOT is_admin() AND NOT (SELECT public._student_token_ok(v_s.id, p_token)) THEN
    RAISE EXCEPTION 'Token invalido';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'message', message,
      'image_url', image_url,
      'status', status,
      'created_at', created_at
    ) ORDER BY created_at DESC
  ), '[]'::jsonb)
  INTO v_result
  FROM payment_captures
  WHERE student_id = v_s.id;

  RETURN v_result;
END;
$$;

-- =====================================================
-- 10. BUCKET payment-captures: subida SOLO para alumnos registrados
--     El path debe ser <student_id>/... y ese id debe existir en students
-- =====================================================

CREATE OR REPLACE FUNCTION public._payment_capture_path_owner(p_path TEXT)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_id UUID;
BEGIN
  BEGIN
    v_id := (regexp_split_to_array(p_path, '/'))[1]::text::uuid;
  EXCEPTION WHEN others THEN
    RETURN false;
  END;
  RETURN EXISTS (
    SELECT 1 FROM public.students s
    WHERE s.id = v_id AND s.deleted IS NOT TRUE
  );
END;
$$;

DROP POLICY IF EXISTS "payment_captures_anon_insert" ON storage.objects;
CREATE POLICY "payment_captures_anon_insert" ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    bucket_id = 'payment-captures'
    AND public._payment_capture_path_owner(name)
  );

-- =====================================================
-- 11. TTL 15 DIAS: limpieza automatica de capturas de pago
--
-- Son DOS jobs, porque son dos cosas distintas:
--   (a) filas de payment_captures  -> SQL puro, corre bien.
--   (b) archivos del bucket        -> NO se pueden borrar por SQL.
--
-- Supabase bloquea el delete directo sobre las tablas de storage con el
-- trigger storage.protect_delete():
--   ERROR: Direct deletion from storage tables is not allowed. Use the Storage API instead.
--   HINT:  This prevents accidental data loss from orphaned objects.
-- Un DELETE en storage.objects borraria la fila de metadata y dejaria el
-- archivo huerfano en el bucket: el espacio NUNCA se libera. Los objetos solo
-- se borran por la Storage API, asi que (b) corre en la Edge Function
-- `cleanup-payment-captures`, que este cron invoca via pg_net.
-- Ver: lib/services/edge_functions/cleanup_payment_captures.ts
-- =====================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Patron idempotente: si el job existe se edita con alter_job, si no existe se
-- crea con schedule. Nunca unschedule por NOMBRE: si el job todavia no existe,
-- pg_cron responde XX000 "could not find valid entry for job '<nombre>'".
DO $$
DECLARE
  v_command text;
  v_jobid bigint;
BEGIN
  -- (a) Job de tabla
  v_command := $job$
    DELETE FROM public.payment_captures
    WHERE created_at < now() - interval '15 days';
  $job$;

  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'cleanup-payment-captures';
  IF v_jobid IS NULL THEN
    PERFORM cron.schedule('cleanup-payment-captures', '0 3 * * *', v_command);
  ELSE
    PERFORM cron.alter_job(v_jobid, '0 3 * * *', v_command);
  END IF;

  -- (b) Job de archivos: invoca la Edge Function que si borra los objetos
  v_command := $job$
    SELECT net.http_post(
      url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
             || '/functions/v1/cleanup-payment-captures',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
      ),
      body := '{}'::jsonb
    );
  $job$;

  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'cleanup-payment-captures-storage';
  IF v_jobid IS NULL THEN
    PERFORM cron.schedule('cleanup-payment-captures-storage', '5 3 * * *', v_command);
  ELSE
    PERFORM cron.alter_job(v_jobid, '5 3 * * *', v_command);
  END IF;
END $$;

-- Prerequisito (una sola vez, desde el SQL Editor):
--   SELECT vault.create_secret('https://<PROJECT_REF>.supabase.co', 'project_url');
--   SELECT vault.create_secret('<SERVICE_ROLE_KEY>', 'service_role_key');
-- Si el secreto ya existe, Vault devuelve error: usa vault.update_secret.

-- Verificacion despues de un run:
--   SELECT jobid, status, return_message, start_time
--   FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
--   SELECT status_code, content, error_msg, created
--   FROM net._http_response ORDER BY created DESC LIMIT 5;