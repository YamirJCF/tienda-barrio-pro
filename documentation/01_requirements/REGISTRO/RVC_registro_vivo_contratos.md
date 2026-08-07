# Registro Vivo de Contratos (RVC)

> **Propósito:** Memoria acumulativa del sistema. Reduce el trabajo de "descubrir" a "verificar lo ya destilado". Evita que cada SDD nuevo tenga que re-escanear todo el ecosistema desde cero.
> **Uso:** 
> 1. Se consulta primero (filtrando por entidad) al iniciar un nuevo SDD.
> 2. Se actualiza (escribiendo nuevas filas o marcando banderas 🟡) al cerrar un SDD.
> 3. Al superar ~15-20 filas por dominio, se particionará en múltiples archivos (`RVC_financiero.md`, `RVC_inventario.md`, etc.).

---

| Entidad/Concepto | Contrato que impone | SDD de origen | Estado | Última verificación |
|------------------|---------------------|---------------|--------|---------------------|
| `supplier_invoices.reference_invoice_id` | Selección explícita + fallback FIFO (Regla #7) | SDD_019 | 🟢 Estable | 2026-07-26 |
| `cash_movements.payment_method_id` | Obligatorio en todo movimiento de dinero | SDD_027 | 🟡 Pendiente en `rpc_procesar_venta_v3` (BD) | 2026-08-04 |
| Trigger `bridge_movement_to_batch` | Lista de exclusión de `movement_type` (venta, merma...) | SDD_006_01 | 🟢 Estable | 2026-08-04 |
| `consume_stock_fifo` (Delegación Kardex) | La función no inserta en Kardex. El invocador DEBE asentar el movimiento tras recibir el desglose. | SDD_006_01 | 🟡 Pendiente en `rpc_procesar_venta_v3` (BD) | 2026-08-04 |
| `inventory_batches` (Estado) | Prohibido usar estados nominales. Disponibilidad es estrictamente `quantity_remaining > 0`. | SDD_006_01 | 🟢 Estable | 2026-08-04 |
| `consume_stock_fifo` (Bloqueo) | Utiliza `FOR UPDATE` fila por fila. El invocador DEBE correr dentro de una transacción que sostenga el candado hasta el final. | SDD_006_01 | 🟡 Pendiente en `rpc_procesar_venta_v3` (BD) | 2026-08-04 |
| `cash_session_balances` (Multicanal) | Deprecia los saldos globales en `cash_sessions`. Todo arqueo y balance se hace estrictamente por canal. | SDD_027 | 🟡 Pendiente refactor de RPCs (Reportes y Cierres) | 2026-08-04 |
| `sale_item_batches` (Valoración COGS) | Prohibido calcular costo de ventas usando `products.purchase_price`. Todo reporte de utilidad DEBE leer las capas FIFO consumidas. | SDD_010_016 | 🟡 Pendiente verificar `rpc_get_comprehensive_financial_report` | 2026-08-04 |
| `cash_sessions` (Límite 24H) | Todo RPC que mueva dinero debe bloquear la inserción si `now() - opened_at > 24 hours`. | SDD_027_02 | 🟡 Pendiente en `rpc_procesar_venta_v3` y RPCs de Abonos/Gastos | 2026-08-04 |
| `daily_passes` (Caducidad masiva) | Todo cierre de caja debe ejecutar un update expirando los pases diarios (`expires_at = NOW()`). | SDD_004 | 🟡 Pendiente inyectar en `cerrar_caja` | 2026-08-04 |
| Abonos de Clientes (`registrar_abono`) | Acción Inseparable: Bajar deuda y generar ingreso explícito en `cash_movements` con un canal válido. | SDD_024 | 🟡 Pendiente reescribir RPC | 2026-08-04 |
| Pagos Proveedor (`pay_supplier_invoice`) | Prevención Sobregiro: Debe exigir `payment_method` y fallar si `expected_balance < p_amount`. | SDD_025 | 🟡 Pendiente reescribir RPC | 2026-08-04 |
| Registro de Gastos (`OPEX`) | Prohibido el INSERT directo desde UI. Requiere RPC `registrar_gasto_v2` con protección anti-sobregiro. | SDD_026 | 🟡 Pendiente crear RPC | 2026-08-04 |
| Triggers `supplier_invoices` | Creación de factura automática si `payment_type = credito`. Deducción en cascada FIFO ante devoluciones. | SDD_019 | 🟡 Pendiente programar autómatas (DB) | 2026-08-04 |
| Movimientos de Entrada (`rpc_registrar_entrada`) | Ceguera Financiera. PROHIBIDO alterar caja (`cash_movements`) o crear deudas. Todo ingreso físico asume su propio registro y lote. | SDD_006_01_01 | 🟡 Pendiente refactor RPC (Limpieza BD) | 2026-08-04 |
| Movimientos de Salida | PROHIBICIÓN: El módulo de inventario NO PUEDE procesar mermas ni salidas. Todo egreso operativo debe pasar por el POS (`closure_type = merma`). | SDD_006_01_02 | 🟢 Consolidado documentalmente en POS | 2026-08-04 |
| Gestor de Reembolsos (UX) | Obliga Frontend a enviar `original_sale_item_id` y canal. El precio a devolver es inmutable. Delegado 100% a `rpc_procesar_venta_v3`. | SDD_006_02 | 🟡 Pendiente construir componente Vue | 2026-08-04 |
| `products.code/sku` (PLU) | Debe tener Índice Parcial Único `WHERE is_active = true`. Permite reciclaje y optimiza autogeneración numérica. | SDD_006_03 | 🟡 Pendiente migración BD (Índice y longitud) | 2026-08-04 |
| `product_price_history` | Inmutabilidad Absoluta. Prohibidos los `UPDATE` y `DELETE` vía RLS. Todo cambio de catálogo debe firmarse con el JWT del autor. | SDD_010 | 🟡 Pendiente migración BD (Trigger + RLS) | 2026-08-04 |
| `daily_passes` (Reemplazo de PIN) | Queda estrictamente erradicado el uso de un "PIN de Caja" para autorizar transacciones financieras. La autorización la otorga el token JWT respaldado por el Pase. | SDD_001 | 🟢 Consolidado documentalmente | 2026-08-04 |
| `auth.users` -> `stores` (Onboarding) | Trigger `handle_new_user_atomic` crea el Tenant *antes* de que el email sea confirmado. La seguridad recae en que GoTrue niega emisión de JWTs a emails no confirmados. | SDD_002 | 🟢 Auditado y Consolidado | 2026-08-04 |
| Cambio de Contraseña (Seguridad JWT) | Cualquier cambio a la contraseña maestra DEBE invocar `signOut({ scope: 'others' })` para purgar tokens en dispositivos remotos previniendo secuestros. | SDD_002_1 | 🟢 Auditado y Consolidado | 2026-08-05 |
| Límite de Concurrencia (Sesiones) | El sistema debe limitar a 6 las sesiones concurrentes por tienda. Como GoTrue no lo soporta nativamente, esto exige construir una tabla interceptora (`device_sessions` o similar) antes de emitir Pases Diarios. | SDD_013 | 🟡 Pendiente programar lógica | 2026-08-05 |
| Revocación Reactiva de JWT | La desactivación de un usuario no destruye sus JWTs instantáneamente. Exige implementar un interceptor global que evalúe si la cuenta fue desactivada en cada petición para forzar el logout local. | SDD_013 | 🟡 Pendiente programar lógica | 2026-08-05 |
| Venta Forzada (`CORRECCION_SISTEMA`) | Prohibido vender con stock negativo. El Admin debe justificar y el backend inyectará un ajuste de tipo `CORRECCION_SISTEMA` atómicamente antes del asiento de venta. | SDD_014 | 🟢 Auditado y Consolidado | 2026-08-05 |
| Auditoría de Venta Forzada | Toda venta forzada debe crear un registro en `audit_logs` (acción `FORCE_SALE` referenciando el `sale_id`). Este registro bloquea el Cierre de Caja hasta que sea visado en el Modal de Auditoría. | SDD_014 | 🟢 Auditado y Consolidado | 2026-08-05 |
| Límite de Personal (5 empleados) | La base de datos debe rechazar vía RPC y RLS la inserción o reactivación (`is_active = true`) si la tienda ya posee 5 empleados activos. | SDD_003 | 🟢 Auditado y Consolidado | 2026-08-05 |
| Mapeo de Identidad Empleados | El término funcional "Alias numérico" (cédula o teléfono) mapea obligatoriamente a la columna `username` en la base de datos `employees`. | SDD_003 | 🟢 Auditado y Consolidado | 2026-08-05 |
| Auditoría con Rastreo de Estado | La entidad `audit_logs` debe incluir `reviewed_by` y `reviewed_at`. La condición `reviewed_at IS NULL` será el bloqueador duro para el cierre de caja, en lugar de un bloqueo genérico por sesión. | SDD_014 | 🟢 Auditado y Consolidado | 2026-08-05 |
| Aislamiento Multi-Tenant (Excepciones) | Toda función `SECURITY DEFINER` que salte barreras de RLS (como `rpc_force_sale` o `rpc_pay_supplier_invoice`) DEBE ejecutar `assert_store_access` en la primera línea. | SDD_014 / SDD_019 | 🟢 Auditado y Consolidado | 2026-08-05 |
| Seguros de Concurrencia (Ventas) | El cálculo de déficit de inventario en ventas forzadas DEBE protegerse con `SELECT ... FOR UPDATE` a nivel de fila individual antes de calcular y corregir, previniendo inyección de stock fantasma concurrente. | SDD_014 | 🟢 Auditado y Consolidado | 2026-08-05 |
| `local_id` (Idempotencia Offline) | El frontend debe inyectar un UUID único (`local_id`) en cada venta asíncrona para que el servidor rechace silenciosamente reintentos de red duplicados. | SDD_011 | 🟡 Pendiente alterar `sales` y RPC | 2026-08-05 |
| `cash_sessions` (Orquestación 24H) | Prohibido alterar la firma del RPC de apertura de caja. El cron job asíncrono se apoyará exclusivamente en `status` y `opened_at`. | SDD_017 | 🟢 Auditado y Consolidado | 2026-08-05 |
| Reporte Financiero (Retrocompatibilidad) | Prohibido anidar JSON (`p_and_l`, `working_capital`). Todo nuevo KPI se añade como llave plana extendida para no romper el dashboard de Vue. | SDD_018 | 🟡 Pendiente alterar RPC | 2026-08-05 |
| Reporte Financiero (Límite DoS) | El servidor debe truncar o rechazar peticiones operacionales cuyo rango temporal exceda 1 año para evitar saturación. | SDD_018 | 🟡 Pendiente alterar RPC | 2026-08-05 |
| Sincronización Asíncrona (Retrocompatibilidad) | Los nuevos parámetros de estado offline en el procesador de ventas DEBEN ser opcionales (`DEFAULT NULL` o `FALSE`) para no colapsar las ventas online puras. | SDD_012 | 🟡 Pendiente alterar RPC | 2026-08-05 |
| Re-apertura Mutante de Cajas (LATE_SYNC_UPDATE) | Inyectar ventas offline en un periodo contable ya cerrado requiere actualizar `cash_session_balances` e insertar OBLIGATORIAMENTE un registro en `audit_logs` justificando la mutación histórica. | SDD_012 | 🟡 Pendiente programar lógica | 2026-08-05 |
| Persistencia Frontend (IndexedDB) | Prohibido almacenar colecciones de dominio (Clientes, Catálogo) en `localStorage`. Deben ir a `IndexedDB` por cuota de memoria. | SDD_028 | 🟡 Pendiente refactor UI | 2026-08-05 |
| Protección de Cola Offline (Cierre Sesión) | Prohibido ejecutar purgas ciegas tipo `localStorage.clear()` al cerrar sesión. El logout debe borrar tokens pero PRESERVAR la `sync_queue` de IndexedDB. | SDD_028 | 🟡 Pendiente refactor UI | 2026-08-05 |
