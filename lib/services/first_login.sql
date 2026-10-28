-- =====================================================
-- RETIRADO (2026-10-28) - NO CORRER
--
-- Flujo viejo de primer ingreso: students.initial_code guardaba un
-- codigo de 6 digitos EN TEXTO PLANO, sin vencimiento, y
-- get_student_initial_code() lo devolvia a cualquiera que supiera
-- el nombre del alumno. Con ese codigo, set_student_password()
-- fijaba la contrasena: cualquiera podia tomar la cuenta.
--
-- Lo reemplazo student_activation.sql: codigo hasheado (bcrypt),
-- vence a los 15 minutos, 5 intentos lo queman y solo lo genera un
-- admin desde el panel.
--
-- Este archivo queda como registro historico. Se le quitaron las
-- definiciones peligrosas y el UPDATE masivo, asi que correrlo ya
-- no recrea el agujero ni toca el estado de las cuentas.
-- =====================================================

-- Columnas historicas: siguen existiendo en la tabla, no se tocan.
-- must_change_password es la senal vigente de "sin contrasena propia".
ALTER TABLE students ADD COLUMN IF NOT EXISTS initial_code TEXT;
ALTER TABLE students ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT true;

-- El flujo viejo no debe existir ni por accidente.
DROP FUNCTION IF EXISTS public.get_student_initial_code(TEXT);
DROP FUNCTION IF EXISTS public.set_student_password(TEXT, TEXT, TEXT);
