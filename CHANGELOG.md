# Changelog

All notable changes to this project will be documented in this file.

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
