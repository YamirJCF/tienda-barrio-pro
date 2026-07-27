-- Fix: check constraint rejects valid new movement types ('ajuste', 'merma')
-- Autor: Antigravity

ALTER TABLE public.inventory_movements 
DROP CONSTRAINT IF EXISTS inventory_movements_movement_type_check;

ALTER TABLE public.inventory_movements
ADD CONSTRAINT inventory_movements_movement_type_check 
CHECK (movement_type IN ('ingreso', 'gasto', 'venta', 'devolucion', 'ajuste_manual', 'ajuste', 'merma', 'entrada', 'salida', 'CORRECCION_SISTEMA'));
