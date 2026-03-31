-- MIGRATION: RESET_PERMISSIONS_MVP
-- Datum: 2026-02-02
-- Description: 
-- DANGER: This truncates (deletes all rows) from the 'daily_passes' table.
-- Use this to force all employees to re-authenticate and get new Auto-Approved passes.
-- This ensures no old/broken sessions remain affecting the tests.

TRUNCATE TABLE public.daily_passes RESTART IDENTITY CASCADE;

-- Optional: Verify it's empty
SELECT COUNT(*) as remaining_passes FROM public.daily_passes;
