# Changelog

All notable changes to this project will be documented in this file.

## [1.6.0] - 2026-10-17

### Added
- **Architecture & Documentation (PAC-SDD v2.0 & PAC-UXD):**
  - Rectificación integral de los 36 SDDs al estándar PAC-SDD v2.0 (`SDD_001` a `SDD_027`) y archivo formal de especificaciones obsoletas (`SDD_010`, `SDD_016`) en `_deprecated/`.
  - Auditoría estructural de la interfaz mediante el protocolo `/pac-uxd` generando 21 reportes de discrepancia (`PAC_UXD_001` a `PAC_UXD_027`) y sincronizando el Registro Vivo de Contratos (`RVC_registro_vivo_contratos.md`).
- **Database & Backend Authority (Supabase Waves 1–6):**
  - **Multicanalidad y Arqueo Ciego (`cash_sessions`, `cash_movements`):** Nuevas columnas `category`, `payment_method`, `voucher_ref`, `expected_balances`, `actual_balances` y `discrepancies`. RPCs `rpc_get_pending_Yesterday_sessions`, `rpc_close_expired_session`, `rpc_get_cash_control_summary` y `rpc_register_cash_movement` actualizados para inicializar canales digitales en \$0 y preservar el arqueo ciego sin filtrar saldos esperados antes del conteo.
  - **Ventas, Anulaciones e Idempotencia Offline (`rpc_procesar_venta_v3`, `rpc_anular_venta`, `rpc_procesar_devolucion`):** Creación de `rpc_procesar_venta_v3` con soporte para `p_idempotency_key` y resolución de duplicados (`DUPLICATE_RESOLVED`). Anulación de ventas atada a turno abierto y canal original (`voided_at`, `void_session_id`). Devoluciones multicanal con validación de fondos por canal y registro tipificado como `Reembolso`.
  - **Inventario, Lotes FIFO y Paginación (`rpc_get_products_paginated`, `rpc_get_kardex_history`, `rpc_assign_supplier_bulk`):** Paginación progresiva en servidor (20 ítems), historial Kardex filtrable por fechas/tipo/empleado, asignación masiva de proveedores y alerta de demanda reprimida/umbral de silencio en `get_smart_supply_report`.
  - **Cuentas por Pagar, Clientes y Empleados (`rpc_get_supplier_invoices_paginated`, `rpc_pay_supplier_invoice`, `rpc_get_clients_filtered`, `rpc_get_client_ledger_paginated`):** Normalización Title Case de proveedores (`trg_normalize_supplier_name`), pago multicanal de facturas con opción de registro en caja, filtros de cartera y paginación del libro mayor de clientes.
  - **Seguridad Diaria, Sesiones y Dispositivos (`rpc_gestionar_dispositivo`, `expire_daily_passes`):** Corrección de `expire_daily_passes()` para que el cierre de turno de caja no revoque el pase diario (Decisión `D-03`), consolidación del límite de 3 reintentos (`RN-7`) y revocación remota inmediata de sesiones concurrentes (`H15`).
- **Frontend & UX Alignment (Vue 3 / Pinia Waves 1–6):**
  - **Arqueo Ciego y Caja Multicanal (`CashControlView.vue`, `ForcedCloseAuditModal.vue`, `ExpensesModal.vue`, `CashHistoryCard.vue`):** Eliminada toda exposición prematura del saldo esperado del sistema antes de confirmar el conteo físico; soporte para selección de categoría OPEX obligatoria y filtro histórico de turnos por rango de fechas.
  - **POS, Ventas y Cola Offline (`POSView.vue`, `SaleDetailModal.vue`, `ReturnProductModal.vue`, `syncQueue.ts`, `SyncStatusModal.vue`):** Conectada la anulación de ventas y devoluciones multicanal al backend; indicador permanente de capacidad de cola offline (`X/50`), alerta al 80% y bloqueo al 100%; migración de sincronización offline a `rpc_procesar_venta_v3` con llave de idempotencia y bloqueo de creación offline de clientes (`RN-OFF-01`).
  - **Inventario, Clientes, Finanzas y Seguridad (`InventoryView.vue`, `ProductFormModal.vue`, `KardexModal.vue`, `ClientsView.vue`, `ClientDetailView.vue`, `AccountsPayableView.vue`, `BusinessHealthView.vue`, `UpdatePasswordView.vue`):** Paginación progresiva ("Cargar más"), selector de lotes FIFO en POS y mermas, filtro por empleado en salud del negocio (Pilar 4) y política de contraseñas `POL-SEC-03` con cierre de sesiones remotas (`scope: 'others'`).

## [1.5.8] - 2026-10-09

### Added
- **Requirements (FRD Cross-Analysis Amendments - Últimos Hallazgos):**
  - **FRD-007 (Sales & Voiding - Hallazgos 9, A, B):** Especificación de filtros en historial de ventas por turno (Nº ticket, canal, estado). Definición estricta de "Anulación de Ventas": reversión contable atada al canal de pago original, protección de inmutabilidad en turnos cerrados (exigencia de turno abierto para la operación), y reversión logística del inventario.
  - **FRD-006 (Inventory - Hallazgo 11):** Navegación y filtrado en el Historial Kardex. Se exigen filtros combinables por rango de fechas (7 días por defecto), tipo de movimiento y empleado responsable para facilitar la auditoría operativa.
  - **FRD-026 / FRD-004 (Expenses - Hallazgo 12):** Categorización OPEX obligatoria. El registro de gastos ahora exige seleccionar una categoría predefinida (Servicios, Nómina, Transporte, Mantenimiento, Insumos, Reembolso) además del motivo en texto libre, garantizando la compatibilidad con el agrupamiento matemático del reporte financiero (FRD-018).

## [1.5.7] - 2026-10-09

### Added
- **Requirements (FRD Cross-Analysis Amendments - Hallazgo 8):**
  - **FRD-005 (Audit & Traceability - Evidence Hub):** Especificación del filtro temporal en el Evidence Hub centralizado. Selección de rango de fechas desde–hasta (extremos inclusivos, días completos) sobre el timestamp de los eventos, atajos rápidos (Hoy, Ayer, Últimos 7 días, Últimos 30 días), rango por defecto de los últimos 7 días consistente con reportes de caja, combinación con filtros de dominio y tipo de evento, respuesta contextual ante consultas vacías, integración con paginación progresiva de FRD-006 y homologación para consultas de historiales contextuales (ej. perfil de cliente).

## [1.5.6] - 2026-10-04

### Added
- **Requirements (FRD Cross-Analysis Amendments - Hallazgo 7):**
  - **FRD-006-02 (Refunds Manager):** Multicanalidad y trazabilidad integral en devoluciones de clientes. Selección obligatoria de canal de egreso con Efectivo preseleccionado por defecto, registro obligatorio del canal de venta original mediante lista desplegable, validación de fondos por canal en el turno activo sin sobregiros ni compensaciones ficticias, tipificación del egreso como Reembolso para el cálculo de Ingresos Netos (FRD-018), y vinculación atómica bidireccional entre el egreso de caja y el incremento de inventario.

## [1.5.5] - 2026-10-02

### Added
- **Requirements (FRD Cross-Analysis Amendments - Hallazgo 6):**
  - **FRD-004 / FRD-020 (Cash Control & Multichannel):** Especificación de base de apertura de caja multicanal. El fondo de cambio declarado en la apertura se asigna exclusivamente al canal EFECTIVO, mientras que los canales digitales (Nequi, Llave BRE) se inicializan automáticamente con base $0 cada turno. Se conectó formalmente con el arqueo desglosado de cierre garantizando el cálculo íntegro del saldo esperado por canal.

## [1.5.4] - 2026-09-24

### Added
- **Requirements (FRD Cross-Analysis Amendments - Medium Severity 13-20):**
  - **FRD-006 (Inventory):** Estrategia transversal de paginación con carga progresiva de 20 en 20 bajo demanda e indicador de totales para listados de alta cardinalidad (Hallazgo 13).
  - **FRD-003 (Employees):** Navegación del listado de empleados con filtro por estado activo/inactivo y búsqueda por nombre/alias (Hallazgo 14).
  - **FRD-013 (Sessions):** Regla RN-013-07 y Caso E para liberación remota de sesión individual por el Administrador a través de revocación de dispositivos (Hallazgo 15).
  - **FRD-014 (Forced Sale):** Regla RN-014-06 ratificando que la venta forzada pasa por el checkout multicanal estándar del POS (Hallazgo 16).
  - **FRD-018 (Operational Control):** Filtro opcional por empleado en la consulta consolidada para aislar métricas del Pilar 4 (Hallazgo 17).
  - **FRD-019 / FRD-006-01-01 (Accounts Payable & Inventory Entries):** Normalización automática del nombre de proveedor (trim + título) y autocompletado en facturas y movimientos de entrada (Hallazgo 18).
  - **FRD-009 (Clients):** Paginación progresiva para el historial de transacciones en el perfil de cliente individual (Hallazgo 19).
  - **FRD-012-01 / FRD-011 (Offline System & Error Handling):** Indicador visual permanente del estado de la cola offline ("X/Y ventas pendientes"), alerta al 80% y bloqueo crítico al 100% (Hallazgo 20).

## [1.5.3] - 2026-09-24

### Added
- **Requirements (FRD Cross-Analysis Amendments):**
  - **FRD-009 (Clients):** Especificación de filtros por estado de deuda (Todos, Con Deuda, Al Día), ordenamiento por nombre o monto de deuda, y opción (exclusiva para Admin) de visualizar clientes con borrado lógico (soft delete). Se añadieron los Casos de Uso E y F.
  - **FRD-007 / FRD-006-03 (Sales):** Especificación de búsqueda inteligente en POS con campo unificado. Detección automática entre PLU (búsqueda exacta) y nombre (búsqueda parcial). Carga progresiva de resultados desplegables priorizando la fluidez de la interfaz. Se añadió el Caso de Uso D y extensión de trazabilidad.

## [1.5.2] - 2026-09-20

### Added
- **Requirements (FRD Cross-Analysis Amendments):**
  - **FRD-006 / FRD-006-03 (Inventory):** Especificación de búsqueda parcial por nombre (≥2 caracteres), filtros por estado activo/inactivo, stock bajo, categorías y ordenamiento múltiple. Cierre de referencia para búsqueda por nombre en POS.
  - **FRD-027-01 / FRD-021 (Cash & Audit):** Navegación temporal en reportes de caja ratificando el turno como unidad atómica, listado cronológico de turnos y filtros por rango de fechas combinables con canales multicanal.
  - **FRD-019 (Accounts Payable):** Búsqueda parcial por proveedor, filtro por estado dinámico (Todas/Pendientes/Vencidas/Pagadas), filtro por fechas de creación, orden por defecto descendente por fecha de creación con alternancia descendente/ascendente.
  - **Analysis Artifact:** Documentación de análisis cruzado de 20 huecos lógicos entre FRDs (`ANALISIS_CRUZADO_HUECOS_LOGICOS_FRD.md`).

## [1.5.1] - 2026-07-24

### Fixed
- **Inventory (Stock Inicial al Crear Producto):**
  - **RPC `rpc_registrar_entrada`:** Soporte para usuarios administradores (`admin_profiles`) y validación de `quantity > 0` con códigos de error estandarizados.
  - **Frontend (`inventory.ts`):** Sustituida la llamada a `registerMovement()` por `registerEntry()` al crear productos con stock inicial. Eliminado el silenciado de errores, haciendo que cualquier fallo de stock inicial sea tratado como error bloqueante e informativo.

## [1.5.0] - 2026-07-23

### Added
- **Inventory (FIFO & Batches - Phase 4/5):**
  - **Batch Price Editing:** Edición directa de precios de costo y venta de lotes activos desde la interfaz (`BatchHistoryModal.vue`).
  - **Dynamic FIFO Sales:** Descuento y valuación de ventas basándose en el precio de venta real de cada lote consumido (RPC `rpc_procesar_venta_v2`).
  - **Batch Price RPC:** RPC `rpc_actualizar_precio_lote` para actualización segura de precios por lote.
  - **Architecture Doc:** FRD documentando la interacción `inventory_movements` -> `inventory_batches` -> `products`.

### Fixed
- **Database:** Eliminación de trigger obsoleto `trg_sales_to_cash` que causaba violaciones de constraint `cash_movements_amount_check` al insertar ventas iniciales en $0.
- **Database:** Corrección de nombres de columnas (`quantity_consumed`, `unit_cost`, `unit_price`) en `sale_item_batches` dentro de `rpc_procesar_venta_v2`.
- **Database:** Corrección de cálculo de `v_deficit` en `rpc_force_sale` al agrupar por `product_id`.

## [1.4.0] - 2026-07-18

### Added
- **Audit UI:** Filtro dinámico de sub-tipos de evento (`eventTypeFilter`) en el Historial para segmentar (ej: Ventas -> Anulaciones, Auditoría -> Login Fallido).
- **Audit UI:** Nueva pestaña "Créditos" en el Historial conectada al RPC `get_history_creditos`.
- **Client Detail:** Filtros por período (Hoy, Semana, Mes) implementados en el Historial de Transacciones del Cliente.

### Fixed
- **Security:** Ocultada la pestaña "Auditoría" en el Historial para perfiles de Cajero (exclusivo para Admins).
- **DB (Audit):** Implementada migración para tablas inmutables (append-only) de auditoría (Precios, Ventas, Seguridad, Caja).
- **DB (Audit):** Implementados triggers en BD para registro automático de eventos de auditoría, eliminando la delegación de esta responsabilidad al Frontend.


## [1.3.0] - 2026-07-17

### Added
- **Clients:** Historial de movimientos visible en la pantalla de detalle de cliente — compras fiadas y abonos aparecen en "Movimientos Recientes".
- **Clients:** Botón "Editar Cliente" en el menú de opciones del detalle de cliente (visible solo para Admins).

### Fixed
- **DB:** `client_transactions` convertida de TABLE a VIEW sobre `client_ledger` (`security_invoker=true`) — elimina la duplicidad de modelos y el historial vacío.
- **DB:** RPC `registrar_abono` ahora escribe en `client_ledger` en lugar de `client_transactions` — consistencia total del libro mayor.
- **DB:** Migración con backfill aplicada en producción para preservar historial existente.
- **Frontend:** `registerPayment` redirigido al RPC `registrar_abono` — elimina el doble cargo de deuda en ventas online.
- **Frontend:** `updateDebt` y `addTransaction` en `clientRepository` convertidos en no-ops cuando hay conexión — escrituras directas eliminadas.
- **Frontend:** Bug en `ClientFormModal` donde `cedula` no coincidía con la clave `cc` del dominio al editar.
- **Frontend:** Inyección de `storeId` en `updateClient` para cumplir validación RLS del adaptador.
- **Frontend:** `supabaseAdapter.update` ahora usa Supabase como fuente de verdad (no localStorage) antes del merge, evitando datos desactualizados con `store_id` vacío.

## [1.2.1] - 2026-07-11


### Fixed
- **Auth:** Corregir redirección del enlace de recuperación de contraseña que enviaba erróneamente al Login en lugar de a la vista de restablecer contraseña (`update-password`).

## [1.2.0] - 2026-02-22

### Added
- **Reports (Phase 5):**
  - **Intelligence Hub (`ReportsHubView`):** New peer-to-peer navigation architecture separating "Dashboard" and "History" into equal-weight tabs.
  - **Organic Widgets:** `InventoryHealthWidget` and `ClientLedgerWidget` for the Financial Dashboard with interactive deep-linking.
  - **Time-Series vs Snapshot Data:** Decoupled static DB payloads (Inventory, Clients) from dynamic date-filtered payloads (Sales, Top Products) in `financial.ts`.
  - **Backend RPCs:** `get_inventory_health`, `get_client_ledger_summary`, and `get_top_products_by_units`.

### Changed
- **UX:** Removed redundant Reports tab and "Historial Financiero" card from the Administration view to reduce cognitive load.
- **Store Architecture:** `financial.ts` strictly acts as a payload receiver mapping directly to Backend RPC structures without performing frontend math.

## [1.1.0] - 2026-02-15
### Added
- **History (Phase 4):**
  - Global search by ticket, client, product, or employee.
  - Custom date range selector with native date inputs.
  - Sale Detail Modal with line items, tax breakdown, and void status.
  - Enhanced summary bar with filtered totals.
  - New RPC `get_sale_detail` with strict store access control.
- **Financial Module (Phase 1):**
  - Initial database structure for cost tracking (`product_costs`, `supplier_orders`).
  - Financial RPCs for P&L and cost analysis.
  - `FinancialDashboardView` with real-time metrics (Sales, Costs, Gross Margin).
  - Comprehensive project documentation (FRD, Architecture, DB Alignment).

### Fixed
- **Security:** Critical vulnerability in `assert_store_access` fixed (referenced non-existent `admin_id` and `user_id` columns).
- **UX:** Fixed search query desynchronization on tab change in History view.
- **Performance:** Added proper cleanup for debounce timeouts.

### Changed
- **Documentation:** Added `documentation/` folder with full project specs.
- **Database:** Strengthened RLS policies for `stores` and `employees`.
