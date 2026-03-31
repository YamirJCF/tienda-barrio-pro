-- Migration: Add payment_type to inventory_movements
-- Purpose: Track whether inventory entries were paid in cash (contado) or credit (credito)
-- Author: Arquitecto de Datos
-- Date: 2026-02-09

-- 1. Add payment_type column with constraint
ALTER TABLE inventory_movements 
ADD COLUMN payment_type TEXT 
CHECK (payment_type IN ('contado', 'credito'));

-- 2. Add column documentation
COMMENT ON COLUMN inventory_movements.payment_type IS 
'Tipo de pago para ENTRADAS de inventario: contado o credito. 
NULL para salidas/ajustes/ventas donde no aplica.';

-- 3. Create index for financial reports (credit tracking)
CREATE INDEX idx_inventory_movements_payment_type 
ON inventory_movements(payment_type) 
WHERE payment_type IS NOT NULL;

-- 4. Create composite index for supplier payment queries
CREATE INDEX idx_inventory_movements_supplier_payment 
ON inventory_movements(supplier_id, payment_type, created_at) 
WHERE supplier_id IS NOT NULL;

-- 5. Create validation trigger function
CREATE OR REPLACE FUNCTION validate_payment_type()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo movimientos tipo "entrada" con proveedor requieren payment_type
    IF NEW.movement_type = 'entrada' AND NEW.supplier_id IS NOT NULL THEN
        IF NEW.payment_type IS NULL THEN
            RAISE EXCEPTION 'Las entradas con proveedor requieren especificar tipo de pago (contado/credito)';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Attach trigger to table
CREATE TRIGGER enforce_payment_type_on_entries
    BEFORE INSERT OR UPDATE ON inventory_movements
    FOR EACH ROW
    EXECUTE FUNCTION validate_payment_type();
