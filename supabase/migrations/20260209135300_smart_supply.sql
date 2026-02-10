-- Smart Supply Migration
-- Based on: DSD-008 (FRD-008 Phase 2)
-- Includes: 4 QA Fixes for security and resilience

-- ============================================================================
-- 1. Crear Tabla Suppliers
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    delivery_day INTEGER CHECK (delivery_day BETWEEN 1 AND 7),
    frequency_days INTEGER NOT NULL DEFAULT 7,
    lead_time_days INTEGER NOT NULL DEFAULT 1,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- [QA FIX #2] Única Proveedor Default por Tienda
CREATE UNIQUE INDEX IF NOT EXISTS idx_suppliers_unique_default 
ON public.suppliers (store_id) 
WHERE is_default = TRUE;

-- ============================================================================
-- 2. RLS para Suppliers
-- ============================================================================
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view suppliers of their store"
ON public.suppliers FOR SELECT
USING (store_id IN (
    SELECT store_id FROM public.employees WHERE auth_user_id = auth.uid()
));

CREATE POLICY "Admins can manage suppliers"
ON public.suppliers FOR ALL
USING (store_id IN (
    SELECT store_id FROM public.employees 
    WHERE auth_user_id = auth.uid() AND role = 'admin'
));

-- ============================================================================
-- 3. Modificar Products (Agregar FK a Suppliers)
-- ============================================================================
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;

-- ============================================================================
-- 4. Trigger: Proveedor por Defecto al crear Tienda
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_default_supplier()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.suppliers (store_id, name, frequency_days, lead_time_days, is_default)
  VALUES (NEW.id, 'Proveedor General', 7, 1, TRUE);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_create_default_supplier ON public.stores;
CREATE TRIGGER trg_create_default_supplier
AFTER INSERT ON public.stores
FOR EACH ROW EXECUTE FUNCTION public.create_default_supplier();

-- ============================================================================
-- 5. Índice de Rendimiento (Crucial para Velocidad de Ventas)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_sale_items_product_date
ON public.sale_items (product_id, created_at DESC);

-- ============================================================================
-- 6. RPC: Smart Supply Report (Con 4 QA Fixes)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_smart_supply_report(p_store_id UUID)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    current_stock NUMERIC,
    velocity NUMERIC,
    doi NUMERIC,
    revenue_at_risk NUMERIC,
    status TEXT,
    suggestion TEXT
) AS $$
DECLARE
    v_window_days INT := 30;
BEGIN
    -- [QA FIX #1] Validación de Autorización (Previene IDOR)
    IF NOT EXISTS (
        SELECT 1 FROM public.employees 
        WHERE store_id = p_store_id 
        AND (auth_user_id = auth.uid() OR id = auth.uid())
    ) AND NOT EXISTS (
        SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Acceso no autorizado a store_id: %', p_store_id;
    END IF;

    RETURN QUERY
    WITH sales_stats AS (
        SELECT 
            si.product_id,
            SUM(si.quantity) as total_sold,
            COUNT(DISTINCT DATE(si.created_at)) as days_sold
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE s.store_id = p_store_id
        AND s.created_at >= (NOW() - (v_window_days || ' days')::INTERVAL)
        GROUP BY si.product_id
    ),
    product_calc AS (
        SELECT 
            p.id,
            p.name,
            p.current_stock,
            p.price,
            COALESCE(ss.total_sold, 0) as total_sold,
            COALESCE(ss.total_sold, 0) / NULLIF(v_window_days, 0) as velocity,
            COALESCE(sup.frequency_days, 7) as frequency_days,
            COALESCE(sup.lead_time_days, 1) as lead_time_days
        FROM products p
        LEFT JOIN suppliers sup ON p.supplier_id = sup.id
        LEFT JOIN sales_stats ss ON p.id = ss.product_id
        WHERE p.store_id = p_store_id
    )
    SELECT 
        pc.id,
        pc.name,
        pc.current_stock,
        pc.velocity,
        CASE WHEN pc.velocity > 0 THEN pc.current_stock / pc.velocity ELSE 999 END as doi,
        CASE 
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days 
            THEN (pc.lead_time_days - (COALESCE(pc.current_stock, 0) / pc.velocity)) * pc.velocity * COALESCE(pc.price, 0)
            ELSE 0 
        END as revenue_at_risk,
        CASE
            WHEN pc.velocity = 0 THEN 'UNKNOWN'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days THEN 'CRITICAL'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) THEN 'WARNING'
            ELSE 'OK'
        END::text as status,
        CASE
            WHEN pc.velocity = 0 THEN 'Recopilando datos...'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days 
                THEN 'Pedir urgente: se agotará antes de la próxima entrega.'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) 
                THEN 'Incluir en próximo pedido.'
            ELSE 'Stock suficiente por ahora.'
        END::text as suggestion
    FROM product_calc pc;

-- [QA FIX #4] Bloque de Excepción para Fail-Safe
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error en Smart Supply Report: %', SQLERRM;
    RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 7. Backfill: Crear Proveedor General para Tiendas Existentes
-- ============================================================================
INSERT INTO public.suppliers (store_id, name, frequency_days, lead_time_days, is_default)
SELECT id, 'Proveedor General', 7, 1, TRUE
FROM public.stores
WHERE NOT EXISTS (
    SELECT 1 FROM public.suppliers 
    WHERE suppliers.store_id = stores.id AND suppliers.is_default = TRUE
);
