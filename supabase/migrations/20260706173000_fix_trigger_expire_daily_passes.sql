-- MIGRATION: FIX_TRIGGER_EXPIRE_DAILY_PASSES, RETRY TIMESTAMP & ENABLE REALTIME
-- Date: 2026-07-06
-- Branch: feat/employee-access-gatekeeper-v2
-- Description:
-- 1. Updates expire_daily_passes() to expire approved passes with pass_date <= CURRENT_DATE
--    (prevents passes from previous days remaining 'approved' indefinitely).
-- 2. Updates solicitar_pase_diario() to reset requested_at = now() on retries,
--    extending the employee's 5-minute wait window on each "Reenviar Alerta" click.
-- 3. Safely enables Supabase Realtime for daily_passes table via idempotent DO block.

-- ============================================================
-- 1. Trigger: expire_daily_passes
--    FIX: pass_date <= CURRENT_DATE (was = CURRENT_DATE)
-- ============================================================
CREATE OR REPLACE FUNCTION public.expire_daily_passes()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.status = 'closed' AND OLD.status = 'open' THEN
    UPDATE public.daily_passes dp
    SET status = 'expired'
    FROM public.employees e
    WHERE dp.employee_id = e.id
      AND e.store_id = NEW.store_id
      AND dp.status = 'approved'
      AND dp.pass_date <= CURRENT_DATE; -- KEY FIX: sweeps today and any historical orphans
  END IF;
  RETURN NEW;
END;
$function$;

-- ============================================================
-- 2. RPC: solicitar_pase_diario
--    FIX: requested_at = now() on retry to reset the 5-minute timeout window
-- ============================================================
CREATE OR REPLACE FUNCTION public.solicitar_pase_diario(
  p_employee_id uuid,
  p_device_fingerprint text DEFAULT NULL::text
)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_existing_pass public.daily_passes%ROWTYPE;
  v_pass_id UUID;
BEGIN
  -- Check if a pass already exists for today
  SELECT * INTO v_existing_pass
  FROM public.daily_passes
  WHERE employee_id = p_employee_id AND pass_date = CURRENT_DATE;

  IF FOUND THEN

    -- Case: already approved → return immediately
    IF v_existing_pass.status = 'approved' THEN
      RETURN json_build_object('success', true, 'status', 'approved', 'pass_id', v_existing_pass.id);
    END IF;

    -- Case: still pending → handle retry
    IF v_existing_pass.status = 'pending' THEN
      IF v_existing_pass.retry_count >= 3 THEN
        RETURN json_build_object('success', false, 'error', 'Límite de intentos alcanzado', 'code', 'MAX_RETRIES');
      END IF;

      -- KEY FIX: Reset requested_at so the 5-min timeout window restarts from now
      UPDATE public.daily_passes
      SET
        retry_count         = retry_count + 1,
        device_fingerprint  = p_device_fingerprint,
        requested_at        = now()
      WHERE id = v_existing_pass.id;

      RETURN json_build_object(
        'success',     true,
        'status',      'pending',
        'pass_id',     v_existing_pass.id,
        'retry_count', v_existing_pass.retry_count + 1
      );
    END IF;

    -- Case: already processed (rejected/expired) → deny
    RETURN json_build_object('success', false, 'error', 'Pase ya procesado para hoy', 'code', 'ALREADY_PROCESSED');

  END IF;

  -- Case: no pass today → create fresh one
  INSERT INTO public.daily_passes (employee_id, device_fingerprint)
  VALUES (p_employee_id, p_device_fingerprint)
  RETURNING id INTO v_pass_id;

  RETURN json_build_object('success', true, 'status', 'pending', 'pass_id', v_pass_id);
END;
$function$;

-- ============================================================
-- 3. Enable Supabase Realtime for daily_passes (idempotent)
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname   = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename  = 'daily_passes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_passes;
  END IF;
END;
$$;
