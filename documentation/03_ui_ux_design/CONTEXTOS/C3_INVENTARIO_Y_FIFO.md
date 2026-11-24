# Contexto C3 — Catálogo e Inventario (Stock & FIFO)

> **Estado:** Cartografía Ola 1 (`Lote 1A` — solo documentación)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-001`)  
> **Restricción de conectividad:** **Online obligatorio** en todas las mutaciones de inventario ([`PRODUCT.md`](../../../PRODUCT.md#L38), [`productRepository.ts`](../../../frontend/src/data/repositories/productRepository.ts#L757-L760)).

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Administrar el ciclo completo del catálogo de productos, las capas de lotes FIFO (costo unitario, precio de venta, vencimiento y saldo restante), la recepción masiva de compras a proveedor, las salidas logísticas (`merma`, `consumo_negocio`, `devolucion_proveedor`, `ajuste_conteo`) y el Kardex histórico inmutable.

### 1.2 Rutas Actuales vs. Objetivo Canónico

| Ruta | Vista (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Destino Objetivo (Ola 2) |
|---|---|---|---|---|
| `/inventory` | [`InventoryView.vue`](../../../frontend/src/views/InventoryView.vue) | `canonica` | `B` (Workspace de Objeto) | **Se mantiene canónica:** Lista buscable → Ficha/Workspace de Producto con **3 pestañas** (`Catálogo \| Lotes FIFO \| Kardex`). |
| `/stock-entry` | [`StockEntryView.vue`](../../../frontend/src/views/StockEntryView.vue) | `canonica` | `C` (Operación Masiva) | **Se mantiene canónica:** Lienzo Bulk exclusivo para recepción de compras (`N` productos por factura). |
| `/stock-outputs` | [`StockOutputsView.vue`](../../../frontend/src/views/StockOutputsView.vue) | `consolidar` | `D` (Hoja Transaccional) | **Se absorbe en Arquetipo `D`:** Hoja Transaccional de Movimiento por Lote invocable desde la pestaña `Lotes FIFO` de la Ficha Producto (y acceso rápido de mostrador para empleados). |

### 1.3 Matriz de Permisos (`SDD-003-01`)

| Capacidad / Acción | `Admin` | Empleado con `canManageInventory` | Empleado sin `canManageInventory` | Regla de Visibilidad |
|---|---|---|---|---|
| Consultar catálogo y precio de venta | ✅ | ✅ | ✅ *(vía POS / búsqueda)* | Ruta `/inventory` exige `canManageInventory` en `router/index.ts` (L362). |
| Crear / editar / eliminar producto | ✅ | ✅ | ❌ | Controlado en router y vista. |
| Entrada masiva de compras (`/stock-entry`) | ✅ | ✅ | ❌ | Requiere `canManageInventory` (`router/index.ts` L362). |
| Editar `sale_price` o `cost_unit` de lote FIFO | ✅ | ✅ | ❌ | `BatchHistoryModal.vue` L101 (`canManageInventory`). |
| Registrar `devolucion_proveedor` o `ajuste_conteo` | ✅ | ✅ | ❌ | Control interno `hasFullInventoryAccess` (`StockOutputsView.vue` L248). |
| Registrar `merma` o `consumo_negocio` | ✅ | ✅ | ✅ *(capacidad operativa base)* | **Invariante:** el empleado puede reportar merma/consumo en mostrador **sin revelar `cost_unit`** ni costos de compra del lote. |

---

## §2. Matriz ORCA (Objetos, Relaciones, CTAs y Densidad)

### 2.1 Objetos Canónicos y Relaciones `1:N`

```text
Producto (1) ──< Lote FIFO (N)
         │
         └──< Movimiento Kardex (N)
         │
         └──> Proveedor [Contexto C5] (en entradas masivas y devoluciones a proveedor)
```

- **Regla ORCA:** Ningún `Lote FIFO` ni `Movimiento Kardex` justifica una ruta independiente; ambos viven anidados dentro de la Ficha del `Producto` (`/inventory`). La única ruta transaccional separada es `/stock-entry` por su naturaleza *Bulk* (Arquetipo `C`).

### 2.2 Matriz Global de CTAs (`Verbo × Objeto`)

| Verbo + Objeto | Rol autorizado | Red | Hogar Actual (Fragmentado) | Hogar Canónico Objetivo |
|---|---|---|---|---|
| **Listar / Buscar `Producto`** | `Admin`, `canManageInventory` | Online | `InventoryView.vue` | `/inventory` (Lista principal) |
| **Crear / Editar Catálogo `Producto`** | `Admin`, `canManageInventory` | Online | `ProductFormModal.vue` (mezclado con lotes) | Ficha Producto → Tab **Catálogo** |
| **Eliminar (Soft Delete) `Producto`** | `Admin`, `canManageInventory` | Online | Botón Trash en tarjeta `InventoryView.vue` (L350-354) | Ficha Producto → Tab **Catálogo** (zona peligrosa con `BaseModal`) |
| **Ver y Editar Precio/Costo de `Lote FIFO`** | `Admin`, `canManageInventory` | Online | Duplicado en `ProductFormModal.vue` (L650-704) **y** `BatchHistoryModal.vue` (L59-122) | Ficha Producto → Tab **Lotes FIFO** *(único hogar)* |
| **Registrar `Entrada Masiva`** | `Admin`, `canManageInventory` | Online | `StockEntryView.vue` | `/stock-entry` (Arquetipo `C`) |
| **Registrar `Merma` / `Consumo` / `Devolución` / `Ajuste`** | `Admin`, `canManageInventory` *(y empleado base en `merma`/`consumo`)* | Online | `StockOutputsView.vue` (sin selector de lote) | **Hoja Transaccional de Movimiento por Lote (`Arquetipo D`)** desde Tab **Lotes FIFO** o acceso rápido de mostrador |
| **Auditar `Movimiento Kardex`** | `Admin`, `canManageInventory` | Online | `KardexModal.vue` | Ficha Producto → Tab **Kardex** *(solo lectura + contra-movimiento compensatorio)* |

### 2.3 Densidad de Atributos (Lista vs. Ficha)

| Superficie | Atributos Visibles (Máximo) | Controles Permitidos |
|---|---|---|
| **Tarjeta / Fila en Lista (`/inventory`)** | 1) Nombre + PLU, 2) Categoría, 3) Precio de venta (`tabular-nums`), 4) Stock total vs. stock mínimo. | Toque único abre **Ficha de Producto** (elimina los 3 botones apiñados `History` / `Layers` / `Trash2` de `InventoryView.vue` L337-355). |
| **Ficha de Producto (3 Pestañas)** | **Catálogo:** datos maestros, unidad, mínimo.<br>**Lotes FIFO:** fecha ingreso, vencimiento, stock restante / inicial, `sale_price` (`cost_unit` solo si `hasFullInventoryAccess`).<br>**Kardex:** línea de tiempo inmutable, actor, motivo y delta. | Acciones contextuales en cada pestaña; cero mezcla de edición de catálogo con capas FIFO. |

---

## §3. Breadboards (Flujo Actual vs. Flujo Objetivo)

### 3.1 Breadboard Actual (6 Superficies Solapadas)

```text
[/inventory (InventoryView.vue)]
  ├── Tarjeta producto (con 3 botones mini apiñados):
  │     ├── Clic tarjeta ──> [ProductFormModal.vue (732 líneas)]
  │     │                      ├── Datos catálogo + precio/costo base
  │     │                      └── Lotes Activos (solo edita sale_price, L680-701)
  │     ├── Botón Layers ──> [BatchHistoryModal.vue (238 líneas)]
  │     │                      └── Tabla lotes (edita cost_unit Y sale_price, L59-122)
  │     └── Botón History ─> [KardexModal.vue] (historial + filtros)
  ├── FAB Verde ───────────> [/stock-entry (StockEntryView.vue)]
  │                            └── Bucle for item-a-item (no atómico) + botón puente a salidas
  └── Ruta aislada ────────> [/stock-outputs (StockOutputsView.vue)]
                               └── Busca producto SIN mostrar lotes FIFO ni precios ──> RPC a ciegas
```

### 3.2 Breadboard Objetivo (Consolidado en 2–3 Toques, Arquetipo `B` + `D` + `C`)

```text
[Lugar 1: /inventory (Lista Limpia)]
  ├── Muestra: Nombre | PLU | Precio | Stock vs. Mínimo
  └── Tap en producto ──> [Lugar 2: Ficha Producto (3 Tabs)]
                            ├── Tab [Catálogo]: editar metadatos / soft-delete (BaseModal)
                            ├── Tab [Lotes FIFO]: lista de lotes activos (Fecha | Venc. | Disp. | PV | Costo*)
                            │     ├── Acción en [Lote #B]: "Editar precio/costo" ──> RPC lote
                            │     └── Acción en [Lote #B]: "Merma / Salida / Ajuste"
                            │           └──> [Hoja Transaccional Arquetipo D: Movimiento Lote #B]
                            │                  ├── Read Model: Lote #B (Disp: 8 un · PV: $4.500 · Venc.)
                            │                  ├── Inputs: Tipo + Cantidad + Motivo (+ Proveedor si dev.)
                            │                  ├── Preview ecuación: 8 un ──> 6 un (-2 un del Lote #B)
                            │                  └── [Confirmar] (lock/loading) ──> RPC(p_batch_id) ──> Toast N2
                            └── Tab [Kardex]: movimientos inmutables (solo lectura + filtros)

[Lugar 3: /stock-entry (Arquetipo C — Bulk Compra Proveedor)]
  ├── Selector Proveedor [C5] + Ref. Factura + Motivo
  ├── Captura rápida de N ítems (cantidad, costo, PV, vencimiento estructurado)
  ├── Read Model / Resumen devuelto por servidor
  └── [Confirmar Entrada Atómica] (lock/loading) ──> RPC batch único ──> Toast N2
```

---

## §4. Matriz de Señalización (`N1–N5`)

| Nivel | Evento / Condición en `C3` | Superficie y Comportamiento | Audiencia |
|---|---|---|---|
| **N1 — Inline** | Precio de venta `<` costo unitario, regla de redondeo `$50`, PLU duplicado, cantidad `>` remanente del lote seleccionado, motivo `< 3` caracteres | Mensaje persistente junto al campo o selector de lote; bloquea envío hasta corregir. | `Admin`, `canManageInventory`, Empleado (`merma`/`consumo`) |
| **N2 — Toast Efímero** | Producto guardado, precio de lote actualizado, merma/salida registrada, entrada masiva confirmada | **Solo** `ToastNotification.vue` (retirar `vue-toastification` de `InventoryView.vue`, `ProductFormModal.vue`, `KardexModal.vue`). | Todos los actores autorizados |
| **N3 — Banner Persistente** | Pérdida de conexión (`OFFLINE_NOT_ALLOWED`), error de concurrencia / cooldown, error al cargar lotes o Kardex | Franja fija en la vista con causa exacta y botón **Reintentar** (cero fallos silenciosos). | Todos |
| **N4 — Bandeja `/notifications`** | Alerta de stock bajo mínimo o lote próximo a vencer / agotado | Notificación persistente con **deep-link directo**: `/inventory?product=<id>&tab=batches`. | `Admin`, `canManageInventory` |
| **N5 — Compuerta (`BaseModal`)** | Confirmación de eliminación segura de producto o salida/ajuste irreversible | `BaseModal` estructurado con resumen `Antes → Después`; prohibido `alert()`/`confirm()`. | `Admin`, `canManageInventory` |

---

## §5. Hotspots Contables y de Dominio Verificados para Ola 2 (`FRD/SDD/SQL` antes de UI)

> Todos los hallazgos fueron verificados directamente en código fuente (Regla 9.3). Ningún hotspot visual se resuelve en Vue sin cerrar primero su contrato en `FRD/SDD/SQL` (Regla 10).

| ID | Severidad | Evidencia Verificada en Código | Brecha de Dominio / UX | Acción Requerida en Ola 2 |
|---|---|---|---|---|
| **C3-H1** | 🔴 **CRÍTICO** | [`StockOutputsView.vue`](../../../frontend/src/views/StockOutputsView.vue#L322-L331), [`productRepository.ts`](../../../frontend/src/data/repositories/productRepository.ts#L765-L772) | `rpc_registrar_salida_logistica` recibe `{ p_product_id, p_movement_type, p_quantity, p_reason, p_direction, p_supplier_id }`, **sin `p_batch_id`** ni política de capa/precio para mermas de lote puntual o ajustes positivos (sobrantes). | Definir en `FRD/SDD/SQL` parámetro opcional/explícito `p_batch_id` + regla de costo/precio para sobrantes, luego migrar UI a Arquetipo `D` con Read Model de lotes FIFO. |
| **C3-H2** | 🟠 **ALTO** | [`ProductFormModal.vue`](../../../frontend/src/components/ProductFormModal.vue#L319-L337) (`saveBatchPrice`) y L650-704; [`BatchHistoryModal.vue`](../../../frontend/src/components/inventory/BatchHistoryModal.vue#L59-L122) | Edición duplicada de lotes FIFO en dos modales distintos con alcances diferentes (`ProductFormModal` edita solo `sale_price` en tema oscuro; `BatchHistoryModal` edita `cost_unit` y `sale_price` con SVG inline). | Unificar en una sola pestaña `Lotes FIFO` dentro de la Ficha Producto (Hogar Canónico único). |
| **C3-H3** | 🟠 **ALTO** | [`inventory.ts`](../../../frontend/src/stores/inventory.ts#L431-L434) (`finalReason`), L471-485 (`productRepository.update({ cost })`); [`StockEntryView.vue`](../../../frontend/src/views/StockEntryView.vue#L150) (L150, L297-299, L371-391) | 1) `expirationDate` se concatena solo como texto `[Vence: ...]` dentro de `reason` en vez de columna estructurada.<br>2) El store actualiza `product.cost` fuera del RPC FIFO cuando `oldStock <= 0`.<br>3) `StockEntryView` ejecuta un bucle `for` no atómico item por item (permite facturas a medias) y calcula subtotales (`item.quantity * item.unitCost`) y `totalInvoice` con `.reduce()` en cliente (viola `SPEC_001`). | Convertir la entrada masiva en RPC transaccional atómico (todo o nada) con vencimiento estructurado y totales devueltos por servidor. |
| **C3-H4** | 🟡 **MEDIO** | [`StockEntryView.vue`](../../../frontend/src/views/StockEntryView.vue#L2-L4), [`StockOutputsView.vue`](../../../frontend/src/views/StockOutputsView.vue#L2-L4), [`InventoryView.vue`](../../../frontend/src/views/InventoryView.vue#L15) y L318, [`ProductFormModal.vue`](../../../frontend/src/components/ProductFormModal.vue#L8), [`KardexModal.vue`](../../../frontend/src/components/inventory/KardexModal.vue#L197) | 1) `bg-gray-900` fijo fuera de tokens duales de `DESIGN.md` en `StockEntryView` y `StockOutputsView`.<br>2) Posible doble `$` en [`InventoryView.vue`](../../../frontend/src/views/InventoryView.vue#L318) (`${{ formatCurrency(product.price) }}`).<br>3) Deuda registrada en `baselineDebt.legacyToastImportsAllowed`: `vue-toastification` activo en `InventoryView`, `ProductFormModal` y `KardexModal`. | Alinear tokens a `DESIGN.md`, corregir formato de moneda y migrar toasts a `ToastNotification.vue` reduciendo `baselineDebt`. |
