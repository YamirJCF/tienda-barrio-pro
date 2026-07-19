# Changelog

All notable changes to this project will be documented in this file.

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
