-- =====================================================
-- PAYMENT CAPTURES - student payment screenshots
-- Run in Supabase SQL Editor
--
-- CUIDADO (2026-10-28): submit_payment_capture y get_student_captures
-- viven ahora en hardening_security.sql (validan identidad con
-- qr_token). Correr este archivo los revierte. Ver SQL_APPLY_ORDER.md.
-- =====================================================

-- 1. TABLE
CREATE TABLE IF NOT EXISTS public.payment_captures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  message TEXT,
  image_url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pendiente',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ
);

ALTER TABLE public.payment_captures ENABLE ROW LEVEL SECURITY;

-- Admin: full access
CREATE POLICY "payment_captures_admin_all" ON public.payment_captures
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- 2. RPC: submit a capture (called by anonymous student app)
CREATE OR REPLACE FUNCTION public.submit_payment_capture(
  p_student_id TEXT,
  p_message TEXT,
  p_image_path TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF p_image_path IS NULL OR p_image_path = '' THEN
    RAISE EXCEPTION 'La captura de pago es obligatoria';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM students WHERE id = p_student_id::UUID AND deleted IS NOT TRUE) THEN
    RAISE EXCEPTION 'Estudiante no encontrado';
  END IF;

  INSERT INTO payment_captures (student_id, message, image_url, status)
  VALUES (p_student_id::UUID, p_message, p_image_path, 'pendiente')
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('id', v_id, 'status', 'ok');
END;
$$;

-- 3. RPC: list a student's own captures
CREATE OR REPLACE FUNCTION public.get_student_captures(p_student_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', id,
      'message', message,
      'image_url', image_url,
      'status', status,
      'created_at', created_at
    ) ORDER BY created_at DESC
  )
  INTO v_result
  FROM payment_captures
  WHERE student_id = p_student_id::UUID;

  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

-- 4. STORAGE BUCKET
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment-captures', 'payment-captures', true)
ON CONFLICT (id) DO NOTHING;

-- Allow anonymous uploads into the bucket
CREATE POLICY "payment_captures_anon_insert" ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id = 'payment-captures');

-- Allow public read of bucket objects
DROP POLICY IF EXISTS "payment_captures_public_read" ON storage.objects;
CREATE POLICY "payment_captures_public_read" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'payment-captures');