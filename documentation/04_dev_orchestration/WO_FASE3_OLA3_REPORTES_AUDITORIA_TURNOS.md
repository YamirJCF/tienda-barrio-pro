# Orden de Trabajo: Fase 3 — Ola 3 (`CHK-301` a `CHK-308`)
## Reportes y Auditoría 100% Admin-Only + "Mis Movimientos del Turno Actual"

**Rama Git:** `feat/fase3-ola3-reportes-auditoria-turnos` (origen: `d12ac24`)  
**SDDs Cubiertos:** `SDD-005` (Auditoría y Trazabilidad), `SDD-008` (Reportes), `SDD-021` (Historiales Multicanal), `SDD-027-01` (Reportes de Caja) y Contrato Marco `SDD-003-01`.

---

## 0. Cuadro de Reconocimiento y Ecografía Estructural (Reglas 2, 6 y 10)

```text
✅ RECONOCIMIENTO DEL TERRENO Y ECOGRAFÍA COMPLETADOS
1. Origen Real del Fallo: [Dato en BD | Contrato RPC | Estado en Store | Render en UI]
   - Múltiples RPCs de reporte/auditoría solo validan assert_store_access (permitiendo a empleados consultar finanzas globales/costos); get_inventory_health y get_top_products_by_units carecen incluso de guardia multi-tenant y search_path fijo.
   - Políticas RLS de audit_caja, audit_precios, audit_ventas, cash_sessions y cash_movements permiten SELECT a empleados activos o por tienda abierta sin filtro de actor.
   - auditRepository.ts silencia errores retornando [] (Regla 3), DashboardView.vue dispara fetchDailySummary() y muestra KPIs globales a empleados, y falta rpc_obtener_mis_movimientos_turno / rpc_obtener_auditoria_evidence_hub / rpc_obtener_historial_caja_multicanal / rpc_get_comprehensive_shift_report.
2. Contratos RVC Activos:
   - cash_movements.payment_method IN ('efectivo', 'nequi', 'llave_bre'); get_financial_summary conserva llaves planas; /reports e /history son 100% Admin-only; Arqueo Ciego nunca expone expected_balance ni difference a empleados.
3. Radio de Explosión:
   - BD: 15+ RPCs analíticos/auditoría + 6 tablas audit_* + cash_sessions + cash_movements + fn_audit_sale_voided + fn_audit_price_change.
   - Frontend: types/database.types.ts, data/repositories/auditRepository.ts, data/repositories/cashRepository.ts, stores/reports.ts, stores/financial.ts, stores/cashRegister.ts, composables/useHistory.ts, router/index.ts, views/DashboardView.vue, views/HistoryView.vue, views/FinancialDashboardView.vue + nueva vista MyShiftMovementsView.vue.
4. Semáforo de Frontera:
   - 🚫 Muro 1 (Autoridad): Todo filtro Admin-only, cálculo financiero, clasificación de canal y alcance de "Mis movimientos del turno" se impone en PostgreSQL (assert_store_admin / resolve_actor_snapshot).
   - 🚫 Muro 2 (Acoplamiento): Mantener compatibilidad con CashControlView (fetchPendingForcedSessions solo Admin), getAuthorizedDevices (Admin), syncFromBackend (cash_movements scoped a Admin o actor propio en sesión open) y signatures en database.types.ts.
   - 🚫 Muro 3 (Visibilidad): Cero catch { return [] } en auditRepository / useHistory / stores.
```

### Evidencia Cruda Verificada (Reglas 2 & 6)
- `audit_logs`: `id, actor_id, event_type, resource_id, metadata, created_at, store_id, severity, ip_address, reviewed_by, reviewed_at, review_notes, actor_name, actor_role`
- `audit_seguridad`: `id, actor_id, store_id, event_type, ip_address, user_agent, created_at, metadata, actor_name, actor_role`
- `audit_caja` (`id, session_id, store_id, event_type, actor_id, created_at, metadata, actor_name, actor_role`), `audit_precios` (`id, product_id, store_id, old_cost, new_cost, old_price, new_price, changed_by, created_at, actor_name, actor_role`), `audit_ventas` (`id, sale_id, store_id, event_type, actor_id, created_at, metadata, actor_name, actor_role`), `client_lifecycle_audit` (`id, store_id, client_id, event_type, actor_id, actor_name, actor_role, created_at`)
- `cash_sessions`: incluye `closing_attempts`, `forced_close_without_count`, `opened_by_name`, `opened_by_role`, `closed_by_name`, `closed_by_role`
- `cash_movements`: incluye `payment_method CHECK IN ('efectivo','nequi','llave_bre')`, `movement_type CHECK IN ('ingreso','gasto','pago_proveedor')`, `actor_id`, `actor_name`, `actor_role`

---

## 1. Desglose Trazable 1:1 (`CHK-301` .. `CHK-308`)

### `[CHK-301]` Reportes Operativos y Smart Supply Admin-Only (`SDD-008 §0.1 / §0.3 / §5`)
- **BD:**
  - `get_daily_summary(p_store_id, p_date)`: añadir `PERFORM public.assert_store_admin(p_store_id);`, filtrar `products` en alertas con `AND is_active = true`, mantener `money_breakdown.transfer = nequi + llave_bre` y `s.is_voided = false`.
  - `get_smart_supply_report(p_store_id)`: añadir `PERFORM public.assert_store_admin(p_store_id);`, mantener `p.is_active = true`, `s.is_voided = false` y umbral de silencio `15 days` (`LEARNING`).
  - `rpc_asignar_proveedor_masivo(p_store_id, p_supplier_id, p_product_ids)`: reemplazar chequeo ad-hoc de `admin_profiles` por `PERFORM public.assert_store_admin(p_store_id);` (cubre `'owner'` y `'manager'`).
  - Extender `assert_store_admin(p_store_id)` + `SET search_path TO 'public'` a los demás RPCs de Inteligencia/Reportes usados exclusivamente en `FinancialDashboardView` / `HistoryView`: `get_inventory_health`, `get_client_ledger_summary`, `get_stagnant_products`, `get_top_products_by_units`, `get_history_ventas`, `get_history_compras`, `get_history_creditos`, `rpc_marcar_auditoria_revisada`.
- **Frontend:**
  - Actualizar `stores/reports.ts`: guard `if (!authStore.isAdmin)` previo a invocar RPC, mapear `ADMIN_ONLY_ACTION` / `42501` con mensaje explícito y exponer helper/estado para canales `cash / transfer (Nequi + Llave Bre-B) / credit`.

### `[CHK-302]` Historial de Caja y Reporte Financiero Admin-Only (`SDD-027-01 §0.1 / §5.2`, `SDD-018 §0.3 D-2`)
- **BD:**
  - `get_history_caja(p_store_id, p_start_date, p_end_date)`: añadir `PERFORM public.assert_store_admin(p_store_id);`, validar `p_start_date > p_end_date` -> `INVALID_DATE_RANGE`, incluir `'pago_proveedor'` en `total_expenses` y `net_session_balance`, canales `'efectivo'`, `'nequi'`, `'llave_bre'`, y exponer `opened_by_name/role`, `closed_by_name/role`, `closing_attempts`, `forced_close_without_count`.
  - `rpc_get_comprehensive_financial_report(p_store_id, p_start_date, p_end_date, p_employee_id)`: añadir `PERFORM public.assert_store_admin(p_store_id);` (heredado también por `get_financial_summary`) y aplicar filtro `p_employee_id` si se pasa.
- **Frontend:**
  - Actualizar `stores/financial.ts`, `useHistory.ts` (`fetchCashLogs`) y `types/database.types.ts` para consumir los campos completos (`closing_attempts`, `forced_close_without_count`, canales y errores `ADMIN_ONLY_ACTION`).

### `[CHK-303]` Evidence Hub Admin-Only & Blindaje RLS de Auditoría (`SDD-005 §0.1 / §6.3`)
- **BD:**
  - Crear `rpc_obtener_auditoria_evidence_hub(p_store_id, p_domain, p_event_type, p_severity, p_start_date, p_end_date, p_limit, p_offset)` con `assert_store_admin(p_store_id)`, validación `INVALID_DATE_RANGE` / `INVALID_DOMAIN`, unión federada de los 6 dominios (`caja`, `ventas`, `inventario`, `seguridad`, `precios`, `creditos` + `todos`/`all`), fallback defensivo a snapshot `actor_name`/`actor_role` y retorno canónico `{ data, count }`.
  - Unificar políticas RLS `SELECT` de `audit_logs`, `audit_caja`, `audit_ventas`, `audit_precios`, `audit_seguridad` y `client_lifecycle_audit` usando exclusivamente `public.is_store_admin(store_id)` (`'owner' | 'manager'`), más `GRANT ALL ... TO anon, authenticated, service_role` (Regla 8).
- **Frontend:**
  - Actualizar `auditRepository.ts`: eliminar `catch { return [] }` silenciosos (`Regla 3`), propagar `ADMIN_ONLY_ACTION` / errores reales, agregar `getEvidenceHub(...)` y `markAsReviewed(...)`.
  - Integrar pestaña/modo Evidence Hub en `useHistory.ts` / `HistoryView.vue`.

### `[CHK-304]` Bitácora de Seguridad e Incidentes (`SDD-005 §0.1 / §5.2 / §7`)
- **BD:**
  - Ampliar `audit_seguridad_event_type_check` y `rpc_log_security_event` con `'CASH_DISCREPANCY'`, `'CORRECTION'`, `'TRANSACTION_CORRECTION'`, `'INVENTORY_COUNT_ADJUSTMENT'`, `'BUSINESS_CONSUMPTION'`, `'PERSONAL_WITHDRAWAL'`, `'REFUND_MERMA'`, garantizando snapshot vía `resolve_actor_snapshot(p_store_id)` (`actor_name`, `actor_role`).
- **Frontend:**
  - Sincronizar catálogo de tipos `SecurityEventType`, severidades y etiquetas en `auditRepository.ts` y filtros/títulos de `useHistory.ts` & `HistoryView.vue`.

### `[CHK-305]` "Mis Movimientos del Turno Actual" + RLS Estricto Caja (`SDD-021 §0.1 / §0.2`, `SDD-027-01 §1 / §6`)
- **BD:**
  - Crear `rpc_obtener_mis_movimientos_turno(p_store_id, p_payment_method DEFAULT 'all', p_limit DEFAULT 50, p_offset DEFAULT 0)`: usa `assert_store_access` + `resolve_actor_snapshot`, ubica sesión `'open'` vigente en `p_store_id`, filtra estrictamente por operaciones propias (`s.employee_id = v_actor_id` / `cm.actor_id = v_actor_id`), sin depender de quién abrió la caja y sin exponer `expected_balance`/`difference`, devolviendo `OwnShiftMovementsResponse` (`{ data, count, has_open_shift, shift_id, shift_opened_at }`).
  - Crear `rpc_obtener_historial_caja_multicanal(p_store_id, p_session_id, p_payment_method, p_start_date, p_end_date, p_limit, p_offset)` 100% Admin-only (`assert_store_admin`), retorno `{ success: true, data, count }`.
  - Cerrar RLS directa en `cash_sessions` (`SELECT` solo `public.is_store_admin(store_id)`) y `cash_movements` (`SELECT` para `is_store_admin(cs.store_id)` o movimientos propios `cm.actor_id = COALESCE(get_employee_id_from_session(), auth.uid())` en sesión `'open'`).
- **Frontend:**
  - Agregar `getOwnShiftMovements(...)`, `getMultichannelCashHistory(...)` y `getShiftForensicReport(...)` en `cashRepository.ts`, `fetchOwnShiftMovements` en `stores/cashRegister.ts`, y actualizar `types/database.types.ts`.

### `[CHK-306]` Expediente Forense Inmutable de Turno (`SDD-027-01 §0.3 / §5.3`)
- **BD:**
  - Crear `rpc_get_comprehensive_shift_report(p_session_id)` 100% Admin-only (`assert_store_admin(v_session.store_id)`), exponiendo sesión con snapshots (`opened_by_name/role`, `closed_by_name/role`, `closing_attempts`, `forced_close_without_count`), resumen por canales `efectivo`, `nequi`, `llave_bre`, `total_refunds`, `total_supplier_payments`, `movements`, y `operational_noise` (`voided_sales`, `security_alerts`).
- **Frontend:**
  - Crear modal/panel `ShiftForensicDetailModal.vue` e integrarlo al clic sobre ítems `cash` en `HistoryView.vue`.

### `[CHK-307]` Dashboard Blindado para Empleados (`SDD-008 §0.2 / §4.1`)
- **Frontend:**
  - `DashboardView.vue`: invocar `reportsStore.fetchDailySummary()` y mostrar banner/KPIs financieros (`Caja Real`, `Ventas Hoy`, `Por Cobrar`, semáforo del servidor) **exclusivamente cuando `authStore.isAdmin`**.
  - En Acciones Rápidas de empleado: ocultar `Ver Clientes` cuando `!authStore.canFiar`, ocultar `Gestionar Productos` si `!authStore.canManageInventory` (o mantener acciones válidas según matriz 4 permisos) y agregar acceso directo a **"Mis movimientos del turno actual"**.

### `[CHK-308]` Vista "Mis Movimientos del Turno Actual" + Compuerta Ola 3 (`SDD-021 §0.1`, `SDD-027-01 §3.2`)
- **Frontend:**
  - Crear vista `frontend/src/views/MyShiftMovementsView.vue` + ruta `/my-shift-movements` (accesible a todo usuario autenticado con pase activo, con filtros de canal `todos / efectivo / nequi / llave_bre / fiado / consumo_personal`, totalizador informativo de sus propias operaciones SIN `expected_balance`/`difference`, y cero fallos silenciosos).
  - Enlazarla desde `DashboardView.vue` y `CashControlView.vue`.
- **Verificación & Compuerta:**
  - Ejecutar `supabase/tests/test_ola3_sql.sql` en Docker (`EXIT=0`, `ROLLBACK` limpio) probando camino feliz y rechazo `42501 ADMIN_ONLY_ACTION` / aislamiento de movimientos propios / RLS.
  - Ejecutar tests unitarios Vitest (`ola3ReportsAuditAndOwnMovements.spec.ts` + suite completa), `npx vue-tsc --noEmit`, `npx vite build`, búsqueda mecánica anti-fallo-silencioso, guardar pruebas crudas en `scratch/ola3_verification_proof.txt`, actualizar `matriz_ejecucion_fase3_sdd_a_codigo.md` y obtener veredicto `APROBADO (8/8 ✅)` de `auditor-qa`.
