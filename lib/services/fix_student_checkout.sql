-- Fix: student_checkout with identity validation + no pending logic
-- Run in Supabase SQL Editor

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
  v_valid BOOLEAN;
BEGIN
  -- Validate student identity via QR token
  IF p_token IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM students 
      WHERE id = p_student_id::UUID 
        AND qr_token = p_token 
        AND deleted IS NOT TRUE
    ) INTO v_valid;
    
    IF NOT v_valid THEN
      RAISE EXCEPTION 'Token inválido para este estudiante';
    END IF;
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_cart_items)
  LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_qty := (v_item->>'quantity')::INT;

    SELECT price INTO v_price FROM products WHERE id = v_product_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Producto no encontrado: %', v_product_id;
    END IF;

    UPDATE products SET stock = stock - v_qty
    WHERE id = v_product_id AND stock >= v_qty;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock insuficiente';
    END IF;

    v_line_total := v_price * v_qty;
    v_total := v_total + v_line_total;

    INSERT INTO sales (student_id, product_id, quantity, total, payment_method, date, time, recreo)
    VALUES (p_student_id::UUID, v_product_id, v_qty, v_line_total, p_payment_method, p_date, p_time, p_recreo);
  END LOOP;

  -- Pending is handled by admin panel only
  RETURN jsonb_build_object('total', v_total, 'status', 'ok');
END;
$$;
