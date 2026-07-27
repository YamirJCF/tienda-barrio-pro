-- ============================================================================
-- ⚠️ ADVERTENCIA CRÍTICA: SCRIPT DE REVERSA (DOWN MIGRATION) ⚠️
-- ============================================================================
-- Este script ejecuta operaciones destructivas (DROP TABLE ... CASCADE).
-- Borrará irrevocablemente todas las facturas de proveedores y los historiales
-- de pago en cascada.
-- 
-- NO EJECUTAR este script en producción a menos que se trate de un escenario
-- de "Botón de Pánico" inmediato post-deploy y se asuma la pérdida de datos.
-- Por diseño del proyecto (Opción D), las migraciones de Supabase son
-- append-only e inmutables. Este archivo se mantiene fuera de `migrations/`
-- expresamente para evitar su ejecución accidental por el CLI.
-- ============================================================================

-- Revertir Modificación de rpc_check_and_force_close_shifts
-- Restauramos la función original que solo incluye 'gasto'
CREATE OR REPLACE FUNCTION rpc_check_and_force_close_shifts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $FUNC$
DECLARE
    r RECORD;
    v_ingresos DECIMAL;
    v_gastos DECIMAL;
    v_expected DECIMAL;
    closed_count INT := 0;
BEGIN
    FOR r IN 
        SELECT id, store_id, opening_balance, opened_at 
        FROM public.cash_sessions 
        WHERE status = 'open' 
          AND opened_at < (NOW() - INTERVAL '24 hours')
    LOOP
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'ingreso';
        
        SELECT COALESCE(SUM(amount), 0) INTO v_gastos
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'gasto';
        
        v_expected := r.opening_balance + v_ingresos - v_gastos;

        UPDATE public.cash_sessions 
        SET status         = 'closed',
            forced_close   = true,
            expected_balance = v_expected,
            actual_balance = NULL,
            difference     = NULL,
            closed_at      = NOW()
        WHERE id = r.id;

        INSERT INTO public.audit_logs (
            store_id, action, entity, entity_id, payload, created_at
        ) VALUES (
            r.store_id,
            'FORCED_CLOSE_24H',
            'cash_sessions',
            r.id,
            jsonb_build_object(
                'reason',           'Shift exceeded 24 hours without manual closure',
                'opened_at',        r.opened_at,
                'forced_at',        NOW(),
                'expected_balance', v_expected
            ),
            NOW()
        );

        INSERT INTO public.notifications (
            store_id, type, title, message, audience, is_read, created_at
        ) VALUES (
            r.store_id,
            'finance',
            '⚠️ Cierre Forzado de Caja (24 Horas)',
            'Una caja fue cerrada automáticamente por el sistema tras cumplir 24 horas abierta. Se requiere verificación de saldo antes de iniciar nuevo turno.',
            'admin',
            FALSE,
            NOW()
        );

        closed_count := closed_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'closed_shifts', closed_count);
END;
$FUNC$;

-- Eliminar el RPC de pago
DROP FUNCTION IF EXISTS public.rpc_pay_supplier_invoice(UUID, DECIMAL);

-- Restaurar el trigger bridge_movement_to_batch a su estado anterior (Fase 1 solamente)
CREATE OR REPLACE FUNCTION public.bridge_movement_to_batch()
RETURNS TRIGGER AS $FUNC$
DECLARE
    v_cost DECIMAL;
    v_batch_record RECORD;
BEGIN
    CASE NEW.movement_type
        WHEN 'entrada' THEN
            v_cost := COALESCE((SELECT cost_price FROM public.products WHERE id = NEW.product_id), 0);
            INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, created_by) 
            VALUES (NEW.product_id, NEW.quantity, NEW.quantity, v_cost, NEW.created_by);

        WHEN 'devolucion', 'salida' THEN
            PERFORM public.consume_stock_fifo(NEW.product_id, NEW.quantity);

        WHEN 'CORRECCION_SISTEMA' THEN
            IF NEW.quantity > 0 THEN
                v_cost := COALESCE((SELECT cost_price FROM public.products WHERE id = NEW.product_id), 0);
                INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, created_by) 
                VALUES (NEW.product_id, NEW.quantity, NEW.quantity, v_cost, NEW.created_by);
            ELSE
                PERFORM public.consume_stock_fifo(NEW.product_id, ABS(NEW.quantity));
            END IF;
            
        WHEN 'venta' THEN
            NULL;

        ELSE NULL;
    END CASE;

    RETURN NEW;
END;
$FUNC$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';

-- Eliminar Políticas RLS y Tablas Nuevas
DROP POLICY IF EXISTS "movement_batches_select_store" ON public.inventory_movement_batches;
ALTER TABLE public.inventory_movement_batches DISABLE ROW LEVEL SECURITY;
DROP TABLE IF EXISTS public.inventory_movement_batches CASCADE;

DROP POLICY IF EXISTS "Users can view invoices from their store" ON public.supplier_invoices;
DROP POLICY IF EXISTS "Admins can manage invoices" ON public.supplier_invoices;
ALTER TABLE public.supplier_invoices DISABLE ROW LEVEL SECURITY;

-- Eliminar Constraints y Columnas Añadidas
ALTER TABLE public.inventory_movements DROP CONSTRAINT IF EXISTS chk_correccion_no_supplier;
ALTER TABLE public.inventory_batches DROP COLUMN IF EXISTS source_movement_id CASCADE;
ALTER TABLE public.inventory_movements DROP COLUMN IF EXISTS reference_invoice_id CASCADE;

-- Eliminar Tabla Base (Cuentas por Pagar)
DROP TABLE IF EXISTS public.supplier_invoices CASCADE;

-- (Opcional) No eliminamos metadata de notifications ni el índice de products por si se usan en otro lado.
