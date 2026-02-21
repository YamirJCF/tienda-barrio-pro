-- =============================================
-- FIFO PHASE 1: REORGANIZACIÓN
-- =============================================
-- Descripción: Elimina el trigger viejo update_product_stock, corrige 
--   sync_product_stock_from_batches (bug columna cost→cost_price),
--   y crea el puente movements→batches.
-- Impacto: CRÍTICO — Cambia el flujo de gestión de stock.
-- Autor: @[/data]

-- =========================================
-- 1. DROP: Trigger viejo y función obsoleta
-- =========================================
-- update_product_stock() gestionaba stock directamente desde inventory_movements.
-- Ahora inventory_batches es la ÚNICA fuente de verdad.

DROP TRIGGER IF EXISTS trg_update_stock ON public.inventory_movements;
DROP FUNCTION IF EXISTS public.update_product_stock();

-- =========================================
-- 2. FIX: sync_product_stock_from_batches()
-- =========================================
-- BUG: Referenciaba columna "cost" que no existe. La columna real es "cost_price".
-- MEJORA: Agregado manejo de DELETE (usa OLD en vez de NEW), SECURITY DEFINER,
--   y SET search_path para seguridad.

CREATE OR REPLACE FUNCTION public.sync_product_stock_from_batches()
RETURNS TRIGGER AS $$
DECLARE
    v_product_id UUID;
    v_total_stock DECIMAL;
    v_active_cost DECIMAL;
BEGIN
    -- Handle DELETE (NEW is null, use OLD)
    v_product_id := COALESCE(NEW.product_id, OLD.product_id);

    -- 1. Calculate Total Stock from all batches
    SELECT COALESCE(SUM(quantity_remaining), 0)
    INTO v_total_stock
    FROM public.inventory_batches
    WHERE product_id = v_product_id;

    -- 2. Find Oldest Active Batch Cost (FIFO: we sell the oldest first)
    SELECT cost_unit
    INTO v_active_cost
    FROM public.inventory_batches
    WHERE product_id = v_product_id AND quantity_remaining > 0
    ORDER BY created_at ASC
    LIMIT 1;

    -- 3. Update Product
    IF v_active_cost IS NOT NULL THEN
        UPDATE public.products
        SET current_stock = v_total_stock,
            cost_price = v_active_cost
        WHERE id = v_product_id;
    ELSE
        -- No active batches (out of stock) — preserve last known cost
        UPDATE public.products
        SET current_stock = v_total_stock
        WHERE id = v_product_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';

-- =========================================
-- 3. NEW: bridge_movement_to_batch()
-- =========================================
-- Traduce inventory_movements → inventory_batches.
-- Cada tipo de movimiento tiene un comportamiento específico:
--   entrada/devolucion → Crea nuevo lote
--   salida             → Consume lotes FIFO
--   CORRECCION_SISTEMA → Crea lote (+) o consume FIFO (-)
--   venta              → NO-OP (consume_stock_fifo ya fue llamado por rpc_procesar_venta_v2)

CREATE OR REPLACE FUNCTION public.bridge_movement_to_batch()
RETURNS TRIGGER AS $$
DECLARE
    v_cost DECIMAL;
BEGIN
    CASE NEW.movement_type
        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        -- ENTRADA / DEVOLUCIÓN: Crear nuevo lote
        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        WHEN 'entrada', 'devolucion' THEN
            v_cost := COALESCE(
                NEW.unit_cost,
                (SELECT cost_price FROM public.products WHERE id = NEW.product_id),
                0
            );

            INSERT INTO public.inventory_batches (
                product_id, quantity_initial, quantity_remaining,
                cost_unit, created_by
            ) VALUES (
                NEW.product_id, NEW.quantity, NEW.quantity,
                v_cost, NEW.created_by
            );

        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        -- SALIDA: Consumir lotes FIFO
        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        WHEN 'salida' THEN
            PERFORM public.consume_stock_fifo(NEW.product_id, NEW.quantity);

        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        -- CORRECCIÓN SISTEMA: Positivo=crear lote, Negativo=consumir FIFO
        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        WHEN 'CORRECCION_SISTEMA' THEN
            IF NEW.quantity > 0 THEN
                v_cost := COALESCE(
                    (SELECT cost_price FROM public.products WHERE id = NEW.product_id),
                    0
                );
                INSERT INTO public.inventory_batches (
                    product_id, quantity_initial, quantity_remaining,
                    cost_unit, created_by
                ) VALUES (
                    NEW.product_id, NEW.quantity, NEW.quantity,
                    v_cost, NEW.created_by
                );
            ELSE
                -- Corrección negativa: consumir FIFO con valor absoluto
                PERFORM public.consume_stock_fifo(NEW.product_id, ABS(NEW.quantity));
            END IF;

        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        -- VENTA: NO-OP
        -- consume_stock_fifo() ya fue llamado por rpc_procesar_venta_v2
        -- ANTES del INSERT del movimiento.
        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        WHEN 'venta' THEN
            NULL;

        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        -- OTROS: No-op (ingreso, gasto, ajuste_manual)
        -- Estos tipos no afectan inventario de productos
        -- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        ELSE
            NULL;
    END CASE;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';

-- =========================================
-- 4. CREATE TRIGGER: Bridge on inventory_movements
-- =========================================

CREATE TRIGGER trg_bridge_movement_to_batch
AFTER INSERT ON public.inventory_movements
FOR EACH ROW
EXECUTE FUNCTION public.bridge_movement_to_batch();
