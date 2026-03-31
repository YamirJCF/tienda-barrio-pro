-- 1. Add auth_user_id to daily_passes to link Supabase Session
ALTER TABLE public.daily_passes 
ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);

-- 2. Update the Request RPC to accept the session ID
DROP FUNCTION IF EXISTS public.solicitar_pase_diario(uuid, text); -- Fix: Drop first to avoid 42P13 error

CREATE OR REPLACE FUNCTION public.solicitar_pase_diario(
    p_employee_id UUID,
    p_device_fingerprint TEXT
    -- p_auth_user_id is implicit via auth.uid() or passed explicitly? 
    -- Better to pass explicitly or rely on auth.uid() if called from anon session.
    -- Let's rely on auth.uid() for security, ensuring the caller owns the token.
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_store_id UUID;
    v_existing_pass_id UUID;
    v_status TEXT;
    v_retry_count INT;
    v_auth_id UUID;
BEGIN
    -- Get current Auth ID (Anonymous or Real)
    v_auth_id := auth.uid();

    -- Get Employee Info
    SELECT store_id INTO v_store_id
    FROM public.employees
    WHERE id = p_employee_id;

    IF v_store_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Empleado no encontrado');
    END IF;

    -- Check if active pass exists
    SELECT id, status, retry_count INTO v_existing_pass_id, v_status, v_retry_count
    FROM public.daily_passes
    WHERE employee_id = p_employee_id
      AND pass_date = CURRENT_DATE
      AND device_fingerprint = p_device_fingerprint;

    IF v_existing_pass_id IS NOT NULL THEN
        -- If creating/updating, ensure we link the auth_id
        UPDATE public.daily_passes
        SET auth_user_id = v_auth_id
        WHERE id = v_existing_pass_id;

        RETURN jsonb_build_object(
            'success', true, 
            'status', v_status,
            'retry_count', v_retry_count,
            'message', 'Pase existente encontrado'
        );
    END IF;

    -- Create new pass
    INSERT INTO public.daily_passes (
        employee_id, 
        pass_date, 
        status, 
        device_fingerprint, 
        retry_count, 
        auth_user_id -- Link the session!
    )
    VALUES (
        p_employee_id, 
        CURRENT_DATE, 
        'pending', 
        p_device_fingerprint, 
        0,
        v_auth_id
    );

    RETURN jsonb_build_object(
        'success', true, 
        'status', 'pending',
        'retry_count', 0
    );
END;
$$;

-- 3. The "Magical" RLS Helper Function
-- This function replaces the basic check. It checks:
-- Is User the Owner? OR Is User an Approved Employee (via Daily Pass)?
CREATE OR REPLACE FUNCTION public.is_store_member(target_store_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        -- 1. Admin/Owner Check
        SELECT 1 FROM public.admin_profiles ap
        WHERE ap.id = auth.uid()
          AND ap.store_id = target_store_id
        UNION ALL
        -- 2. Employee Check (Direct Link - Legacy/Future for Real Accounts)
        SELECT 1 FROM public.employees e
        WHERE e.id = auth.uid()
          AND e.store_id = target_store_id
        UNION ALL
        -- 3. Anonymous Session Link (The Fix!)
        SELECT 1 FROM public.daily_passes dp
        JOIN public.employees e ON dp.employee_id = e.id
        WHERE dp.auth_user_id = auth.uid()   -- The Anon ID
          AND dp.status = 'approved'         -- Must be approved
          AND dp.pass_date = CURRENT_DATE    -- Must be today
          AND e.store_id = target_store_id   -- Must match store
    );
$$;

-- 4. Update Policies to use the new helper (Example: Sales)
-- We need to drop and recreate policies that relied on the old logic or update them to use is_store_member
-- Actually, let's redefine the generic policies.

-- Policy for Sales
DROP POLICY IF EXISTS "sales_select_policy" ON public.sales;
CREATE POLICY "sales_select_policy" ON public.sales 
FOR SELECT USING (public.is_store_member(store_id));

-- Policy for Clients
DROP POLICY IF EXISTS "clients_select_policy" ON public.clients;
CREATE POLICY "clients_select_policy" ON public.clients
FOR SELECT USING (public.is_store_member(store_id));

-- Policy for Products
DROP POLICY IF EXISTS "products_select_policy" ON public.products;
CREATE POLICY "products_select_policy" ON public.products
FOR SELECT USING (public.is_store_member(store_id));

-- Policy for Cash Movements (Linked via Session)
DROP POLICY IF EXISTS "cash_movements_select_policy" ON public.cash_movements;
CREATE POLICY "cash_movements_select_policy" ON public.cash_movements
FOR SELECT USING (
  public.is_store_member(
    (SELECT store_id FROM public.cash_sessions WHERE id = session_id)
  )
);

-- Policy for Expenses - REMOVED as table may not exist yet
-- DROP POLICY IF EXISTS "expenses_select_policy" ON public.expenses;
-- CREATE POLICY "expenses_select_policy" ON public.expenses
-- FOR SELECT USING (public.is_store_member(store_id));

-- GRANT EXECUTE just in case
GRANT EXECUTE ON FUNCTION public.is_store_member TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.solicitar_pase_diario TO authenticated, anon;
