-- =====================================================
-- LIMPIEZA DE SOBRECARGAS VIEJAS - kiosco_app
-- Correr DESPUES de login_rate_limit.sql, checkout_hardening.sql
-- y student_activation.sql. Es idempotente: se puede repegar.
--
-- CREATE OR REPLACE no cambia la firma de una funcion. Cuando el
-- hardening agrego un parametro (p_token), Postgres creo una SEGUNDA
-- funcion y la vieja siguio viva. Los DROP de hardening_security.sql
-- apuntaban a la firma nueva, asi que la vieja quedo con todos sus
-- permisos y sin validar nada:
--
--   student_checkout(6 args)        -> sin p_token, sin chequeo de
--                                      cantidades: pedidos gratis
--   submit_payment_capture(3 args)  -> sin p_token
--   get_student_captures(1 arg)     -> sin p_token, lee capturas ajenas
--
-- PostgREST elige la sobrecarga por los nombres de argumentos que
-- manda el cliente, asi que un atacante puede pedir explicitamente
-- la vieja. Mientras exista, el hardening es decorativo.
-- =====================================================

DROP FUNCTION IF EXISTS public.student_checkout(TEXT, JSONB, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.submit_payment_capture(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.get_student_captures(TEXT);
-- Administracion: la vieja (2 args) no escribe el rol en los metadatos.
-- No es un agujero (las dos validan is_admin), pero es una sobrecarga
-- muerta que confunde.
DROP FUNCTION IF EXISTS public.create_admin_user(TEXT, TEXT);

-- =====================================================
-- VERIFICACION (correr a mano)
-- =====================================================
--
-- Quedan duplicados de pgcrypto (armor, digest, gen_salt, hmac,
-- pgp_*): esos son overloads legitimos de la extension, ignorar.
-- En public solo tiene que quedar una version de cada RPC propio:
--
-- SELECT proname, count(*)
-- FROM pg_proc
-- WHERE pronamespace = 'public'::regnamespace
--   AND proname IN ('student_checkout', 'submit_payment_capture',
--                   'get_student_captures', 'create_admin_user')
-- GROUP BY 1 HAVING count(*) > 1;
