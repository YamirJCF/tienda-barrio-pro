# Contexto C2 — Tesorería Diaria (Caja & Turnos)

> **Estado:** Consolidado Ola 2 (`UX-ADR-002` — `WO-OLA2-C2-001`)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-002`)  
> **Restricción de conectividad:** **Online obligatorio** para toda operación de Caja y Turnos ([`PRODUCT.md`](../../../PRODUCT.md#L38)).  
> **Invariantes de seguridad (`POL-SEG-01` / `POL-SEG-03`):** **Arqueo Ciego** (prohibido exponer `expected_balance` o `difference` al cajero/empleado), **propiedad estricta del turno** (solo quien abrió el turno o el Admin pueden cerrarlo; cierre asistido de 3 intentos; compuerta `+24h` y reconciliación forzada) y **gastos OPEX 100% exclusivos del Administrador (`assert_store_admin`)**.

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Gobernar el ciclo de vida completo de cada turno operativo de caja en un único Workspace (`/cash-control`): apertura con base inicial, registro/consulta de gastos OPEX del turno (exclusivo Admin), consulta de movimientos propios del actor y cierre ciego / asistido o reconciliación de cierres forzados (`+24h`).

### 1.2 Rutas Actuales (Consolidadas en `UX-ADR-002`)

| Ruta | Vista / Subcomponente (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Implementación Canónica |
|---|---|---|---|---|
| `/cash-control` *(tabs `?tab=shift\|expenses\|movements`)* | [`CashControlView.vue`](../../../frontend/src/views/CashControlView.vue) + [`ShiftExpensesTab.vue`](../../../frontend/src/components/cash/ShiftExpensesTab.vue) + [`OwnShiftMovementsTab.vue`](../../../frontend/src/components/cash/OwnShiftMovementsTab.vue) | `canonica` | `B/D` *(+ `E` en tab `movements`)* | **Único Hogar Canónico del Turno:** acceso `requiresAuth` con pestañas segregadas por rol (`Turno` \| `Gastos` \| `Mis Movimientos`) y Compuerta `F` prioritaria en `+24h` / turnos forzados pendientes. |
| `/my-shift-movements` *(retirada)* | — | Retirada en `UX-ADR-002` | — | **Consolidada en `/cash-control?tab=movements`** (`OwnShiftMovementsTab.vue`). |
| `/expenses` *(retirada)* | — | Retirada en `UX-ADR-002` | — | **Consolidada en `/cash-control?tab=expenses`** (`ShiftExpensesTab.vue` + `BaseModal` Arquetipo `D`, exclusivo Admin). |

### 1.3 Matriz de Permisos (`SDD-003-01` & Enmienda `SDD-026` / `UX-ADR-002`)

| Capacidad / Acción | `Admin` | Empleado con `canOpenCloseCash` | Empleado sin `canOpenCloseCash` | Regla de Visibilidad / Seguridad |
|---|---|---|---|---|
| Abrir turno de caja | ✅ | ✅ | ❌ | Tab `Turno` visible solo si `Admin \|\| canOpenCloseCash`. |
| Cerrar turno propio (Arqueo Ciego + 3 intentos) | ✅ | ✅ *(solo si es abridor)* | ❌ | Propiedad estricta; otro usuario ve banner `N3` de turno ajeno (`isShiftOwnedByOther`). |
| Cerrar / reconciliar turno de otro o forzado `+24h` | ✅ | ❌ *(solo si fue el abridor en `+24h`)* | ❌ | Guard en `router/index.ts` (L317-334) y `ForcedCloseAuditModal`. |
| Registrar y consultar Gasto OPEX (`SDD-026`) | ✅ | ❌ | ❌ | **100% exclusivo Admin:** Tab `Gastos` oculto para no-Admin + `assert_store_admin` en `rpc_registrar_gasto_v2` y `rpc_obtener_gastos_turno` (`ADMIN_ONLY_ACTION`, `42501`). |
| Consultar Mis Movimientos del Turno | ✅ | ✅ | ✅ | Todo autenticado accede a `/cash-control?tab=movements` (`OwnShiftMovementsTab.vue`, Arqueo Ciego preservado). |

---

## §2. Matriz ORCA (Objetos, Relaciones, CTAs y Lockfile)

### 2.1 Objetos Canónicos y Relaciones `1:N`

```text
Turno de Caja (1) ──< Gasto OPEX (N)  [5 categorías × 3 canales — SDD-026]
                  │
                  └──< Movimiento Propio del Turno (N)  [solo lectura acotada]
```

- **Catálogo cerrado de `Gasto OPEX` (`SDD-026` / [`ExpensesView.vue`](../../../frontend/src/views/ExpensesView.vue#L29-L34)):**
  - **5 categorías:** `Servicios`, `Nomina`, `Transporte`, `Mantenimiento`, `Insumos`.
  - **3 canales:** `efectivo`, `nequi`, `llave_bre` (+ comprobante opcional cuando no es efectivo).

### 2.2 Matriz Global de CTAs (`Verbo × Objeto`)

| Verbo + Objeto | Rol autorizado | Red | Hogar Actual (Desconectado) | Hogar Canónico Objetivo |
|---|---|---|---|---|
| **Abrir `Turno de Caja`** | `Admin`, `canOpenCloseCash` | Online | `/cash-control` | `/cash-control` → Tab **Turno / Arqueo** |
| **Cerrar / Reconciliar `Turno de Caja`** | `Admin` o abridor con `canOpenCloseCash` | Online | `/cash-control` + `ForcedCloseAuditModal` | `/cash-control` → Tab **Turno / Arqueo** (y Compuerta `F` si `+24h`/forzado) |
| **Registrar `Gasto OPEX`** | **Estrictamente `Admin`** (`assert_store_admin`) | Online | `/expenses` (retirada) | `/cash-control?tab=expenses` → botón `+ Registrar Gasto` abre **Hoja Transaccional Arquetipo `D` (`BaseModal`)** |
| **Consultar `Gasto OPEX` del Turno** | **Estrictamente `Admin`** (`rpc_obtener_gastos_turno`) | Online | `/expenses` (retirada) | `/cash-control?tab=expenses` (payload limpio `movement_type = 'gasto'` y `total_opex_expenses` calculado en SQL) |
| **Consultar `Movimiento Propio del Turno`** | Todo usuario autenticado | Online | `/my-shift-movements` (retirada) | `/cash-control?tab=movements` (pestaña `Mis Movimientos`, Arquetipo `E`) |

> **🔒 Nota Obligatoria de Gobernanza (`LOCKFILE.md`):** Tanto `ExpensesView.vue` / `expenses.ts` (**`LF-003`**) como los RPCs de control de caja (**`LF-004`**) están protegidos en [`.agent/LOCKFILE.md`](../../../.agent/LOCKFILE.md#L29-L30). Ninguna modificación de Ola 2 sobre esos archivos puede ejecutarse sin autorización explícita del usuario y marcador `[LOCKFILE-APPROVED]` en el commit.

---

## §3. Breadboards (Flujo Actual vs. Flujo Objetivo)

### 3.1 Breadboard Actual (3 Rutas Desconectadas)

```text
[/cash-control (CashControlView.vue)]
  ├── Sin enlace ni acceso hacia /expenses ni /my-shift-movements
  ├── onMounted: si falla catch -> console.error() sin aviso visual (L152-154)
  └── Mutación ejecuta con checkConnectivity: false (L283)

[/expenses (ExpensesView.vue)]
  ├── Header: botón Atrás ──> router.push('/') (L79, pierde contexto de Caja)
  ├── Summary Card: "Total Salidas (Sesión)" calculado con .reduce() en cliente (L47-49)
  └── Modal custom inline (L142-205, sin BaseModal)

[/my-shift-movements (MyShiftMovementsView.vue)]
  ├── Header: botón Atrás ──> router.push('/') (L97, pierde contexto de Caja)
  └── Loading: spinner genérico en vez de BaseListSkeleton (L143-146)
```

### 3.2 Breadboard Objetivo (1 Workspace del Turno `/cash-control`)

```text
[Compuerta F Prioritaria (solo si +24h expirado o cierre forzado pendiente)]
  ├── Causa: Turno abierto >24h o pendiente de reconciliación (Arqueo Ciego)
  └── Acción única: [Contar y Reconciliar / Cerrar Turno Expirado] ──> ForcedCloseAuditModal

[Lugar Único: /cash-control (Workspace del Turno — 3 Tabs)]
  ├── Tab 1 [Turno / Arqueo]:
  │     ├── Read Model: Estado del turno (Abierto por quién, hora inicio, intentos usados)
  │     ├── Si abierto por otro usuario (no-Admin): Banner N3 + bloqueo de cierre
  │     └── Si abierto por actor/Admin: Inputs conteo (Efectivo / Nequi / Llave Bre-B)
  │           └── [Confirmar Conteo y Cerrar] (online obligatorio + lock) ──> Cierre Ciego
  │
  ├── Tab 2 [Gastos del Turno (Arquetipo D + Lista)]:
  │     ├── Read Model del servidor: solo source === 'expense' + total OPEX del servidor
  │     └── Botón [+ Registrar Gasto] ──> [BaseModal Arquetipo D]
  │                                          ├── Inputs: Monto, Concepto, Medio (3), Categoría (5), Ref.
  │                                          └── [Guardar Gasto] (online + lock) ──> RPC ──> Toast N2
  │
  └── Tab 3 [Mis Movimientos (Arquetipo E — Solo Lectura)]:
        ├── Skeleton: BaseListSkeleton + montos en tabular-nums
        ├── Filtros por canal/origen + paginación desde getOwnShiftMovements
        └── Retorno contextual seguro (router.back() con fallback a '/')
```

---

## §4. Matriz de Señalización (`N1–N5`)

| Nivel | Evento / Condición en `C2` | Superficie y Comportamiento | Audiencia |
|---|---|---|---|
| **N1 — Inline** | Monto `<= 0` o inválido, concepto `< 3` caracteres, notas requeridas en intento de cierre asistido | Error persistente junto al campo en formulario de apertura/cierre o `BaseModal` de gasto. | `Admin`, `canOpenCloseCash`, actor de gasto |
| **N2 — Toast Efímero** | Turno abierto, gasto OPEX registrado, turno cerrado correctamente | **Solo** `ToastNotification.vue`. Prohibido usar toast para errores que requieran reintento o reconciliación. | Actor operativo |
| **N3 — Banner Persistente** | 1) Turno abierto por otro usuario (`isShiftOwnedByOther`).<br>2) Intentos 1–2 de cierre asistido (`assistedRetryNotice`).<br>3) Caja cerrada al intentar registrar gasto.<br>4) **Error de carga inicial en `onMounted`** con botón **Reintentar** (elimina fallo silencioso). | Franja fija dentro del Workspace del Turno mientras persista la condición. | Todos según vista |
| **N4 — Bandeja `/notifications`** | Cierre sellado con alerta al 3.er intento (`sealedWithAlert`) o cierre forzado automático `+24h` | Notificación persistente para Admin con **deep-link directo** a `/cash-control` o `/reports?tab=history`. | `Admin` |
| **N5 — Compuerta (Arquetipo `F`)** | Turno expirado `+24h` bloqueado en `router.beforeEach` (L317-334) y cola de reconciliación `ForcedCloseAuditModal` | Modal/pantalla bloqueante que impide operar caja hasta completar el conteo ciego o firma de auditoría. | `Admin` y abridor con `canOpenCloseCash` |

---

## §5. Hotspots Contables y de Dominio — Estado de Resolución en Ola 2 (`WO-OLA2-C2-001`)

> Todos los hallazgos fueron verificados directamente en código fuente (Regla 9.3) y resueltos en **PR 2.1A (`WO-OLA2-C2-001`)** bajo `[UX-ARCH-APPROVED]` y `[LOCKFILE-APPROVED]` (`LF-003`, `LF-004`, `LF-013`, `LF-014`).

| ID | Severidad | Evidencia Previa | Brecha Contable / Seguridad / UX | Resolución Implementada en Ola 2 |
|---|---|---|---|---|
| **C2-H1** | 🟢 **RESUELTO** *(antes CRÍTICO)* | `cashRegister.ts` (L180-195); `ExpensesView.vue` (retirada) | Mapeo erróneo de `m.source === 'refund'` a `movementType: 'gasto'` y suma `totalExpenses` con `.reduce()` en cliente. | ✅ Corregido `source === 'refund'` → `movementType: 'reembolso'` en `cashRegister.ts`; nuevo RPC `rpc_obtener_gastos_turno` entrega lista OPEX limpia y `total_opex_expenses` calculado por PostgreSQL (cero `.reduce()` en UI). |
| **C2-H2** | 🟢 **RESUELTO** *(antes ALTO)* | `CashControlView.vue` (L152-154, L283) | `onMounted` ocultaba fallo de `syncFromBackend` en `console.error` (fallo silencioso Regla 3) y mutación usaba `checkConnectivity: false`. | ✅ `syncFromBackend(storeId, { throwOnError: true })` + `lastSyncError` + `BaseListSkeleton` + banner `N3` persistente con **Reintentar** y bloqueo fail-closed; `checkConnectivity: true` obligatorio en mutaciones. |
| **C2-H3** | 🟢 **RESUELTO** *(antes ALTO)* | `router/index.ts` (L146-150); `ExpensesView.vue` (retirada) | `/expenses` carecía de control por rol y mostraba título ambiguo `"Total Salidas (Sesión)"`. | ✅ Retiradas `/expenses` y `/my-shift-movements`; Workspace `/cash-control` (`requiresAuth`) con pestañas segregadas por rol (`Gastos` solo `Admin`), `assert_store_admin` en ambos RPCs (`ADMIN_ONLY_ACTION`) y título `"Total Gastos OPEX del Turno"`. |
| **C2-H4** | 🟢 **RESUELTO** *(antes MEDIO)* | `CashControlView.vue`, `ExpensesView.vue`, `MyShiftMovementsView.vue` | Emoji `⚠️`, `bg-gray-50`, `border-2`, modal custom, spinner `border-2` y ausencia de `tabular-nums`. | ✅ Tokens `DESIGN.md` (`bg-background-*`, `bg-surface-*`, `border` `1px`), íconos Lucide, `BaseModal` en gasto OPEX y cierre sellado, `BaseListSkeleton`, `font-mono tabular-nums` y validaciones `N1` inline. |
