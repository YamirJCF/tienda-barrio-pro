-- ==============================================================================
-- MIGRATION: REFACTOR PHASE 1 - DATA LAYER FOUNDATION
-- Ref: DATA-001 | EXEC-001 (Block 1)
-- Description: Create configuration tables and System Config RPC.
-- Impact: ADDITIVE ONLY. No current logic is touched.
-- ==============================================================================

-- 1. PAYMENT METHODS (Tabla Maestra)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,          -- 'cash', 'nequi', 'fiado'
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    requires_reference BOOLEAN DEFAULT false, -- UI pide comprobante
    allows_change BOOLEAN DEFAULT false,      -- UI calcula devuelta
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: Public Read (Authenticated), Admin Write
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "read_active_methods" ON public.payment_methods;
CREATE POLICY "read_active_methods" ON public.payment_methods 
    FOR SELECT USING (true); -- Authenticated users can read valid methods

DROP POLICY IF EXISTS "admin_manage_methods" ON public.payment_methods;
CREATE POLICY "admin_manage_methods" ON public.payment_methods 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) OR
        auth.jwt() ->> 'role' = 'service_role'
    );

-- SEED DATA (Backward Compatibility)
INSERT INTO public.payment_methods (code, name, allows_change, requires_reference, sort_order)
VALUES 
    ('cash', 'Efectivo', true, false, 10),
    ('nequi', 'Nequi / Daviplata', false, true, 20),
    ('fiado', 'Fiado / Crédito', false, false, 30),
    ('card', 'Tarjeta Débito/Crédito', false, true, 40)
ON CONFLICT (code) DO NOTHING;


-- 2. TRANSACTION TYPES (Tabla Maestra)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transaction_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,          -- 'sale', 'expense', 'income'
    description TEXT NOT NULL,
    impact_stock INTEGER DEFAULT 0,     -- -1 (Resta), 0 (Neutro), 1 (Suma)
    impact_cash INTEGER DEFAULT 0,      -- -1 (Salida), 0 (Neutro), 1 (Entrada)
    is_system BOOLEAN DEFAULT false     -- Si true, no se puede borrar
);

-- RLS: Public Read
ALTER TABLE public.transaction_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "read_tx_types" ON public.transaction_types;
CREATE POLICY "read_tx_types" ON public.transaction_types FOR SELECT USING (true);

-- SEED DATA
INSERT INTO public.transaction_types (code, description, impact_stock, impact_cash, is_system)
VALUES
    ('sale', 'Venta Regular', -1, 1, true),
    ('expense', 'Gasto Operativo', 0, -1, true),
    ('income', 'Ingreso Extra', 0, 1, true),
    ('void', 'Anulación Venta', 1, -1, true),
    ('adjustment_in', 'Ajuste Inventario (+)', 1, 0, true),
    ('adjustment_out', 'Ajuste Inventario (-)', -1, 0, true)
ON CONFLICT (code) DO NOTHING;


-- 3. RPC: GET SYSTEM CONFIG (The Source of Truth)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_get_system_config()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'payment_methods', (
            SELECT jsonb_agg(pm) FROM (
                SELECT code, name, requires_reference, allows_change, is_active 
                FROM public.payment_methods 
                WHERE is_active = true 
                ORDER BY sort_order
            ) pm
        ),
        'transaction_types', (
            SELECT jsonb_agg(tt) FROM (
                SELECT code, description, impact_stock, impact_cash 
                FROM public.transaction_types
            ) tt
        ),
        'server_timestamp', now()
    );
END;
$$;
