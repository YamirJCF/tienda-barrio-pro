# Orden de Trabajo (WO) — Fase 3 Ola 1: Cimientos Transversales RBAC, Snapshots, Continuidad `<24h` y Canales

> **Generado por:** Orquestador Técnico (`/orchestrator`, Nivel 3)  
> **Rama de Trabajo:** `feat/fase3-ola1-cimientos-rbac-canales` (desde `0678819`)  
> **Matriz Maestra:** `matriz_ejecucion_fase3_sdd_a_codigo.md` (`CHK-101` a `CHK-116`, `N = 16` átomos)  
> **SDDs Vinculantes:** `SDD_003_01` *(contrato marco)*, `SDD_001`, `SDD_003`, `SDD_015`  
> **Aprobaciones LOCKFILE:** `LF-008` (`EmployeePermissions`), `LF-010` (Políticas RLS y helpers centralizados) — aprobados explícitamente por el usuario el 2026-11-19 (`[LOCKFILE-APPROVED]`).

---

## 0. Declaración de Reconocimiento y Ecógrafo Estructural (`AGENTS.md` Reglas 2, 4, 6 y 10)

```text
✅ RECONOCIMIENTO DEL TERRENO Y ECOGRAFÍA COMPLETADOS
```

1. **Origen Real del Fallo / Brecha:** Multi-capa (`Dato en BD | Contrato RPC | Estado en Store | Render en UI`) — `employees.permissions` conserva llaves legacy (`canViewReports`, `canViewInventory`, `canSell`, `canManageClients`), `daily_passes` en `request_employee_access`/`toggle_empleado_activo` evalúa solo `pass_date = v_today`, faltan `is_store_admin`/`assert_store_admin`/`assert_employee_permission`/`resolve_actor_snapshot` y columnas de snapshot histórico, y constraints/RPCs/vistas conservan `'daviplata'`/`'bre'` en lugar de `'llave_bre'`.
2. **Contratos RVC Activos (Eje 1 `scan-impact.mjs`):** `employees` (`40` SQL / `26` FE), `daily_passes` (`12` SQL / `5` FE), `admin_profiles` (`39` SQL / `3` FE), `cash_movements` (`28` SQL / `4` FE), `sales` (`24` SQL / `30` FE), `auth` (`53` SQL / `87` FE).
3. **Radio de Explosión Verificado (Ejes 2 y 3):**
   - SQL: 23 funciones en `pg_proc` (`crear_empleado`, `rpc_obtener_empleados`, `toggle_empleado_activo`, `request_employee_access`, `check_my_pass_status`, `rpc_gestionar_dispositivo`, `rpc_procesar_venta_v3`, `rpc_anular_venta`, `rpc_registrar_gasto_v2`, `rpc_registrar_abono`, `get_history_caja`, `get_daily_summary`, `rpc_get_comprehensive_financial_report`, etc.).
   - Esquema vivo (`supabase_db_prueba`): verificado `information_schema.columns` y `pg_constraint` en `cash_sessions`, `cash_movements`, `sales`, `employees`, `admin_profiles`, `daily_passes`, `audit_logs`, `audit_caja`, `audit_ventas`, `audit_precios`, `audit_seguridad`, `inventory_movements`, `client_ledger`, `payment_methods`.
   - Frontend: `types/index.ts`, `types/database.types.ts`, `stores/auth.ts`, `stores/config.ts`, `stores/reports.ts`, `router/index.ts`, `components/BottomNav.vue`, `components/EmployeeFormModal.vue`, `views/EmployeeManagerView.vue`, `data/repositories/employeeRepository.ts`, `data/repositories/authRepository.ts`, `data/repositories/auditRepository.ts`, `composables/useHistory.ts`, vistas/modales con `daviplata`/`bre`.
4. **Semáforo de Frontera (Muros Inviolables):**
   - 🚫 Muro 1 (Autoridad): Validación de permisos, rol admin y snapshot se implementan en PostgreSQL (`SECURITY DEFINER`), nunca solo en `.vue`.
   - 🚫 Muro 2 (Acoplamiento): Eliminar `'daviplata'`/`'bre'` en constraints exige actualizar simultáneamente datos, `payment_methods` y todos los RPCs/UI consumidores.
   - 🚫 Muro 3 (Visibilidad): `assert_store_admin` y `assert_employee_permission` lanzan `RAISE EXCEPTION` explícito (`42501` `ADMIN_ONLY_ACTION`/`PERMISSION_DENIED`) con cero `WHEN OTHERS` silenciosos (`audit_logs.actor_id` pasa a nullable). **Trade-off Regla 7:** por atomicidad ACID de PostgreSQL sin `dblink`, un `INSERT` previo a `RAISE EXCEPTION` en la misma transacción se revierte en el rollback; la persistencia inmutable de intentos denegados (`UNAUTHORIZED_ACCESS` en `audit_seguridad` + `audit_logs`) se ejecuta en transacción separada vía `rpc_log_security_event` desde `useSessionGuard`/`auditRepository`.

---

## 1. Orden de Ejecución Trazada (`[CHK-101]` a `[CHK-116]`)

### Fase 1: Capa Base de Datos / SQL (`@[/data]`)
- **`[CHK-101]`** Crear `public.is_store_admin(p_store_id UUID)` (`admin_profiles.role IN ('owner','manager')`) y `public.assert_store_admin(p_store_id UUID)` (aborta atómicamente con `RAISE EXCEPTION 'ADMIN_ONLY_ACTION'` `SQLSTATE '42501'`, complementado por `rpc_log_security_event('UNAUTHORIZED_ACCESS')` para persistencia fuera del rollback). Habilitar `audit_logs.actor_id` nullable para soportar actores de `admin_profiles` sin fila en `employees`.
- **`[CHK-102]`** Crear `public.assert_employee_permission(p_store_id UUID, p_permission_key TEXT)` admitiendo únicamente `'canManageInventory'`, `'canFiar'`, `'canOpenCloseCash'`, `'canManageRefunds'`; aprobar si `is_store_admin`; en empleado exigir Zero-Trust `is_active = true`, pase diario aprobado (`v_today` o `v_today - 1` en turno abierto `<24h`) y llave `'true'`; abortar con `PERMISSION_DENIED` (`42501`) si falla + persistencia vía `rpc_log_security_event`.
- **`[CHK-103]`** Crear `public.resolve_actor_snapshot(p_store_id UUID)` retornando `(actor_id UUID, actor_name TEXT, actor_role TEXT)` resolviendo desde `admin_profiles` (`'owner'`/`'manager'`) + `_resolve_store_actor_name` o desde `employees` (`'employee'`).
- **`[CHK-104]`** Sanear todas las filas en `public.employees`: preservar valores booleanos de las 4 llaves canónicas (`false` por defecto) y purgar llaves legacy (`canViewReports`, `canViewInventory`, `canSell`, `canManageClients`, etc.).
- **`[CHK-105]`** Actualizar `public.crear_empleado` (validar admin vía `assert_store_admin`, sanear/rechazar llaves fuera de las 4, registrar snapshot), crear `public.rpc_actualizar_permisos_empleado(p_employee_id UUID, p_permissions JSONB)` (`assert_store_admin` + rechazo de llaves no permitidas + auditoría `EMPLOYEE_PERMISSIONS_UPDATED`) y blindar `public.rpc_obtener_empleados` con `assert_store_admin(p_store_id)`.
- **`[CHK-106]`** Actualizar `request_employee_access` y `check_my_pass_status` para evaluar continuidad `<24h` (`pass_date = v_today` o `pass_date = v_today - 1` con turno abierto `<24h`), y actualizar `toggle_empleado_activo` con `assert_store_admin` y revocación de `pass_date IN (v_today, v_today - 1)` al desactivar; homologar lectura de errores en `authRepository.ts`.
- **`[CHK-107]`** Actualizar `rpc_gestionar_dispositivo` para validar `is_store_admin(v_pass.store_id)` (`role IN ('owner','manager')`) y contar en el límite de 5 tanto `'approved'` de `v_today` como `'approved'` de `v_today - 1` vigentes por turno abierto `<24h`; actualizar `authRepository.ts` (bandeja dispositivos `<24h` sin consultar `employees.role`).
- **`[CHK-108]`** Añadir columnas de snapshot histórico (`actor_name`, `actor_role`, y variantes `opened_by_*/closed_by_*`, `voided_by_*`) a `sales`, `cash_sessions`, `cash_movements`, `inventory_movements`, `client_ledger`, `audit_logs`, `audit_caja`, `audit_ventas`, `audit_precios`, `audit_seguridad`, con backfill histórico y `GRANT ALL` (`Regla 8`).
- **`[CHK-109]`** Migrar `'bre'` → `'llave_bre'` (y `'daviplata'` → `'nequi'` en históricos si existiesen), actualizar `payment_methods` (`cash`, `nequi`, `llave_bre`, `fiado`, eliminando `card` y `daviplata`), actualizar constraints `chk_cash_movements_payment_method` (`efectivo`, `nequi`, `llave_bre`) y `sales_payment_method_check` (`efectivo`, `nequi`, `llave_bre`, `fiado`, `consumo_personal`), y actualizar RPCs existentes que referencian `'daviplata'`/`'bre'` (`rpc_procesar_venta_v3`, `rpc_anular_venta`, `rpc_registrar_gasto_v2`, `rpc_registrar_abono`, `get_history_caja`, `get_daily_summary`, `rpc_get_comprehensive_financial_report`).

### Fase 2: Contratos TypeScript y Repositorios (`@[/data]` + `@[/ux]`)
- **`[CHK-110]`** Actualizar `frontend/src/types/index.ts` (`EmployeePermissions` cerrado a 4 llaves) y `frontend/src/types/database.types.ts` (nuevas columnas/RPCs de Ola 1).
- **`[CHK-111]`** Actualizar `frontend/src/stores/auth.ts` (4 getters canónicos + `canManageRefunds`; eliminar `canViewReports`, `canViewInventory`, `canManageClients`) y `frontend/src/data/repositories/employeeRepository.ts` (`defaultPermissions` de 4 llaves, invocación a `rpc_actualizar_permisos_empleado` para permisos y actualización segura de perfil).
- **`[CHK-115]`** Actualizar `frontend/src/data/repositories/auditRepository.ts` y `frontend/src/composables/useHistory.ts` para priorizar `actor_name`/`actor_role` inmutables sobre JOINs y retirar `'Cajero'` hardcodeado.

### Fase 3: Stores, Router y Navegación (`@[/ux]`)
- **`[CHK-113]`** Actualizar `frontend/src/components/BottomNav.vue` (retirar tab/referencias a `canViewReports`) y `frontend/src/router/index.ts` (protección estricta `isAdmin` en `/admin*`, `/reports`, `/suppliers`, `/payables`, `/employees`; permisos canónicos `canManageInventory`, `canFiar`, `canOpenCloseCash`).
- **`[CHK-114]`** *(Stores)* Actualizar `frontend/src/stores/config.ts` (`ALLOWED_POS_PAYMENT_CODES` con `llave_bre`, sin `daviplata`/`bre`) y `frontend/src/stores/reports.ts` (`nequi`/`llave_bre`).

### Fase 4: Vistas, Modales y Pruebas Unitarias (`@[/ux]` + `@[/test-expert]`)
- **`[CHK-112]`** Actualizar `frontend/src/components/EmployeeFormModal.vue` (exactamente 4 switches: `Inventario completo`, `Fiar y cobrar abonos`, `Abrir/cerrar caja`, `Reembolsos`) y `frontend/src/views/EmployeeManagerView.vue` (excluir `owner_` del contador de 5 activos + filtro Activos/Inactivos + buscador).
- **`[CHK-114]`** *(Vistas/Repos restantes)* Limpiar `Daviplata` y migrar `'bre'` → `'llave_bre'` en `CheckoutModal.vue`, `ClientDetailView.vue`, `PayInvoiceModal.vue`, `HistoryView.vue`, `historyShortcutParser.ts`, `SaleDetailModal.vue`, `saleRepository.ts` y pruebas relacionadas.
- Actualizar/crear pruebas unitarias Vitest cubriendo camino feliz y rechazo para `CHK-110`..`CHK-115`.

### Fase 5: Compuerta de Cierre de Ola 1 (`[CHK-116]`)
- Ejecutar verificación SQL (esquema real, camino feliz y rechazo de cada átomo `CHK-101`..`CHK-109` en `supabase_db_prueba`), `npm run type-check`, `npx vitest run` y búsqueda mecánica confirmando `0` residuos activos de `canViewReports`, `canViewInventory` y `daviplata`.
- Invocar `auditor-qa` (`86e5137e-a412-44e5-be8d-f02decbb5ff6`) para auditar `git diff` contra SDDs verificando `16/16 ✅`.
- Ejecutar `@[/verification-before-completion]`, `@[/commit]` con `[LOCKFILE-APPROVED]` y `@[/push-sync]`.
