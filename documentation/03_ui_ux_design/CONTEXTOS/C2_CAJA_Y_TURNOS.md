# Contexto C2 — Tesorería Diaria (Caja & Turnos)

> **Estado:** Cartografía Ola 1 (`Lote 1A` — solo documentación)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-001`)  
> **Restricción de conectividad:** **Online obligatorio** para toda operación de Caja y Turnos ([`PRODUCT.md`](../../../PRODUCT.md#L38)).  
> **Invariantes de seguridad (`POL-SEG-01` / `POL-SEG-03`):** **Arqueo Ciego** (prohibido exponer `expected_balance` o `difference` al cajero/empleado) y **propiedad estricta del turno** (solo quien abrió el turno o el Admin pueden cerrarlo; cierre asistido de 3 intentos; compuerta `+24h` y reconciliación forzada).

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Gobernar el ciclo de vida completo de cada turno operativo de caja: apertura con base inicial, registro de gastos OPEX del turno, consulta de movimientos propios del actor y cierre ciego / asistido o reconciliación de cierres forzados (`+24h`).

### 1.2 Rutas Actuales vs. Objetivo Canónico

| Ruta | Vista (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Destino Objetivo (Ola 2) |
|---|---|---|---|---|
| `/cash-control` | [`CashControlView.vue`](../../../frontend/src/views/CashControlView.vue) | `canonica` | `B/D` | **Se mantiene como único Hogar Canónico:** Workspace del Turno con **3 pestañas** (`Turno / Arqueo \| Gastos del Turno \| Mis Movimientos`) + Compuerta `F` prioritaria en bloqueos `+24h` o turnos forzados pendientes. |
| `/my-shift-movements` | [`MyShiftMovementsView.vue`](../../../frontend/src/views/MyShiftMovementsView.vue) | `consolidar` | `E` | **Consolidar en `/cash-control?tab=movements`** (pestaña `Mis Movimientos` dentro del Workspace del Turno). |
| `/expenses` | [`ExpensesView.vue`](../../../frontend/src/views/ExpensesView.vue) | `consolidar` (`LF-003`) | `D` | **Consolidar en `/cash-control?tab=expenses`** (pestaña `Gastos del Turno`, manteniendo Hoja Transaccional Arquetipo `D` en `BaseModal`). |

### 1.3 Matriz de Permisos (`SDD-003-01`)

| Capacidad / Acción | `Admin` | Empleado con `canOpenCloseCash` | Empleado sin `canOpenCloseCash` | Regla de Visibilidad / Seguridad |
|---|---|---|---|---|
| Abrir turno de caja | ✅ | ✅ | ❌ | Guard `!authStore.canOpenCloseCash` en `router/index.ts` (L357). |
| Cerrar turno propio (Arqueo Ciego + 3 intentos) | ✅ | ✅ *(solo si es abridor)* | ❌ | Propiedad estricta; otro usuario ve banner de turno ajeno (`isShiftOwnedByOther`). |
| Cerrar / reconciliar turno de otro o forzado `+24h` | ✅ | ❌ *(solo si fue el abridor en `+24h`)* | ❌ | Guard en `router/index.ts` (L317-334) y `ForcedCloseAuditModal`. |
| Registrar Gasto OPEX (`SDD-026`) | ✅ | ✅ | ⚠️ *(sin guard hoy en `/expenses`)* | Definir regla explícita en Ola 2 y cerrar hueco en `router/index.ts` (L146-150). |
| Consultar Mis Movimientos del Turno | ✅ | ✅ | ✅ | Solo movimientos propios del actor (`getOwnShiftMovements`); Arqueo Ciego preservado. |

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
| **Registrar `Gasto OPEX`** | Según política `SDD-003-01` / `SDD-026` | Online | `/expenses` (ruta aislada sin vínculo desde Caja) | `/cash-control?tab=expenses` → botón abre **Hoja Transaccional Arquetipo `D` (`BaseModal`)** |
| **Consultar `Gasto OPEX` del Turno** | Según política / actor | Online | `/expenses` (contaminado con `refund` para no-Admin) | `/cash-control?tab=expenses` (payload limpio y total calculado por backend) |
| **Consultar `Movimiento Propio del Turno`** | Todo usuario autenticado | Online | `/my-shift-movements` (botón Atrás fijo a `/`) | `/cash-control?tab=movements` (pestaña `Mis Movimientos`, Arquetipo `E`) |

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

## §5. Hotspots Contables y de Dominio Verificados para Ola 2 (`FRD/SDD/SQL` antes de UI)

> Todos los hallazgos fueron verificados directamente en código fuente (Regla 9.3). La corrección en Ola 2 inicia en `SDD/SQL/Store` antes de consolidar la vista y exige `[LOCKFILE-APPROVED]` para `LF-003` / `LF-004`.

| ID | Severidad | Evidencia Verificada en Código | Brecha Contable / Seguridad / UX | Acción Requerida en Ola 2 |
|---|---|---|---|---|
| **C2-H1** | 🔴 **CRÍTICO** | [`cashRegister.ts`](../../../frontend/src/stores/cashRegister.ts#L180-L185); [`ExpensesView.vue`](../../../frontend/src/views/ExpensesView.vue#L43-L49) | 1) Para empleados no-Admin, `cashRegister.ts` mapea `m.source === 'refund'` a `type: 'expense'` y **`movementType: 'gasto'`**, contaminando `currentExpenses` en `ExpensesView.vue` (que filtra `movementType === 'gasto'`).<br>2) `totalExpenses` se calcula en cliente con `.reduce()` (violando `SPEC_001` Backend Authority y `POL-FIN-04`). | Corregir mapeo de `source === 'refund'` (`movementType: 'reembolso'`) en store y exponer `totalExpenses` calculado desde backend/RPC (`[LOCKFILE-APPROVED]` `LF-003`). |
| **C2-H2** | 🟠 **ALTO** | [`CashControlView.vue`](../../../frontend/src/views/CashControlView.vue#L152-L154) y L283 | 1) `onMounted` atrapa errores en `catch (e)` solo con `console.error(...)`, dejando la pantalla sin aviso visual ni botón Reintentar (riesgo de fallo silencioso, Regla 3).<br>2) La operación principal usa `checkConnectivity: false` (L283), contradiciendo el requisito online obligatorio de Caja (`PRODUCT.md` L38). | Exponer estado de error `N3` con botón Reintentar en carga inicial y exigir `checkConnectivity: true` en operaciones de Caja. |
| **C2-H3** | 🟠 **ALTO** | [`router/index.ts`](../../../frontend/src/router/index.ts#L146-L150); [`ExpensesView.vue`](../../../frontend/src/views/ExpensesView.vue#L107) | 1) La ruta `/expenses` solo exige `requiresAuth: true` sin guard explícito de permiso.<br>2) `ExpensesView.vue` muestra la etiqueta ambigua `"Total Salidas (Sesión)"` que induce a confundir gastos OPEX con devoluciones/pagos. | Definir permiso canónico en `SDD-003-01` al consolidar en `/cash-control?tab=expenses` y corregir etiqueta a `"Total Gastos OPEX del Turno"`. |
| **C2-H4** | 🟡 **MEDIO** | [`CashControlView.vue`](../../../frontend/src/views/CashControlView.vue#L183); [`ExpensesView.vue`](../../../frontend/src/views/ExpensesView.vue#L84) y L142-205; [`MyShiftMovementsView.vue`](../../../frontend/src/views/MyShiftMovementsView.vue#L143-L199) | 1) Emoji `⚠️` en título de `CashControlView.vue` (L183).<br>2) `bg-gray-50 dark:bg-gray-900` (`ExpensesView.vue` L84) y `border-2` (`MyShiftMovementsView.vue` L144) fuera de tokens `DESIGN.md`.<br>3) Modal custom manual en `ExpensesView.vue` (L142-205) en vez de `BaseModal`.<br>4) Ausencia de `tabular-nums` en montos y spinner genérico en lugar de `BaseListSkeleton` en `MyShiftMovementsView.vue` (L143-199). | Migrar a tokens de `DESIGN.md`, reemplazar modal custom por `BaseModal`, usar `BaseListSkeleton`, `tabular-nums` e íconos Lucide sin emojis. |
