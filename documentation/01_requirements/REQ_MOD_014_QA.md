# Solicitud de Modificación QA - FRD-014

> **Referencia:** QA Report R-01, R-02
> **Objetivo:** Pre-parchar la base de datos para soportar la "Venta Forzada" sin violar integridad referecial existente.

## 1. Justificación Técnica
El análisis de QA detectó que la tabla `inventory_movements` posee un `CHECK CONSTRAINT` restrictivo que solo permite valores como `'ingreso'`, `'gasto'`, `'venta'`.
El nuevo requerimiento FRD-014 introduce el tipo `'CORRECCION_SISTEMA'`. Si no actualizamos la restricción, el RPC `rpc_force_sale` fallará.

## 2. Cambios Requeridos (Implementación)

### Script de Migración (SQL)
Este script debe ejecutarse **ANTES** de crear el RPC `rpc_force_sale`.

```sql
-- MITIGATION R-01: Update Check Constraint
DO $$
DECLARE
    v_constraint_name TEXT;
BEGIN
    -- Buscar el nombre exacto del constraint de check para movement_type
    SELECT conname INTO v_constraint_name
    FROM pg_constraint
    WHERE conrelid = 'public.inventory_movements'::regclass
    AND pg_get_constraintdef(oid) LIKE '%movement_type%';

    -- Si existe, modificarlo (Drop & Re-Add)
    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE public.inventory_movements DROP CONSTRAINT %I', v_constraint_name);
    END IF;

    -- Agregar constraint actualizado con el nuevo tipo 'CORRECCION_SISTEMA'
    ALTER TABLE public.inventory_movements
    ADD CONSTRAINT inventory_movements_movement_type_check 
    CHECK (movement_type IN (
        'ingreso', 
        'gasto', 
        'venta', 
        'devolucion', 
        'ajuste_manual', 
        'CORRECCION_SISTEMA' -- <--- NUEVO TIPO AUTORIZADO
    ));
END $$;
```

### Ajuste de Seguridad (SQL)
En la definición del RPC `rpc_force_sale` (DSD-014), asegurar la siguiente línea:

```sql
CREATE OR REPLACE FUNCTION public.rpc_force_sale(...)
...
SECURITY DEFINER
SET search_path = public -- <--- MITIGATION R-02
AS $$ ...
```

## 3. Instrucción al Desarrollador Backend
1.  Incluir el bloque `DO $$ ... $$` al inicio de la migración de `FRD-014`.
2.  Copiar el RPC actualizado con `search_path`.
