-- Descripción del cambio: Estructura FIFO Pricing y Trazabilidad de lotes
-- Autor: Antigravity

-- 1. DDL (Create/Alter Tables)

-- Tabla product_price_history (Catálogo)
CREATE TABLE IF NOT EXISTS public.product_price_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    purchase_price DECIMAL(12,2) NOT NULL CHECK (purchase_price >= 0),
    sale_price DECIMAL(12,2) NOT NULL CHECK (sale_price >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_product_price_history_product_id ON public.product_price_history(product_id);
CREATE INDEX IF NOT EXISTS idx_product_price_history_created_at ON public.product_price_history(created_at);

-- Tabla sale_item_batches (Trazabilidad estricta Venta-Lote)
CREATE TABLE IF NOT EXISTS public.sale_item_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_item_id UUID NOT NULL REFERENCES public.sale_items(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES public.inventory_batches(id) ON DELETE RESTRICT,
    quantity_consumed DECIMAL(10,2) NOT NULL CHECK (quantity_consumed > 0),
    unit_cost DECIMAL(12,2) NOT NULL CHECK (unit_cost >= 0),
    unit_price DECIMAL(12,2) NOT NULL CHECK (unit_price >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sale_item_batches_sale_item_id ON public.sale_item_batches(sale_item_id);
CREATE INDEX IF NOT EXISTS idx_sale_item_batches_batch_id ON public.sale_item_batches(batch_id);

-- Agregar sale_price a inventory_batches si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'inventory_batches' AND column_name = 'sale_price') THEN
        ALTER TABLE public.inventory_batches ADD COLUMN sale_price DECIMAL(12,2);
    END IF;
END $$;

-- Update existing batches to have sale_price equal to products.price
UPDATE public.inventory_batches ib
SET sale_price = p.price
FROM public.products p
WHERE ib.product_id = p.id AND ib.sale_price IS NULL;

-- Now make it NOT NULL
ALTER TABLE public.inventory_batches ALTER COLUMN sale_price SET NOT NULL;

-- 2. RLS (Policies)

ALTER TABLE public.product_price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_item_batches ENABLE ROW LEVEL SECURITY;

-- product_price_history policies
CREATE POLICY "Employees can view price history" ON public.product_price_history
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.employees e WHERE e.id = auth.uid() AND e.store_id = (SELECT store_id FROM public.products p WHERE p.id = product_id)));

CREATE POLICY "Admin can insert price history" ON public.product_price_history
    FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()));

-- sale_item_batches policies
CREATE POLICY "Employees can view sale item batches" ON public.sale_item_batches
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.employees e JOIN public.sales s ON s.store_id = e.store_id JOIN public.sale_items si ON si.sale_id = s.id WHERE si.id = sale_item_id AND e.id = auth.uid()));

CREATE POLICY "System can insert sale item batches" ON public.sale_item_batches
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- Cierre estricto: Revocar INSERT directo en inventory_movements
DROP POLICY IF EXISTS "movements_insert_store" ON public.inventory_movements;
