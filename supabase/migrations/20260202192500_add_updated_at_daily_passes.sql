-- MIGRATION: ADD_UPDATED_AT_DAILY_PASSES
-- Datum: 2026-02-02
-- Description:
-- Adds the `updated_at` column to `daily_passes`.
-- This is required by the `request_employee_access` UPSERT logic which updates this field.
-- Also sets a default value and creates a trigger to auto-update it.

ALTER TABLE public.daily_passes 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

-- Create Trigger to auto-update (Standard Practice)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_daily_passes_updated_at ON public.daily_passes;

CREATE TRIGGER update_daily_passes_updated_at
    BEFORE UPDATE ON public.daily_passes
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();
