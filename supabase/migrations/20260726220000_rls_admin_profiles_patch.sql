-- ==============================================================================
-- MIGRATION: RLS ADMIN PROFILES PATCH
-- Propósito: Refactoriza las políticas RLS que utilizaban public.employees
-- para usar public.get_current_store_id(), permitiendo el acceso correcto
-- a dueños de tiendas (admin_profiles) de forma nativa y robusta.
-- ==============================================================================

-- 1. Actualizar RLS de `suppliers`
DROP POLICY IF EXISTS "Users can view suppliers of their store" ON public.suppliers;
CREATE POLICY "Users can view suppliers of their store" ON public.suppliers
FOR SELECT USING (store_id = public.get_current_store_id());

-- 2. Actualizar RLS de `product_price_history`
DROP POLICY IF EXISTS "Employees can view price history" ON public.product_price_history;
CREATE POLICY "Users can view price history of their store" ON public.product_price_history
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.products p
        WHERE p.id = product_id AND p.store_id = public.get_current_store_id()
    )
);

-- 3. Actualizar RLS de `sale_item_batches`
DROP POLICY IF EXISTS "Employees can view sale item batches" ON public.sale_item_batches;
CREATE POLICY "Users can view sale item batches of their store" ON public.sale_item_batches
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.sales s
        INNER JOIN public.sale_items si ON si.sale_id = s.id
        WHERE si.id = sale_item_id AND s.store_id = public.get_current_store_id()
    )
);

-- 4. Actualizar RLS de `supplier_invoices` (Select)
DROP POLICY IF EXISTS "Users can view invoices from their store" ON public.supplier_invoices;
CREATE POLICY "Users can view invoices from their store" ON public.supplier_invoices
FOR SELECT USING (store_id = public.get_current_store_id());

-- 5. Actualizar RLS de `supplier_invoices` (Manage)
DROP POLICY IF EXISTS "Admins can manage invoices" ON public.supplier_invoices;
CREATE POLICY "Admins can manage invoices" ON public.supplier_invoices
FOR ALL USING (
    store_id = public.get_current_store_id() AND 
    EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid())
);

-- 6. Actualizar RLS de `inventory_movement_batches`
DROP POLICY IF EXISTS "movement_batches_select_store" ON public.inventory_movement_batches;
CREATE POLICY "movement_batches_select_store" ON public.inventory_movement_batches
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.inventory_movements m 
        INNER JOIN public.products p ON p.id = m.product_id
        WHERE m.id = movement_id AND p.store_id = public.get_current_store_id()
    )
);
