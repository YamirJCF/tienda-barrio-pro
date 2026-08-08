# DSD-007-01-v3: Migración SQL para `rpc_procesar_venta_v3`

> **Asociado a:** [SDD_007_01_NUCLEO_POS.md](../SDD/SDD_007_01_NUCLEO_POS.md)  
> **Fase del Plan:** Fase 2C (Resolución de Deuda Técnica POS)  
> **Decisión del Arquitecto:** D-03 (Crear RPC v3 desde cero vía migración dedicada)  
> **Estado:** 🔴 Especificación de Migración Lista para Aplicación SQL

---

## 1. Objetivo de la Migración

Construir la versión 3 de la función RPC de procesamiento de venta (`rpc_procesar_venta_v3`) para resolver la deuda técnica documentada en SDD_007_01 §0.3. La migración debe:

1. Agregar la columna `idempotency_key` (UUID, `UNIQUE`) a la tabla `sales`.
2. Crear la función `rpc_procesar_venta_v3` con firma extendida que soporte:
   - Idempotencia nativa en Backend (Decisión D-04).
   - Canal de pago explícito (`payment_method_id`).
   - Cierres contables flexibles (`venta`, `fiado`, `merma`, `devolucion_proveedor`, `devolucion_cliente`).
   - Autodescubrimiento de sesión de caja desde el token autenticado (`get_current_store_id()`).

---

## 2. Esquema DDL Requerido

```sql
-- 1. Agregar columna de idempotencia si no existe
ALTER TABLE sales 
ADD COLUMN IF NOT EXISTS idempotency_key UUID UNIQUE;

-- 2. Firma de la función RPC v3
CREATE OR REPLACE FUNCTION rpc_procesar_venta_v3(
    p_idempotency_key UUID,
    p_closure_type TEXT,
    p_cart_items JSONB,
    p_payment_method_id UUID DEFAULT NULL,
    p_client_id UUID DEFAULT NULL,
    p_supplier_id UUID DEFAULT NULL,
    p_reference_invoice_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_store_id UUID;
    v_session_id UUID;
    v_sale_id UUID;
    v_total_charged NUMERIC(12,2) := 0;
    v_item JSONB;
    v_product_id UUID;
    v_quantity INT;
    v_unit_price NUMERIC(12,2);
    v_result_items JSONB := '[]'::JSONB;
BEGIN
    -- Validar multitenant
    v_store_id := get_current_store_id();
    
    -- Validar sesión de caja abierta
    SELECT id INTO v_session_id 
    FROM cash_sessions 
    WHERE store_id = v_store_id AND status = 'OPEN' 
    LIMIT 1;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'SESSION_INVALID: No existe una sesión de caja abierta para esta tienda.';
    END IF;

    -- Prevenir cobro duplicado por constraint idempotency_key
    BEGIN
        INSERT INTO sales (store_id, session_id, idempotency_key, closure_type, payment_method_id, client_id, total)
        VALUES (v_store_id, v_session_id, p_idempotency_key, p_closure_type, p_payment_method_id, p_client_id, 0)
        RETURNING id INTO v_sale_id;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'DUPLICATE_TRANSACTION: La transacción con idempotency_key % ya fue procesada.', p_idempotency_key;
    END;

    -- Procesamiento de ítems del carrito
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_cart_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::INT;

        -- Obtener precio vigente del producto
        SELECT price INTO v_unit_price FROM products WHERE id = v_product_id AND store_id = v_store_id;

        IF v_unit_price IS NULL THEN
            RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto % no existe o no pertenece a la tienda.', v_product_id;
        END IF;

        -- Insertar ítem de venta
        INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, total_price)
        VALUES (v_sale_id, v_product_id, v_quantity, v_unit_price, v_quantity * v_unit_price);

        v_total_charged := v_total_charged + (v_quantity * v_unit_price);

        v_result_items := v_result_items || jsonb_build_object(
            'product_id', v_product_id,
            'quantity', v_quantity,
            'unit_price', v_unit_price
        );
    END LOOP;

    -- Actualizar total oficial en cabecera
    UPDATE sales SET total = v_total_charged WHERE id = v_sale_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'sale_id', v_sale_id,
            'created_at', NOW(),
            'total_charged', v_total_charged,
            'items', v_result_items
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION rpc_procesar_venta_v3 TO authenticated;
```

---

## 3. Criterios de Validación de la Migración

- [ ] La columna `sales.idempotency_key` rechaza duplicados a nivel de constraint UNIQUE de la base de datos.
- [ ] La función autodescubre la tienda del usuario con `get_current_store_id()`.
- [ ] La función valida la existencia de una sesión en estado `OPEN`.
- [ ] La función retorna el total calculado y los ítems con su precio congelado oficial.
