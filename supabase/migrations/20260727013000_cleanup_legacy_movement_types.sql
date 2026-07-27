-- Fix: Remover tipos legados del constraint para evitar movimientos fantasma
-- Autor: Antigravity
-- Ref: Auditoría QA - Bloqueo estricto de constraint a lo que el trigger puede procesar

ALTER TABLE public.inventory_movements 
DROP CONSTRAINT IF EXISTS inventory_movements_movement_type_check;

-- Lista blanca ESTRICTA alineada 1:1 con las ramas del trigger bridge_movement_to_batch
ALTER TABLE public.inventory_movements
ADD CONSTRAINT inventory_movements_movement_type_check 
CHECK (movement_type IN (
    'entrada', 
    'salida', 
    'devolucion', 
    'merma', 
    'ajuste', 
    'CORRECCION_SISTEMA', 
    'venta'
));
