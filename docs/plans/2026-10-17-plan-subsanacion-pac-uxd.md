# Plan de Subsanación Documental y Cartografía `/pac-uxd` Pre-Código

> **Principio Rector:** Ningún archivo de código (`.sql`, `.ts`, `.vue`) se modifica hasta que:
> 1. Las inconsistencias entre SDDs, RVC y Base de Datos estén **subsanadas por escrito** en los documentos fuente (`SDD` y `RVC`).
> 2. Se haya determinado formalmente **sobre qué SDDs y componentes `.vue`** se ejecutará `/pac-uxd`.
> 3. Cada discrepancia del Frontend esté **cartografiada por escrito** en su respectivo informe `documentation/01_requirements/VERIFICACION/PAC_UXD_SDD_[NUMERO].md`.

---

## Diagnóstico de Origen: ¿Por qué surgieron las inconsistencias?

El análisis mecánico previo reveló **16 defectos (`F-1` a `F-16`)** y **1 conflicto inter-SDD (`D-F1` / `RN-012-04`)** provenientes de tres causas raíz documentales que deben cerrarse por escrito antes de tocar código:

1. **Contradicciones Inter-SDD o Intra-SDD no reconciliadas en el RVC (`F-8`, `F-16`, `D-F1`/`RN-012-04`, `F-4`):**
   - **`F-16` (Zona Horaria de Pases Diarios):** `SDD_001` §0.3 (`D-2`) y `SDD_015` §0.3 (`D-1`) fijaron `(now() AT TIME ZONE 'America/Bogota')::date`, pero `SDD_001` §4.6 (Caso G) dejó escrito `pass_date = CURRENT_DATE`, induciendo a que `get_current_store_id()` y `get_employee_id_from_session()` usaran `CURRENT_DATE` (UTC en servidor).
   - **`F-8` (Tope de Personal `1 Admin + 5 Empleados`):** `FRD_003` (RN-7) y `FRD_013` (RN-013-02) definen `1 Admin + 5 Empleados`, pero `SDD_003` §2.1 escribió `SELECT COUNT(*) FROM employees WHERE store_id = p_store_id AND is_active = true` sin excluir la fila del propietario (`owner_*` presente en `admin_profiles`), reduciendo el cupo real a 4 empleados operativos.
   - **`D-F1` y `RN-012-04` (Cero Cálculos en Cliente vs. Cola Offline):** `SDD_007_01` §2.3 prohíbe al cliente calcular o enviar montos/precios (`{ product_id, quantity }`), mientras que `SDD_012` §4.3 (`RN-012-04`), §4.5 y §5.1 exigen que en modo offline el cliente valide el cupo local y congele el `unit_price` histórico del momento de la venta, sin que `rpc_procesar_venta_v3` acepte aún ese precio histórico en sincronización diferida.
   - **`F-4` (Pago Mixto en POS):** `FRD_004` Caso B declara el Pago Mixto como `(Próximamente POS)`, pero `SDD_007_01` no incluyó la prohibición explícita del valor `'mixed'` que hoy existe en `CheckoutModal.vue` y `saleRepository.ts`.
2. **Pre-requisitos estructurales de `/pac-uxd` ausentes en 7 SDDs activos:**
   - El protocolo `/pac-uxd` exige en su **Bloque 1 (`B1.2`)** citar la **Sección 5 (Contrato de Interfaz)** y en su **Bloque 3 (`B3.8`)** listar textualmente los estados del **Diagrama de Estados (`stateDiagram-v2`)** del SDD.
   - En `SDD_015_GESTION_DISPOSITIVOS.md`, los Contratos de Interfaz están numerados como `## 3.` en lugar de `## 5.`.
   - Siete SDDs con interfaz de usuario (`SDD_002_1`, `SDD_002_REGISTRO_ADMIN`, `SDD_009`, `SDD_014`, `SDD_015`, `SDD_021`, `SDD_024`) tienen diagramas de secuencia (`sequenceDiagram`), pero carecen del bloque `stateDiagram-v2` requerido por `B3.8`.
3. **Ausencia total de reportes `PAC_UXD_SDD_[NUMERO].md` en `documentation/01_requirements/VERIFICACION/`:**
   - Actualmente `documentation/01_requirements/VERIFICACION/` contiene 7 reportes `PVS_A_SDD_*.md` (Backend), pero **0 reportes `PAC_UXD_SDD_*.md`** (Frontend).

---

## Etapa 1 — Subsanación Documental en SDDs y RVC (Pre-`/pac-uxd`)

Antes de ejecutar `/pac-uxd`, se enmendarán por escrito los siguientes documentos de especificación para que la Verdad Documental sea única, sin ambigüedades ni contradicciones:

| Tarea | Documentos a Enmendar | Defecto que Subsana por Escrito | Contenido Exacto de la Enmienda Documental |
|---|---|---|---|
| **T1.1** | `SDD_001_SEGURIDAD_DIARIA.md`<br>`SDD_015_GESTION_DISPOSITIVOS.md`<br>`RVC_registro_vivo_contratos.md` | **`F-16`** (Zona horaria UTC vs Bogotá)<br>**`F-15`** (Filtro TTL 5 min indocumentado)<br>**Pre-requisito `/pac-uxd`** en `SDD_015` | 1. En `SDD_001` §4.6 (Caso G) y §5.3: reemplazar `pass_date = CURRENT_DATE` por `pass_date = (now() AT TIME ZONE 'America/Bogota')::date` y prohibir filtros de expiración de 5 minutos sobre `requested_at` en cliente.<br>2. En `SDD_001` §0.3: registrar **Deuda `D-5`** sobre `get_current_store_id()` y `get_employee_id_from_session()` (usan `CURRENT_DATE` en vez de `America/Bogota`).<br>3. En `SDD_015`: renumerar `Contratos de Interfaz` a `## 5. Contrato de Interfaz` e incluir el `stateDiagram-v2` de estados del pase/dispositivo.<br>4. En `RVC`: agregar invariante transversal de Fecha Operativa `America/Bogota`. |
| **T1.2** | `SDD_003_GESTION_EMPLEADOS.md`<br>`RVC_registro_vivo_contratos.md` | **`F-8`** (Conteo de `owner_*` reduce cupo de 5 a 4 empleados) | 1. En `SDD_003` §2.1, §3 (RN-7) y §5.1: especificar que el conteo de máximo 5 empleados activos (`1 Admin + 5 Empleados`) debe excluir al propietario de tienda (`AND NOT EXISTS (SELECT 1 FROM public.admin_profiles ap WHERE ap.id = e.id)`).<br>2. En `SDD_003` §0.3: registrar **Deuda `D-4`** para actualizar la cláusula `WHERE` de `crear_empleado` en BD.<br>3. En `RVC`: actualizar nota de invariante en la fila de `crear_empleado`. |
| **T1.3** | `SDD_007_01_NUCLEO_POS.md`<br>`SDD_012_SINCRONIZACION_OFFLINE.md`<br>`RVC_registro_vivo_contratos.md` | **`D-F1` / `F-5`** (Cero cálculos vs. UI/Offline)<br>**`RN-012-04`** (Precio histórico offline)<br>**`F-4`** (Pago mixto en POS) | 1. En `SDD_007_01` §2.3 y §5.1: establecer que la visualización previa en el carrito es informativa (`SPEC-011`) pero el payload de venta online a `rpc_procesar_venta_v3` **prohíbe** enviar `total`, `subtotal` o `unit_price` (`p_items: [{ product_id, quantity }]`), y **prohíbe** `payment_method = 'mixed'` (`FRD_004`).<br>2. En `SDD_012` §4.3, §4.5, §5.1 y §0.3: formalizar que en modo desconectado (`OfflineSaleRecord`), el cliente guarda `historical_unit_price` del catálogo cacheado e invoca `rpc_procesar_venta_v3` con `p_is_offline_sync = true`; registrar **Deuda `D-6`** en `SDD_012` §0.3 para que `rpc_procesar_venta_v3` honre `historical_unit_price` cuando `p_is_offline_sync = true` (`RN-012-04`). |
| **T1.4** | `SDD_002_REGISTRO_ADMIN.md`<br>`SDD_002_1_CAMBIO_CONTRASENA.md`<br>`SDD_009_CLIENTES.md`<br>`SDD_014_VENTA_FORZADA_Y_AUDITORIA.md`<br>`SDD_021_HISTORIALES_MULTICANAL.md`<br>`SDD_024_POLITICA_FIADOS.md` | **Pre-requisito Bloque 3 (`B3.8`) de `/pac-uxd`** | Incorporar en la Sección 2 de cada uno de estos SDDs su respectivo Diagrama de Estados (`stateDiagram-v2`) de interfaz y transacción (estados de carga/skeleton, validación, vuelo/bloqueo de botón, éxito y error explícito anti-`$0 disfrazado`) para que `/pac-uxd` audite contra una matriz de estados explícita y no inferida. |

---

## Etapa 2 — Determinación Formal de SDDs para Ejecutar `/pac-uxd`

De los **36 archivos SDD** existentes en `documentation/01_requirements/SDD/`, se establece la clasificación completa para determinar con exactitud sobre cuáles se ejecutará `/pac-uxd`:

### 2.1 Grupo A — 18 SDDs con Interfaz de Usuario Activa (Objetivo Directo de `/pac-uxd`)

Cada fila de esta tabla constituye una ejecución obligatoria de `/pac-uxd [RUTA_DEL_COMPONENTE_VUE] [NUMERO_SDD]` y genera un archivo formal en `documentation/01_requirements/VERIFICACION/`:

| Ola | SDD Fuente | Archivo de Salida `/pac-uxd` | Componentes `.vue` y Capa de Datos Asociada a Auditar | Defectos Preliminares que Documentará por Escrito |
|---|---|---|---|---|
| **Ola 1**<br>*(Caja y Gastos)* | `SDD_004_CONTROL_DE_CAJA.md`<br>`SDD_020_CAJA_MULTICANAL.md` | `PAC_UXD_SDD_004.md`<br>`PAC_UXD_SDD_020.md` | • `frontend/src/views/CashControlView.vue`<br>• `frontend/src/components/cash/OpenRegisterModal.vue`<br>• `frontend/src/components/cash/CloseRegisterModal.vue`<br>• *(Store/Repo: `cashRegister.ts`, `cashRepository.ts`)* | • **`F-13` (Severidad Alta):** Violación de Arqueo Ciego (`POL-SEG-01`) al mostrar `Total Esperado` y calcular descuadre en cliente (`CashControlView.vue:183,332`, `CloseRegisterModal.vue:51,61,177`).<br>• Ausencia de desglose multicanal (`rpc_abrir_caja_multicanal` / `rpc_cerrar_caja_multicanal`). |
| **Ola 1**<br>*(Caja y Gastos)* | `SDD_017_CICLO_CONTABLE_Y_SESIONES.md` | `PAC_UXD_SDD_017.md` | • `frontend/src/components/ForcedCloseAuditModal.vue`<br>• *(Repo: `cashRepository.ts`)* | • Contraste de payload contra `rpc_reconciliar_cierre_forzado` (`p_real_digital_balances`, `p_admin_notes`) y manejo de alerta de turno >24h. |
| **Ola 1**<br>*(Caja y Gastos)* | `SDD_022_GASTOS_MULTICANAL.md` | `PAC_UXD_SDD_022.md` | • `frontend/src/views/ExpensesView.vue`<br>• *(Store/Repo: `expenses.ts`, `expenseRepository.ts`)* | • **`F-2` (Severidad Alta):** Inserción directa `.from('cash_movements').insert()` en `expenseRepository.ts:200` en lugar de `rpc_registrar_gasto_v2`, omitiendo `p_payment_method` y voucher. |
| **Ola 2**<br>*(Inventario y CxP)* | `SDD_006_NUCLEO_INVENTARIO_PADRE.md`<br>`SDD_006_03_CODIGO_PRODUCTO.md` | `PAC_UXD_SDD_006.md`<br>`PAC_UXD_SDD_006_03.md` | • `frontend/src/views/InventoryView.vue`<br>• `frontend/src/components/ProductFormModal.vue`<br>• `frontend/src/components/inventory/KardexModal.vue`<br>• `frontend/src/components/ProductSearchModal.vue` | • Verificación de payloads a `get_inventory_products`, `get_inventory_kardex`, `rpc_soft_delete_product` y `buscar_producto_pos` (búsqueda rápida por PLU). |
| **Ola 2**<br>*(Inventario y CxP)* | `SDD_006_01_01_MOVIMIENTOS_ENTRADA.md` | `PAC_UXD_SDD_006_01_01.md` | • `frontend/src/views/StockEntryView.vue`<br>• *(Repo: `inventoryRepository.ts`)* | • Verificación de llamada a `rpc_registrar_entrada` vs. mutaciones directas o funciones legacy de movimientos. |
| **Ola 2**<br>*(Inventario y CxP)* | `SDD_010_HISTORIAL_PRECIOS.md` | `PAC_UXD_SDD_010.md` | • `frontend/src/components/inventory/BatchHistoryModal.vue`<br>• `frontend/src/components/analytics/InventoryValuationCard.vue` | • Contraste contra `rpc_actualizar_precio_lote` y consulta de historial de costos/precios por lote. |
| **Ola 2**<br>*(Inventario y CxP)* | `SDD_019_CUENTAS_POR_PAGAR.md` | `PAC_UXD_SDD_019.md` | • `frontend/src/views/PayablesView.vue`<br>• `frontend/src/components/suppliers/PayInvoiceModal.vue`<br>• `frontend/src/views/SuppliersView.vue` | • Contraste contra `rpc_crear_factura_proveedor`, `rpc_pay_supplier_invoice` y `rpc_obtener_cuentas_por_pagar`, más verificación anti-`$0 disfrazado`. |
| **Ola 3**<br>*(Ventas POS y Clientes)* | `SDD_007_01_NUCLEO_POS.md`<br>`SDD_007_02_TICKET_DE_VENTA.md` | `PAC_UXD_SDD_007_01.md`<br>`PAC_UXD_SDD_007_02.md` | • `frontend/src/views/POSView.vue`<br>• `frontend/src/components/sales/CheckoutModal.vue`<br>• `frontend/src/components/WeightCalculatorModal.vue`<br>• *(Stores/Repos: `cart.ts`, `sales.ts`, `saleRepository.ts`)* | • **`F-3` (Severidad Alta):** `saleRepository.ts:168` invoca `rpc_procesar_venta_v2` sin `p_idempotency_key` en vez de `rpc_procesar_venta_v3`.<br>• **`F-4` (Severidad Alta):** `CheckoutModal.vue` expone `'mixed'` y `saleRepository.ts:163` lo degrada silenciosamente a `'efectivo'`.<br>• **`F-5` (Severidad Alta):** `stores/cart.ts:38-39,268` calcula totales y `roundToNearest50` en cliente. |
| **Ola 3**<br>*(Ventas POS y Clientes)* | `SDD_014_VENTA_FORZADA_Y_AUDITORIA.md` | `PAC_UXD_SDD_014.md` | • `frontend/src/components/ForceSaleModal.vue` | • Contraste de payload contra `rpc_force_sale` (justificación >=10 caracteres, rol Admin/Owner, `p_idempotency_key`). |
| **Ola 3**<br>*(Ventas POS y Clientes)* | `SDD_009_CLIENTES.md` | `PAC_UXD_SDD_009.md` | • `frontend/src/views/ClientListView.vue`<br>• `frontend/src/views/ClientDetailView.vue`<br>• `frontend/src/components/ClientFormModal.vue`<br>• *(Store/Repo: `clients.ts`, `clientRepository.ts`)* | • **`F-1` (Severidad Alta):** `stores/clients.ts:189` llama `registrar_abono` con 3 argumentos (error `42883`) en lugar de `rpc_registrar_abono`, y resta el saldo localmente (`clients.ts:211`).<br>• Ausencia de uso de `rpc_admin_get_clients`. |
| **Ola 4**<br>*(Auditoría, Historiales y Reportes)* | `SDD_005_AUDITORIA_TRAZABILIDAD.md` | `PAC_UXD_SDD_005.md` | • `frontend/src/views/SystemAuditView.vue`<br>• *(Store: `audit.ts`)* | • Contraste contra `rpc_obtener_auditoria_evidence_hub` y `rpc_log_security_event`. |
| **Ola 4**<br>*(Auditoría, Historiales y Reportes)* | `SDD_008_REPORTES.md` | `PAC_UXD_SDD_008.md` | • `frontend/src/views/ReportsView.vue`<br>• `frontend/src/components/reports/SmartSupplySection.vue`<br>• `frontend/src/components/modals/BulkSupplierAssign.vue`<br>• `frontend/src/components/SmartDailySummary.vue` | • Contraste contra `get_daily_summary`, `get_smart_supply_report` (`has_repressed_demand`, `saturated_days`) y `rpc_asignar_proveedor_masivo`. |
| **Ola 4**<br>*(Auditoría, Historiales y Reportes)* | `SDD_018_CONTROL_OPERACIONAL.md` | `PAC_UXD_SDD_018.md` | • `frontend/src/views/FinancialDashboardView.vue`<br>• `frontend/src/views/DashboardView.vue` | • Contraste contra `rpc_get_comprehensive_financial_report` y verificación de cero sumatorias financieras en cliente. |
| **Ola 4**<br>*(Auditoría, Historiales y Reportes)* | `SDD_021_HISTORIALES_MULTICANAL.md`<br>`SDD_027_01_REPORTES_CAJA.md` | `PAC_UXD_SDD_021.md`<br>`PAC_UXD_SDD_027_01.md` | • `frontend/src/views/HistoryView.vue`<br>• `frontend/src/components/history/SaleDetailModal.vue`<br>• `frontend/src/components/history/HistoryItemCard.vue` | • Contraste contra `rpc_obtener_historial_caja_multicanal`, `get_history_ventas`, `get_sale_detail`, `rpc_anular_venta` (`SDD_007`) y `rpc_procesar_reembolso_item` (`SDD_006_02`). |
| **Ola 5**<br>*(Seguridad, Dispositivos, Empleados y Offline)* | `SDD_001_SEGURIDAD_DIARIA.md`<br>`SDD_015_GESTION_DISPOSITIVOS.md` | `PAC_UXD_SDD_001.md`<br>`PAC_UXD_SDD_015.md` | • `frontend/src/views/DailyWaitingRoom.vue`<br>• `frontend/src/views/GatekeeperPending.vue`<br>• `frontend/src/views/AdminHubView.vue`<br>• `frontend/src/views/NotificationCenterView.vue`<br>• *(Repo: `authRepository.ts`)* | • **`F-6` y `F-15` (Severidad Alta):** `authRepository.ts:458,460,494` usa fecha UTC (`toISOString().split('T')[0]`) y filtro indocumentado de 5 minutos sobre `requested_at`.<br>• **`F-7` (Severidad Alta):** `authRepository.ts:536-542` ejecuta `.from('daily_passes').update()` directo al rechazar/revocar en vez de `rpc_gestionar_dispositivo`. |
| **Ola 5**<br>*(Seguridad, Dispositivos, Empleados y Offline)* | `SDD_003_GESTION_EMPLEADOS.md` | `PAC_UXD_SDD_003.md` | • `frontend/src/views/EmployeeManagerView.vue`<br>• `frontend/src/components/EmployeeFormModal.vue` | • Contraste contra `crear_empleado`, `toggle_empleado_activo`, `actualizar_pin_empleado`, `rpc_obtener_empleados` y visualización del cupo `5/5`. |
| **Ola 5**<br>*(Seguridad, Dispositivos, Empleados y Offline)* | `SDD_012_SINCRONIZACION_OFFLINE.md` | `PAC_UXD_SDD_012.md` | • `frontend/src/components/common/ConflictResolver.vue`<br>• `frontend/src/components/common/SyncIndicator.vue`<br>• *(Store: `syncQueue.ts`)* | • **`F-3` Offline (Severidad Alta):** `syncQueue.ts:418` invoca `rpc_procesar_venta_v2` sin `p_idempotency_key` ni `p_is_offline_sync`.<br>• **`F-14` (Severidad Alta):** `syncQueue.ts:441` inserta directo en `.from('clients').insert()`. |
| **Ola 5**<br>*(Auth Admin)* | `SDD_002_REGISTRO_ADMIN.md`<br>`SDD_002_1_CAMBIO_CONTRASENA.md` | `PAC_UXD_SDD_002.md`<br>`PAC_UXD_SDD_002_1.md` | • `frontend/src/views/RegisterStoreView.vue`<br>• `frontend/src/views/LoginView.vue`<br>• `frontend/src/components/security/ChangePasswordModal.vue`<br>• `frontend/src/views/auth/UpdatePasswordView.vue` | • Contraste contra `registerStore`, `rpc_verify_store_pin`, `changePassword` y `updatePasswordFromRecovery`. |

---

### 2.2 Grupo B — SDDs Transversales / Normativos Auditados por Cobertura en Grupo A

| SDD Transversal | Naturaleza | Reporte `PAC_UXD` del Grupo A que Audita su Contrato |
|---|---|---|
| `SDD_006_02_GESTOR_REEMBOLSOS.md` | Acción de reembolso parcial sobre ticket | Auditado en `PAC_UXD_SDD_021.md` (`SaleDetailModal.vue`) |
| `SDD_007_NUCLEO_VENTAS_PADRE.md` | Documento padre de ventas y anulaciones | Auditado en `PAC_UXD_SDD_007_01.md`, `PAC_UXD_SDD_007_02.md` y `PAC_UXD_SDD_021.md` |
| `SDD_010_016_VALORACION_FIFO.md` | Función interna Postgres (`consume_stock_fifo`) | Sin UI directa; despiece verificado en `PAC_UXD_SDD_007_02.md` y `PAC_UXD_SDD_010.md` |
| `SDD_011_MANEJO_ERRORES.md` | Esquema universal `ActionResponse` y catálogo | Verificado transversalmente en el **Bloque 3** de todos los `PAC_UXD_SDD_*.md` |
| `SDD_013_GESTION_SESIONES.md` | Límite de concurrencia y revocación remota | Auditado en `PAC_UXD_SDD_001.md` y `PAC_UXD_SDD_015.md` (`AdminHubView.vue` / `LoginView.vue`) |
| `SDD_023_IMPACTO_CRUZADO_MULTICANAL.md` | Matriz de impacto cruzado multicanal | Auditado en `PAC_UXD_SDD_020.md`, `PAC_UXD_SDD_017.md` y `PAC_UXD_SDD_022.md` |
| `SDD_024_POLITICA_FIADOS.md` | Política contable de fiados (`ledger` vs `cash`) | Auditado en `PAC_UXD_SDD_009.md` (`ClientDetailView.vue`) y `PAC_UXD_SDD_007_01.md` (`CheckoutModal.vue`) |
| `SDD_026_POLITICA_GASTOS_INMEDIATOS.md` | Política de egreso inmediato de caja | Auditado en `PAC_UXD_SDD_022.md` (`ExpensesView.vue`) |
| `SDD_028_ALMACENAMIENTO_LOCAL.md` | Política de IndexedDB y `localStorage` | Auditado en `PAC_UXD_SDD_012.md` (`ConflictResolver.vue` / `syncQueue.ts`) |

---

### 2.3 Grupo C — 8 SDDs Stubs / Obsoletos (61 líneas — Excluidos)

`SDD_002_AUTORIZACION_ESTRICTA.md`, `SDD_003_INDEPENDENCIA_LOGISTICA_CONTABLE.md`, `SDD_006_01_02_MOVIMIENTOS_SALIDA.md`, `SDD_006_01_NUCLEO_INVENTARIO.md`, `SDD_016_CORRECCION_COSTO_VENTAS.md`, `SDD_025_POLITICA_DEUDAS_PROVEEDORES.md`, `SDD_027_02_LIMITE_24_HORAS.md`, `SDD_027_NUCLEO_CAJA_DIARIA.md`.

---

## Etapa 3 — Protocolo de Ejecución de `/pac-uxd` (Cero Código, 100% Cartografía Escrita)

Para cada SDD del **Grupo A (Sección 2.1)**, se ejecutará `/pac-uxd` generando su informe en `documentation/01_requirements/VERIFICACION/PAC_UXD_SDD_[NUMERO].md` con los Bloques 1, 2, 2b, 3, 4 y 5 completos y el conteo exacto de la Regla 9.

---

## Etapa 4 — Subsanación de Defectos en Código (Solo tras completar Etapas 1, 2 y 3)

1. **Sub-etapa 4.1 (`Ola 6 SQL`):** Migración SQL para cerrar las deudas documentadas en la Etapa 1 (`D-5` de `SDD_001` sobre zona horaria en helpers RLS, `D-4` de `SDD_003` sobre exclusión del owner en tope de 5 empleados, y `D-6` de `SDD_012` sobre `historical_unit_price` en sincronización offline).
2. **Sub-etapa 4.2 (Frontend `.ts` y `.vue`):** Ejecución de las instrucciones atómicas de cada reporte `PAC_UXD_SDD_[NUMERO].md` por Olas 1 a 5.
3. **Sub-etapa 4.3 (Verificación con Evidencia Real):** Suite Vitest (`npx vitest run`) al 100%.
