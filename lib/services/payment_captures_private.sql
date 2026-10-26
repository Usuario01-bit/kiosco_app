-- =====================================================
-- BUCKET PRIVADO DE COMPROBANTES - kiosco_app
-- Correr DESPUES de checkout_hardening.sql
--
-- Hoy el bucket `payment-captures` es publico y la policy de
-- SELECT deja listar todos los objetos: cualquiera con la
-- publishable key baja los comprobantes de pago de todos los
-- alumnos.
--
-- Despues de esto:
--   - listar el bucket        -> bloqueado
--   - bajar por URL publica   -> bloqueado
--   - admin autenticado       -> URLs firmadas de 60s
--   - alumno (anon)           -> sigue subiendo, ya no lee
-- =====================================================

-- 1. Bucket privado
UPDATE storage.buckets
SET public = false
WHERE id = 'payment-captures';

-- 2. Fuera la lectura publica (y con ella el listado)
DROP POLICY IF EXISTS "payment_captures_public_read" ON storage.objects;

-- 3. Solo admin autenticado puede leer objetos del bucket
DROP POLICY IF EXISTS "payment_captures_admin_read" ON storage.objects;
CREATE POLICY "payment_captures_admin_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'payment-captures'
    AND public.is_admin()
  );

-- =====================================================
-- VERIFICACION
-- =====================================================
--
-- Debe devolver public = false
-- SELECT id, public FROM storage.buckets WHERE id = 'payment-captures';
--
-- Debe devolver solo la policy del admin y la de insert del alumno
-- SELECT policyname, cmd, roles FROM pg_policies
-- WHERE schemaname = 'storage' AND tablename = 'objects'
--   AND policyname LIKE 'payment_captures%';
