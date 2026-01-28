# Políticas de Seguridad RLS

> **Documento:** Row Level Security Policies  
> **Generado desde:** FRDs + QA_ADDENDUM  
> **Fecha:** 2026-01-28

---

## Principios Generales

Según QA_ADDENDUM §3:

| Regla | Requisito |
|-------|-----------|
| RLS-001 | Toda tabla DEBE tener RLS habilitado |
| RLS-002 | Toda tabla DEBE tener al menos una política de SELECT |
| RLS-003 | La política DEBE filtrar por `store_id` del usuario autenticado |
| RLS-004 | Tablas de auditoría DEBEN ser INSERT-only |

---

## Función Helper: `get_current_store_id()`

```sql
-- Extrae store_id del JWT del usuario autenticado
CREATE OR REPLACE FUNCTION public.get_current_store_id()
RETURNS UUID AS $$
BEGIN
  RETURN (auth.jwt() ->> 'store_id')::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
```

---

## Tabla: `stores`

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `stores_select_own` | `id = get_current_store_id()` |
| UPDATE | `stores_update_own` | `id = get_current_store_id()` |
| INSERT | `stores_insert_auth` | `auth.uid() IS NOT NULL` |
| DELETE | ❌ Prohibido | N/A - Las tiendas no se eliminan |

**Justificación:** Un usuario solo puede ver y modificar su propia tienda.

---

## Tabla: `admin_profiles`

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `admin_profiles_select_own` | `store_id = get_current_store_id()` |
| UPDATE | `admin_profiles_update_self` | `id = auth.uid()` |
| INSERT | ❌ Via RPC | Solo durante registro (función SECURITY DEFINER) |
| DELETE | ❌ Prohibido | N/A |

**Justificación:** Los admins ven perfiles de su tienda, pero solo editan el suyo.

---

## Tabla: `employees`

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `employees_select_store` | `store_id = get_current_store_id()` |
| INSERT | `employees_insert_store` | `store_id = get_current_store_id()` + validar límite 5 |
| UPDATE | `employees_update_store` | `store_id = get_current_store_id()` |
| DELETE | ❌ Prohibido | Los empleados se desactivan, no se eliminan |

**Justificación:** Solo se ven/editan empleados de la propia tienda. Límite de 5 validado via RPC.

### Función RPC: `validar_pin_empleado`

```sql
-- Valida PIN sin exponer hash
-- Requisito: QA_ADDENDUM §3.2 CRED-004
CREATE OR REPLACE FUNCTION public.validar_pin_empleado(
  p_username TEXT,
  p_pin TEXT
)
RETURNS JSON AS $$
-- Retorna {success, employee, store_state} o {success: false, error}
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Tabla: `products`

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `products_select_store` | `store_id = get_current_store_id()` |
| INSERT | `products_insert_store` | `store_id = get_current_store_id()` |
| UPDATE | `products_update_store` | `store_id = get_current_store_id()` |
| DELETE | `products_delete_admin` | `store_id = get_current_store_id() AND is_admin()` |

**Justificación:** Productos filtrados por tienda. Solo Admin puede eliminar (FRD_006 §Matriz).

> **Nota:** Campo `cost_price` NO se oculta via RLS sino via lógica de aplicación/RPC.

---

## Tabla: `inventory_movements`

> **IMMUTABLE:** Solo INSERT permitido (QA_ADDENDUM §4.2)

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `movements_select_store` | Via JOIN con products.store_id |
| INSERT | `movements_insert_store` | Via RPC `registrar_movimiento` |
| UPDATE | ❌ Prohibido | Inmutable |
| DELETE | ❌ Prohibido | Inmutable |

**Justificación:** Movimientos son auditoría inmutable. Se insertan via RPC transaccional.

### Trigger: `trg_update_stock`

```sql
-- Actualiza stock automáticamente al insertar movimiento
-- FRD_006 §Kardex - Trigger automático
CREATE TRIGGER trg_update_stock
  AFTER INSERT ON public.inventory_movements
  FOR EACH ROW EXECUTE FUNCTION public.update_product_stock();
```

---

## Tabla: `sales`

> **IMMUTABLE:** No UPDATE/DELETE permitido (QA_ADDENDUM)

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `sales_select_store` | `store_id = get_current_store_id()` |
| INSERT | Via RPC | `procesar_venta()` transaccional |
| UPDATE | ❌ Prohibido | Solo anulación via RPC Admin |
| DELETE | ❌ Prohibido | Inmutable |

**Justificación:** Ventas son inmutables para auditoría fiscal. Anulación solo marca `is_voided`.

---

## Tabla: `sale_items`

> **IMMUTABLE:** INSERT-only

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `sale_items_select_store` | Via JOIN con sales.store_id |
| INSERT | Via RPC | Solo dentro de `procesar_venta()` |
| UPDATE | ❌ Prohibido | Inmutable |
| DELETE | ❌ Prohibido | Inmutable |

### RPC: `procesar_venta`

```sql
-- Procesa venta completa en transacción atómica
-- FRD_007 - Crea sale, sale_items, genera movimientos de inventario
CREATE OR REPLACE FUNCTION public.procesar_venta(
  p_items JSONB,
  p_payment_method TEXT,
  p_amount_received DECIMAL DEFAULT NULL,
  p_client_id UUID DEFAULT NULL
)
RETURNS JSON AS $$
-- Retorna {success, sale_id, ticket_number} o {success: false, error}
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Tabla: `clients`

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `clients_select_store` | `store_id = get_current_store_id() AND NOT is_deleted` |
| INSERT | `clients_insert_store` | `store_id = get_current_store_id()` (Solo Admin via RPC) |
| UPDATE | `clients_update_store` | `store_id = get_current_store_id()` (Solo Admin via RPC) |
| DELETE | ❌ Prohibido | Soft delete via `is_deleted = true` |

**Justificación:** Clientes ocultos si `is_deleted = true`. Solo Admin crea/edita.

---

## Tabla: `client_transactions`

> **IMMUTABLE:** INSERT-only

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `client_tx_select_store` | Via JOIN con clients.store_id |
| INSERT | Via RPC | `registrar_abono()` o automático en venta fiado |
| UPDATE | ❌ Prohibido | Inmutable |
| DELETE | ❌ Prohibido | Inmutable |

### RPC: `registrar_abono`

```sql
-- Registra abono validando balance >= monto
CREATE OR REPLACE FUNCTION public.registrar_abono(
  p_client_id UUID,
  p_amount DECIMAL
)
RETURNS JSON AS $$
-- Valida monto <= balance, actualiza balance, registra transacción
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Tabla: `cash_sessions`

> **Invariante:** Solo 1 sesión abierta por tienda (enforced via partial unique index)

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `cash_sessions_select_store` | `store_id = get_current_store_id()` |
| INSERT | Via RPC | `abrir_caja()` con validación |
| UPDATE | Via RPC | Solo `cerrar_caja()` para cerrar |
| DELETE | ❌ Prohibido | Historial inmutable |

---

## Tabla: `cash_movements`

> **IMMUTABLE:** INSERT-only

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `cash_movements_select_store` | Via JOIN con cash_sessions.store_id |
| INSERT | Via RPC | `registrar_movimiento_caja()` |
| UPDATE | ❌ Prohibido | Inmutable |
| DELETE | ❌ Prohibido | Inmutable |

### RPC: `abrir_caja`

```sql
-- Abre sesión validando que no haya otra abierta
CREATE OR REPLACE FUNCTION public.abrir_caja(
  p_store_id UUID,
  p_employee_id UUID,
  p_opening_balance DECIMAL
)
RETURNS JSON AS $$
-- Valida única sesión abierta, crea sesión
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### RPC: `cerrar_caja`

```sql
-- Cierra sesión calculando balance esperado
CREATE OR REPLACE FUNCTION public.cerrar_caja(
  p_session_id UUID,
  p_employee_id UUID,
  p_actual_balance DECIMAL
)
RETURNS JSON AS $$
-- Calcula expected, difference, cierra sesión
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Tabla: `daily_passes`

> **Expiración:** Todos los pases expiran al cerrar caja

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `daily_passes_select_store` | Via JOIN con employees.store_id |
| INSERT | Via RPC | `solicitar_pase_diario()` |
| UPDATE | Via RPC | Solo Admin puede aprobar/rechazar |
| DELETE | ❌ Prohibido | Historial inmutable |

### RPC: `aprobar_pase_diario`

```sql
-- Admin aprueba pase cambiando status
CREATE OR REPLACE FUNCTION public.aprobar_pase_diario(
  p_pass_id UUID,
  p_admin_id UUID
)
RETURNS JSON AS $$
-- Cambia status a 'approved', registra resolved_by/at
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Tabla: `audit_logs`

> **IMMUTABLE:** INSERT-only (RLS-004)

| Operación | Política | Condición USING |
|-----------|----------|-----------------|
| SELECT | `audit_logs_select_admin` | `store_id = get_current_store_id() AND is_admin()` |
| INSERT | Via RPC | `log_security_event()` automático |
| UPDATE | ❌ Prohibido | Inmutable (V-006) |
| DELETE | ❌ Prohibido | Inmutable (V-006) |

**Justificación (QA_ADDENDUM §4.2):** Solo Admin puede leer logs. Empleados NO pueden acceder a logs de auditoría para evitar cubrir pistas.

### RPC: `log_security_event`

```sql
-- Registra evento de seguridad (llamado automáticamente)
CREATE OR REPLACE FUNCTION public.log_security_event(
  p_store_id UUID,
  p_event_type TEXT,
  p_severity TEXT,
  p_actor_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
-- Inserta log, retorna ID
$$ LANGUAGE plpgsql SECURITY DEFINER;
```
