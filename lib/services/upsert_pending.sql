-- Run this in Supabase SQL Editor
-- Creates a function that handles pending inserts safely (bypassing RLS)

CREATE OR REPLACE FUNCTION public.upsert_pending(
  p_student_id TEXT,
  p_amount NUMERIC,
  p_created_at TEXT DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO pending (student_id, amount, paid, paid_at, created_at)
  VALUES (
    p_student_id,
    p_amount,
    0,
    NULL,
    COALESCE(p_created_at, now()::text)
  )
  ON CONFLICT (student_id)
  DO UPDATE SET
    amount = pending.amount + EXCLUDED.amount,
    paid_at = NULL;
END;
$$;
