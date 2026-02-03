-- BACKUP SNAPSHOT: V1 (Before Consolidation)
-- Datum: 2026-02-02

-- 1. get_current_store_id (with RLS fix)
CREATE OR REPLACE FUNCTION public.get_current_store_id()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_store_id UUID;
BEGIN
  v_store_id := (auth.jwt() -> 'app_metadata' ->> 'store_id')::uuid;
  IF v_store_id IS NOT NULL THEN RETURN v_store_id; END IF;

  SELECT store_id INTO v_store_id FROM public.admin_profiles WHERE id = auth.uid();
  IF v_store_id IS NOT NULL THEN RETURN v_store_id; END IF;

  SELECT store_id INTO v_store_id FROM public.employees WHERE id = auth.uid();
  IF v_store_id IS NOT NULL THEN RETURN v_store_id; END IF;

  SELECT store_id INTO v_store_id FROM public.daily_passes
  WHERE auth_user_id = auth.uid() AND status = 'approved' AND pass_date = CURRENT_DATE;

  RETURN v_store_id;
END;
$function$;

-- 2. request_employee_access (Last known good state)
-- (Omitted full body for brevity in backup, but conceptually linked to fix_pass_upsert.sql)
