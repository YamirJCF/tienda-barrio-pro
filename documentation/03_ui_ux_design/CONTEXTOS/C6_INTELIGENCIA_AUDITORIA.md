# Contexto C6 — Inteligencia y Auditoría (Solo Lectura)

> **Estado:** Cartografía Ola 1 (`Lote 1C` — solo documentación)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-001`)  
> **Restricción de conectividad y rol:** **Online obligatorio** y **100% exclusivo para `Admin`** (`isAdmin`, [`router/index.ts`](../../../frontend/src/router/index.ts#L342-L354)).

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Proveer visibilidad gerencial y auditoría inmutable de solo lectura: rentabilidad financiera (`P&L` 4 Pilares, semáforo de margen, valor de inventario) y trazabilidad histórica transversal en 7 dominios (`Ventas`, `Caja`, `Compras`, `Gastos`, `Créditos`, `Precios`, `Auditoría`). Cero mutaciones destructivas directas desde este contexto.

### 1.2 Rutas Actuales vs. Objetivo Canónico

| Ruta | Vista (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Destino Objetivo (Ola 2) |
|---|---|---|---|---|
| `/reports` | [`ReportsHubView.vue`](../../../frontend/src/views/ReportsHubView.vue) | `canonica` | `E` (Inteligencia) | **Único Hogar Canónico** del contexto con `?tab=dashboard \| history`. |
| `/admin/financial-dashboard` | [`FinancialDashboardView.vue`](../../../frontend/src/views/FinancialDashboardView.vue) | `duplicada` | `E` | **Retirar / redirigir** a `/reports?tab=dashboard` en Ola 2 (`1 Vista = 1 Ruta`). |
| `/history` | [`HistoryView.vue`](../../../frontend/src/views/HistoryView.vue) | `duplicada` | `E` | **Retirar / redirigir** a `/reports?tab=history` en Ola 2. |

### 1.3 Matriz de Permisos (`SDD-003-01`)

| Capacidad / Acción | `Admin` | Empleado (cualquier permiso) | Evidencia en Código |
|---|---|---|---|
| Acceder a `/reports`, `/admin/financial-dashboard` y `/history` | ✅ | ❌ *(redirige a `/`)* | [`router/index.ts`](../../../frontend/src/router/index.ts#L342-L354) (`!authStore.isAdmin`) |
| Exportar reportes / inspeccionar detalles forenses | ✅ | ❌ | Visibilidad exclusiva en `BottomNav` y router (`SDD-003-01` / `POL-AUD-02`) |

---

## §2. Matriz ORCA (Objetos, Relaciones, CTAs y Densidad)

### 2.1 Objetos Canónicos (Solo Lectura) y Enlaces Heterárquicos

```text
Resumen Financiero P&L 4 Pilares (Solo Lectura)
Registro Histórico / Evidencia [7 Dominios] (Solo Lectura)
        │
        ├──(drill-down contextual)──> Producto / Kardex [Contexto C3: /inventory]
        └──(drill-down contextual)──> Cliente / Cartera [Contexto C4: /clients/:id]
```

- **Regla de corrección:** Toda anomalía detectada en auditoría se corrige navegando al Hogar Canónico del objeto (`C3` o `C4`) para ejecutar un Arquetipo `D` compensatorio, nunca mutando historia desde `C6`.

### 2.2 Matriz Global de CTAs (`Verbo × Objeto`)

| Verbo + Objeto | Rol autorizado | Red | Hogar Actual | Hogar Canónico Objetivo |
|---|---|---|---|---|
| **Consultar `Resumen Financiero P&L`** | `Admin` | Online | `/reports?tab=dashboard` **y** `/admin/financial-dashboard` | `/reports?tab=dashboard` *(carga lazy `v-if`)* |
| **Auditar `Registro Histórico` (7 dominios)** | `Admin` | Online | `/reports?tab=history` **y** `/history` | `/reports?tab=history` *(carga lazy `v-if`)* |
| **Inspeccionar Detalle Forense (`Producto` / `Cliente`)** | `Admin` | Online | Modal aislado en `HistoryView.vue` sin enlace al objeto | Modal forense con enlace contextual hacia `C3` o `C4` |

### 2.3 Densidad de Atributos (KPIs y Listas Históricas)

| Superficie | Atributos Visibles | Regla de Densidad |
|---|---|---|
| **KPIs Financieros (`FinancialDashboardView.vue`)** | Ingresos netos, Costo FIFO (`cogs`), Utilidad bruta + margen %, OPEX, Ganancia/Pérdida neta y Valor inventario. | Cifras en `font-mono tabular-nums`, formato consistente (sin doble `$` ni emojis en títulos). |
| **Lista de Auditoría (`HistoryView.vue`)** | Selector de dominio (7 dominios sin emojis), Fecha/Actor, Concepto, Canal y Delta (`tabular-nums`). | Filtros consistentes y detalle forense enlazado a su objeto origen. |

---

## §3. Breadboards (Flujo Actual vs. Flujo Objetivo)

### 3.1 Breadboard Actual (Duplicación de Rutas + Doble Montaje `v-show`)

```text
[BottomNav "Reportes" o acceso directo]
  ├── /reports (ReportsHubView.vue, L90-95):
  │     ├── Monta CON v-show <FinancialDashboardView /> Y <HistoryView /> simultáneamente (doble fetch en mount)
  │     └── Botón Atrás ──> router.push('/') (L21)
  ├── /admin/financial-dashboard (ruta duplicada en router/index.ts L86-90):
  │     └── Botón Atrás ──> router.push('/admin') (L40, retorno inconsistente)
  └── /history (ruta duplicada en router/index.ts L165-169):
        └── Modales forenses sin deep-link hacia /inventory o /clients/:id
```

### 3.2 Breadboard Objetivo (Hub Único Lazy `/reports`)

```text
[Lugar Único: /reports?tab=dashboard|history (Admin Only, Arquetipo E)]
  ├── Tab [Dashboard Financiero] (montaje lazy v-if):
  │     ├── Read Model servidor: P&L 4 Pilares + Semáforo + Inventario (tabular-nums, sin emojis)
  │     └── Error de carga -> Banner N3 con botón Reintentar (retry)
  │
  └── Tab [Historial y Auditoría] (montaje lazy v-if):
        ├── Selector de 7 dominios (Ventas, Caja, Compras, Gastos, Créditos, Precios, Auditoría)
        └── Tap en registro ──> [Modal Forense] ──(enlace contextual)──> C3 (/inventory) o C4 (/clients/:id)
```

---

## §4. Matriz de Señalización (`N1–N5`)

| Nivel | Evento / Condición en `C6` | Superficie y Comportamiento | Audiencia |
|---|---|---|---|
| **N1 — Inline** | Rango de fechas o filtros inválidos en consulta histórica | Mensaje persistente junto al filtro; evita consulta inválida. | `Admin` |
| **N2 — Toast Efímero** | Reporte/resumen copiado o exportado correctamente | **Solo** `ToastNotification.vue`. | `Admin` |
| **N3 — Banner Persistente** | Error al cargar snapshots P&L o historial con botón **Reintentar** (`FinancialDashboardView.vue` L43-46); modo offline bloqueado | Franja fija en la pestaña activa hasta reintentar con éxito. | `Admin` |
| **N4 — Bandeja `/notifications`** | Alertas financieras críticas (cierre con discrepancia, pérdida neta, cierre forzado `+24h`) | Origen de navegación con deep-link hacia `/reports?tab=history` o `/reports?tab=dashboard`. | `Admin` |
| **N5 — Compuerta** | No aplica en vistas internas (contexto 100% solo lectura sin mutaciones). | — | — |

---

## §5. Hotspots Contables y de Dominio Verificados para Ola 2 (`FRD/SDD/SQL` antes de UI)

| ID | Severidad | Evidencia Verificada en Código | Brecha Arquitectónica / UX | Acción Requerida en Ola 2 |
|---|---|---|---|---|
| **C6-H1** | 🟠 **ALTO** | [`router/index.ts`](../../../frontend/src/router/index.ts#L86-L90) y L165-169; [`ReportsHubView.vue`](../../../frontend/src/views/ReportsHubView.vue#L90-L95) | Coexisten las rutas duplicadas `/admin/financial-dashboard` y `/history` junto a `/reports`; además `ReportsHubView.vue` usa `v-show` montando ambas subvistas simultáneamente desde el primer render. | Retirar/redirigir rutas duplicadas a `/reports?tab=...` (con su `UX-ADR`) y cambiar `v-show` por carga lazy `v-if` en `ReportsHubView.vue`. |
| **C6-H2** | 🟡 **MEDIO** | [`FinancialDashboardView.vue`](../../../frontend/src/views/FinancialDashboardView.vue#L40); [`ReportsHubView.vue`](../../../frontend/src/views/ReportsHubView.vue#L21) | Retornos inconsistentes (`FinancialDashboardView.vue` regresa a `/admin` vs `ReportsHubView.vue` a `/`) y modales forenses en `HistoryView.vue` sin enlaces contextuales hacia `C3` (`/inventory`) o `C4` (`/clients/:id`). | Unificar retorno contextual (`router.back()` con fallback seguro) y añadir enlaces heterárquicos en el detalle forense. |
| **C6-H3** | 🟡 **MEDIO** | [`FinancialDashboardView.vue`](../../../frontend/src/views/FinancialDashboardView.vue#L64) (L64, L142, L155-196); [`HistoryView.vue`](../../../frontend/src/views/HistoryView.vue#L69-L75) | Emojis visibles en UI (`📊`, `📈`, `⚠️` en `FinancialDashboardView.vue`; 7 emojis en `domainOptions` de `HistoryView.vue` L69-75); KPIs sin `font-mono tabular-nums` y posible doble `$` (`$ {{ formatCurrency(...) }}`, L155-195). | Reemplazar emojis por íconos Lucide, aplicar `font-mono tabular-nums` y corregir formato monetario único con `formatCurrency`. |
