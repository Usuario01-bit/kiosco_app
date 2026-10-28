-- CUIDADO (2026-10-28): set_student_qr_token vive ahora en
-- login_rate_limit.sql, que comparte el contador de intentos con el
-- login. Correr este archivo lo revierte a una version sin limite.
-- clear_student_qr_token SI sigue siendo la vigente aca.
-- Ver SQL_APPLY_ORDER.md.
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
  v_student RECORD;
BEGIN
  SELECT id, temp_password INTO v_student
  FROM students
  WHERE id = p_student_id::UUID AND deleted IS NOT TRUE
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Estudiante no encontrado';
  END IF;

  IF v_student.temp_password IS NULL OR v_student.temp_password = '' THEN
    RAISE EXCEPTION 'Contrasena no configurada';
  END IF;

  IF NOT (v_student.temp_password = crypt(p_password, v_student.temp_password)) THEN
    RAISE EXCEPTION 'Contrasena incorrecta';
  END IF;

  UPDATE students SET qr_token = p_token WHERE id = v_student.id;

  RETURN jsonb_build_object('status', 'ok');
END;
$$;

CREATE OR REPLACE FUNCTION public.clear_student_qr_token(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  UPDATE students SET qr_token = NULL WHERE qr_token = p_token;
  RETURN jsonb_build_object('status', 'ok');
END;
$$;
