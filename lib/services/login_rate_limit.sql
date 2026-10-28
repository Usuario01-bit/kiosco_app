-- =====================================================
-- RATE LIMIT DE LOGIN - kiosco_app
-- Correr DESPUES de payment_captures_private.sql
--
-- verify_student() validaba la contrasena sin ningun limite:
-- se podia probar passwords contra cualquier alumno de forma
-- indefinida. Y set_student_qr_token() usaba el mismo
-- crypt() como oraculo, saltandose cualquier control que
-- pusieramos solo en el login.
--
-- Politica: 5 fallos dentro de 15 minutos bloquean la cuenta
-- 5 minutos. Un login exitoso resetea el contador.
--
-- Los fallos se devuelven como JSON y NO con RAISE EXCEPTION:
-- una excepcion revierte la transaccion y borraria el
-- incremento del contador.
-- =====================================================

-- =====================================================
-- 1. TABLA DE CONTROL
-- Sin policies + RLS: solo las funciones SECURITY DEFINER
-- pueden tocarla.
-- =====================================================

CREATE TABLE IF NOT EXISTS public.login_guard (
  student_id        UUID PRIMARY KEY REFERENCES public.students(id) ON DELETE CASCADE,
  failed_count      INT NOT NULL DEFAULT 0,
  window_started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  locked_until      TIMESTAMPTZ
);

ALTER TABLE public.login_guard ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.login_guard FROM PUBLIC, anon, authenticated;

-- =====================================================
-- 2. HELPERS INTERNOS
-- =====================================================

CREATE OR REPLACE FUNCTION public._login_locked_seconds(p_student_id UUID)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT COALESCE((
    SELECT GREATEST(0, CEIL(EXTRACT(EPOCH FROM (locked_until - now()))))::int
    FROM public.login_guard
    WHERE student_id = p_student_id
      AND locked_until IS NOT NULL
      AND locked_until > now()
  ), 0)
$$;

CREATE OR REPLACE FUNCTION public._login_fail(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_rec   RECORD;
  v_count INT;
BEGIN
  INSERT INTO public.login_guard (student_id)
  VALUES (p_student_id)
  ON CONFLICT (student_id) DO NOTHING;

  SELECT failed_count, window_started_at
  INTO v_rec
  FROM public.login_guard
  WHERE student_id = p_student_id
  FOR UPDATE;

  IF v_rec.window_started_at < now() - interval '15 minutes' THEN
    -- ventana vencida: arranca de cero
    UPDATE public.login_guard
    SET failed_count = 1,
        window_started_at = now(),
        locked_until = NULL
    WHERE student_id = p_student_id;
    v_count := 1;
  ELSE
    v_count := v_rec.failed_count + 1;
    UPDATE public.login_guard
    SET failed_count = v_count,
        locked_until = CASE
          WHEN v_count >= 5 THEN now() + interval '5 minutes'
          ELSE locked_until
        END
    WHERE student_id = p_student_id;
  END IF;

  RETURN jsonb_build_object('failed', v_count, 'locked', v_count >= 5);
END;
$$;

CREATE OR REPLACE FUNCTION public._login_ok(p_student_id UUID)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
  DELETE FROM public.login_guard WHERE student_id = p_student_id;
$$;

REVOKE ALL ON FUNCTION public._login_locked_seconds(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._login_fail(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._login_ok(UUID) FROM PUBLIC, anon, authenticated;

-- =====================================================
-- 3. LOGIN CON LIMITE DE INTENTOS
--
-- Devuelve:
--   NULL                                    -> credenciales incorrectas
--   {"status":"locked","retry_after":<seg>} -> cuenta bloqueada
--   {"status":"needs_activation"}           -> existe y nunca creo contrasena
--   {...student...}                         -> login ok
-- =====================================================

CREATE OR REPLACE FUNCTION public.verify_student(p_name TEXT, p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_s      RECORD;
  v_locked INT;
  v_fail   JSONB;
BEGIN
  SELECT id, name, role, grade, code, temp_password, must_change_password
  INTO v_s
  FROM public.students
  WHERE name = p_name
    AND deleted IS NOT TRUE
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  v_locked := public._login_locked_seconds(v_s.id);
  IF v_locked > 0 THEN
    RETURN jsonb_build_object('status', 'locked', 'retry_after', v_locked);
  END IF;

  IF v_s.temp_password IS NOT NULL
     AND v_s.temp_password = public.crypt(p_password, v_s.temp_password) THEN
    PERFORM public._login_ok(v_s.id);
    RETURN jsonb_build_object(
      'id', v_s.id::text,
      'name', v_s.name,
      'role', v_s.role,
      'grado', v_s.grade,
      'code', v_s.code
    );
  END IF;

  -- La cuenta existe pero todavia no tiene contrasena propia: toda
  -- alta (manual o import) escribe un temp_password aleatorio que
  -- nadie conoce y deja must_change_password = true. Esa es la
  -- senal real de "sin configurar" que ya usa el panel de admin.
  --
  -- Va despues del chequeo de password para que una contrasena
  -- valida gane siempre, y antes de _login_fail porque no hay
  -- credencial conocida que adivinar: el alumno no puede
  -- bloquearse a si mismo antes de activar.
  IF v_s.must_change_password IS TRUE THEN
    RETURN jsonb_build_object('status', 'needs_activation');
  END IF;

  v_fail := public._login_fail(v_s.id);

  IF (v_fail->>'locked')::boolean THEN
    RETURN jsonb_build_object('status', 'locked', 'retry_after', 300);
  END IF;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.verify_student(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_student(TEXT, TEXT) TO anon, authenticated;

-- =====================================================
-- 4. set_student_qr_token CON EL MISMO CONTROL
--
-- Usaba crypt() con la misma contrasena: era otro punto de
-- fuerza bruta que se saltaba el limite del login.
-- Ahora comparte el contador y devuelve estado en JSON.
-- =====================================================

CREATE OR REPLACE FUNCTION public.set_student_qr_token(
  p_student_id TEXT,
  p_token TEXT,
  p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_s      RECORD;
  v_locked INT;
BEGIN
  SELECT id, temp_password
  INTO v_s
  FROM public.students
  WHERE id = p_student_id::UUID
    AND deleted IS NOT TRUE
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'Estudiante no encontrado');
  END IF;

  v_locked := public._login_locked_seconds(v_s.id);
  IF v_locked > 0 THEN
    RETURN jsonb_build_object(
      'status', 'locked',
      'message', 'Demasiados intentos',
      'retry_after', v_locked
    );
  END IF;

  IF v_s.temp_password IS NULL OR v_s.temp_password = '' THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'Contrasena no configurada');
  END IF;

  IF v_s.temp_password IS DISTINCT FROM public.crypt(p_password, v_s.temp_password) THEN
    PERFORM public._login_fail(v_s.id);
    RETURN jsonb_build_object('status', 'error', 'message', 'Contrasena incorrecta');
  END IF;

  PERFORM public._login_ok(v_s.id);

  -- Un token vacio queda igual al de cualquier alumno sin token y
  -- habilita get_student_by_token(''). No se acepta nunca.
  IF p_token IS NULL OR btrim(p_token) = '' THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'Token invalido');
  END IF;

  UPDATE public.students SET qr_token = p_token WHERE id = v_s.id;

  RETURN jsonb_build_object('status', 'ok');
END;
$$;

REVOKE ALL ON FUNCTION public.set_student_qr_token(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_student_qr_token(TEXT, TEXT, TEXT) TO anon, authenticated;

-- =====================================================
-- VERIFICACION
-- =====================================================
--
-- 5 passwords mal -> la quinta devuelve status locked
-- SELECT public.verify_student('<nombre real>', 'mal1');
-- SELECT public.verify_student('<nombre real>', 'mal2');
-- SELECT public.verify_student('<nombre real>', 'mal3');
-- SELECT public.verify_student('<nombre real>', 'mal4');
-- SELECT public.verify_student('<nombre real>', 'mal5');
--
-- Desbloquear una cuenta (desde el SQL Editor):
-- DELETE FROM public.login_guard WHERE student_id = '<uuid>';
