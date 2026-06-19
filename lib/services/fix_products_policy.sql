-- Fix: products catalog needs anon read (students need to see products to buy)
-- Run in Supabase SQL Editor

CREATE POLICY "products_anon_read" ON products FOR SELECT USING (true);

-- Also verify the RPC functions exist
-- DO $$
-- BEGIN
--   RAISE NOTICE 'Functions should exist: search_student_names, get_student_by_token, get_product_catalog';
-- END $$;
