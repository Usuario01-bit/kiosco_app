-- =====================================================
-- ACTIVACION DE ALUMNOS - kiosco_app
-- Correr DESPUES de hardening_security.sql
--
-- Reemplaza el codigo inicial en texto plano por un codigo
-- de activacion hasheado, de un solo uso, con vencimiento
-- (15 min) e intentos limitados (5).
--
-- Genera el codigo el admin desde el panel: RPC
-- admin_generate_activation(). El alumno lo canjea con
-- activate_student().
--
-- ORDEN DE DESPLIEGUE: correr este SQL y despues publicar
-- la app nueva. Las versiones viejas de la app pierden el
-- primer ingreso (esperado: era el agujero).
-- =====================================================

-- =====================================================
-- 1. COLUMNAS DE ACTIVACION
-- =====================================================

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS activation_code_hash   TEXT,
  ADD COLUMN IF NOT EXISTS activation_expires_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS activation_attempts    INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS activation_claimed_at  TIMESTAMPTZ;

-- El codigo viejo queda inutilizable
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'students'
      AND column_name = 'initial_code'
  ) THEN
    EXECUTE 'UPDATE public.students SET initial_code = NULL WHERE initial_code IS NOT NULL';
  END IF;
END $$;

-- =====================================================
-- 2. RPC: GENERAR CODIGO (SOLO ADMIN)
--
-- El codigo se devuelve UNA vez en la respuesta. En la
-- tabla solo queda el hash: un dump de `students` no
-- entrega ningun codigo utilizable.
-- =====================================================

CREATE OR REPLACE FUNCTION public.admin_generate_activation(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public, extensions'
AS $$
DECLARE
  v_code    TEXT;
  v_expires TIMESTAMPTZ;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  -- 6 digitos, sin depender del PRNG no criptografico de Postgres
  v_code := lpad((abs(hashtext(gen_random_uuid()::text)::bigint) % 1000000)::text, 6, '0');
  v_expires := now() + interval '15 minutes';

  UPDATE public.students
  SET activation_code_hash  = crypt(v_code, gen_salt('bf')),
      activation_expires_at = v_expires,
      activation_attempts   = 0,
      must_change_password  = true
  WHERE id = p_student_id
    AND deleted IS NOT TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Alumno no encontrado';
  END IF;

  RETURN jsonb_build_object(
    'code', v_code,
    'expires_at', v_expires
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_generate_activation(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_generate_activation(UUID) TO authenticated;

-- =====================================================
-- 3. RPC: ACTIVAR ALUMNO (ANON)
--
-- Unico camino para crear la contrasena. Requiere el
-- codigo que entrego el kiosco.
-- =====================================================

CREATE OR REPLACE FUNCTION public.activate_student(
  p_name TEXT,
  p_code TEXT,
  p_new_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public, extensions'
AS $$
DECLARE
  v_s RECORD;
  v_error JSONB := jsonb_build_object('status', 'error', 'message', 'Codigo invalido o vencido');
BEGIN
  IF p_new_password IS NULL OR length(p_new_password) < 8 THEN
    RAISE EXCEPTION 'La contrasena debe tener al menos 8 caracteres';
  END IF;

  -- Sin codigo no hay nada que comparar. Sin este guard, crypt(NULL)
  -- devuelve NULL y la comparacion de abajo se evalua como NULL,
  -- que en un IF se trata como falso: la cuenta se activaria igual.
  IF p_code IS NULL OR btrim(p_code) = '' THEN
    RETURN v_error;
  END IF;

  SELECT id, name, role, grade,
         activation_code_hash, activation_expires_at, activation_attempts
  INTO v_s
  FROM public.students
  WHERE lower(name) = lower(btrim(p_name))
    AND deleted IS NOT TRUE
  LIMIT 1;

  -- Mismo mensaje para alumno inexistente, codigo vencido y
  -- codigo incorrecto: no se filtra que nombres existen.
  --
  -- Los fallos se devuelven como JSON y NO con RAISE EXCEPTION:
  -- una excepcion revierte la transaccion y borraria el
  -- incremento de activation_attempts del bloque de abajo.
  IF NOT FOUND THEN
    RETURN v_error;
  END IF;

  IF v_s.activation_code_hash IS NULL
     OR v_s.activation_expires_at IS NULL
     OR v_s.activation_expires_at < now()
     OR v_s.activation_attempts >= 5 THEN
    RETURN v_error;
  END IF;

  IF v_s.activation_code_hash IS DISTINCT FROM crypt(btrim(p_code), v_s.activation_code_hash) THEN
    UPDATE public.students
    SET activation_attempts = activation_attempts + 1,
        activation_code_hash = CASE
          WHEN activation_attempts + 1 >= 5 THEN NULL
          ELSE activation_code_hash
        END,
        activation_expires_at = CASE
          WHEN activation_attempts + 1 >= 5 THEN NULL
          ELSE activation_expires_at
        END
    WHERE id = v_s.id;

    RETURN v_error;
  END IF;

  -- temp_password se hashea solo por trg_hash_student_password
  UPDATE public.students
  SET temp_password         = p_new_password,
      must_change_password  = false,
      activation_code_hash  = NULL,
      activation_expires_at = NULL,
      activation_attempts   = 0,
      activation_claimed_at = now()
  WHERE id = v_s.id;

  RETURN jsonb_build_object(
    'status', 'ok',
    'id', v_s.id::text,
    'name', v_s.name,
    'role', v_s.role,
    'grade', v_s.grade
  );
END;
$$;

REVOKE ALL ON FUNCTION public.activate_student(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.activate_student(TEXT, TEXT, TEXT) TO anon, authenticated;

-- =====================================================
-- 4. RETIRAR LOS DOS RPC QUE ENTREGABAN EL CODIGO
--
-- get_student_initial_code(name) devolvia el codigo en
-- texto plano a cualquiera que supiera el nombre.
-- set_student_password(name, codigo, pass) era el paso
-- final de la toma de cuenta.
-- =====================================================

DROP FUNCTION IF EXISTS public.get_student_initial_code(TEXT);
DROP FUNCTION IF EXISTS public.set_student_password(TEXT, TEXT, TEXT);

-- =====================================================
-- 5. CIERRES IDEMPOTENTES DE HARDENING PREVIO
-- =====================================================

-- Lectura anonima del padron (por si hardening_security.sql no corrio)
DROP POLICY IF EXISTS "students_anon_read" ON public.students;

-- is_admin() estricta: solo quien esta en admin_profiles
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid())
$$;

-- upsert_pending no se usa en la app y permitia cargar deuda
-- arbitraria a cualquier alumno desde anon.
DO $$
BEGIN
  EXECUTE 'REVOKE ALL ON FUNCTION public.upsert_pending(TEXT, NUMERIC, TEXT) FROM PUBLIC, anon';
  EXECUTE 'GRANT EXECUTE ON FUNCTION public.upsert_pending(TEXT, NUMERIC, TEXT) TO authenticated';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'upsert_pending no se pudo endurecer (%), se omite', SQLERRM;
END $$;

-- =====================================================
-- VERIFICACION (solo lectura, correr a mano)
-- =====================================================
--
-- SELECT id, name,
--        activation_code_hash IS NOT NULL AS tiene_codigo,
--        activation_expires_at, activation_attempts,
--        must_change_password
-- FROM students
-- WHERE deleted IS NOT TRUE
-- ORDER BY name
-- LIMIT 20;
--
-- SELECT p.proname,
--        has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_puede
-- FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public'
--   AND p.proname IN ('get_student_initial_code', 'set_student_password',
--                     'activate_student', 'admin_generate_activation',
--                     'upsert_pending')
-- ORDER BY p.proname;
