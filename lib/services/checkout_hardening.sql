-- =====================================================
-- HARDENING DEL CHECKOUT - kiosco_app
-- Correr DESPUES de student_activation.sql
--
-- Cierra dos agujeros de student_checkout:
--
-- 1. p_token era OPCIONAL. El cuerpo hacia
--    "IF p_token IS NOT NULL THEN" validar identidad, asi que
--    omitir el parametro salteaba la validacion entera:
--    cualquiera registraba compras a nombre de otro alumno.
--
-- 2. No se validaba la cantidad. Con quantity negativa pasaba:
--      stock = stock - (-5)   -> el stock AUMENTABA
--      total = precio * (-5)  -> venta negativa, baja la deuda
--
-- La app del alumno siempre tiene el qr_token en
-- FlutterSecureStorage, asi que exigirlo no cambia el flujo
-- real de compra.
-- =====================================================

CREATE OR REPLACE FUNCTION public.student_checkout(
  p_student_id TEXT,
  p_cart_items JSONB,
  p_recreo TEXT,
  p_payment_method TEXT,
  p_date TEXT,
  p_time TEXT,
  p_token TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_item JSONB;
  v_product_id UUID;
  v_qty INT;
  v_price NUMERIC;
  v_line_total NUMERIC;
  v_total NUMERIC := 0;
BEGIN
  -- 1. Identidad obligatoria
  IF p_token IS NULL OR btrim(p_token) = '' THEN
    RAISE EXCEPTION 'Token requerido';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.students
    WHERE id = p_student_id::UUID
      AND qr_token = p_token
      AND qr_token IS NOT NULL
      AND qr_token <> ''
      AND deleted IS NOT TRUE
  ) THEN
    RAISE EXCEPTION 'Token invalido';
  END IF;

  IF p_cart_items IS NULL
     OR jsonb_typeof(p_cart_items) <> 'array'
     OR jsonb_array_length(p_cart_items) = 0 THEN
    RAISE EXCEPTION 'Carrito vacio';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_cart_items)
  LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_qty := (v_item->>'quantity')::INT;

    -- 2. Cantidad positiva y acotada
    IF v_qty IS NULL OR v_qty <= 0 THEN
      RAISE EXCEPTION 'Cantidad invalida';
    END IF;
    IF v_qty > 50 THEN
      RAISE EXCEPTION 'Cantidad fuera de rango';
    END IF;

    SELECT price INTO v_price FROM public.products WHERE id = v_product_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Producto no encontrado: %', v_product_id;
    END IF;

    UPDATE public.products SET stock = stock - v_qty
    WHERE id = v_product_id AND stock >= v_qty;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock insuficiente';
    END IF;

    v_line_total := v_price * v_qty;
    v_total := v_total + v_line_total;

    INSERT INTO public.sales (student_id, product_id, quantity, total, payment_method, date, time, recreo)
    VALUES (p_student_id::UUID, v_product_id, v_qty, v_line_total, p_payment_method, p_date, p_time, p_recreo);
  END LOOP;

  RETURN jsonb_build_object('total', v_total, 'status', 'ok');
END;
$$;

-- =====================================================
-- VERIFICACION
-- =====================================================
--
-- Sin token -> debe fallar con 'Token requerido'
-- SELECT public.student_checkout(
--   '<student_uuid>', '[{"product_id":"<uuid>","quantity":1}]'::jsonb,
--   'Recreo', 'Pendiente', '2026-10-26', '10:00');
--
-- Cantidad negativa -> debe fallar con 'Cantidad invalida'
-- (despues de pasar el token correcto)
-- SELECT public.student_checkout(
--   '<student_uuid>', '[{"product_id":"<uuid>","quantity":-5}]'::jsonb,
--   'Recreo', 'Pendiente', '2026-10-26', '10:00', '<qr_token>');
