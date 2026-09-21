# 📊 Auditoría de Datos para Módulo de Analytics
**Proyecto:** `tienda-barrio-staging`
**Fecha:** 2026-02-22
**Autor:** Arquitecto de Producto y Requisitos
**Estado:** Borrador — Pre-diseño de Dashboard

---

## Contexto y Propósito

Este documento responde una pregunta fundamental antes de diseñar cualquier dashboard o módulo de reportes:

> **¿Qué datos tenemos HOY en el sistema y qué métricas podemos calcular honestamente con ellos?**

La premisa de diseño es que el usuario objetivo (tendero con 20+ años de experiencia) no necesita recomendaciones de la app. Necesita un **espejo inteligente**: sus propios números, claros y sin mentiras. Por esto, solo se mostrarán métricas que se puedan calcular con datos 100% confiables y completos.

La auditoría fue realizada directamente sobre el esquema de Supabase, verificando tablas, columnas, tipos, constraints y cantidad de registros reales.

---

## Inventario de Tablas y Datos

### 1. Ventas — `sales` (44 registros)

| Columna | Tipo | Notas |
|---------|------|-------|
| `id` | uuid | PK |
| `store_id` | uuid | FK |
| `ticket_number` | integer | Número correlativo de venta |
| `employee_id` | uuid | Quién realizó la venta |
| `client_id` | uuid (nullable) | Cliente (solo en ventas fiadas) |
| `total` | numeric | Monto total de la venta |
| `payment_method` | text (enum) | `efectivo`, `nequi`, `daviplata`, `fiado` |
| `amount_received` | numeric (nullable) | Cuánto entregó el cliente |
| `change_given` | numeric (nullable) | Vuelto entregado |
| `rounding_difference` | numeric | Diferencia por redondeo |
| `is_voided` | boolean | Si la venta fue anulada |
| `voided_by` | uuid (nullable) | Empleado que anuló |
| `void_reason` | text (nullable) | Motivo de anulación |
| `created_at` | timestamptz | Fecha y hora exacta de la venta |

**Capacidades analíticas confirmadas:**
- Ventas brutas por período (día, semana, mes)
- Desglose por método de pago
- Ventas por empleado
- Tasa de anulaciones

---

### 2. Líneas de Venta — `sale_items` (83 registros)

| Columna | Tipo | Notas |
|---------|------|-------|
| `sale_id` | uuid | FK a `sales` |
| `product_id` | uuid | FK a `products` |
| `quantity` | numeric | Unidades vendidas |
| `unit_price` | numeric | Precio al que se vendió |
| `subtotal` | numeric | `quantity × unit_price` (calculado en backend) |
| `unit_cost` | numeric | **DEFAULT 0** — costo al momento de la venta |

> ⚠️ **Alerta sobre `unit_cost`:** El campo existe con `DEFAULT 0`. Si el sistema lo llena automáticamente desde `products.cost_price` al momento de la venta (lo cual debe verificarse), entonces sí se puede calcular ganancia bruta línea a línea de forma histórica confiable. Si está en `0` por no haberse llenado, el dato de margen sería incorrecto.

**Capacidades analíticas confirmadas:**
- Productos más vendidos (por unidades y por monto)
- Productos sin movimiento
- Velocidad de rotación por producto

---

### 3. Productos — `products` (13 registros)

| Columna | Tipo | Notas |
|---------|------|-------|
| `name` | text | Nombre del producto |
| `price` | numeric | Precio de venta al público |
| `cost_price` | numeric | **DEFAULT 0** — costo base registrado |
| `last_purchase_price` | numeric (nullable) | Último precio de compra registrado |
| `last_purchase_date` | timestamptz (nullable) | Cuándo fue la última compra |
| `current_stock` | numeric | Stock actual |
| `min_stock` | numeric | Umbral de alerta de stock bajo |
| `category` | text (nullable) | Categoría del producto (texto libre) |
| `measurement_unit` | text (enum) | `unidad`, `kg`, `lb`, `g` |
| `supplier_id` | uuid (nullable) | Proveedor principal del producto |
| `brand` | text (nullable) | Marca del producto |

> ⚠️ **Alerta sobre `cost_price`:** El campo existe pero tiene `DEFAULT 0`. Si el usuario no llena este campo al crear los productos, todas las métricas de margen serían `100%` (incorrecto). Se debe verificar en datos reales cuántos de los 13 productos tienen `cost_price > 0`.

**Capacidades analíticas confirmadas (si `cost_price > 0`):**
- Margen bruto por producto
- Productos más rentables vs. más vendidos
- Valor del inventario (`current_stock × cost_price`)

---

### 4. Movimientos de Inventario — `inventory_movements` (113 registros)

| Columna | Tipo | Notas |
|---------|------|-------|
| `product_id` | uuid | Producto afectado |
| `movement_type` | text (enum) | `ingreso`, `gasto`, `venta`, `devolucion`, `ajuste_manual`, `entrada`, `salida`, `CORRECCION_SISTEMA` |
| `quantity` | numeric | Unidades del movimiento |
| `unit_cost` | numeric (nullable) | Precio de compra por unidad (nullable) |
| `total_cost` | numeric (nullable) | Costo total del movimiento (nullable) |
| `supplier_id` | uuid (nullable) | Proveedor de la entrada |
| `payment_type` | text (nullable, enum) | `contado` o `credito` — solo para entradas |
| `invoice_reference` | text (nullable) | Número de factura del proveedor |
| `reason` | text (nullable) | Razón del movimiento |

> **Nota arquitectónica:** Los campos `unit_cost` y `total_cost` son nullable. Esto confirma que registrar el precio de compra al recibir mercancía **no es obligatorio** en el flujo actual. Muchas entradas probablemente llegan sin este dato.

---

### 5. Lotes FIFO — `inventory_batches` (13 registros)

| Columna | Tipo | Notas |
|---------|------|-------|
| `product_id` | uuid | Producto del lote |
| `cost_unit` | numeric | **Obligatorio (≥ 0)** — costo unitario de este lote |
| `quantity_initial` | numeric | Unidades que entraron en el lote |
| `quantity_remaining` | numeric | Unidades que quedan |
| `is_active` | boolean (generated) | `true` si `quantity_remaining > 0` |

> **Hallazgo significativo:** El sistema ya implementa **método FIFO** con `inventory_batches`. Cada lote tiene su `cost_unit` registrado de forma **obligatoria**. Esto es la base para calcular el Costo de Ventas (COGS) de manera precisa por método FIFO. Esta capacidad está diseñada y existe en el esquema.

---

### 6. Sesiones de Caja — `cash_sessions` (19 registros)

| Columna | Tipo | Notas |
|---------|------|-------|
| `opening_balance` | numeric | Efectivo con que abrió la caja |
| `expected_balance` | numeric (nullable) | Lo que debería haber según ventas |
| `actual_balance` | numeric (nullable) | Lo que el cajero contó al cerrar |
| `difference` | numeric (nullable) | Diferencia (sobrante o faltante) |
| `opened_by` | uuid | Empleado que abrió |
| `closed_by` | uuid (nullable) | Empleado que cerró |
| `opened_at` | timestamptz | Timestamp de apertura |
| `closed_at` | timestamptz (nullable) | Timestamp de cierre |

**Capacidades analíticas confirmadas:**
- Historial de aperturas/cierres de caja
- Faltantes o sobrantes por sesión y por empleado
- Tiempo promedio de jornada laboral

---

### 7. Movimientos de Caja — `cash_movements` (66 registros)

| Columna | Tipo | Notas |
|---------|------|-------|
| `movement_type` | text (enum) | **Solo `ingreso` o `gasto`** |
| `amount` | numeric | Monto del movimiento |
| `description` | text | Descripción libre escrita por usuario |
| `sale_id` | uuid (nullable) | Si está asociado a una venta |
| `session_id` | uuid | Sesión de caja a la que pertenece |

> **Conclusión sobre gastos operativos:** No existe una tabla `expenses` dedicada. Los gastos (luz, agua, transporte, etc.) se registran como `cash_movements` con `movement_type = 'gasto'` y una `description` de texto libre. Esto implica:
> - ✅ El tendero **puede** registrar gastos operativos como movimientos de caja.
> - ❌ No hay categorización de gastos (no se puede distinguir "luz" de "salario" de "retiro del dueño").
> - ❌ No se puede registrar un gasto si no hay una sesión de caja activa.
> - ❌ No existe un concepto de "retiro del dueño" separado del gasto operativo.

---

### 8. Clientes y Fiado — `clients`, `client_ledger`, `client_transactions`

| Tabla | Registros | Dato clave |
|-------|-----------|------------|
| `clients` | 1 | `balance` (deuda actual), `credit_limit` (cupo máximo) |
| `client_ledger` | 5 | Libro mayor: `previous_balance → new_balance` por cada movimiento |
| `client_transactions` | 6 | Tipos: `compra` y `pago` |

**Capacidades analíticas confirmadas:**
- Total de cartera fiada pendiente (`SUM(clients.balance)`)
- Clientes con mayor deuda
- Historial de abonos y compras por cliente

---

### 9. Empleados — `employees` (4 registros)

| Campo existe | Campo | Nota |
|-------------|-------|------|
| ✅ | `name`, `alias` | Identificación del empleado |
| ✅ | `is_active` | Estado activo/inactivo |
| ✅ | `permissions` | jsonb con permisos por función |
| ❌ | `salary` | **No existe**. No hay registro de salarios en el sistema. |

---

### 10. Proveedores — `suppliers` (7 registros)

| Columna | Notas |
|---------|-------|
| `name` | Nombre del proveedor |
| `delivery_day` | Día de entrega (1–7, nullable) |
| `frequency_days` | Cada cuántos días visita (default 7) |
| `lead_time_days` | Días de anticipación para pedir |

**Capacidades analíticas confirmadas:**
- Qué productos vienen de qué proveedor
- Entradas de inventario agrupadas por proveedor
- (Futuro) Cuánto se le debe a cada proveedor si se implementan pagos a proveedores

---

### 11. Otras Tablas del Sistema

| Tabla | Registros | Propósito | Relevancia Analytics |
|-------|-----------|-----------|---------------------|
| `price_change_logs` | 0 | Historial de cambios de precio | Baja (sin datos aún) |
| `audit_logs` | 46 | Log de eventos del sistema | Nula para el tendero |
| `payment_methods` | 4 | Config de métodos de pago | Soporte para desglose |
| `transaction_types` | 6 | Config de tipos de transacción | Soporte para filtros |
| `sync_queue` | 0 | Cola de sincronización offline | Nula |
| `error_logs` | 0 | Log de errores | Nula |

---

## Mapa de Escenarios: ¿Dónde Estamos HOY?

Basado en la auditoría real del esquema, el sistema se encuentra en:

### ✅ Escenario A — CONFIRMADO (Datos 100% disponibles)
Métricas que se pueden mostrar **inmediatamente** sin ningún dato adicional:

| Métrica | Fuente de datos |
|---------|----------------|
| Ventas brutas por período | `sales.total` |
| Desglose por método de pago | `sales.payment_method` |
| Productos más vendidos (unidades) | `sale_items.quantity` agrupado |
| Productos sin movimiento (>30 días) | Última venta vs. fecha actual |
| Tendencia semanal | Ventas actuales vs. promedio 7 días |
| Ventas por empleado | `sales.employee_id` |
| Total de cartera fiada | `SUM(clients.balance)` |
| Cuadre de caja (faltantes/sobrantes) | `cash_sessions.difference` |
| Gastos de caja (sin categorizar) | `cash_movements WHERE type='gasto'` |

---

### ⚠️ Escenario B — CONDICIONAL (Requiere verificar calidad de datos)
Métricas disponibles **si `cost_price` y `unit_cost` en `sale_items` tienen valores > 0**:

| Métrica | Fuente de datos | Riesgo |
|---------|----------------|--------|
| Ganancia bruta por venta | `sale_items.unit_price - sale_items.unit_cost` | Alto: `unit_cost` tiene DEFAULT 0 |
| Margen promedio del negocio | `(ventas - costo) / ventas` | Alto: idem |
| Productos por rentabilidad | `(price - cost_price) / price` en `products` | Medio: `cost_price` tiene DEFAULT 0 |
| Valor del inventario | `SUM(current_stock × cost_price)` | Medio: idem |
| COGS por FIFO | `inventory_batches.cost_unit` | Bajo: campo obligatorio en batches |

---

### ❌ Escenario C — NO DISPONIBLE (Datos estructuralmente ausentes)
Métricas que **no se pueden calcular** con el esquema actual:

| Métrica | Motivo |
|---------|--------|
| Ganancia neta | No hay gastos categorizados ni salarios |
| Punto de equilibrio | No hay gastos fijos registrados |
| Costo de salarios | `employees.salary` no existe |
| Pagos a proveedores | No hay tabla de pagos a proveedores |
| Retiros del dueño | No distinguible de otros gastos de caja |

---

## Brechas Identificadas y su Impacto

| Brecha | Impacto en Analytics | Esfuerzo para Cerrarla |
|--------|---------------------|----------------------|
| `cost_price` puede ser 0 | Ganancia bruta incorrecta o imposible | Bajo: campo ya existe, solo UI que lo haga obligatorio |
| `sale_items.unit_cost` DEFAULT 0 | Historial de costos vendidos sin datos | Medio: verificar si el RPC de venta llena este campo |
| Sin categorías en `cash_movements.gasto` | No se puede desglosar gastos por tipo | Alto: requiere migración y nuevo flujo de UI |
| Sin `employees.salary` | Sin costo laboral real | Alto: nuevo campo + flujo de registro |
| Sin pagos a proveedores | Sin cuentas por pagar reales | Alto: nueva tabla + flujo completo |

---

## Próximos Pasos Recomendados

### Inmediato (sin cambios de esquema)
1. Verificar si el RPC `rpc_procesar_venta_v2` llena `sale_items.unit_cost` al momento de la venta. Si sí, el Escenario B ya está disponible.
2. Verificar en datos reales de staging cuántos productos tienen `cost_price > 0`.
3. Diseñar Dashboard del Escenario A como fase 1 (sin condiciones).

### Fase 2 (con cambios menores)
4. Hacer `cost_price` obligatorio en el formulario de creación de producto (UI, no esquema).
5. Agregar campo `category` obligatorio en `cash_movements` para distinguir tipos de gasto.

### Fase 3 (cambios estructurales, decisión del equipo)
6. Evaluar si agregar `employees.salary` agrega valor real dado que muchos tenderos tienen 0 o 1 empleado.
7. Evaluar si implementar "pagos a proveedores" es prioritario para el segmento de usuario actual.

---

*Documento generado por el rol Arquitecto de Producto y Requisitos.*
*Fuente: Esquema real de Supabase — proyecto `tienda-barrio-staging` (`zolanvecewgdcmfwzqdb`).*
