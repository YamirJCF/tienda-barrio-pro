# WO-FASE3-OLA2: Caja Dedicada POS, Propiedad del Turno, Cierre Asistido (3 Intentos), `+24h` y Gastos Menores

> **Rama:** `feat/fase3-ola2-caja-cierres-gastos`  
> **SDDs Cubiertos (`6`):** `SDD-004`, `SDD-017`, `SDD-020`, `SDD-022`, `SDD-026`, `SDD-027-02` *(absorbido)* + Contrato Marco `SDD-003-01`  
> **Átomos Gobernados:** `[CHK-201]` a `[CHK-210]` (`10` átomos)

---

## Precondiciones Mecánicas (`AGENTS.md` Reglas 2, 4, 6 y 10)

### Esquema Real Verificado (`supabase_db_prueba`)
- `cash_sessions` (16 cols): `id`, `store_id`, `opened_by`, `closed_by`, `opening_balance`, `expected_balance`, `actual_balance`, `difference`, `status` (`CHECK ('open','closed')`), `opened_at`, `closed_at`, `forced_close`, `opened_by_name`, `opened_by_role`, `closed_by_name`, `closed_by_role`. Faltan `closing_attempts` y `forced_close_without_count`; `cash_sessions_opened_by_fkey` y `cash_sessions_closed_by_fkey` referencian `employees(id)`.
- `cash_movements` (13 cols): `id`, `session_id`, `movement_type` (`'ingreso'`, `'gasto'`, `'pago_proveedor'`), `amount`, `description`, `sale_id`, `created_at`, `payment_method` (`'efectivo'`, `'nequi'`, `'llave_bre'`), `category`, `voucher_ref`, `actor_id`, `actor_name`, `actor_role`.
- `notifications` (9 cols): `id`, `store_id`, `type`, `title`, `message`, `audience`, `is_read`, `created_at`, `metadata`. Políticas actuales usan `EXISTS (SELECT 1 FROM admin_profiles ...)` ad-hoc en vez de `is_store_admin(store_id)`.

### Cuadro de Ecografía (Regla 10)
1. **Origen Real del Fallo:** Contrato RPC SQL (`abrir_caja`, `cerrar_caja`, `rpc_check_and_force_close_shifts`, `rpc_reconciliar_cierre_forzado`, `rpc_registrar_gasto_v2`, RLS `notifications`) + Store (`cashRegister.ts`, `notificationsStore.ts`) + Repositorios (`cashRepository.ts`, `expenseRepository.ts`) + Vistas (`CashControlView.vue`, `ForcedCloseAuditModal.vue`, `ExpensesView.vue`, `NotificationCenterView.vue`, `router/index.ts`).
2. **Contratos RVC Activos:** Columnas escalares de `cash_sessions`, techo `24h`, independencia entre cierre de caja y `daily_passes` (D-03), aislamiento frente a pagos externos a proveedores.
3. **Radio de Explosión:** `24` funciones SQL (`pg_proc`), `17` consumidores directos de `cashRegister` + `11` de `notificationsStore`.
4. **Semáforo de Frontera:** Muro 1 (esperados, intentos, propiedad estricta y firma en SQL); Muro 2 (actualizar `CashControlView`, `ForcedCloseAuditModal`, `ExpensesView`, `expenseRepository`, `notificationsStore`, `router`, tests); Muro 3 (cero `catch` con estado local falso y cero `IF EXISTS (... information_schema.tables ...)`).

---

## Plan de Ejecución Atómico (`[CHK-201]` – `[CHK-210]`)

1. **`[CHK-201]`** DDL `cash_sessions`: añadir `closing_attempts SMALLINT NOT NULL DEFAULT 0`, `forced_close_without_count BOOLEAN NOT NULL DEFAULT false`, liberar FK restrictiva hacia `employees(id)` en `opened_by`/`closed_by` (permitiendo `manager`/`owner` de `admin_profiles` sin fila sombra), `GRANT ALL`, y actualizar `database.types.ts` + `types/index.ts` + `stores/cashRegister.ts`.
2. **`[CHK-202]`** `abrir_caja` y `get_active_cash_session`: exigir `canOpenCloseCash`, validar compuerta `RECONCILIATION_REQUIRED`, estampar `opened_by`/`opened_by_name`/`opened_by_role`, retornar estado `lifecycleState` sin exponer `expected_balance`/`difference`, y propagar errores reales en `cashRepository.ts` y `cashRegister.ts` (sin estado local falso).
3. **`[CHK-203]`** `cerrar_caja` + `rpc_log_security_event`: exigir `canOpenCloseCash` + propiedad estricta (`opened_by = v_actor_id OR is_store_admin`), registrar `UNAUTHORIZED_SHIFT_CLOSE` en `audit_logs` y `notifications` (`audience = 'admin'`) ante rechazo, implementar Cierre Asistido (3 intentos) por los 3 canales (`efectivo`, `nequi`, `llave_bre`) sin compensación cruzada ni fuga de esperados/diferencias, alerta `CASH_DISCREPANCY_ALERT` al 3.er intento y snapshot `closed_by_name`/`closed_by_role`.
4. **`[CHK-204]`** `rpc_check_and_force_close_shifts`: calcular esperado consolidado multicanal (`efectivo`, `nequi`, `llave_bre`), retirar `IF EXISTS (... information_schema ...)` (Regla 3), insertar alerta `FORCED_CLOSE_24H` en `notifications`, y reflejar `Expirado/Bloqueado` en `cashRegister.ts`.
5. **`[CHK-205]`** `rpc_reconciliar_cierre_forzado`: exigir `assert_store_admin`, hacer `p_actual_balance DEFAULT NULL` opcional (`forced_close_without_count = true` + alerta crítica `FORCED_CLOSE_NO_COUNT` cuando se omite), estampar `closed_by_name`/`closed_by_role`, y actualizar `cashRepository.ts`.
6. **`[CHK-206]`** `rpc_registrar_gasto_v2`: restringir catálogo OPEX a **5 categorías** (`Servicios`, `Nomina`, `Transporte`, `Mantenimiento`, `Insumos` — retirar `'Reembolso'`), canales `('efectivo','nequi','llave_bre')`, incluir `'reembolso'` en egresos del cálculo de liquidez, aceptar `p_voucher_ref`, estampar `actor_id`/`actor_name`/`actor_role`, y actualizar `cashRepository.ts`.
7. **`[CHK-207]`** Frontend Caja (`CashControlView.vue`, `cashRegister.ts`): retirar `PinChallengeModal` al abrir/cerrar, retirar modal post-cierre con `"Esperado en Sistema"` / `"Diferencia"` para cajeros, implementar inputs multicanal (`efectivo`, `nequi`, `llave_bre`), manejo de `SHIFT_OWNERSHIP_VIOLATION` y flujo de **3 intentos** del Cierre Asistido con aviso de alerta enviada al Admin.
8. **`[CHK-208]`** Frontend `+24h` (`ForcedCloseAuditModal.vue`, `router/index.ts`): permitir en `ForcedCloseAuditModal.vue` omitir conteo físico con confirmación explícita (Admin-only); ajustar guard `+24h` en `router/index.ts` para redirigir únicamente al abridor original o al Admin sin bloquear tareas no monetarias de otros empleados.
9. **`[CHK-209]`** RLS `notifications` + Centro de Notificaciones: políticas RLS centralizadas con `is_store_admin(store_id)` / `get_current_store_id()` + `GRANT ALL`; conectar `stores/notificationsStore.ts` y `NotificationCenterView.vue` / `DashboardView.vue` a la tabla `notifications` de Supabase con lectura, marcado de lectura y filtrado por audiencia.
10. **`[CHK-210]`** Gastos Frontend (`ExpensesView.vue`, `expenseRepository.ts`) + Compuerta Ola 2: eliminar `'Reembolso'` y placeholder `"Pago Proveedor Pan"`, mostrar autoría y canal en la lista, eliminar `p_payment_method: 'efectivo'` hardcodeado y filtro `'expense'` vs `'gasto'` en `expenseRepository.ts`; ejecutar tests SQL reales + Vitest (`happy + rejection`) y auditoría `auditor-qa`.
