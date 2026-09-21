-- =============================================
-- WO-PHASE5-001: MIGRACIÓN A INVENTARIO FIFO (LOTES)
-- =============================================
-- Autor: @[/data]
-- Descripción: Transición de modelo de stock plano a modelo de lotes (batches).
-- Impacto: Crítico (Tocar datos financieros).

BEGIN;

-- 1. CREACIÓN DE TABLA DE LOTES
CREATE TABLE IF NOT EXISTS public.inventory_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    quantity_initial DECIMAL(10,2) NOT NULL CHECK (quantity_initial > 0),
    quantity_remaining DECIMAL(10,2) NOT NULL CHECK (quantity_remaining >= 0),
    cost_unit DECIMAL(12,0) NOT NULL CHECK (cost_unit >= 0),
    is_active BOOLEAN GENERATED ALWAYS AS (quantity_remaining > 0) STORED,
    
    -- Auditoría
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    created_by UUID REFERENCES public.employees(id),
    
    -- Constraint: Remaining no puede superar Initial
    CONSTRAINT chk_remaining_valid CHECK (quantity_remaining <= quantity_initial)
);

-- Índices para búsqueda rápida FIFO
CREATE INDEX IF NOT EXISTS idx_batches_fifo 
ON public.inventory_batches(product_id, created_at ASC) 
WHERE quantity_remaining > 0;

-- RLS: Seguridad Primero
ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "batches_select_store" ON public.inventory_batches
FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.products p WHERE p.id = product_id AND p.store_id = get_current_store_id())
);

-- 2. FUNCIÓN DE CONSUMO FIFO (Lógica Core)
CREATE OR REPLACE FUNCTION public.consume_stock_fifo(
    p_product_id UUID,
    p_quantity_needed DECIMAL
)
RETURNS TABLE (batch_id UUID, quantity_taken DECIMAL, cost_unit DECIMAL) AS $$
DECLARE
    v_qty_left DECIMAL := p_quantity_needed;
    v_batch RECORD;
    v_take DECIMAL;
BEGIN
    -- Validar stock total suficiente (Quick check)
    IF (SELECT current_stock FROM public.products WHERE id = p_product_id) < p_quantity_needed THEN
        RAISE EXCEPTION 'Stock insuficiente (FIFO Check)';
    END IF;

    -- Iterar lotes activos por antigüedad
    FOR v_batch IN 
        SELECT id, quantity_remaining, cost_unit 
        FROM public.inventory_batches 
        WHERE product_id = p_product_id AND quantity_remaining > 0
        ORDER BY created_at ASC
        FOR UPDATE -- Lock rows to prevent race conditions
    LOOP
        IF v_qty_left <= 0 THEN EXIT; END IF;

        -- Calcular cuánto tomar de este lote
        v_take := LEAST(v_qty_left, v_batch.quantity_remaining);
        
        -- Actualizar lote
        UPDATE public.inventory_batches 
        SET quantity_remaining = quantity_remaining - v_take
        WHERE id = v_batch.id;

        -- Retornar info para costeo de venta
        batch_id := v_batch.id;
        quantity_taken := v_take;
        cost_unit := v_batch.cost_unit;
        RETURN NEXT;

        v_qty_left := v_qty_left - v_take;
    END LOOP;

    IF v_qty_left > 0 THEN
        RAISE EXCEPTION 'Inconsistencia de Inventario: Stock en Products no coincide con Lotes.';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. MIGRACIÓN DE DATOS (SEEDING INICIAL)
-- Convierte el stock actual "plano" en el "Lote Génesis"
INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, created_at)
SELECT 
    id, 
    current_stock, 
    current_stock, 
    COALESCE(cost_price, price * 0.7), -- Fallback si no hay costo: 70% del precio venta
    now()
FROM public.products
WHERE current_stock > 0;

-- 4. TRIGGER DE SINCRONIZACIÓN (Products <-> Batches)
-- Mantiene products.current_stock actualizado automáticamente
CREATE OR REPLACE FUNCTION public.sync_product_stock_from_batches()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.products
    SET current_stock = (
        SELECT COALESCE(SUM(quantity_remaining), 0)
        FROM public.inventory_batches
        WHERE product_id = NEW.product_id
    )
    WHERE id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_batches
AFTER INSERT OR UPDATE OR DELETE ON public.inventory_batches
FOR EACH ROW EXECUTE FUNCTION public.sync_product_stock_from_batches();

COMMIT;
