-- Add role support to admin user creation
-- Run in Supabase SQL Editor

-- 1. Add role column to admin_profiles
ALTER TABLE admin_profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'admin';

-- 2. Update create_admin_user function to accept role
CREATE OR REPLACE FUNCTION public.create_admin_user(p_username TEXT, p_password TEXT, p_role TEXT DEFAULT 'admin')
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
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
    jsonb_build_object('role', p_role),
    'authenticated', 'authenticated',
    now(), now()
  );

  INSERT INTO public.admin_profiles (id, username, role)
  VALUES (v_user_id, p_username, p_role);

  RETURN jsonb_build_object('id', v_user_id::text, 'username', p_username, 'role', p_role);
END;
$$;
