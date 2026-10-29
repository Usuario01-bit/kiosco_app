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

-- =====================================================
-- VERIFICACION (correr a mano)
-- =====================================================
--
-- No debe quedar ninguna funcion duplicada en public:
--
-- SELECT proname, count(*)
-- FROM pg_proc
-- WHERE pronamespace = 'public'::regnamespace
-- GROUP BY 1 HAVING count(*) > 1;
--
-- Y estas dos tienen que devolver 1 sola fila cada una:
--
-- SELECT oid::regprocedure FROM pg_proc
-- WHERE proname IN ('student_checkout', 'submit_payment_capture',
--                   'get_student_captures');
