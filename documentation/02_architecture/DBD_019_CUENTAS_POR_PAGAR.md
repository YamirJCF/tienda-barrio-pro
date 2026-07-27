## Modelo de Datos - Módulo Cuentas por Pagar (FRD-019)

> **Módulo:** Finanzas / Proveedores  
> **Rol:** Arquitecto de Datos y Supabase (Ingeniero de Datos)  
> **Estado:** 🟢 Aprobado para Construcción

### Explicación Lógica

La arquitectura de datos para Cuentas por Pagar se diseña bajo cuatro principios fundamentales derivados del FRD-019:
1. **Inmutabilidad del Estado:** La tabla `supplier_invoices` no almacena el campo `status`. El estado ("pendiente", "vencida", "pagada") se calculará al vuelo en consultas y vistas usando `amount_paid >= total_amount` y `due_date < CURRENT_DATE`. Esto elimina la desincronización por reloj.
2. **Integridad de Trazabilidad:** Se añade `reference_invoice_id` a `inventory_movements` con `ON DELETE RESTRICT` para vincular devoluciones explícitas sin riesgo de pérdida silenciosa de registros.
3. **Atomicidad Transaccional (Cascada):** La lógica de deducción FIFO para devoluciones se implementa en un bloque `plpgsql` dentro del trigger `AFTER INSERT` de `inventory_movements`. La cascada de actualización de múltiples facturas garantiza que si algo falla, se hace rollback completo.
4. **Separación de P&L (Doble Conteo):** Se introduce el movimiento de caja `pago_proveedor` que reduce el saldo esperado, pero se excluye de la suma de `OPEX` en los reportes financieros para no duplicar el `COGS`.

---

### Bloque de Código SQL (Migraciones Proyectadas)

#### Migración 1: DDL y RLS de `supplier_invoices`
```sql
-- Descripción: Creación de la tabla supplier_invoices y actualización de inventory_movements.

-- 1. DDL
CREATE TABLE public.supplier_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE RESTRICT,
    total_amount DECIMAL(12,0) NOT NULL CHECK (total_amount >= 0),
    amount_paid DECIMAL(12,0) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
    due_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    
    CONSTRAINT supplier_invoices_amount_paid_check CHECK (amount_paid <= total_amount)
);

ALTER TABLE public.inventory_movements 
ADD COLUMN reference_invoice_id UUID REFERENCES public.supplier_invoices(id) ON DELETE RESTRICT;

-- Conexión de Trazabilidad Monetaria (NUEVO)
ALTER TABLE public.inventory_batches
ADD COLUMN source_movement_id UUID REFERENCES public.inventory_movements(id) ON DELETE RESTRICT;

-- Constraint preventivo: Correcciones de sistema nunca pueden tener proveedor
ALTER TABLE public.inventory_movements
ADD CONSTRAINT chk_correccion_no_supplier 
CHECK (movement_type != 'CORRECCION_SISTEMA' OR supplier_id IS NULL);

-- Índices para optimización de queries y FIFO
CREATE INDEX idx_supplier_invoices_supplier_id ON public.supplier_invoices(supplier_id);
CREATE INDEX idx_supplier_invoices_due_date ON public.supplier_invoices(due_date);
CREATE INDEX idx_supplier_invoices_store_id ON public.supplier_invoices(store_id);
CREATE INDEX IF NOT EXISTS idx_products_store_id ON public.products(store_id); -- Necesario para la cascada

-- Preparación de tabla de auditoría (Notificaciones estructuradas)
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- 2. RLS (Policies)
ALTER TABLE public.supplier_invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view invoices from their store"
ON public.supplier_invoices
FOR SELECT
USING (store_id IN (
    SELECT s.id FROM public.stores s 
    INNER JOIN public.employees e ON e.store_id = s.id 
    WHERE e.user_id = auth.uid()
));

-- Las inserciones y actualizaciones se manejarán primariamente vía Triggers (SECURITY DEFINER)
-- pero se puede dejar política de INSERT/UPDATE si se requiere acceso directo del Admin.
CREATE POLICY "Admins can manage invoices"
ON public.supplier_invoices
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.employees 
        WHERE user_id = auth.uid() AND role = 'admin' AND store_id = supplier_invoices.store_id
    )
);
```

#### Migración 2: Trazabilidad FIFO y Lógica Consolidada de Cuentas por Pagar
```sql
-- 1. Nueva tabla para rastrear lotes consumidos por movimientos generales (salidas/devoluciones)
CREATE TABLE public.inventory_movement_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    movement_id UUID NOT NULL REFERENCES public.inventory_movements(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES public.inventory_batches(id) ON DELETE RESTRICT,
    quantity_consumed DECIMAL(10,2) NOT NULL,
    unit_cost DECIMAL(12,0) NOT NULL
);

CREATE INDEX idx_movement_batches_mov ON public.inventory_movement_batches(movement_id);

-- 2. Políticas RLS para inventory_movement_batches
ALTER TABLE public.inventory_movement_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "movement_batches_select_store" ON public.inventory_movement_batches
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.inventory_movements m 
        INNER JOIN public.products p ON p.id = m.product_id
        INNER JOIN public.employees e ON e.store_id = p.store_id
        WHERE m.id = movement_id AND e.user_id = auth.uid()
    )
);

-- 3. Consolidación de Lógica en UN SOLO TRIGGER para evitar dependencia de orden alfabético
-- Reemplazaremos y extenderemos el trigger existente `bridge_movement_to_batch`

CREATE OR REPLACE FUNCTION public.bridge_movement_to_batch()
RETURNS TRIGGER AS $$
DECLARE
    v_cost DECIMAL;
    v_batch_record RECORD;
    v_total_value DECIMAL(12,0) := 0;
    v_supplier_freq INT;
    v_remaining_deduction DECIMAL(12,0);
    v_store_id UUID;
BEGIN
    -- Precálculo del store_id para todo el trigger (garantiza aislamiento multi-tienda)
    SELECT store_id INTO v_store_id FROM public.products WHERE id = NEW.product_id;

    -- FASE 1: GESTIÓN DE LOTES (Lógica original extendida)
    CASE NEW.movement_type
        WHEN 'entrada' THEN
            v_cost := COALESCE((SELECT cost_price FROM public.products WHERE id = NEW.product_id), 0);
            INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, created_by, source_movement_id) 
            VALUES (NEW.product_id, NEW.quantity, NEW.quantity, v_cost, NEW.created_by, NEW.id);
            v_total_value := NEW.quantity * v_cost;

        WHEN 'devolucion', 'salida' THEN
            -- Consumir FIFO y registrar el desglose en inventory_movement_batches
            FOR v_batch_record IN SELECT * FROM public.consume_stock_fifo(NEW.product_id, NEW.quantity) LOOP
                INSERT INTO public.inventory_movement_batches (movement_id, batch_id, quantity_consumed, unit_cost)
                VALUES (NEW.id, v_batch_record.batch_id, v_batch_record.quantity_taken, v_batch_record.cost_unit);
                
                v_total_value := v_total_value + (v_batch_record.quantity_taken * v_batch_record.cost_unit);
            END LOOP;

        WHEN 'CORRECCION_SISTEMA' THEN
            IF NEW.quantity > 0 THEN
                v_cost := COALESCE((SELECT cost_price FROM public.products WHERE id = NEW.product_id), 0);
                INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, created_by, source_movement_id) 
                VALUES (NEW.product_id, NEW.quantity, NEW.quantity, v_cost, NEW.created_by, NEW.id);
            ELSE
                PERFORM public.consume_stock_fifo(NEW.product_id, ABS(NEW.quantity));
            END IF;
            
        -- VENTA: Las ventas procesan su FIFO en `rpc_procesar_venta_v2` explícitamente. NO-OP aquí.
        WHEN 'venta' THEN
            NULL;

        ELSE NULL;
    END CASE;

    -- FASE 2: CUENTAS POR PAGAR (Se ejecuta de forma secuencial garantizada)
    IF NEW.supplier_id IS NOT NULL THEN
        -- RAMA A: Creación de Deuda
        IF NEW.movement_type = 'entrada' AND NEW.payment_type = 'credito' THEN
            SELECT frequency_days INTO v_supplier_freq FROM public.suppliers WHERE id = NEW.supplier_id;
            INSERT INTO public.supplier_invoices (store_id, supplier_id, total_amount, due_date)
            VALUES (
                v_store_id,
                NEW.supplier_id, v_total_value, CURRENT_DATE + COALESCE(v_supplier_freq, 15)
            );
            
        -- RAMA B: Devolución a Proveedor (Aplicación de saldos)
        ELSIF NEW.movement_type IN ('devolucion', 'salida') THEN
            v_remaining_deduction := v_total_value; 
            IF NEW.reference_invoice_id IS NOT NULL THEN
                -- Lógica iterativa explícita aquí...
                -- (El código real será implementado por el Orquestador)
                NULL;
            ELSE
                -- Cascada FIFO pura
                NULL;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';
```

#### Migración 3: RPC de Abono y Actualización Financiera
```sql
-- Descripción: RPC de Abono y ajuste a cierre de caja.

CREATE OR REPLACE FUNCTION public.rpc_pay_supplier_invoice(
    p_invoice_id UUID,
    p_amount DECIMAL(12,0)
)
RETURNS void -- Retorno vacío, excepciones manejadas con RAISE
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_invoice RECORD;
    v_active_cash_session UUID;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto del abono debe ser mayor a cero.';
    END IF;

    -- Validar Factura y saldo
    SELECT * INTO v_invoice FROM public.supplier_invoices WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Factura no encontrada.';
    END IF;

    -- [SEGURIDAD] Validar que el usuario pertenece a la tienda dueña de la factura
    PERFORM public.assert_store_access(v_invoice.store_id);
    
    IF p_amount > (v_invoice.total_amount - v_invoice.amount_paid) THEN
        RAISE EXCEPTION 'El abono supera el saldo pendiente de la factura.';
    END IF;

    -- Validar Caja Abierta
    SELECT id INTO v_active_cash_session FROM public.cash_sessions 
    WHERE store_id = v_invoice.store_id AND status = 'open' LIMIT 1;
    
    IF v_active_cash_session IS NULL THEN
        RAISE EXCEPTION 'No hay un turno de caja abierto para registrar el egreso.';
    END IF;

    -- Registrar Egreso (Tipo: pago_proveedor)
    INSERT INTO public.cash_movements (session_id, movement_type, amount, reason, created_by)
    VALUES (v_active_cash_session, 'pago_proveedor', p_amount, 'Abono Factura ' || v_invoice.id, auth.uid());

    -- Actualizar Factura
    UPDATE public.supplier_invoices 
    SET amount_paid = amount_paid + p_amount
    WHERE id = p_invoice_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_pay_supplier_invoice TO authenticated;
```

---

### Diccionario de Datos (`supplier_invoices`)

| Columna | Tipo | Descripción | Restricciones / Reglas |
|---------|------|-------------|-------------------------|
| `id` | UUID | Identificador único de la factura | `PRIMARY KEY` |
| `store_id` | UUID | Tienda a la que pertenece la deuda | `FK (stores.id) ON DELETE CASCADE` |
| `supplier_id` | UUID | Proveedor al que se le debe | `FK (suppliers.id) ON DELETE RESTRICT` |
| `total_amount` | DECIMAL | Valor total original de la mercancía (sin decimales) | `>= 0` |
| `amount_paid` | DECIMAL | Monto acumulado de abonos y deducciones (sin decimales) | `>= 0`, `<= total_amount` |
| `due_date` | DATE | Fecha estimada o real de vencimiento | No nulo |
| `created_at` | TIMESTAMP | Fecha en que se generó la deuda | Default `now()` |

*(Nota: La columna calculada virtual `status` se infiere en Views/RPCs como `CASE WHEN amount_paid >= total_amount THEN 'pagada' WHEN due_date < CURRENT_DATE THEN 'vencida' ELSE 'pendiente' END`)*

### Diccionario de Datos (`inventory_movement_batches` - NUEVO)

| Columna | Tipo | Descripción | Restricciones / Reglas |
|---------|------|-------------|-------------------------|
| `id` | UUID | Identificador único del registro de desglose | `PRIMARY KEY` |
| `movement_id` | UUID | FK al movimiento (salida/devolución) que consumió el lote | `FK ON DELETE CASCADE` |
| `batch_id` | UUID | FK al lote consumido | `FK ON DELETE RESTRICT` |
| `quantity_consumed` | DECIMAL | Cantidad restada de este lote específico | No nulo |
| `unit_cost` | DECIMAL | Costo unitario con el que se compró ese lote | No nulo |

---

### Instrucción para el Orquestador

1. **Creación de `inventory_movement_batches`:** Necesitas crear esta tabla para registrar exactamente qué lotes consumen las salidas. Así resuelves el problema de calcular el costo real de una devolución.
2. **Consolidación de Triggers:** En lugar de crear un trigger nuevo para las Cuentas por Pagar y depender del orden alfabético (fragilidad técnica), **extiende y reescribe** la función del trigger existente `bridge_movement_to_batch`. Ejecuta la Fase 1 (creación o consumo de lotes guardando los registros) y, secuencialmente dentro de la misma función, ejecuta la Fase 2 (creación de deuda o descuento en cascada de las facturas).
3. **Confirmación de Seguridad en `inventory_movements`:** Asegúrate de que la inserción de movimientos de inventario por una "venta" (en `rpc_procesar_venta_v2`) definitivamente NO incluya un `supplier_id`, garantizando que la Fase 2 del trigger se salte las ventas.
4. **Implementar Cascada Real:** El código SQL provisto para la Cascada de la Rama B es un skeleton. Tú serás el responsable de escribir los loops reales y la actualización secuencial de las facturas (`amount_paid`) aplicando la Regla #7 aprobada.
    - **Validación Crítica:** Debes asegurar que la factura seleccionada explícitamente pertenece al mismo proveedor del movimiento (`AND supplier_id = NEW.supplier_id`). Si no coincide, levantar una excepción (`RAISE EXCEPTION`), ya que indica una selección corrupta en el frontend.
    - **Validación de Saldo (Factura Pagada):** Si la factura seleccionada explícitamente ya está pagada por completo (`amount_paid >= total_amount`), debes levantar una excepción explícita (`RAISE EXCEPTION 'La factura seleccionada ya se encuentra pagada.'`) en lugar de caer silenciosamente al fallback FIFO.
    - **Orden de Cascada:** La cascada debe ordenarse por `ORDER BY due_date ASC, created_at ASC` para priorizar las deudas próximas a vencer.
    - **Aislamiento Multi-tienda:** El cursor de la cascada `FOR v_invoice IN SELECT...` DEBE tener estrictamente la condición `AND store_id = v_store_id` para evitar que se paguen facturas de otra tienda.
    - **Concurrencia (Seguridad):** El cursor de la cascada DEBE usar explícitamente `SELECT ... FOR UPDATE` para evitar cualquier condición de carrera durante la iteración.
    - **Notificación Auditada:** El remanente a favor que no encuentre factura pendiente registrará un `INSERT INTO public.notifications`. Debes incluir el `supplier_id` y el `monto` de forma estructurada en la columna `metadata` (JSONB) que se añadirá en el DDL.
