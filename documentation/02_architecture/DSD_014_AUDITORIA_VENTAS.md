# DSD-014: Auditoría de Ventas y Ajustes Forzados (Hardened)

> **Basado en:** FRD-014 V1.4
> **Modificaciones QA:** REQ_MOD_014_QA (Verificado 2026-02-07)

### Explicación del Modelo
Este documento define la implementación técnica del Protocolo de Excepción.
Se incluye una **Migración Defensiva** previa para asegurar que la base de datos acepte los nuevos tipos de movimientos requeridos.

---

## 1. Script de Migración Defensiva (Pre-requisito)

Este bloque anónimo detecta y actualiza el constraint de `movement_type` de forma segura.

```sql
DO $$
DECLARE
    v_constraint_name TEXT;
BEGIN
    -- 1. Identificar el nombre del constraint actual (puede variar según el entorno)
    SELECT conname INTO v_constraint_name
    FROM pg_constraint
    WHERE conrelid = 'public.inventory_movements'::regclass
    AND pg_get_constraintdef(oid) LIKE '%movement_type%';

    -- 2. Si existe, eliminarlo para recrearlo con los nuevos valores
    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE public.inventory_movements DROP CONSTRAINT %I', v_constraint_name);
    END IF;

    -- 3. Crear el constraint actualizado incluyendo 'CORRECCION_SISTEMA'
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

---

## 2. Definición de Objetos (DDL/RPC)

### Tabla Auditoría (`audit_logs`)

```sql
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    action TEXT NOT NULL,
    resource_id TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: Seguridad estricta
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view audit logs"
ON public.audit_logs FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.employees 
        WHERE auth_id = auth.uid() 
        AND role IN ('admin', 'owner')
    )
);

CREATE POLICY "System can insert audit logs"
ON public.audit_logs FOR INSERT
TO authenticated
WITH CHECK (true);
```

### Función Atómica (`rpc_force_sale`)

**Mejoras de Seguridad:**
- `SECURITY DEFINER`: Ejecuta con permisos del dueño (necesario para escribir en `audit_logs`).
- `SET search_path = public`: Previene ataques de suplantación de esquema (Mitigación R-02).
- **Validación de Rol:** Solo Admins/Owners pueden invocarla.

```sql
CREATE OR REPLACE FUNCTION public.rpc_force_sale(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_items JSONB,
    p_justification TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role TEXT;
    v_item JSONB;
    v_product_id UUID;
    v_qty NUMERIC;
    v_current_stock NUMERIC;
    v_deficit NUMERIC;
    v_sale_result JSONB;
    v_sale_id UUID;
    v_affected_count INT := 0;
BEGIN
    -- 0. Validar Rol Riguroso
    SELECT role INTO v_role FROM public.employees WHERE auth_id = auth.uid();
    IF v_role NOT IN ('admin', 'owner') THEN
        RAISE EXCEPTION 'Access Denied: FRD-007 Enforced. User role % not allowed.', v_role;
    END IF;

    -- Validar longitud justificación
    IF length(p_justification) < 10 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Justificación muy corta (min 10 caracteres).');
    END IF;

    -- 1. Ajuste de Inventario (Pre-Venta)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_qty := (v_item->>'quantity')::NUMERIC;
        
        -- Obtener stock actual
        SELECT current_stock INTO v_current_stock 
        FROM public.products 
        WHERE id = v_product_id;

        -- Calcular déficit
        v_deficit := v_qty - COALESCE(v_current_stock, 0);

        -- Inyectar stock correctivo (ahora permitido por el constraint actualizado)
        IF v_deficit > 0 THEN
            INSERT INTO public.inventory_movements (
                product_id,
                movement_type,
                quantity,
                reason,
                created_by
            ) VALUES (
                v_product_id,
                'CORRECCION_SISTEMA',
                v_deficit,
                'AUTO-CORRECCION (EXCEPCION ADMIN): ' || p_justification,
                auth.uid()
            );
            v_affected_count := v_affected_count + 1;
        END IF;
    END LOOP;

    -- 2. Procesar Venta (Llamada a V2 existente)
    -- Se pasa 0 como amount_received, el backend calculará el cambio como 0 si es exacto o irrelevante en este contexto
    SELECT public.rpc_procesar_venta_v2(
        p_store_id,
        p_client_id,
        p_payment_method,
        0, 
        p_items
    ) INTO v_sale_result;

    -- Validar resultado venta atomicamente
    IF (v_sale_result->>'success')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'Venta falló tras ajuste: %', v_sale_result->>'error';
    END IF;

    v_sale_id := (v_sale_result->>'sale_id')::UUID;

    -- 3. Registrar Auditoría Inmutable
    INSERT INTO public.audit_logs (
        user_id,
        action,
        resource_id,
        details
    ) VALUES (
        auth.uid(),
        'FORCE_SALE',
        v_sale_id::TEXT,
        jsonb_build_object(
            'reason', p_justification,
            'items_adjusted', v_affected_count,
            'original_items', p_items
        )
    );

    RETURN jsonb_build_object('success', true, 'sale_id', v_sale_id, 'adjusted_items', v_affected_count);
END;
$$;
```
