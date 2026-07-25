-- Migration: Add PIN hash and Crypto Salt to Stores
-- Date: 2026-07-25
-- Description: Enables pgcrypto extension, adds pin_hash and crypto_salt columns, and implements rpc_verify_store_pin

-- 1. Enable pgcrypto extension for secure bcrypt hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Add pin_hash and crypto_salt columns to stores table
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS pin_hash TEXT;
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS crypto_salt TEXT;

-- 3. Create RPC for store PIN verification with bcrypt
CREATE OR REPLACE FUNCTION rpc_verify_store_pin(p_store_id UUID, p_pin TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    stored_hash TEXT;
BEGIN
    SELECT pin_hash INTO stored_hash FROM public.stores WHERE id = p_store_id;
    
    IF stored_hash IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN crypt(p_pin, stored_hash) = stored_hash;
END;
$$;

-- 4. Grant execution privileges on the RPC
GRANT EXECUTE ON FUNCTION rpc_verify_store_pin(UUID, TEXT) TO authenticated, anon;
