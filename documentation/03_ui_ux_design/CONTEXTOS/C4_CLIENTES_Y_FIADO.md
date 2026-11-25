# Contexto C4 — Cartera (Clientes & Fiado)

> **Estado:** Consolidado en Ola 2 (`UX-ADR-006`, `WO-OLA2-C4-001`)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-006`)  
> **Restricción de conectividad:** **Online obligatorio** para todas las operaciones de Cartera y Fiado ([`PRODUCT.md`](../../../PRODUCT.md#L38)).

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Gestionar la cartera de clientes con crédito ("fiado"), su estado de cuenta, cupos individuales, abonos de deuda y la política de cupo global por defecto de la tienda (absorbiendo la configuración que hoy vive desubicada en `AdminHubView.vue` / Contexto `C7`).

### 1.2 Rutas Actuales vs. Objetivo Canónico

| Ruta | Vista (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Estado Consolidado (`UX-ADR-006`) |
|---|---|---|---|---|
| `/clients` | [`ClientListView.vue`](../../../frontend/src/views/ClientListView.vue) | `canonica` | `B` (Workspace Lista) | **Canónica:** Lista paginada con `totalPortfolioDebt` del servidor y modal **Cupo Global** (solo `Admin`, reubicado desde `/admin`). |
| `/clients/:id` | [`ClientDetailView.vue`](../../../frontend/src/views/ClientDetailView.vue) | `canonica` | `B/D` (Workspace Ficha + Hoja Transaccional) | **Canónica:** Ficha hidratada desde `statementData.client`, tokens `DESIGN.md`, y modal de abono (`Arquetipo D`) fail-closed con validación `N1` inline. |

### 1.3 Matriz de Permisos (`SDD-003-01`)

| Capacidad / Acción | `Admin` | Empleado con `canFiar` | Empleado sin `canFiar` | Evidencia en Código |
|---|---|---|---|---|
| Consultar lista de clientes y ficha `/clients/:id` | ✅ | ✅ | ❌ | Guard `!authStore.canFiar` en [`router/index.ts`](../../../frontend/src/router/index.ts#L344-L346) |
| Registrar abono de cliente | ✅ | ✅ | ❌ | [`ClientDetailView.vue`](../../../frontend/src/views/ClientDetailView.vue) |
| Crear / editar / eliminar cliente | ✅ | ❌ | ❌ | [`ClientListView.vue`](../../../frontend/src/views/ClientListView.vue) (`canManageClients = authStore.isAdmin`) |
| Configurar `globalCreditLimit` por defecto | ✅ | ❌ | ❌ | [`ClientListView.vue`](../../../frontend/src/views/ClientListView.vue) (modal **Cupo Global**, solo `isAdmin`) |

---

## §2. Matriz ORCA (Objetos, Relaciones, CTAs y Densidad)

### 2.1 Objetos Canónicos y Relaciones `1:N`

```text
Política de Cupo Global [Tienda] (1) ──> defaults al crear Cliente
Cliente (1) ──< Movimiento de Cartera [Fiado | Abono] (N)
        │
        └──> Venta Fiada en Mostrador [Contexto C1] (?from=pos / ?checkoutClientId=...)
```

### 2.2 Matriz Global de CTAs (`Verbo × Objeto`)

| Verbo + Objeto | Rol autorizado | Red | Hogar Actual | Hogar Canónico Objetivo |
|---|---|---|---|---|
| **Buscar / Filtrar `Cliente`** | `Admin`, `canFiar` | Online | `/clients` (`ClientListView.vue`) | `/clients` (total cartera devuelto por servidor) |
| **Configurar `Política de Cupo Global`** | `Admin` | Online | Desubicado en `AdminHubView.vue` (L55-96, `C7`) | `/clients` (panel/modal de política para `Admin`) |
| **Crear / Editar / Eliminar `Cliente`** | `Admin` | Online | `ClientFormModal` desde `/clients` y `/clients/:id` | `/clients` y `/clients/:id` (bloqueo si deuda `> 0`) |
| **Consultar `Estado de Cuenta`** | `Admin`, `canFiar` | Online | `/clients/:id` (dependiente de caché en memoria) | `/clients/:id` hidratado desde `statementData.client` |
| **Registrar `Abono`** | `Admin`, `canFiar` | Online | `/clients/:id` (errores solo por toast `showWarning`) | `/clients/:id` → Hoja Transaccional Arquetipo `D` con validación `N1` inline |

### 2.3 Densidad de Atributos (Lista vs. Ficha)

| Superficie | Atributos Visibles | Regla de Densidad |
|---|---|---|
| **Fila en Lista (`/clients`)** | Iniciales/Nombre, Cédula/Teléfono, Deuda actual (`tabular-nums`), Indicador de cupo. | Badge de deuda total global calculado por backend (nunca suma parcial de página). |
| **Ficha (`/clients/:id`)** | Saldo pendiente (`tabular-nums`), Cupo disponible vs. límite, Lista cronológica de movimientos (`Fiado` / `Abono`). | Cero gradientes ni fondos fuera de `DESIGN.md`; retorno contextual hacia `/pos?checkoutClientId=:id` si viene de POS. |

---

## §3. Breadboards (Flujo Actual vs. Flujo Objetivo)

### 3.1 Breadboard Actual (Top Task #3 y Fricciones Detectadas)

```text
[/admin (AdminHubView.vue — C7)]
  └── Formulario suelto "globalCreditLimit" (L55-96) desconectado de Cartera

[/clients (ClientListView.vue)]
  ├── Header badge "Total:" = reduce() solo sobre pagedClients (primeros 20 clientes, L103-108)
  └── Tap en cliente ──> [/clients/:id (ClientDetailView.vue)]
                           ├── client = clientsStore.getClientById(id) (L59)
                           ├── Si recarga/deep-link sin caché: Hero v-if="client" desaparece (L293)
                           └── Botón [REGISTRAR ABONO] ──> Modal Abono
                                 └── Sobre-abono o error RPC -> showWarning() toast efímero (L261-280)
```

### 3.2 Breadboard Objetivo (Top Task #3 en 2–3 Toques)

```text
[Lugar 1: /clients (Workspace Cartera)]
  ├── Read Model servidor: Total deuda global tienda + total clientes + página actual
  ├── Botón Admin [Cupo Global] ──> Modal/Sheet configuración globalCreditLimit (en su Contexto C4)
  └── Tap en cliente ──> [Lugar 2: /clients/:id (Ficha Cliente)]
                           ├── Hidratación resiliente: statementData.client || store (Hero siempre visible)
                           ├── Read Model: Saldo actual | Cupo disponible | Uso % (tabular-nums)
                           ├── Si ?from=pos: botón retorno ──> /pos?checkoutClientId=:id
                           └── Botón [REGISTRAR ABONO] ──> [Hoja Transaccional Arquetipo D]
                                                             ├── Read Model: Deuda actual + impacto (Antes -> Después)
                                                             ├── Validación N1 inline: sobre-abono y error servidor en modal
                                                             └── [Confirmar] (lock) ──> RPC ──> Toast N2 + recarga estado
```

---

## §4. Matriz de Señalización (`N1–N5`)

| Nivel | Evento / Condición en `C4` | Superficie y Comportamiento | Audiencia |
|---|---|---|---|
| **N1 — Inline** | Monto `<= 0`, abono mayor a `totalDebt` (sobre-abono), error devuelto por RPC al abonar o actualizar cupo | Error persistente dentro del modal de abono o formulario (retirar dependencia exclusiva de `showWarning` toast). | `Admin`, `canFiar` |
| **N2 — Toast Efímero** | Abono registrado exitosamente, cliente creado/editado, cupo global actualizado | **Solo** `ToastNotification.vue`. | `Admin`, `canFiar` |
| **N3 — Banner Persistente** | Error al cargar lista de clientes o `getClientStatement`, estado offline bloqueado | Franja fija con causa y botón **Reintentar** (`BaseButton`). | `Admin`, `canFiar` |
| **N4 — Bandeja `/notifications`** | Cliente alcanza `>= 90%` o `100%` de su cupo de crédito o registra mora | Notificación persistente con deep-link directo: `/clients/:id`. | `Admin`, `canFiar` |
| **N5 — Compuerta (`BaseModal`)** | Intento de eliminar cliente con deuda activa (bloqueado) o confirmación de eliminación segura | `BaseModal` explícito con estado de deuda y acción segura. | `Admin` |

---

## §5. Hotspots Contables y de Dominio Cerrados en Ola 2 (`WO-OLA2-C4-001` / `UX-ADR-006`)

| ID | Severidad | Evidencia Original Auditada | Estado en Ola 2 | Resolución Implementada (`WO-OLA2-C4-001`) |
|---|---|---|---|---|
| **C4-H1** | ✅ **CERRADO** | [`ClientListView.vue`](../../../frontend/src/views/ClientListView.vue) calculaba `totalDebt` con `.reduce()` parcial sobre `pagedClients` | **Resuelto en SQL + Repositorio + UI** | `rpc_admin_get_clients` devuelve `total_portfolio_debt` y `debtors_count` agregados sobre el 100% de clientes activos; `ClientListView.vue` consume `totalPortfolioDebt` en `font-mono tabular-nums`. |
| **C4-H2** | ✅ **CERRADO** | [`AdminHubView.vue`](../../../frontend/src/views/AdminHubView.vue) contenía el formulario incrustado de `globalCreditLimit` | **Reubicado a `/clients`** | Formulario retirado de [`AdminHubView.vue`](../../../frontend/src/views/AdminHubView.vue) (ahora tarjeta lanzadora `Hub`) y migrado a modal **Cupo Global** solo `isAdmin` en [`ClientListView.vue`](../../../frontend/src/views/ClientListView.vue) con validación `N1` inline. |
| **C4-H3** | ✅ **CERRADO** | [`ClientDetailView.vue`](../../../frontend/src/views/ClientDetailView.vue) leía `client` solo de caché en memoria | **Resuelto en Store + UI** | `clientsStore.getClientStatement` inserta el cliente en memoria si no existía y `ClientDetailView.vue` hidrata `statementData.client || getClientById`, mostrando skeleton en carga y tarjeta `N3` fail-closed en error. |
| **C4-H4** | ✅ **CERRADO** | [`ClientDetailView.vue`](../../../frontend/src/views/ClientDetailView.vue) usaba `showWarning`, `bg-slate-800` fijo y gradientes | **Alineado a `DESIGN.md` + `N1`/`N3`** | Validación de sobre-abono y errores RPC migrados a alertas `N1` inline sin `showWarning`; sincronización fail-closed de caja (`throwOnError: true`) con Reintentar; Hero dual `bg-surface-light dark:bg-surface-dark`, cifras `font-mono tabular-nums` y `border-l-[6px]` eliminado en `/clients`. |
