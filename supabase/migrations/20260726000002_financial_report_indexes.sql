-- Migration: Performance indexes for comprehensive financial report
-- Date: 2026-07-26
-- FRD-018: Soporte de rendimiento para rpc_get_comprehensive_financial_report

-- Query principal: ventas por tienda + rango de fecha + no anuladas
CREATE INDEX IF NOT EXISTS idx_sales_store_date_voided
ON public.sales (store_id, created_at, is_voided)
WHERE is_voided = FALSE;

-- JOIN sale_items → sale_item_batches (JOIN masivo para COGS)
CREATE INDEX IF NOT EXISTS idx_sale_item_batches_item_id
ON public.sale_item_batches (sale_item_id);

-- JOIN sale_items → sales
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id
ON public.sale_items (sale_id);

-- Gastos operativos: cash_movements por sesión y tipo en el período
CREATE INDEX IF NOT EXISTS idx_cash_movements_session_type_date
ON public.cash_movements (session_id, movement_type, created_at);

-- JOIN cash_sessions → store_id para filtrar por tienda en OPEX
CREATE INDEX IF NOT EXISTS idx_cash_sessions_store_status
ON public.cash_sessions (store_id, status);

-- Valor inventario: lotes activos con stock, por producto
CREATE INDEX IF NOT EXISTS idx_inventory_batches_active_cost
ON public.inventory_batches (product_id, is_active, quantity_remaining)
WHERE is_active = TRUE AND quantity_remaining > 0;
