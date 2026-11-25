# Contexto C6 — Inteligencia y Auditoría (Solo Lectura)

> **Estado:** Consolidado Ola 2 (`UX-ADR-008` — 2026-11-25)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-008`)  
> **Restricción de conectividad y rol:** **Online obligatorio** y **100% exclusivo para `Admin`** (`isAdmin`, [`router/index.ts`](../../../frontend/src/router/index.ts#L316-L318)).

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Proveer visibilidad gerencial y auditoría inmutable: rentabilidad financiera (`P&L` 4 Pilares, semáforo de margen, valor de inventario) y trazabilidad histórica transversal en 7 dominios (`Ventas`, `Caja`, `Compras`, `Gastos`, `Créditos`, `Precios`, `Auditoría`). Como única excepción compensatoria (`Arquetipo D`), el Administrador puede ejecutar **Anular Venta** (`rpc_anular_venta`) directamente desde [`SaleDetailModal.vue`](../../../frontend/src/components/history/SaleDetailModal.vue) previa visualización del Read Model de la venta y captura de motivo mínimo (`N1`); cualquier otro ajuste de inventario o cartera navega hacia `C3` o `C4`.

### 1.2 Rutas Actuales vs. Objetivo Canónico

| Ruta *(Aliases)* | Vista (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Consolidación Aplicada (`UX-ADR-008`) |
|---|---|---|---|---|
| `/reports` *(aliases `/admin/financial-dashboard`, `/history`)* | [`ReportsHubView.vue`](../../../frontend/src/views/ReportsHubView.vue) | `canonica` | `E` (Inteligencia) | **Único Hogar Canónico** con montaje lazy `v-if` / `v-else` en `?tab=dashboard \| history`. Rutas duplicadas retiradas; [`FinancialDashboardTab.vue`](../../../frontend/src/components/reports/FinancialDashboardTab.vue) y [`AuditHistoryTab.vue`](../../../frontend/src/components/reports/AuditHistoryTab.vue) viven como subcomponentes de pestaña. |

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
| **N5 — Compuerta** | Confirmación compensatoria **Anular Venta** (`Arquetipo D`) en [`SaleDetailModal.vue`](../../../frontend/src/components/history/SaleDetailModal.vue) (`showVoidModal`) | Modal de confirmación exclusiva `Admin` con Read Model visible (`Venta #ticket`, `Total`, canal y cliente), advertencia de reversión atómica y bloqueo de doble envío (`isVoiding`). | `Admin` |

---

## §5. Hotspots Contables y de Dominio Verificados en Ola 2 (`FRD/SDD/SQL` + UI)

| ID | Severidad | Evidencia Verificada en Código | Brecha Arquitectónica / UX | Estado en Ola 2 (`UX-ADR-008`) |
|---|---|---|---|---|
| **C6-H1** | 🟠 **ALTO** | [`router/index.ts`](../../../frontend/src/router/index.ts); [`ReportsHubView.vue`](../../../frontend/src/views/ReportsHubView.vue) | Coexistían rutas duplicadas `/admin/financial-dashboard` y `/history` junto a `/reports` y `v-show` montaba ambas pestañas al abrir. | ✅ **Cerrado (`UX-ADR-008`):** Rutas duplicadas convertidas en aliases de `/reports`, vistas reubicadas en `components/reports/` (`FinancialDashboardTab.vue`, `AuditHistoryTab.vue`) y montaje lazy `v-if` / `v-else` con normalización de alias. |
| **C6-H2** | 🟡 **MEDIO** | [`ReportsHubView.vue`](../../../frontend/src/views/ReportsHubView.vue); [`SaleDetailModal.vue`](../../../frontend/src/components/history/SaleDetailModal.vue); [`20261125100000_ola2_c6_sale_detail_entity_links.sql`](../../../supabase/migrations/20261125100000_ola2_c6_sale_detail_entity_links.sql) | Retornos inconsistentes y modales/widgets sin enlaces heterárquicos hacia `C3` o `C4`. | ✅ **Cerrado (`UX-ADR-008`):** Retorno unificado (`?from=admin`), `get_sale_detail` expone `client_id` y `items[].product_id`, enlaces directos hacia `/clients/:id`, `/clients?debt=with_debt` e `/inventory?productId=:id`, y `voidError` `N1` inline sin doble toast. |
| **C6-H3** | 🟡 **MEDIO** | [`FinancialDashboardTab.vue`](../../../frontend/src/components/reports/FinancialDashboardTab.vue); [`AuditHistoryTab.vue`](../../../frontend/src/components/reports/AuditHistoryTab.vue); [`financial.ts`](../../../frontend/src/stores/financial.ts) | Emojis en KPIs/filtros, clases dinámicas rotas en `InventoryHealthWidget`, posible doble `$`, zona horaria UTC y `.reduce()` en `totalStagnantValue`. | ✅ **Cerrado (`UX-ADR-008`):** Emojis reemplazados por Lucide, `font-mono tabular-nums` + `formatWithSign`, mapa estático en `InventoryHealthWidget`, fechas `America/Bogota`, `.reduce()` eliminado y bloqueo `N3` offline fail-closed. |
