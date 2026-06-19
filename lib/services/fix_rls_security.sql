-- =====================================================
-- SECURITY FIX — Restrict anon access to students & products
-- Run in Supabase SQL Editor
-- =====================================================

-- 1. DROP overly permissive policies
DROP POLICY IF EXISTS "students_anon_read" ON students;
DROP POLICY IF EXISTS "products_anon_read" ON products;

-- 2. RPC: search student names (anon, for login autocomplete)
-- Returns only id + name, no sensitive fields
CREATE OR REPLACE FUNCTION public.search_student_names(p_query TEXT)
RETURNS TABLE(id UUID, name TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT id, name FROM students
  WHERE deleted IS NOT TRUE AND name ILIKE '%' || p_query || '%'
  ORDER BY name
  LIMIT 10;
$$;

-- 3. RPC: get product catalog (anon, for student shopping)
-- Returns only public fields
CREATE OR REPLACE FUNCTION public.get_product_catalog()
RETURNS TABLE(id UUID, name TEXT, price NUMERIC, stock INT, icon TEXT, category TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT id, name, price, stock, icon, category FROM products
  ORDER BY category, name;
$$;

-- 4. RPC: verify student by QR token (anon)
CREATE OR REPLACE FUNCTION public.get_student_by_token(p_token TEXT)
RETURNS TABLE(id UUID, name TEXT, role TEXT, grade TEXT, code TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT id, name, role, grade, code FROM students
  WHERE qr_token = p_token AND deleted IS NOT TRUE
  LIMIT 1;
$$;

-- 5. Policy: students - admin full access (existing, keep)
-- Already exists: "students_admin_all"

-- 6. Policy: products - admin full access (existing, keep)  
-- Already exists: "products_admin_all"
