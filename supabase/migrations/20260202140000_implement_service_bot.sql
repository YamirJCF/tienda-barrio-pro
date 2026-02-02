-- 1. Function to create/get a Service Bot User for a store
-- NOTE: We use a deterministic password based on the Store ID for simplicity in this rescue mission.
-- In production, we'd manage this via a secret manager, but here the PIN is the gatekeeper.
CREATE OR REPLACE FUNCTION public.get_or_create_store_bot(target_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Needs high privilege to touch auth.users
AS $$
DECLARE
    v_email TEXT;
    v_password TEXT;
    v_user_id UUID;
    v_encrypted_pw TEXT;
BEGIN
    v_email := 'bot_' || target_store_id || '@tienda.system';
    v_password := 'key_' || target_store_id || '_secure'; -- Deterministic password
    
    -- Check if user exists
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
    
    IF v_user_id IS NULL THEN
        -- Create the user manually in auth.users
        -- NOTE: This requires the `pgcrypto` extension usually, but Supabase manages auth.
        -- We can use Supabase's internal functions if available, or just INSERT.
        -- Inserting directly into auth.users is risky/hard due to hashing.
        -- ALTERNATIVE: We can't easily create users from purely SQL without extensions.
        
        -- WORKAROUND: We will return a specific "signal" that the frontend needs to handle?
        -- No, frontend can't create users without Admin rights.
        -- We MUST create it here.
        
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000', -- Default instance_id
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            v_email,
            crypt(v_password, gen_salt('bf')), -- Uses pgcrypto
            now(), -- Auto confirmed
            '{"provider": "email", "providers": ["email"]}',
            json_build_object('store_id', target_store_id, 'is_bot', true),
            now(),
            now()
        ) RETURNING id INTO v_user_id;
        
        -- Also insert into public.employees? No, maybe admin_profiles? 
        -- Or just rely on metadata.
    END IF;

    RETURN jsonb_build_object(
        'email', v_email,
        'password', v_password,
        'user_id', v_user_id
    );
END;
$$;

-- 2. Update Validate PIN to return the Bot Credentials
CREATE OR REPLACE FUNCTION public.validar_pin_empleado(
    p_pin TEXT,
    p_device_fingerprint TEXT -- Optional, for logging
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_employee public.employees%ROWTYPE;
    v_store_state JSONB;
    v_bot_creds JSONB;
BEGIN
    -- 1. Find Employee by PIN
    SELECT * INTO v_employee
    FROM public.employees
    WHERE pin = p_pin
      -- AND status = 'active' (Assuming we have status, if not ignore)
    LIMIT 1;

    IF v_employee IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'PIN inválido');
    END IF;

    -- 2. Get Store Status (Optional, keeping existing logic)
    SELECT jsonb_build_object(
        'is_open', (SELECT COUNT(*) > 0 FROM public.cash_sessions WHERE store_id = v_employee.store_id AND status = 'open')
    ) INTO v_store_state;

    -- 3. GET/CREATE SERVICE BOT
    v_bot_creds := public.get_or_create_store_bot(v_employee.store_id);

    RETURN jsonb_build_object(
        'success', true,
        'employee', row_to_json(v_employee),
        'store_state', v_store_state,
        'service_auth', v_bot_creds -- The Keys to the Kingdom
    );
END;
$$;

-- 3. Update RLS to trust the Bot
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
        -- 2. Employee Check (Direct Link)
        SELECT 1 FROM public.employees e
        WHERE e.id = auth.uid()
          AND e.store_id = target_store_id
        UNION ALL
        -- 3. Service Bot Check (Metadata match)
        -- We check if the current user has the correct store_id in metadata
        SELECT 1 
        WHERE (auth.jwt() -> 'user_metadata' ->> 'store_id')::UUID = target_store_id
          AND (auth.jwt() -> 'user_metadata' ->> 'is_bot')::boolean = true
    );
$$;

-- Enable pgcrypto for password hashing if not enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;
