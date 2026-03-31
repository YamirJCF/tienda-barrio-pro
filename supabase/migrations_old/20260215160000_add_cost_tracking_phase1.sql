-- ==============================================================================
-- MIGRATION: PHASE 1 - COST TRACKING FOUNDATION
-- Date: 2026-02-15
-- Ref: FRD_Reportes_Historiales_v1.0 | DB_ALIGNMENT_PHASE1.md
-- Description: Add cost tracking columns for profit calculation.
--              IMPORTANT: products.cost_price ALREADY EXISTS, so we only fix
--              its default and add supplementary columns.
-- Impact: ADDITIVE ONLY. Existing RPCs continue to work.
-- ==============================================================================

-- 1. FIX products.cost_price DEFAULT (Currently NULLABLE, no default)
-- This ensures new products won't have NULL cost, which would break calculations.
ALTER TABLE public.products
ALTER COLUMN cost_price SET DEFAULT 0;

-- Fill any NULLs with estimated cost (70% of sale price)
UPDATE public.products
SET cost_price = ROUND(price * 0.70, 0)
WHERE cost_price IS NULL;

-- Now make it NOT NULL to prevent future NULLs
ALTER TABLE public.products
ALTER COLUMN cost_price SET NOT NULL;

-- Add tracking columns for last purchase
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS last_purchase_price DECIMAL(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_purchase_date TIMESTAMPTZ;

-- Index for cost-based reports
CREATE INDEX IF NOT EXISTS idx_products_cost_price ON public.products(cost_price);

-- 2. SALE_ITEMS: Add unit_cost for historical margin tracking
ALTER TABLE public.sale_items
ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0;

-- Backfill existing sale_items with current product cost
UPDATE public.sale_items si
SET unit_cost = COALESCE(
    (SELECT cost_price FROM public.products WHERE id = si.product_id),
    0
)
WHERE unit_cost = 0;

-- 3. INVENTORY_MOVEMENTS: Add cost tracking for purchases
ALTER TABLE public.inventory_movements
ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(12,2),
ADD COLUMN IF NOT EXISTS total_cost DECIMAL(12,2);
