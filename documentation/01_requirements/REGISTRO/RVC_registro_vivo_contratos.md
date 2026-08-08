# Registro Vivo de Contratos (RVC)

> **Propósito:** Memoria acumulativa del sistema. Reduce el trabajo de "descubrir" a "verificar lo ya destilado". Evita que cada SDD nuevo tenga que re-escanear todo el ecosistema desde cero.
> **Uso:** 
> 1. Se consulta primero (filtrando por entidad) al iniciar un nuevo SDD.
> 2. Se actualiza (escribiendo nuevas filas o marcando banderas 🟡) al cerrar un SDD.
> 3. Al superar ~15-20 filas por dominio, se particionará en múltiples archivos (`RVC_financiero.md`, `RVC_inventario.md`, etc.).
> **Última Auditoría Global (QA + Architect):** 2026-08-07 (Consolidación Post-Saneamiento Documental)

---

| Entidad/Concepto | Contrato que impone | SDD de origen | Estado Documental | Estado en BD Real | Última verificación |
|------------------|---------------------|---------------|------------------|-------------------|---------------------|
| `supplier_invoices.reference_invoice_id` | Selección explícita + fallback FIFO (Regla #7). Módulo Cuentas por Pagar aislado como libreta digital. | SDD_019 | 🟢 Alineado | 🟢 Aplicado en BD | 2026-08-07 |
| `cash_movements.payment_method_id` | Obligatorio en todo movimiento de dinero. | SDD_020 / SDD_027 | 🟢 Alineado | 🟡 Diseñado en `DSD_007_01_v3_MIGRATION` | 2026-08-07 |
| Trigger `bridge_movement_to_batch` | Lista de exclusión de `movement_type` (venta, merma...). | SDD_006_01 | 🟢 Alineado | 🟢 Aplicado en BD | 2026-08-07 |
| `consume_stock_fifo` (Delegación Kardex) | La función no inserta en Kardex. El invocador DEBE asentar el movimiento tras recibir el desglose. | SDD_006_01 / SDD_016 | 🟢 Alineado | 🟡 Diseñado en `DSD_007_01_v3_MIGRATION` | 2026-08-07 |
| `inventory_batches` (Estado) | Prohibido usar estados nominales. Disponibilidad es estrictamente `quantity_remaining > 0`. | SDD_006_01 | 🟢 Alineado | 🟢 Aplicado en BD | 2026-08-07 |
| `consume_stock_fifo` (Bloqueo) | Utiliza `FOR UPDATE` fila por fila. El invocador DEBE correr dentro de una transacción que sostenga el candado hasta el final. | SDD_006_01 | 🟢 Alineado | 🟡 Diseñado en `DSD_007_01_v3_MIGRATION` | 2026-08-07 |
| `cash_session_balances` (Multicanal) | Deprecia los saldos globales en `cash_sessions`. Todo arqueo y balance se hace estrictamente por canal. | SDD_020 / SDD_027 | 🟢 Alineado | 🟢 Tabla creada en `20260727000000_multichannel_schema` | 2026-08-07 |
| `sale_item_batches` (Valoración COGS) | Prohibido calcular costo de ventas usando `products.purchase_price`. Todo reporte de utilidad DEBE leer las capas FIFO consumidas. | SDD_016 / SDD_010_016 | 🟢 Alineado | 🟡 Diseñado en `DSD_007_01_v3_MIGRATION` | 2026-08-07 |
| `cash_sessions` (Límite 24H) | Todo RPC que mueva dinero debe bloquear la inserción si `now() - opened_at > 24 hours`. | SDD_004 / SDD_020 / SDD_027_02 | 🟢 Alineado | 🟡 Pendiente en BD | 2026-08-07 |
| `daily_passes` (Caducidad masiva) | Todo cierre de caja debe ejecutar un update expirando los pases diarios (`expires_at = NOW()`). | SDD_001 / SDD_004 | 🟢 Alineado | 🟡 Pendiente en `cerrar_caja` | 2026-08-07 |
| Abonos de Clientes (`registrar_abono`) | Acción Inseparable: Bajar deuda y generar ingreso explícito en `cash_movements` con un canal válido. | SDD_009 / SDD_024 | 🟢 Alineado | 🟡 Pendiente refactor RPC | 2026-08-07 |
| Pagos Proveedor (`pay_supplier_invoice`) | Libreta independiente: Registro aislado de deuda pagada sin afectar caja ni inventario. | SDD_019 / SDD_025 | 🟢 Alineado | 🟢 Aplicado en BD (Tabla `supplier_invoices`) | 2026-08-07 |
| Registro de Gastos (`OPEX`) | Prohibido el INSERT directo desde UI. Requiere RPC `registrar_gasto_v2` con protección anti-sobregiro y canal. | SDD_022 / SDD_026 | 🟢 Alineado | 🟡 Pendiente crear RPC v2 | 2026-08-07 |
| Triggers `supplier_invoices` | Factura creada por usuario como registro aislado en la libreta digital (sin triggers logísticos automáticos). | SDD_019 | 🟢 Alineado | 🟢 Aplicado en BD | 2026-08-07 |
| Movimientos de Entrada (`rpc_registrar_entrada`) | Ceguera Financiera. PROHIBIDO alterar caja (`cash_movements`) o crear deudas. Todo ingreso físico asume su propio registro y lote. | SDD_003 / SDD_006_01_01 | 🟢 Alineado | 🟢 Aplicado en `20260724150000_fix_rpc_registrar_entrada` | 2026-08-07 |
| Movimientos de Salida | PROHIBICIÓN: El módulo de inventario NO PUEDE procesar mermas ni salidas. Todo egreso operativo debe pasar por el POS (`closure_type = merma`). | SDD_006_01_02 / SDD_007 | 🟢 Alineado | 🟢 Consolidado | 2026-08-07 |
| Gestor de Reembolsos (UX) | Obliga Frontend a enviar `original_sale_item_id` y canal. El precio a devolver es inmutable. Delegado 100% a `rpc_procesar_venta_v3`. | SDD_006_02 / SDD_007_01 | 🟢 Alineado | 🟡 Diseñado en `DSD_007_01_v3_MIGRATION` | 2026-08-07 |
| `products.code/sku` (PLU) | Debe tener Índice Parcial Único `WHERE is_active = true`. Permite reciclaje y optimiza autogeneración numérica. | SDD_006 / SDD_006_03 | 🟢 Alineado | 🟢 Aplicado en `20260727020000_soft_delete_products` | 2026-08-07 |
| `product_price_history` | Inmutabilidad Absoluta. Prohibidos los `UPDATE` y `DELETE` vía RLS. Todo cambio de catálogo debe firmarse con el JWT del autor. | SDD_010 | 🟢 Alineado | 🟡 Pendiente migración BD | 2026-08-07 |
| `daily_passes` (Reemplazo de PIN) | Queda estrictamente erradicado el uso de un "PIN de Caja" (Decisión D-01). La autorización la otorga el Pase Diario y la sesión de usuario. | SDD_001 / SDD_004 | 🟢 Alineado | 🟢 Consolidado (FRD_004_1 DEPRECATED) | 2026-08-07 |
| `auth.users` -> `stores` (Onboarding) | Trigger `handle_new_user_atomic` crea el Tenant *antes* de que el email sea confirmado. La seguridad recae en que GoTrue niega emisión de JWTs a emails no confirmados. | SDD_002 | 🟢 Alineado | 🟢 Aplicado en BD | 2026-08-07 |
| Cambio de Contraseña (Seguridad JWT) | Cualquier cambio a la contraseña maestra DEBE invocar `signOut({ scope: 'others' })` para purgar tokens en dispositivos remotos previniendo secuestros. | SDD_002_1 | 🟢 Alineado | 🟢 Consolidado | 2026-08-07 |
| Límite de Concurrencia (Sesiones) | El sistema debe limitar las sesiones concurrentes por tienda gestionadas desde el módulo de dispositivos. | SDD_015 / SDD_013 | 🟢 Alineado | 🟡 Diseñado en `SDD_015` | 2026-08-07 |
| Revocación Reactiva de JWT | La desactivación de un usuario exige invalidar pases y forzar logout en peticiones subsiguientes. | SDD_001 / SDD_015 / SDD_013 | 🟢 Alineado | 🟢 Diseñado en `SDD_001` y `SDD_015` | 2026-08-07 |
| Venta Forzada (`CORRECCION_SISTEMA`) | Prohibido vender con stock negativo. El Admin debe justificar y el backend inyectará un ajuste de tipo `CORRECCION_SISTEMA` atómicamente antes del asiento de venta. | SDD_014 / SDD_006 | 🟢 Alineado | 🟢 Consolidado | 2026-08-07 |
| Auditoría de Venta Forzada | Toda venta forzada debe crear un registro en `audit_logs` (acción `FORCE_SALE` referenciando el `sale_id`). Este registro bloquea el Cierre de Caja hasta que sea visado en el Modal de Auditoría. | SDD_005 / SDD_014 | 🟢 Alineado | 🟢 Consolidado en `SDD_005` | 2026-08-07 |
| Límite de Personal (5 empleados) | La base de datos debe rechazar vía RPC y RLS la inserción o reactivación (`is_active = true`) si la tienda ya posee 5 empleados activos. | SDD_002 / SDD_003 | 🟢 Alineado | 🟢 Consolidado en `SDD_002` y `SDD_003` | 2026-08-07 |
| Mapeo de Identidad Empleados | El término funcional "Alias numérico" (cédula o teléfono) mapea obligatoriamente a la columna `username` en la base de datos `employees`. | SDD_003 | 🟢 Alineado | 🟢 Consolidado en `SDD_003` | 2026-08-07 |
| Auditoría con Rastreo de Estado | La entidad `audit_logs` debe incluir `reviewed_by` y `reviewed_at`. La condición `reviewed_at IS NULL` será el bloqueador duro para el cierre de caja. | SDD_005 / SDD_014 | 🟢 Alineado | 🟢 Consolidado en `SDD_005` | 2026-08-07 |
| Aislamiento Multi-Tenant (Excepciones) | Toda función `SECURITY DEFINER` que salte barreras de RLS DEBE ejecutar `assert_store_access` en la primera línea. | SDD_002 / SDD_014 / SDD_019 | 🟢 Alineado | 🟢 Aplicado en BD | 2026-08-07 |
| Seguros de Concurrencia (Ventas) | El cálculo de déficit de inventario en ventas forzadas DEBE protegerse con `SELECT ... FOR UPDATE` a nivel de fila individual. | SDD_007_01 / SDD_014 | 🟢 Alineado | 🟡 Diseñado en `DSD_007_01_v3_MIGRATION` | 2026-08-07 |
| `local_id` (Idempotencia Offline) | El frontend debe inyectar un UUID único (`local_id`) en cada venta asíncrona para que el servidor rechace silenciosamente reintentos de red duplicados. | SDD_012 / SDD_011 | 🟢 Alineado | 🟢 Diseñado en `SDD_012` §8 y §9 | 2026-08-07 |
| `cash_sessions` (Orquestación 24H) | Prohibido alterar la firma del RPC de apertura de caja. El cron job asíncrono se apoyará exclusivamente en `status` y `opened_at`. | SDD_020 / SDD_017 | 🟢 Alineado | 🟢 Consolidado en `SDD_020` | 2026-08-07 |
| Reporte Financiero (Retrocompatibilidad) | Prohibido anidar JSON (`p_and_l`, `working_capital`). Todo nuevo KPI se añade como llave plana extendida. | SDD_018 | 🟢 Alineado | 🟢 Consolidado en `FRD_018` | 2026-08-07 |
| Reporte Financiero (Límite DoS) | El servidor debe truncar o rechazar peticiones operacionales cuyo rango temporal exceda 1 año para evitar saturación. | SDD_018 | 🟢 Alineado | 🟢 Consolidado en `FRD_018` | 2026-08-07 |
| Sincronización Asíncrona (Retrocompatibilidad) | Los nuevos parámetros de estado offline en el procesador de ventas DEBEN ser opcionales (`DEFAULT NULL` o `FALSE`). | SDD_012 | 🟢 Alineado | 🟢 Diseñado en `SDD_012` §8 | 2026-08-07 |
| Re-apertura Mutante de Cajas (`LATE_SYNC_UPDATE`) | Inyectar ventas offline en un periodo contable ya cerrado requiere actualizar `cash_session_balances` e insertar OBLIGATORIAMENTE un registro en `audit_logs`. | SDD_012 | 🟢 Alineado | 🟢 Diseñado en `SDD_012` §9 | 2026-08-07 |
| Persistencia Frontend (IndexedDB) | Prohibido almacenar colecciones de dominio (Clientes, Catálogo) en `localStorage`. Deben ir a `IndexedDB` por cuota de memoria. | SDD_009 / SDD_012 / SDD_028 | 🟢 Alineado | 🟢 Especificado en `SDD_012` y `SDD_009` | 2026-08-07 |
| Protección de Cola Offline (Cierre Sesión) | Prohibido ejecutar purgas ciegas tipo `localStorage.clear()` al cerrar sesión. El logout debe borrar tokens pero PRESERVAR la `sync_queue` de IndexedDB. | SDD_012 / SDD_028 | 🟢 Alineado | 🟢 Especificado en `SDD_012` §8 | 2026-08-07 |
| V3 POS RPC (`rpc_procesar_venta_v3`) | Único embudo de ventas que maneja `closure_type` (venta, fiado, merma, devoluciones) en una transacción atómica protegida por RLS. | SDD_007_01 | 🟢 Alineado | 🟡 Pendiente en BD (Migración V3) | 2026-08-07 |
| Idempotencia POS (`idempotency_key`) | Obligatorio inyectar UUID en cada venta para prevenir doble deducción por latencia. Restricción `UNIQUE` en tabla `sales`. | SDD_007_01 | 🟢 Alineado | 🟡 Pendiente en BD (Migración V3) | 2026-08-07 |
