# Orden de Trabajo — FASE 3, OLA 5 (`CHK-501` a `CHK-512`)

**Alcance:** Inventario Completo (`canManageInventory`), Salidas Logísticas `$0`, Reembolsos `"merma"` y P&L de 4 Pilares (`SDD-006`, `SDD-006-01-01`, `SDD-006-01-02`, `SDD-006-02`, `SDD-018`).
**Rama Git:** `feat/fase3-ola5-inventario-salidas-reembolsos-pnl`
**Autor:** Orquestador Técnico (`AGENTS.md` Reglas 2, 3, 4, 5, 6, 8, 9, 10)

---

## Diagnóstico Ecográfico Previo (Regla 10 — Fase A)

Comando ejecutado: `node scripts/scan-impact.mjs products inventory_batches inventory_movements sales`

1. **Origen Real del Fallo:** Contrato RPC + Esquema/Constraints BD + Estado en Store/UI (`rpc_registrar_entrada` y `rpc_actualizar_precio_lote` con sobrecargas legacy de 5 y 2 argumentos; `bridge_movement_to_batch` acoplado automáticamente a `supplier_invoices`; `cash_movements_movement_type_check` sin `'reembolso'`; `inventory_movements` sin `reversed_movement_id`; ausencia de `rpc_registrar_salida_logistica`, `rpc_registrar_contra_movimiento`, `rpc_procesar_reembolso_item`, `get_inventory_kardex` y búsqueda `stock = 0` para reembolsos; `rpc_get_comprehensive_financial_report` sin `opex_breakdown` al costo ni `personal_consumptions_summary`; `inventory.ts` sumando `+qty` en ajustes negativos y `ProductFormModal.vue` bloqueando costo a `canManageInventory`).
2. **Contratos RVC Activos:** `RVC-003` (Autoridad de Entrada de Mercancía / Catálogo / FIFO), `RVC-004` (Cierre de Caja y Tesorería Multicanal), `RVC-005` (P&L 4 Pilares y Reporte Financiero Admin), `RVC-006` (Gestión de Reembolsos e Inventario).
3. **Radio de Explosión:**
   - **SQL (42 migraciones inspeccionadas + `pg_proc` vivo):** `bridge_movement_to_batch()`, `cerrar_caja`, `rpc_pay_supplier_invoice`, `rpc_registrar_gasto_v2`, `rpc_obtener_historial_caja_multicanal`, `rpc_obtener_mis_movimientos_turno`, `rpc_get_comprehensive_shift_report`, `rpc_anular_venta`, `rpc_registrar_entrada` (2 sobrecargas), `rpc_actualizar_precio_lote` (2 sobrecargas), `rpc_soft_delete_product`, `rpc_actualizar_producto_catalogo`, `buscar_producto_pos`, `rpc_get_comprehensive_financial_report`, `product_price_history`.
   - **Frontend (`frontend/src/`):** `types/database.types.ts`, `types/index.ts`, `data/repositories/productRepository.ts`, `data/repositories/saleRepository.ts`, `stores/inventory.ts`, `stores/financial.ts`, `stores/batches.ts`, `views/StockEntryView.vue`, `views/StockOutputsView.vue` (nueva), `views/InventoryView.vue`, `views/POSView.vue`, `views/FinancialDashboardView.vue`, `views/DashboardView.vue`, `components/ProductFormModal.vue`, `components/inventory/BatchHistoryModal.vue`, `components/inventory/KardexModal.vue`, `components/sales/RefundModal.vue` (nueva), `router/index.ts`.
4. **Semáforo de Frontera:**
   - 🚫 **Muro 1 (Autoridad):** Todo cálculo de FIFO, totales de reembolso, validación de liquidez por canal y consolidado P&L/OPEX vive exclusivamente en PostgreSQL (`SECURITY DEFINER`).
   - 🚫 **Muro 2 (Acoplamiento):** El cambio en `cash_movements.movement_type` (`'reembolso'`) actualiza todos los consumidores identificados en `pg_proc` (`rpc_pay_supplier_invoice`, `rpc_anular_venta`, `rpc_obtener_historial_caja_multicanal`, `rpc_obtener_mis_movimientos_turno`, `rpc_get_comprehensive_shift_report`).
   - 🚫 **Muro 3 (Visibilidad):** Eliminados `EXCEPTION WHEN OTHERS RETURN {success:false}` en `rpc_registrar_entrada` y `rpc_soft_delete_product` / `rpc_actualizar_precio_lote`; todo error hace `RAISE`.

---

## Plan de Ejecución (`CHK-501` – `CHK-512`)

- **CHK-501 & CHK-502:** Añadir `reversed_movement_id` a `inventory_movements`, `GRANT ALL` explícitos (`product_price_history`, `inventory_movements`, `inventory_batches`, `inventory_movement_batches`), ampliar `cash_movements_movement_type_check` con `'reembolso'` y refactorizar `bridge_movement_to_batch()` desacoplado de `supplier_invoices`.
- **CHK-503 & CHK-504:** Crear `rpc_registrar_salida_logistica`, `rpc_registrar_contra_movimiento`, repositorios dedicados y vista `StockOutputsView.vue` (`/stock-outputs`) abierta a todo usuario activo para `merma` y `consumo_negocio` (sin `unit_cost` y sin requerir caja), separando `ajuste_conteo` (`+/-`) y `devolucion_proveedor` (`$0`) para `canManageInventory`/Admin.
- **CHK-505, CHK-506 & CHK-507:** Limpiar sobrecargas legacy (`rpc_registrar_entrada` 5-args, `rpc_actualizar_precio_lote` 2-args, `buscar_producto_pos` 4-args), endurecer `canManageInventory` en catálogo/entradas/lotes/soft-delete, limpiar `StockEntryView.vue` (solo Compra/Reposición, sin CxP), habilitar Costo en `ProductFormModal.vue` para `canManageInventory || isAdmin` y corregir el bug `+qty` en `stores/inventory.ts`.
- **CHK-508 & CHK-509:** Crear `rpc_procesar_reembolso_item` (`canManageRefunds` o Admin, caja `<24h`, saldo por canal, switch único `"merma"` sin tocar lotes cuando es `true`, protegiendo `rpc_anular_venta` con `SALE_HAS_PARTIAL_REFUNDS`), `buscar_producto_pos(..., p_include_zero_stock)` y `RefundModal.vue` desde `POSView.vue`.
- **CHK-510, CHK-511 & CHK-512:** Crear `get_inventory_kardex` y actualizar `KardexModal.vue` (filtros nuevos + actor + contra-movimiento); refactorizar `rpc_get_comprehensive_financial_report` + `stores/financial.ts` + `FinancialDashboardView.vue` para P&L de 4 pilares sin doble conteo y Consumos Personales; ejecutar pruebas SQL + Vitest + build + auditoría `auditor-qa`.
