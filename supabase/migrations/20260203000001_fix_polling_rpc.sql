-- FIX: ENSURE CHECK_MY_PASS_STATUS RPC EXISTS
-- Datum: 2026-02-03
-- Description: 
-- Explicitly re-creates the polling RPC function to resolve 400 Bad Request errors.
-- This ensures the function exists, accepts UUID, and has correct permissions.

CREATE OR REPLACE FUNCTION public.check_my_pass_status(p_pass_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result RECORD;
BEGIN
    -- Select pass and employee details
    SELECT dp.status as pass_status, e.* 
    INTO v_result
    FROM public.daily_passes dp
    JOIN public.employees e ON dp.employee_id = e.id
    WHERE dp.id = p_pass_id;

    IF NOT FOUND THEN
         -- Return explicit status so frontend knows it vanished
         RETURN jsonb_build_object('status', 'not_found');
    END IF;

    -- If approved, return employee data for login
    IF v_result.pass_status = 'approved' THEN
        RETURN jsonb_build_object(
            'status', 'approved',
            'employee', jsonb_build_object(
                'id', v_result.id,
                'name', v_result.name,
                'role', 'employee',
                'store_id', v_result.store_id,
                'username', v_result.alias, 
                'permissions', v_result.permissions
            )
        );
    ELSE
        -- Return simple status (pending, rejected, expired)
        RETURN jsonb_build_object('status', v_result.pass_status);
    END IF;
END;
$$;

-- IMPORTANT: Grant permissions to anonymous users so they can poll
GRANT EXECUTE ON FUNCTION public.check_my_pass_status(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.check_my_pass_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_my_pass_status(uuid) TO service_role;
