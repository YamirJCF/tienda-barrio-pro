-- ==============================================================================
-- MIGRATION: FRD-005 AUDIT REMEDIATION
-- Remediación completa del sistema de auditoría y trazabilidad.
--
-- Cambios:
--   1. Parche de seguridad: Revocación de GRANT ALL en audit_logs
--   2. Tabla audit_precios + Trigger automático en products
--   3. Tabla audit_ventas + Trigger automático en sales
--   4. Tabla audit_seguridad + RPC cerrado para eventos de UI
--   5. Tabla audit_caja + Trigger automático en cash_sessions
--   6. Grants seguros (solo SELECT) para tablas nuevas
--
-- Principio rector: "El Backend es la Autoridad Absoluta"
--   - Eventos Reactivos → Triggers (BD genera el log automáticamente)
--   - Eventos Proactivos → RPCs SECURITY DEFINER (Frontend solicita, BD valida e inserta)
-- ==============================================================================

BEGIN;

-- ============================================================================
-- FASE 1: PARCHE CRÍTICO DE SEGURIDAD
-- Revocar el GRANT ALL que permitía DELETE/UPDATE en audit_logs
-- ============================================================================

REVOKE ALL ON public.audit_logs FROM anon;
REVOKE ALL ON public.audit_logs FROM authenticated;

-- Solo lectura para usuarios autenticados. Las inserciones existentes
-- se migrarán a las nuevas tablas dedicadas o al RPC.
GRANT SELECT ON public.audit_logs TO authenticated;
-- service_role mantiene ALL para operaciones administrativas
GRANT ALL ON public.audit_logs TO service_role;

-- ============================================================================
-- FASE 2: DOMINIO PRECIOS (Tabla + Trigger)
-- Cada cambio de cost_price o sale_price en products genera un registro
-- automático e inmutable. El frontend NO interviene.
-- ============================================================================

CREATE TABLE public.audit_precios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE NOT NULL,
    old_cost NUMERIC(12,2),
    new_cost NUMERIC(12,2),
    old_price NUMERIC(12,2),
    new_price NUMERIC(12,2),
    changed_by UUID REFERENCES public.employees(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.audit_precios IS 'FRD-005: Historial inmutable de cambios de precio/costo de productos';

ALTER TABLE public.audit_precios ENABLE ROW LEVEL SECURITY;

-- Solo lectura. Cualquier miembro de la tienda puede consultar precios históricos.
CREATE POLICY "audit_precios_select" ON public.audit_precios
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_profiles WHERE id = auth.uid() AND store_id = audit_precios.store_id
        )
        OR EXISTS (
            SELECT 1 FROM public.employees WHERE id = auth.uid() AND store_id = audit_precios.store_id AND is_active = true
        )
    );

-- Sin políticas INSERT/UPDATE/DELETE → solo el trigger (SECURITY DEFINER) puede insertar.

-- Grants seguros: solo lectura
GRANT SELECT ON public.audit_precios TO authenticated;

-- Índices para consultas frecuentes
CREATE INDEX idx_audit_precios_store_date ON public.audit_precios (store_id, created_at DESC);
CREATE INDEX idx_audit_precios_product ON public.audit_precios (product_id, created_at DESC);

-- Trigger: Captura automática de cambios de precio
CREATE OR REPLACE FUNCTION public.fn_audit_price_change()
RETURNS TRIGGER AS $$
DECLARE
    v_employee_id UUID;
BEGIN
    -- Obtener el employee_id del usuario autenticado en esta tienda
    SELECT id INTO v_employee_id
    FROM public.employees
    WHERE id = auth.uid() AND store_id = NEW.store_id AND is_active = true
    LIMIT 1;

    -- Si no se encuentra empleado, intentar con admin_profiles
    IF v_employee_id IS NULL THEN
        -- Admin puede no ser empleado, dejamos changed_by como NULL
        -- pero el registro SÍ se crea (la auditoría no se pierde)
        v_employee_id := NULL;
    END IF;

    IF (OLD.cost_price IS DISTINCT FROM NEW.cost_price)
       OR (OLD.price IS DISTINCT FROM NEW.price) THEN
        INSERT INTO public.audit_precios (
            product_id, store_id, old_cost, new_cost, old_price, new_price, changed_by
        ) VALUES (
            NEW.id,
            NEW.store_id,
            OLD.cost_price,
            NEW.cost_price,
            OLD.price,
            NEW.price,
            v_employee_id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_audit_price_change
    AFTER UPDATE OF cost_price, price ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_audit_price_change();

-- ============================================================================
-- FASE 3: DOMINIO VENTAS (Tabla + Trigger)
-- Registra creación de ventas y anulaciones como eventos inmutables
-- separados de la tabla operativa sales.
-- ============================================================================

CREATE TABLE public.audit_ventas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID REFERENCES public.sales(id) ON DELETE SET NULL,
    store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('CREACION', 'ANULACION', 'MODIFICACION')),
    actor_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE public.audit_ventas IS 'FRD-005: Historial inmutable de eventos de ventas (creación, anulación)';

ALTER TABLE public.audit_ventas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "audit_ventas_select" ON public.audit_ventas
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_profiles WHERE id = auth.uid() AND store_id = audit_ventas.store_id
        )
        OR EXISTS (
            SELECT 1 FROM public.employees WHERE id = auth.uid() AND store_id = audit_ventas.store_id AND is_active = true
        )
    );

GRANT SELECT ON public.audit_ventas TO authenticated;

CREATE INDEX idx_audit_ventas_store_date ON public.audit_ventas (store_id, created_at DESC);
CREATE INDEX idx_audit_ventas_sale ON public.audit_ventas (sale_id);

-- Trigger: Creación de venta
CREATE OR REPLACE FUNCTION public.fn_audit_sale_created()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.audit_ventas (sale_id, store_id, event_type, actor_id, metadata)
    VALUES (
        NEW.id,
        NEW.store_id,
        'CREACION',
        NEW.employee_id,
        jsonb_build_object(
            'total', NEW.total,
            'payment_method', NEW.payment_method,
            'sale_number', NEW.ticket_number,
            'client_id', NEW.client_id
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_audit_sale_created
    AFTER INSERT ON public.sales
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_audit_sale_created();

-- Trigger: Anulación de venta
CREATE OR REPLACE FUNCTION public.fn_audit_sale_voided()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.is_voided IS DISTINCT FROM NEW.is_voided) AND NEW.is_voided = true THEN
        INSERT INTO public.audit_ventas (sale_id, store_id, event_type, actor_id, metadata)
        VALUES (
            NEW.id,
            NEW.store_id,
            'ANULACION',
            NEW.voided_by,
            jsonb_build_object(
                'total', NEW.total,
                'void_reason', NEW.void_reason,
                'sale_number', NEW.ticket_number
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_audit_sale_voided
    AFTER UPDATE OF is_voided ON public.sales
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_audit_sale_voided();

-- ============================================================================
-- FASE 4: DOMINIO SEGURIDAD (Tabla + RPC)
-- Eventos proactivos: solo el backend puede insertar, el frontend
-- solicita a través de un RPC cerrado y validado.
-- ============================================================================

CREATE TABLE public.audit_seguridad (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
    store_id UUID REFERENCES public.stores(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'LOGIN_SUCCESS', 'LOGIN_FAILED', 'PIN_CHANGE',
        'UNAUTHORIZED_ACCESS', 'FORCE_SALE', 'SESSION_EXPIRED',
        'ROLE_CHANGE', 'EMPLOYEE_DEACTIVATED'
    )),
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE public.audit_seguridad IS 'FRD-005: Historial inmutable de eventos de seguridad. Solo lectura para Admin/Owner.';

ALTER TABLE public.audit_seguridad ENABLE ROW LEVEL SECURITY;

-- Solo ADMIN/OWNER puede ver los logs de seguridad (requisito FRD-005)
CREATE POLICY "audit_seguridad_select_admin" ON public.audit_seguridad
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'owner')
        )
    );

-- Sin políticas INSERT/UPDATE/DELETE → solo RPCs SECURITY DEFINER pueden insertar.

GRANT SELECT ON public.audit_seguridad TO authenticated;

CREATE INDEX idx_audit_seguridad_store_date ON public.audit_seguridad (store_id, created_at DESC);
CREATE INDEX idx_audit_seguridad_type ON public.audit_seguridad (event_type, created_at DESC);

-- RPC cerrado: API segura para que el frontend registre eventos de seguridad
CREATE OR REPLACE FUNCTION public.rpc_log_security_event(
    p_event_type TEXT,
    p_store_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS void AS $$
DECLARE
    v_employee_id UUID;
    v_ip TEXT;
    v_user_agent TEXT;
BEGIN
    -- Validar tipo de evento (el backend decide qué es válido)
    IF p_event_type NOT IN (
        'LOGIN_SUCCESS', 'LOGIN_FAILED', 'PIN_CHANGE',
        'UNAUTHORIZED_ACCESS', 'FORCE_SALE', 'SESSION_EXPIRED',
        'ROLE_CHANGE', 'EMPLOYEE_DEACTIVATED'
    ) THEN
        RAISE EXCEPTION 'Tipo de evento de seguridad no válido: %', p_event_type;
    END IF;

    -- Resolver employee_id del usuario autenticado
    SELECT id INTO v_employee_id
    FROM public.employees
    WHERE id = auth.uid()
    LIMIT 1;

    -- Capturar datos de red desde los headers de la request
    BEGIN
        v_ip := current_setting('request.headers', true)::json->>'x-forwarded-for';
        v_user_agent := current_setting('request.headers', true)::json->>'user-agent';
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
        v_user_agent := NULL;
    END;

    -- Inserción con autoridad de backend (SECURITY DEFINER salta RLS)
    INSERT INTO public.audit_seguridad (
        actor_id, store_id, event_type, ip_address, user_agent, metadata
    ) VALUES (
        v_employee_id,
        p_store_id,
        p_event_type,
        v_ip,
        v_user_agent,
        p_metadata
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FASE 5: DOMINIO CAJA (Tabla + Trigger)
-- Registra aperturas y cierres de caja como eventos inmutables.
-- ============================================================================

CREATE TABLE public.audit_caja (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES public.cash_sessions(id) ON DELETE SET NULL,
    store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('APERTURA', 'CIERRE', 'MOVIMIENTO')),
    actor_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE public.audit_caja IS 'FRD-005: Historial inmutable de operaciones de caja';

ALTER TABLE public.audit_caja ENABLE ROW LEVEL SECURITY;

CREATE POLICY "audit_caja_select" ON public.audit_caja
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_profiles WHERE id = auth.uid() AND store_id = audit_caja.store_id
        )
        OR EXISTS (
            SELECT 1 FROM public.employees WHERE id = auth.uid() AND store_id = audit_caja.store_id AND is_active = true
        )
    );

GRANT SELECT ON public.audit_caja TO authenticated;

CREATE INDEX idx_audit_caja_store_date ON public.audit_caja (store_id, created_at DESC);
CREATE INDEX idx_audit_caja_session ON public.audit_caja (session_id);

-- Trigger: Apertura de caja (INSERT en cash_sessions)
CREATE OR REPLACE FUNCTION public.fn_audit_cash_opened()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.audit_caja (session_id, store_id, event_type, actor_id, metadata)
    VALUES (
        NEW.id,
        NEW.store_id,
        'APERTURA',
        NEW.opened_by,
        jsonb_build_object(
            'initial_amount', NEW.opening_balance
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_audit_cash_opened
    AFTER INSERT ON public.cash_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_audit_cash_opened();

-- Trigger: Cierre de caja (UPDATE status a 'cerrada')
CREATE OR REPLACE FUNCTION public.fn_audit_cash_closed()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) AND NEW.status = 'closed' THEN
        INSERT INTO public.audit_caja (session_id, store_id, event_type, actor_id, metadata)
        VALUES (
            NEW.id,
            NEW.store_id,
            'CIERRE',
            NEW.closed_by,
            jsonb_build_object(
                'initial_amount', NEW.opening_balance,
                'final_amount', NEW.actual_balance,
                'difference', NEW.difference
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_audit_cash_closed
    AFTER UPDATE OF status ON public.cash_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_audit_cash_closed();

-- ============================================================================
-- FASE 6: DOMINIO CRÉDITOS
-- La tabla client_ledger ya funciona como historial inmutable (inserciones
-- vía RPCs SECURITY DEFINER). Solo necesitamos un RPC de consulta dedicado
-- para la vista centralizada de auditoría.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_history_creditos(
    p_store_id UUID,
    p_start_date TIMESTAMPTZ DEFAULT (now() - INTERVAL '30 days'),
    p_end_date TIMESTAMPTZ DEFAULT now()
)
RETURNS TABLE (
    id UUID,
    client_name TEXT,
    transaction_type TEXT,
    amount NUMERIC,
    previous_balance NUMERIC,
    new_balance NUMERIC,
    description TEXT,
    employee_name TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    RETURN QUERY
    SELECT
        cl.id,
        c.name AS client_name,
        cl.transaction_type,
        cl.amount,
        cl.previous_balance,
        cl.new_balance,
        cl.description,
        e.name AS employee_name,
        cl.created_at
    FROM public.client_ledger cl
    JOIN public.clients c ON c.id = cl.client_id
    LEFT JOIN public.employees e ON e.id = cl.created_by
    WHERE cl.store_id = p_store_id
      AND cl.created_at >= p_start_date
      AND cl.created_at <= p_end_date
    ORDER BY cl.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FASE 7: DOMINIO INVENTARIO
-- La tabla inventory_movements ya es append-only (solo INSERT RLS).
-- No requiere tabla adicional. Se asegura que no existan políticas
-- de UPDATE/DELETE que pudieran haberse agregado.
-- ============================================================================

-- Verificar que no haya políticas destructivas (idempotente)
DROP POLICY IF EXISTS "inventory_movements_update" ON public.inventory_movements;
DROP POLICY IF EXISTS "inventory_movements_delete" ON public.inventory_movements;

-- ============================================================================
-- NOTAS FINALES
-- ============================================================================
-- La tabla audit_logs original NO se elimina para preservar datos históricos
-- existentes. Se mantiene en modo "solo lectura" (GRANT SELECT únicamente).
-- Los nuevos eventos deben ir a las tablas dedicadas por dominio.
--
-- Tablas de auditoría FRD-005 (RESUMEN):
--   audit_precios     → Trigger automático en products
--   audit_ventas      → Triggers automáticos en sales (INSERT + UPDATE)
--   audit_seguridad   → RPC rpc_log_security_event (Frontend → Backend)
--   audit_caja        → Triggers automáticos en cash_sessions
--   client_ledger     → Ya existente, se agrega RPC get_history_creditos
--   inventory_movements → Ya existente, append-only confirmado
-- ==============================================================================

COMMIT;
