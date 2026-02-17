-- QA-FIX-003: Remove redundant/conflicting SELECT policies from products table
-- Keeping: products_select_store, products_insert_store, products_update_store, products_delete_admin_only
-- Removing: products_select_policy (duplicate SELECT with is_store_member),
--           products_policy_unified (ALL policy conflicts with individual policies)
-- Rollback: See supabase/rollback_rls_products.sql

DROP POLICY IF EXISTS "products_select_policy" ON products;
DROP POLICY IF EXISTS "products_policy_unified" ON products;
