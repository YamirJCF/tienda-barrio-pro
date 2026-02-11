-- 🛡️ SECURITY AUDIT SCRIPT (OT-003)
-- Execute this in Supabase SQL Editor to validate RLS coverage.

-- 1. Check for tables with RLS DISABLED (Critical)
-- Expected Result: 0 rows
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND rowsecurity = false;

-- 2. List all active policies for review
-- audit_action: Review 'cmd' (ALL, SELECT, INSERT, etc) and 'qual' logic.
SELECT schemaname, tablename, policyname, cmd, roles, qual, with_check 
FROM pg_policies 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- 3. Check for specific high-risk tables (users, sales, payments)
-- Ensure they appear in the policies list.
