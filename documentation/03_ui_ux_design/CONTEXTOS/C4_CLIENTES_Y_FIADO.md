# Contexto C4 — Cartera (Clientes & Fiado)

> **Estado:** Cartografía Ola 1 (`Lote 1B` — solo documentación)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-001`)  
> **Restricción de conectividad:** **Online obligatorio** para todas las operaciones de Cartera y Fiado ([`PRODUCT.md`](../../../PRODUCT.md#L38)).

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Gestionar la cartera de clientes con crédito ("fiado"), su estado de cuenta, cupos individuales, abonos de deuda y la política de cupo global por defecto de la tienda (absorbiendo la configuración que hoy vive desubicada en `AdminHubView.vue` / Contexto `C7`).

### 1.2 Rutas Actuales vs. Objetivo Canónico

| Ruta | Vista (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Destino Objetivo (Ola 2) |
|---|---|---|---|---|
| `/clients` | [`ClientListView.vue`](../../../frontend/src/views/ClientListView.vue) | `canonica` | `B` (Workspace Lista) | **Se mantiene canónica:** Lista paginada de cartera + **absorbe configuración de `globalCreditLimit`** (solo `Admin`, migrada desde `C7 /admin`). |
| `/clients/:id` | [`ClientDetailView.vue`](../../../frontend/src/views/ClientDetailView.vue) | `canonica` | `B` (Workspace Ficha) | **Se mantiene canónica:** Ficha única de cliente con saldo, barra de cupo, historial de fiados/abonos y modal de abono (Arquetipo `D`). |

### 1.3 Matriz de Permisos (`SDD-003-01`)

| Capacidad / Acción | `Admin` | Empleado con `canFiar` | Empleado sin `canFiar` | Evidencia en Código |
|---|---|---|---|---|
| Consultar lista de clientes y ficha `/clients/:id` | ✅ | ✅ | ❌ | Guard `!authStore.canFiar` en [`router/index.ts`](../../../frontend/src/router/index.ts#L367) |
| Registrar abono de cliente | ✅ | ✅ | ❌ | [`ClientDetailView.vue`](../../../frontend/src/views/ClientDetailView.vue#L254-L284) |
| Crear / editar / eliminar cliente | ✅ | ❌ | ❌ | [`ClientListView.vue`](../../../frontend/src/views/ClientListView.vue#L111) (`canManageClients = authStore.isAdmin`) |
| Configurar `globalCreditLimit` por defecto | ✅ | ❌ | ❌ | Hoy en [`AdminHubView.vue`](../../../frontend/src/views/AdminHubView.vue#L55-L96); pasa a `/clients` para `isAdmin` |

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

## §5. Hotspots Contables y de Dominio Verificados para Ola 2 (`FRD/SDD/SQL` antes de UI)

| ID | Severidad | Evidencia Verificada en Código | Brecha Contable / UX | Acción Requerida en Ola 2 |
|---|---|---|---|---|
| **C4-H1** | 🟠 **ALTO** | [`ClientListView.vue`](../../../frontend/src/views/ClientListView.vue#L103-L108) y L197 | `totalDebt` se calcula en cliente con `.reduce()` únicamente sobre `pagedClients` (página parcial de 20 clientes), violando `SPEC_001` y mostrando una deuda total falsa cuando la tienda supera 20 clientes. | Devolver `totalPortfolioDebt` agregado desde RPC/servidor y eliminar el `.reduce()` parcial en cliente. |
| **C4-H2** | 🟠 **ALTO** | [`AdminHubView.vue`](../../../frontend/src/views/AdminHubView.vue#L55-L96) | La configuración de `globalCreditLimit` vive incrustada en el hub de navegación de `C7` (`AdminHubView.vue`), rompiendo la frontera ORCA de Cartera (`C4`). | Mover la configuración de `globalCreditLimit` a `/clients` (solo `isAdmin`) dejando `AdminHubView` como lanzador puro (`Hub`). |
| **C4-H3** | 🟡 **MEDIO** | [`ClientDetailView.vue`](../../../frontend/src/views/ClientDetailView.vue#L59) y L293 | `client` se lee solo de `clientsStore.getClientById(clientId.value)` (caché en memoria); al entrar por deep-link (`N4`) o recargar en frío sin lista previa, el Hero `v-if="client"` queda oculto en vez de hidratarse desde `statementData.client`. | Hidratar `client` haciendo fallback a `statementData.value?.client` y mostrar `BaseListSkeleton` mientras carga. |
| **C4-H4** | 🟡 **MEDIO** | [`ClientDetailView.vue`](../../../frontend/src/views/ClientDetailView.vue#L261-L281), L294, L367, L384, L495 | 1) Validación de sobre-abono y error de RPC en abono se comunican solo por toast efímero (`showWarning`) en lugar de `N1` inline en el modal.<br>2) Faltan clases `font-mono tabular-nums` en el saldo gigante (L367) y en los montos de transacciones (L495).<br>3) El Hero usa `bg-slate-800` fijo y gradiente `bg-gradient-to-r` (L294, L384) fuera de `DESIGN.md`. | Mover validación/errores de abono a `N1` inline, aplicar `font-mono tabular-nums` a todas las cifras y alinear el Hero a tokens sólidos de `DESIGN.md`. |
