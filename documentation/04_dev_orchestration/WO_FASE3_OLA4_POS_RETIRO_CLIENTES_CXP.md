# ORDEN DE TRABAJO: FASE 3 — OLA 4 (`CHK-401` a `CHK-410`)

**Rama de implementación:** `feat/fase3-ola4-pos-retiro-clientes-cxp` (base `e87748e`)  
**Alcance SDD:** `SDD-007-01`, `SDD-009`, `SDD-019`, `SDD-024`, `SDD-030` + Contrato Marco `SDD-003-01`  
**Átomos asignados:** `[CHK-401]` a `[CHK-410]` (`N = 10`)

---

## 0. Ecógrafo Estructural y Verificación de Esquema Real (Reglas 2, 4, 6 y 10)

```
✅ RECONOCIMIENTO DEL TERRENO Y ECOGRAFÍA COMPLETADOS
1. Origen Real del Fallo: [Contrato RPC / Esquema / Store / Render UI] — Brechas detectadas entre SDDs de Ola 4 y BD/Frontend actual: falta soporte `consumo_personal` ($0 caja + inventario con costo y precio de referencia + beneficiario), falta enforcement `assert_employee_permission(..., 'canFiar')` en `rpc_procesar_venta_v3` / `rpc_registrar_abono` / `rpc_obtener_estado_cuenta_cliente` / `rpc_admin_get_clients`, falta `stores.default_credit_limit` y `supplier_invoices.due_date` nullable, existen 2 sobrecargas legacy de `rpc_pay_supplier_invoice`, falta tabla `supplier_payments` (EXTERNO/INTERNO) con RLS Admin-only, y faltan controles equivalentes en `CheckoutModal.vue`, `ClientListView.vue`, `ClientDetailView.vue`, `ClientFormModal.vue`, `AdminHubView.vue`, `SaleDetailModal.vue`, `PayInvoiceModal.vue` y `PayablesView.vue`.
2. Contratos RVC Activos: `sales`, `inventory_movements`, `clients`, `client_ledger`, `suppliers`, `supplier_invoices`, `stores`, `cash_sessions`, `cash_movements`, `rpc_procesar_venta_v3`, `rpc_registrar_abono`, `rpc_obtener_estado_cuenta_cliente`, `rpc_admin_get_clients`, `rpc_crear_cliente_fiado`, `rpc_actualizar_cliente`, `rpc_eliminar_cliente`, `rpc_anular_venta`, `rpc_pay_supplier_invoice`.
3. Radio de Explosión:
   - SQL / Triggers: `rpc_force_sale` (invoca `rpc_procesar_venta_v3` posicionalmente), `bridge_movement_to_batch` (`inventory_movements`), `fn_audit_sale_created` (`sales`), `suppliers` / `supplier_invoices` RLS, `cash_movements_amount_check` (`amount > 0` exige `$0` sin fila en `cash_movements`).
   - Frontend: `database.types.ts`, `saleRepository.ts`, `syncQueue.ts`, `stores/sales.ts`, `useSaleProcessor.ts`, `CheckoutModal.vue`, `clientRepository.ts`, `stores/clients.ts`, `ClientListView.vue`, `ClientDetailView.vue`, `ClientFormModal.vue`, `AdminHubView.vue`, `SaleDetailModal.vue`, `stores/payables.ts`, `PayInvoiceModal.vue`, `PayablesView.vue`.
4. Semáforo de Frontera (Muros Inviolables):
   - Muro 1 (Autoridad): Todo cálculo de totales/redondeos, FIFO, validación `canFiar`/`is_store_admin`, cupos, saldos y liquidez de canal en CxP reside en Postgres `SECURITY DEFINER`.
   - Muro 2 (Acoplamiento): Al extender `rpc_procesar_venta_v3` con parámetro trailing `p_beneficiary_employee_id uuid DEFAULT NULL`, se conserva compatibilidad con `rpc_force_sale` y `syncQueue.ts`; al reemplazar las 2 sobrecargas legacy de `rpc_pay_supplier_invoice`, se eliminan ambas antes de crear la firma canónica de 4 parámetros.
   - Muro 3 (Visibilidad): Cero `catch` silenciosos; mapeo explícito de `PERMISSION_DENIED`, `CLIENT_NOT_FOUND`, `CREDIT_REVERSAL_BLOCKED`, `INSUFFICIENT_CHANNEL_BALANCE` / `INSUFFICIENT_CASH`, `SHIFT_EXPIRED_24H`.
```

---

## 1. Desglose Trazable 1:1 (`[CHK-401]` .. `[CHK-410]`)

1. **`[CHK-401]` Consumo / Retiro Personal Backend & Repositorio (`SDD-007-01 §2.1 / §5`)**
   - DDL: `sales.beneficiary_employee_id`, `inventory_movements.(session_id, beneficiary_employee_id, reference_sale_price)` + `CHECK (movement_type IN (..., 'consumo_personal', 'consumo_negocio', 'devolucion_proveedor', 'ajuste_conteo'))`.
   - `rpc_procesar_venta_v3`: acepta `p_payment_method = 'consumo_personal'`, exige turno `open < 24h`, descuenta FIFO, graba `total = 0` en `sales`, `$0` en `cash_movements` (sin fila por `amount > 0`), inserta en `inventory_movements` con `unit_cost`, `reference_sale_price`, `session_id`, `beneficiary_employee_id`, auto-asigna al actor y exige `is_store_admin` si elige otro perfil.
   - Frontend: `database.types.ts` + `saleRepository.ts`.

2. **`[CHK-402]` Consumo / Retiro Personal UI POS & Contexto Sesión (`SDD-007-01 §2.1 / §3.2`)**
   - `CheckoutModal.vue`, `useSaleProcessor.ts`, `stores/sales.ts`: opción de cierre **Consumo / Retiro Personal ($0)** (`$0` en caja, selector de empleado beneficiario visible/habilitado solo si `authStore.isAdmin`, omitiendo cobro/cambio).
   - `saleRepository.ts`: enviar `p_origin_session_id` y `p_sold_by` también en ventas online.

3. **`[CHK-403]` Limpieza estricta de `client_id` fuera de `'fiado'` (`SDD-007-01 §0.1 / §5`)**
   - BD: `rpc_procesar_venta_v3` fuerza `v_sale_client_id := NULL` siempre que `p_payment_method <> 'fiado'`.
   - Frontend: `CheckoutModal.vue` limpia/omite `clientId` en toda venta distinta de `'fiado'`.

4. **`[CHK-404]` Permiso `canFiar` y filtro `is_deleted = false` (`SDD-007-01`, `SDD-009`, `SDD-024`, `SDD-030`)**
   - BD: `assert_employee_permission(p_store_id, 'canFiar')` + `COALESCE(is_deleted, false) = false` en `rpc_procesar_venta_v3` (`fiado`), `rpc_registrar_abono` y `rpc_obtener_estado_cuenta_cliente`; en `rpc_registrar_abono`, validar tienda antes de `FOR UPDATE` y resolver `client_ledger.created_by` seguro cuando opera Admin sin fila en `employees`.
   - Frontend: `saleRepository.ts` y `clientRepository.ts` mapean explícitamente `PERMISSION_DENIED` y `CLIENT_NOT_FOUND`.

5. **`[CHK-405]` Matriz RBAC Clientes/Fiados Admin vs `canFiar` (`D-ARCO-01`)**
   - BD: verificar `assert_store_admin` / rol `owner|manager` en `rpc_crear_cliente_fiado`, `rpc_actualizar_cliente`, `rpc_eliminar_cliente`.
   - Frontend: blindar con `authStore.canFiar || authStore.isAdmin`: opción `Fiado` en `CheckoutModal.vue`, rutas `/clients*`, `BottomNav.vue`, acceso rápido en `DashboardView.vue`, y botones `REGISTRAR ABONO` y `Exportar CSV` en `ClientDetailView.vue`.

6. **`[CHK-406]` Cupo Global por Defecto (`SDD-009 §3 RN-009-09`)**
   - BD: `stores.default_credit_limit NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (default_credit_limit >= 0)`, `rpc_actualizar_cupo_credito_global(p_store_id, p_default_credit_limit)` Admin-only sin alterar clientes existentes, y `rpc_crear_cliente_fiado` aplica `default_credit_limit` cuando `p_credit_limit IS NULL`.
   - Frontend: control Admin en `AdminHubView.vue` y precarga del cupo por defecto en `ClientFormModal.vue` al crear cliente nuevo.

7. **`[CHK-407]` Paginación, Filtros y Retiro de Eliminados en Clientes (`CONFLICTO-01`)**
   - BD: `rpc_admin_get_clients` exige `assert_employee_permission(p_store_id, 'canFiar')`, filtra `COALESCE(is_deleted, false) = false`, soporta `p_filter_debt` (`todos`, `con_deuda`, `sin_deuda`/`al_dia`), `p_search_query`, `p_order_by`, retorna `{ success, data, count }` sin `p_include_deleted`, `is_deleted` ni `deleted_at`.
   - Frontend: `clientRepository.ts`, `stores/clients.ts` y `ClientListView.vue` conectados a `fetchClientsPage` con filtros `Todos / Con Deuda / Al Día` y selector de ordenamiento sin filtro de eliminados.

8. **`[CHK-408]` Protección de Anulación `'fiado'` (`CONFLICTO-03`)**
   - BD: `rpc_anular_venta` valida `balance >= v_sale.total`, `COALESCE(is_deleted, false) = false` (`CREDIT_REVERSAL_BLOCKED` / `CLIENT_NOT_FOUND`) y estampa `voided_by_name`/`voided_by_role`.
   - Frontend: `SaleDetailModal.vue` y `saleRepository.ts` muestran mensaje claro al usuario ante rechazo de integridad de cartera.

9. **`[CHK-409]` Endurecimiento CxP Proveedores y Pagos Internos/Externos (`SDD-019 §0.1 / §5.2`)**
   - BD: tabla `supplier_payments` (`origin_type IN ('EXTERNO','INTERNO')`, `actor_name`, `actor_role`, `cash_movement_id`) con RLS `is_store_admin(store_id)` + `GRANT ALL` (Regla 8); eliminar sobrecargas legacy de `rpc_pay_supplier_invoice`; crear firma canónica `(p_invoice_id, p_amount, p_payment_method, p_description)` con `assert_store_admin`, `resolve_actor_snapshot`, canales `('efectivo','nequi','llave_bre','externo')` (`'externo'` = `$0` caja y sin turno obligatorio; interno = turno `<24h` + liquidez exacta por canal + descripción obligatoria).
   - Frontend: `PayInvoiceModal.vue` con botón `Llave Bre-B`, etiqueta `"Pago externo / fuera de caja"`, descripción obligatoria en pago interno y nota opcional en externo, validando liquidez con el saldo del canal seleccionado en `cashRegisterStore.balancesByMethod`.

10. **`[CHK-410]` Facturas Nullable Due Date, CRUD CxP Paginado y Compuerta Ola 4 (`SDD-019 §5 / §6.3`)**
    - BD: `supplier_invoices.due_date DROP NOT NULL`, RLS estricto `is_store_admin(store_id)` en `supplier_invoices`, RPCs Admin-only `rpc_crear_factura_proveedor` y `rpc_obtener_cuentas_por_pagar` (`{ data, count }`).
    - Frontend: `stores/payables.ts` conectado a `rpc_obtener_cuentas_por_pagar` y `PayablesView.vue` con modal `"Nueva Factura"`.
    - Verificación: suite SQL (`supabase/tests/test_ola4_sql.sql`), Vitest, `vue-tsc`, build y auditoría formal de `auditor-qa` (`10/10 ✅`).
