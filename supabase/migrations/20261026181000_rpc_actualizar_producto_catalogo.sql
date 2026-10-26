-- ==============================================================================
-- Migración: 20261026181000_rpc_actualizar_producto_catalogo.sql
-- Propósito: Desplegar rpc_actualizar_producto_catalogo con Escudo 1 y Escudo 2
--            aislando el Vector Catálogo del Vector Logístico (current_stock intacto)
-- Documento: SDD-028 v2.0.0 (§4.8, §5.4) / SDD-006 Padre (§5.4, §6.4)
-- ==============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.rpc_actualizar_producto_catalogo(
    p_product_id UUID,
    p_name TEXT,
    p_price NUMERIC,
    p_expected_old_price NUMERIC,
    p_expected_name TEXT,
    p_cost NUMERIC DEFAULT NULL,
    p_min_stock NUMERIC DEFAULT 0,
    p_plu TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_expected_old_cost NUMERIC DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_employee_id UUID;
    v_store_id UUID;
    v_current_name TEXT;
    v_current_price NUMERIC;
    v_current_cost NUMERIC;
    v_current_min_stock NUMERIC;
    v_current_plu TEXT;
    v_current_category TEXT;
    v_is_active BOOLEAN;
    v_last_price_change TIMESTAMPTZ;
    v_last_my_change TIMESTAMPTZ;
    v_ip TEXT;
    v_user_agent TEXT;
BEGIN
    -- 1. Validar parámetros requeridos
    IF p_product_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'INVALID_PARAMS', 'error', 'p_product_id es obligatorio');
    END IF;

    IF p_name IS NULL OR length(trim(p_name)) < 2 THEN
        RETURN jsonb_build_object('success', false, 'code', 'INVALID_NAME', 'error', 'El nombre debe tener al menos 2 caracteres');
    END IF;

    IF p_price IS NULL OR p_price < 50 THEN
        RETURN jsonb_build_object('success', false, 'code', 'INVALID_PRICE', 'error', 'El precio debe ser mayor o igual a $50 COP');
    END IF;

    IF p_expected_old_price IS NULL OR p_expected_name IS NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'MISSING_SNAPSHOT_SEAL', 'error', 'El sello de estado base (Escudo 2) es obligatorio');
    END IF;

    -- 2. Bloqueo de fila pesimista (SELECT ... FOR UPDATE)
    SELECT store_id, name, price, cost_price, min_stock, plu, category, is_active
    INTO v_store_id, v_current_name, v_current_price, v_current_cost, v_current_min_stock, v_current_plu, v_current_category, v_is_active
    FROM public.products
    WHERE id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'PRODUCT_NOT_FOUND', 'error', 'El producto especificado no existe');
    END IF;

    -- 3. Verificación de Seguridad Centralizada (Regla 4 AGENTS.md)
    PERFORM public.assert_store_access(v_store_id);

    -- 4. Resolver employee_id para auditoría
    SELECT id INTO v_employee_id
    FROM public.employees
    WHERE id = v_user_id AND store_id = v_store_id AND is_active = true
    LIMIT 1;

    -- Capturar headers de red si están disponibles
    BEGIN
        v_ip := current_setting('request.headers', true)::json->>'x-forwarded-for';
        v_user_agent := current_setting('request.headers', true)::json->>'user-agent';
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
        v_user_agent := NULL;
    END;

    -- 5. ESCUDO 1: Cooldown mínimo por vector (< 3 segundos)
    IF (p_price IS DISTINCT FROM v_current_price) OR (p_cost IS DISTINCT FROM v_current_cost) THEN
        SELECT max(created_at) INTO v_last_price_change
        FROM public.audit_precios
        WHERE product_id = p_product_id;

        IF v_last_price_change IS NOT NULL AND (now() - v_last_price_change) < interval '3 seconds' THEN
            -- Inserción segura en audit_seguridad sin rollback
            INSERT INTO public.audit_seguridad (
                actor_id, store_id, event_type, ip_address, user_agent, metadata
            ) VALUES (
                v_employee_id, v_store_id, 'CONCURRENT_MUTATION_BLOCKED', v_ip, v_user_agent,
                jsonb_build_object(
                    'reason', 'MUTATION_COOLDOWN_ACTIVE',
                    'product_id', p_product_id,
                    'last_change', v_last_price_change,
                    'attempted_price', p_price,
                    'user_id', v_user_id
                )
            );

            RETURN jsonb_build_object(
                'success', false,
                'code', 'MUTATION_COOLDOWN_ACTIVE',
                'error', 'Operación bloqueada temporalmente por cooldown de seguridad (3 segundos).'
            );
        END IF;
    END IF;

    -- 6. ESCUDO 2: Sello de Estado Base por Vector (Vector Snapshot Seal)
    -- Se comparan estrictamente los atributos de catálogo esperados contra los vigentes en BD.
    -- Queda PROHIBIDO evaluar current_stock o products.updated_at (Deuda D-6).
    IF (v_current_price IS DISTINCT FROM p_expected_old_price)
       OR (v_current_name IS DISTINCT FROM trim(p_expected_name)) THEN

        -- Sub-regla de Idempotencia de Red Lenta:
        IF (v_current_price = p_price) AND (v_current_name = trim(p_name)) THEN
            SELECT max(created_at) INTO v_last_my_change
            FROM public.audit_precios
            WHERE product_id = p_product_id
              AND (changed_by = v_employee_id OR (changed_by IS NULL AND v_employee_id IS NULL));

            IF v_last_my_change IS NOT NULL AND (now() - v_last_my_change) < interval '10 seconds' THEN
                RETURN jsonb_build_object(
                    'success', true,
                    'code', 'ALREADY_APPLIED_IDEMPOTENT',
                    'message', 'Actualización ya aplicada en reintento previo.'
                );
            END IF;
        END IF;

        -- Bloqueo Definitivo y Registro Forense
        INSERT INTO public.audit_seguridad (
            actor_id, store_id, event_type, ip_address, user_agent, metadata
        ) VALUES (
            v_employee_id, v_store_id, 'CONCURRENT_MUTATION_BLOCKED', v_ip, v_user_agent,
            jsonb_build_object(
                'reason', 'STALE_VECTOR_SNAPSHOT',
                'product_id', p_product_id,
                'expected_price', p_expected_old_price,
                'current_price', v_current_price,
                'expected_name', p_expected_name,
                'current_name', v_current_name,
                'attempted_price', p_price,
                'attempted_name', trim(p_name),
                'user_id', v_user_id
            )
        );

        RETURN jsonb_build_object(
            'success', false,
            'code', 'CONCURRENT_MUTATION_BLOCKED',
            'error', 'Operación bloqueada. El producto fue modificado concurrentemente desde otro dispositivo.'
        );
    END IF;

    -- 7. Validación de Unicidad de PLU por tienda activa
    IF p_plu IS NOT NULL AND trim(p_plu) != '' AND (v_current_plu IS DISTINCT FROM trim(p_plu)) THEN
        IF EXISTS (
            SELECT 1 FROM public.products
            WHERE store_id = v_store_id
              AND plu = trim(p_plu)
              AND id != p_product_id
              AND is_active = true
        ) THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'PLU_ALREADY_EXISTS',
                'error', 'El código PLU ya se encuentra asignado a otro producto activo'
            );
        END IF;
    END IF;

    -- 8. Actualización Atómica de Catálogo (current_stock permanece INTACTO)
    UPDATE public.products
    SET name = trim(p_name),
        price = p_price,
        cost_price = p_cost,
        min_stock = COALESCE(p_min_stock, 0),
        plu = NULLIF(trim(p_plu), ''),
        category = NULLIF(trim(p_category), ''),
        updated_at = now()
    WHERE id = p_product_id;

    -- 9. Retorno exitoso en formato estándar ActionResponse
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'product_id', p_product_id,
            'name', trim(p_name),
            'price', p_price,
            'cost_price', p_cost,
            'min_stock', COALESCE(p_min_stock, 0),
            'plu', NULLIF(trim(p_plu), ''),
            'category', NULLIF(trim(p_category), '')
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_actualizar_producto_catalogo(
    UUID, TEXT, NUMERIC, NUMERIC, TEXT, NUMERIC, NUMERIC, TEXT, TEXT, NUMERIC
) TO authenticated, service_role;

COMMIT;
