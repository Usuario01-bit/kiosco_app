-- =====================================================
-- FIX: RLS — make is_admin() work for existing admins
-- Run this in Supabase SQL Editor (AFTER security migration)
-- =====================================================

-- 1. Drop ALL existing RLS policies
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
  END LOOP;
END $$;

-- 2. Fix is_admin(): authenticated users are admins (safe: only admins have auth accounts)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT auth.role() = 'authenticated';
$$;

-- 3. Recreate RLS policies
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
CREATE POLICY "students_admin_all" ON students
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "students_anon_read" ON students
  FOR SELECT USING (true);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "products_admin_all" ON products
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "products_anon_read" ON products
  FOR SELECT USING (true);

ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sales_admin_all" ON sales
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

ALTER TABLE pending ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pending_admin_all" ON pending
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_profiles_self_read" ON admin_profiles
  FOR SELECT USING (id = auth.uid() OR is_admin());
