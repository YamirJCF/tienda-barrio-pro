# FRD-023: Matriz de Impacto Cruzado - Caja Multicanal

### Nombre del Documento
Auditoría de Impacto Transversal: Migración a `cash_session_balances`

### Documentos Base (Referencias)
- `FRD_020_CAJA_MULTICANAL.md`, `FRD_022_GASTOS_MULTICANAL.md`
- Aplica Regla #6 del Proyecto: "Auditoría de Impacto Cruzado Antes de Modificar Esquema Compartido"

#### Descripción
La migración de un modelo de "saldo único" (columnas `expected_balance` y `actual_balance` en la tabla `cash_sessions`) a un modelo "multicanal" (tabla anexa `cash_session_balances` y columna `payment_method` en `cash_movements`) afecta profundamente a múltiples módulos del sistema que asumen la existencia y formato del modelo original. Este documento lista exhaustivamente los componentes que DEBEN refactorizarse para evitar fallos catastróficos.

---

## 1. Migración de Datos Históricos (Backfill y Transición)

### 1.1 `cash_movements` (Histórico)
- **Impacto:** Las filas existentes no tienen `payment_method`. Si se fuerza a `NOT NULL`, el sistema colapsará.
- **Refactor Obligatorio:** Se DEBE realizar un *backfill* retroactivo, actualizando todas las filas históricas a `payment_method = 'efectivo'`. Tras esto, la columna se puede marcar como `NOT NULL`.

### 1.2 `cash_sessions` (Sesiones Cerradas)
- **Impacto:** Existen turnos cerrados que solo tienen saldos en las columnas obsoletas `expected_balance` y `actual_balance`. Si los reportes leen de la nueva tabla, el historial desaparecerá.
- **Refactor Obligatorio:** Se DEBE ejecutar un script de migración que lea todas las sesiones históricas e inserte un registro equivalente en `cash_session_balances` (con `payment_method = 'efectivo'`) por cada sesión existente. Solo después de esta copia, se pueden depreciar las columnas antiguas.

---

## 2. Módulos y RPCs Financieros (Crítico)

### 1.1 `rpc_check_and_force_close_shifts` (Cierre Forzado)
- **Impacto:** Actualmente consulta `cash_movements` para sumar ingresos y restar gastos, generando un `v_expected_balance` único que inserta en `cash_sessions.actual_balance` y `expected_balance`.
- **Refactor Obligatorio:** DEBE agrupar la suma de `cash_movements` por `payment_method` y realizar un `INSERT` múltiple en la nueva tabla `cash_session_balances` para la sesión expirada, en lugar de actualizar las columnas obsoletas de `cash_sessions`.

### 1.2 `rpc_pay_supplier_invoice` (Cuentas por Pagar)
- **Impacto:** Actualmente inserta un registro en `cash_movements` con `movement_type = 'pago_proveedor'` pero sin método de pago (asumiendo que sale del pozo único).
- **Refactor Obligatorio:** DEBE recibir el parámetro `p_payment_method` y guardarlo en la tabla, de lo contrario descuadrará el arqueo multicanal.

### 1.3 `rpc_process_sale` / Funciones de Venta
- **Impacto:** Las ventas en efectivo se insertan en `cash_movements` asumiendo que son el único tipo de venta que afecta la caja.
- **Refactor Obligatorio:** TODA venta (Efectivo, Nequi, Daviplata) DEBE generar un registro en `cash_movements` etiquetado con su respectivo `payment_method`.

### 1.4 `registrar_abono` (Cartera de Clientes)
- **Impacto:** Actualmente no interactúa con `cash_movements`.
- **Refactor Obligatorio:** DEBE insertar el ingreso en `cash_movements` con el `payment_method` especificado por el usuario.

### 1.5 `rpc_get_comprehensive_financial_report` (Reporte de P&L)
- **Impacto:** Calcula el OPEX filtrando `cash_movements` por `movement_type = 'gasto'`.
- **Refactor Obligatorio:** Verificación de no-regresión. Aunque el método de pago no afecta el P&L (un gasto es un gasto sea en Nequi o Efectivo), se DEBE validar que la consulta SQL no se rompa por la adición de la nueva columna o por el cambio estructural de `cash_sessions` (si es que hace JOINs con los saldos esperados).

---

## 2. Triggers y Auditoría (Muy Crítico)

### 2.1 Triggers de `audit_caja` (Remediación de Auditoría)
- **Impacto:** El archivo `20260718130000_audit_remediation.sql` creó triggers sobre `cash_sessions` (ej. `AFTER INSERT`, `AFTER UPDATE OF status`) para capturar el `opening_balance`, `expected_balance` y `actual_balance` en la tabla histórica de auditoría.
- **Refactor Obligatorio:** Al depreciar o eliminar `expected_balance` y `actual_balance` de `cash_sessions`, estos triggers fallarán estruendosamente. El sistema de auditoría DEBE rediseñarse para capturar los balances desde la nueva tabla `cash_session_balances` al momento de cerrar la caja, garantizando que el "Evidence Hub" (FRD-005) siga funcionando con la data multicanal.

---

## 3. Interfaces de Usuario (Frontend)

### 3.1 `ForcedCloseAuditModal.vue`
- **Impacto:** Pide un único valor numérico al administrador para reconciliar la caja expirada.
- **Refactor Obligatorio:** DEBE pedir un valor por cada canal activo en la sesión.

### 3.2 `CashControlView.vue` y Cierre Regular
- **Impacto:** Muestra un único "Saldo Esperado".
- **Refactor Obligatorio:** DEBE listar los saldos agrupados por canal y desplegar N inputs al momento del arqueo final.

### 3.3 Formularios de Salida de Dinero (Gastos y Proveedores)
- **Impacto:** No preguntan origen de fondos.
- **Refactor Obligatorio:** `ExpensesView.vue` y `SupplierPayments.vue` (o equivalentes) DEBEN exigir la selección del método de pago.

## Conclusión Arquitectónica
La adición de la tabla `cash_session_balances` no es una simple extensión; es un "Breaking Change" estructural en el dominio de caja. Ninguna migración debe aplicarse en producción sin haber cubierto y probado todos los puntos de esta matriz de impacto cruzado, priorizando especialmente los triggers de auditoría y los cierres forzados.
