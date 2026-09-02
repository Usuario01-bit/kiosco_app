ALTER TABLE students ADD COLUMN IF NOT EXISTS initial_code TEXT;
ALTER TABLE students ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT true;

UPDATE students
SET
  initial_code = lpad(floor(random() * 1000000)::text, 6, '0'),
  must_change_password = true
WHERE initial_code IS NULL;

CREATE OR REPLACE FUNCTION public.get_student_initial_code(p_name TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_code TEXT;
BEGIN
  SELECT initial_code INTO v_code
  FROM students
  WHERE lower(name) = lower(trim(p_name))
    AND deleted IS NOT TRUE
    AND must_change_password IS TRUE
    AND initial_code IS NOT NULL
  LIMIT 1;

  RETURN v_code;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_student_password(
  p_name TEXT,
  p_initial_code TEXT,
  p_new_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_student RECORD;
BEGIN
  IF p_new_password IS NULL OR length(p_new_password) < 8 THEN
    RAISE EXCEPTION 'La contraseña debe tener al menos 8 caracteres';
  END IF;

  SELECT id, name, role, grade, code, initial_code, must_change_password
  INTO v_student
  FROM students
  WHERE lower(name) = lower(trim(p_name))
    AND deleted IS NOT TRUE
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Estudiante no encontrado';
  END IF;

  IF v_student.must_change_password IS NOT TRUE
     OR v_student.initial_code IS NULL
     OR v_student.initial_code <> p_initial_code THEN
    RAISE EXCEPTION 'Codigo inicial invalido';
  END IF;

  UPDATE students
  SET temp_password = p_new_password,
      initial_code = NULL,
      must_change_password = false
  WHERE id = v_student.id;

  RETURN jsonb_build_object(
    'id', v_student.id,
    'name', v_student.name,
    'role', v_student.role,
    'grade', v_student.grade,
    'code', v_student.code
  );
END;
$$;
