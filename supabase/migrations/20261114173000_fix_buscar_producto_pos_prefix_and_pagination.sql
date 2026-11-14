-- Migration: Fix buscar_producto_pos for 1+ char prefix search, PLU prefix/exact priority, and 7-item pagination
-- Certified specs: SDD_006_03 / SDD_007_01 / POL-SEC-01 (no cost_price exposure)

CREATE OR REPLACE FUNCTION public.buscar_producto_pos(
    p_store_id UUID,
    p_term TEXT DEFAULT '',
    p_limit INTEGER DEFAULT 7,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_term TEXT := TRIM(COALESCE(p_term, ''));
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 7), 1), 50);
    v_offset INTEGER := GREATEST(COALESCE(p_offset, 0), 0);
    v_norm_term TEXT;
    v_plu_like TEXT;
    v_has_exact_plu BOOLEAN := false;
    v_results JSONB;
    v_count INTEGER := 0;
BEGIN
    -- 1. Validación obligatoria de aislamiento multi-tenant (Regla 4 AGENTS.md)
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Sin término de búsqueda: catálogo paginado activo con stock > 0
    IF v_clean_term IS NULL OR LENGTH(v_clean_term) = 0 THEN
        SELECT COUNT(*) INTO v_count
        FROM public.products
        WHERE store_id = p_store_id
          AND is_active = true
          AND current_stock > 0;

        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sub.id,
                    'name', sub.name,
                    'plu', sub.plu,
                    'price', sub.price,
                    'current_stock', sub.current_stock,
                    'min_stock', sub.min_stock,
                    'brand', sub.brand,
                    'category', sub.category,
                    'measurement_unit', sub.measurement_unit,
                    'is_weighable', sub.is_weighable
                )
                ORDER BY sub.name ASC, sub.id ASC
            ),
            '[]'::jsonb
        ) INTO v_results
        FROM (
            SELECT id, name, plu, price, current_stock, min_stock, brand, category, measurement_unit, is_weighable
            FROM public.products
            WHERE store_id = p_store_id
              AND is_active = true
              AND current_stock > 0
            ORDER BY name ASC, id ASC
            LIMIT v_limit
            OFFSET v_offset
        ) sub;

        RETURN jsonb_build_object(
            'data', v_results,
            'count', v_count,
            'match_type', 'catalog_page'
        );
    END IF;

    -- 3. Búsqueda numérica por PLU (exacto prioritario o por prefijo con stock > 0)
    IF v_clean_term ~ '^[0-9]+$' THEN
        v_plu_like := replace(replace(replace(v_clean_term, '!', '!!'), '%', '!%'), '_', '!_') || '%';

        SELECT EXISTS (
            SELECT 1
            FROM public.products
            WHERE store_id = p_store_id
              AND is_active = true
              AND plu = v_clean_term
        ) INTO v_has_exact_plu;

        SELECT COUNT(*) INTO v_count
        FROM public.products
        WHERE store_id = p_store_id
          AND is_active = true
          AND (
              plu = v_clean_term
              OR (plu ILIKE v_plu_like ESCAPE '!' AND current_stock > 0)
          );

        IF v_count = 0 THEN
            RETURN jsonb_build_object(
                'data', '[]'::jsonb,
                'count', 0,
                'match_type', 'not_found'
            );
        END IF;

        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sub.id,
                    'name', sub.name,
                    'plu', sub.plu,
                    'price', sub.price,
                    'current_stock', sub.current_stock,
                    'min_stock', sub.min_stock,
                    'brand', sub.brand,
                    'category', sub.category,
                    'measurement_unit', sub.measurement_unit,
                    'is_weighable', sub.is_weighable
                )
                ORDER BY sub.exact_rank ASC, sub.plu ASC, sub.name ASC, sub.id ASC
            ),
            '[]'::jsonb
        ) INTO v_results
        FROM (
            SELECT
                id, name, plu, price, current_stock, min_stock, brand, category, measurement_unit, is_weighable,
                CASE WHEN plu = v_clean_term THEN 0 ELSE 1 END AS exact_rank
            FROM public.products
            WHERE store_id = p_store_id
              AND is_active = true
              AND (
                  plu = v_clean_term
                  OR (plu ILIKE v_plu_like ESCAPE '!' AND current_stock > 0)
              )
            ORDER BY exact_rank ASC, plu ASC, name ASC, id ASC
            LIMIT v_limit
            OFFSET v_offset
        ) sub;

        RETURN jsonb_build_object(
            'data', v_results,
            'count', v_count,
            'match_type', CASE WHEN v_has_exact_plu THEN 'exact_plu' ELSE 'prefix_plu' END
        );
    END IF;

    -- 4. Búsqueda alfabética estricta por primera letra / prefijo del nombre (desde 1 carácter, sin tildes)
    v_norm_term := replace(
        replace(
            replace(translate(lower(v_clean_term), 'áéíóúü', 'aeiouu'), '!', '!!'),
            '%', '!%'
        ),
        '_', '!_'
    );

    SELECT COUNT(*) INTO v_count
    FROM public.products
    WHERE store_id = p_store_id
      AND is_active = true
      AND current_stock > 0
      AND translate(lower(name), 'áéíóúü', 'aeiouu') LIKE (v_norm_term || '%') ESCAPE '!';

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', sub.id,
                'name', sub.name,
                'plu', sub.plu,
                'price', sub.price,
                'current_stock', sub.current_stock,
                'min_stock', sub.min_stock,
                'brand', sub.brand,
                'category', sub.category,
                'measurement_unit', sub.measurement_unit,
                'is_weighable', sub.is_weighable
            )
            ORDER BY sub.name ASC, sub.id ASC
        ),
        '[]'::jsonb
    ) INTO v_results
    FROM (
        SELECT id, name, plu, price, current_stock, min_stock, brand, category, measurement_unit, is_weighable
        FROM public.products
        WHERE store_id = p_store_id
          AND is_active = true
          AND current_stock > 0
          AND translate(lower(name), 'áéíóúü', 'aeiouu') LIKE (v_norm_term || '%') ESCAPE '!'
        ORDER BY name ASC, id ASC
        LIMIT v_limit
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'data', v_results,
        'count', v_count,
        'match_type', 'prefix_name'
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.buscar_producto_pos(UUID, TEXT, INTEGER, INTEGER) TO authenticated, service_role;
