-- Migration: Add supplier tracking to inventory_movements
-- Purpose: Connect stock entries to suppliers table for traceability
-- Date: 2026-02-09
-- Author: Antigravity Agent

-- =============================================================================
-- 1. ADD NEW COLUMNS TO inventory_movements
-- =============================================================================

-- Add supplier reference (optional - entries can exist without supplier)
ALTER TABLE public.inventory_movements 
  ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;

-- Add invoice reference for accounting traceability
ALTER TABLE public.inventory_movements 
  ADD COLUMN IF NOT EXISTS invoice_reference TEXT;

-- =============================================================================
-- 2. ADD INDEX FOR PERFORMANCE
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_movements_supplier 
  ON public.inventory_movements(supplier_id) 
  WHERE supplier_id IS NOT NULL;

-- =============================================================================
-- 3. ADD COMMENT FOR DOCUMENTATION
-- =============================================================================

COMMENT ON COLUMN public.inventory_movements.supplier_id IS 
  'Optional FK to suppliers table. Used for purchase entries to track source.';

COMMENT ON COLUMN public.inventory_movements.invoice_reference IS 
  'Invoice or receipt reference number for accounting purposes.';

-- =============================================================================
-- 4. VERIFICATION
-- =============================================================================

DO $$
BEGIN
  -- Verify columns exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'inventory_movements' 
    AND column_name = 'supplier_id'
  ) THEN
    RAISE EXCEPTION 'Migration failed: supplier_id column not created';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'inventory_movements' 
    AND column_name = 'invoice_reference'
  ) THEN
    RAISE EXCEPTION 'Migration failed: invoice_reference column not created';
  END IF;
  
  RAISE NOTICE '[Migration 20260209144550] SUCCESS: supplier_id and invoice_reference added to inventory_movements';
END $$;
