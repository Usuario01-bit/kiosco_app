-- =====================================================
-- SECURITY MIGRATION — kiosco_app
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. ENABLE EXTENSIONS
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- 2. ADD MISSING COLUMNS TO students
-- =====================================================

ALTER TABLE students ADD COLUMN IF NOT EXISTS temp_password TEXT;
ALTER TABLE students ADD COLUMN IF NOT EXISTS code TEXT;
ALTER TABLE students ADD COLUMN IF NOT EXISTS qr_token TEXT;

-- =====================================================
-- 3. RLS POLICIES
-- =====================================================

-- Helper: is the current user an admin?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid());
$$;

-- Drop existing policies (safe to re-run)
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
  END LOOP;
END $$;

-- ----- students -----
ALTER TABLE students ENABLE ROW LEVEL SECURITY;

CREATE POLICY "students_admin_all" ON students
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

CREATE POLICY "students_anon_read" ON students
  FOR SELECT USING (true);

-- ----- products -----
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "products_admin_all" ON products
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

CREATE POLICY "products_anon_read" ON products
  FOR SELECT USING (true);

-- ----- sales -----
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sales_admin_all" ON sales
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ----- pending -----
ALTER TABLE pending ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pending_admin_all" ON pending
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ----- admin_profiles -----
ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_profiles_admin_read" ON admin_profiles
  FOR SELECT USING (is_admin());

-- =====================================================
-- 4. PASSWORD HASHING
-- =====================================================

-- Hash any existing plaintext passwords
UPDATE students
SET temp_password = crypt(temp_password, gen_salt('bf'))
WHERE temp_password IS NOT NULL
  AND temp_password !~ '^\$2[aby]\$';

-- Trigger: auto-hash on INSERT or UPDATE of temp_password
CREATE OR REPLACE FUNCTION public.hash_student_password_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.temp_password IS NOT NULL AND NEW.temp_password !~ '^\$2[aby]\$' THEN
    NEW.temp_password := crypt(NEW.temp_password, gen_salt('bf'));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_hash_student_password ON students;
CREATE TRIGGER trg_hash_student_password
  BEFORE INSERT OR UPDATE OF temp_password ON students
  FOR EACH ROW
  EXECUTE FUNCTION hash_student_password_trigger();

-- =====================================================
-- 5. RPC: verify_student
-- =====================================================

CREATE OR REPLACE FUNCTION public.verify_student(p_name TEXT, p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student RECORD;
BEGIN
  SELECT id, name, role, grade, code, temp_password INTO v_student
  FROM students
  WHERE name = p_name AND deleted IS NOT TRUE
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_student.temp_password = crypt(p_password, v_student.temp_password) THEN
    RETURN jsonb_build_object(
      'id', v_student.id::text,
      'name', v_student.name,
      'role', v_student.role,
      'grado', v_student.grade,
      'code', v_student.code
    );
  END IF;

  RETURN NULL;
END;
$$;

-- =====================================================
-- 6. RPC: student_checkout (atomic)
-- =====================================================

CREATE OR REPLACE FUNCTION public.student_checkout(
  p_student_id TEXT,
  p_cart_items JSONB,
  p_recreo TEXT,
  p_payment_method TEXT,
  p_date TEXT,
  p_time TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_item JSONB;
  v_product_id UUID;
  v_qty INT;
  v_price NUMERIC;
  v_line_total NUMERIC;
  v_total NUMERIC := 0;
  v_pending RECORD;
BEGIN
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

  IF p_payment_method ILIKE '%pendiente%' THEN
    SELECT id, amount INTO v_pending
    FROM pending
    WHERE student_id = p_student_id::UUID AND paid_at IS NULL
    LIMIT 1;

    IF FOUND THEN
      UPDATE pending SET amount = amount + v_total
      WHERE id = v_pending.id;
    ELSE
      INSERT INTO pending (student_id, amount, paid)
      VALUES (p_student_id::UUID, v_total, 0);
    END IF;
  END IF;

  RETURN jsonb_build_object('total', v_total, 'status', 'ok');
END;
$$;

-- =====================================================
-- 7. RPC: admin user management (SECURITY DEFINER)
-- =====================================================

CREATE OR REPLACE FUNCTION public.create_admin_user(p_username TEXT, p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_email TEXT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  v_email := p_username || '@kiosco.app';
  v_user_id := gen_random_uuid();

  INSERT INTO auth.users (
    id, email, encrypted_password, email_confirmed_at,
    confirmation_sent_at, raw_app_meta_data, raw_user_meta_data,
    aud, role, created_at, updated_at
  ) VALUES (
    v_user_id, v_email, crypt(p_password, gen_salt('bf')),
    now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    'authenticated', 'authenticated',
    now(), now()
  );

  INSERT INTO public.admin_profiles (id, username)
  VALUES (v_user_id, p_username);

  RETURN jsonb_build_object('id', v_user_id::text, 'username', p_username);
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_admin_user(p_user_id TEXT)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  DELETE FROM public.admin_profiles WHERE id = p_user_id::UUID;
  DELETE FROM auth.users WHERE id = p_user_id::UUID;

  RETURN FOUND;
END;
$$;

-- =====================================================
-- FIX: add category + icon columns to products
-- Run this to fix products that have NULL/missing category and icon
-- =====================================================
ALTER TABLE products ADD COLUMN IF NOT EXISTS category TEXT DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS icon TEXT DEFAULT '';

-- Assign categories from category_id FK
UPDATE products p SET category = c.name
FROM categories c
WHERE p.category_id = c.id AND (p.category IS NULL OR p.category = '');

-- For products without category_id, assign by name matching
UPDATE products SET category = 'Emparedados' WHERE (category IS NULL OR category = '') AND (name ILIKE '%jamón%' OR name ILIKE '%salami%' OR name ILIKE '%peperoni%' OR name ILIKE '%pollo%');
UPDATE products SET category = 'Empanadas'   WHERE (category IS NULL OR category = '') AND name ILIKE '%empanada%';
UPDATE products SET category = 'Especiales'  WHERE (category IS NULL OR category = '') AND (name ILIKE '%derretido%' OR name ILIKE '%hot dog%' OR name ILIKE '%hamburguesa%');
UPDATE products SET category = 'Café'        WHERE (category IS NULL OR category = '') AND (name ILIKE '%café%' OR name ILIKE '%cafe%' OR name ILIKE '%té%' OR name ILIKE '%te%');
UPDATE products SET category = 'Bebidas'     WHERE (category IS NULL OR category = '') AND (name ILIKE '%jugo%' OR name ILIKE '%agua%' OR name ILIKE '%bebida%' OR name ILIKE '%agua saborizada%');
UPDATE products SET category = 'Duros'       WHERE (category IS NULL OR category = '') AND name ILIKE '%duro%';
UPDATE products SET category = 'General'     WHERE category IS NULL OR category = '';

-- Assign icons by category
UPDATE products SET icon = 'breakfast_dining' WHERE (icon IS NULL OR icon = '') AND category = 'Emparedados';
UPDATE products SET icon = 'set_meal'         WHERE (icon IS NULL OR icon = '') AND category = 'Empanadas';
UPDATE products SET icon = 'fastfood'         WHERE (icon IS NULL OR icon = '') AND category = 'Especiales';
UPDATE products SET icon = 'coffee'           WHERE (icon IS NULL OR icon = '') AND category = 'Café';
UPDATE products SET icon = 'local_drink'      WHERE (icon IS NULL OR icon = '') AND category = 'Bebidas';
UPDATE products SET icon = 'icecream'         WHERE (icon IS NULL OR icon = '') AND category = 'Duros';
UPDATE products SET icon = 'inventory_2'      WHERE (icon IS NULL OR icon = '') AND (category IS NULL OR category = '' OR category = 'General');
