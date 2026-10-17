# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-006)

> **Componente Auditado:** `frontend/src/views/InventoryView.vue` (y componentes auxiliares `frontend/src/components/ProductFormModal.vue`, `frontend/src/components/inventory/KardexModal.vue`; repositorios `frontend/src/data/repositories/productRepository.ts`, store `frontend/src/stores/inventory.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_006_NUCLEO_INVENTARIO_PADRE.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_006_NUCLEO_INVENTARIO_PADRE.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/InventoryView.vue`
- **Componentes Auxiliares:**
  - `frontend/src/components/ProductFormModal.vue`
  - `frontend/src/components/inventory/KardexModal.vue`
- **Capa de Datos:** `frontend/src/stores/inventory.ts` y `frontend/src/data/repositories/productRepository.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.1 Operación: Consulta Paginada de Catálogo de Productos (`get_inventory_products`)
- **Tipo:** Consulta PostgREST / Lectura (READ)
- **Entradas (Query Parameters):**
  ```json
  {
    "store_id": "UUID (Obligatorio, resuelto por RLS)",
    "is_active": "BOOLEAN (Default: true, Admin puede consultar false)",
    "category": "TEXT (Opcional, filtro por categoría exacta)",
    "low_stock_only": "BOOLEAN (Opcional, si true filtra current_stock <= min_stock)",
    "search": "TEXT (Opcional, búsqueda parcial name ilike '%search%')",
    "order_by": "TEXT (Valores: 'name.asc', 'name.desc', 'current_stock.asc', 'current_stock.desc', 'price.asc', 'price.desc')",
    "limit": "INTEGER (Default: 20)",
    "offset": "INTEGER (Default: 0)"
  }
  ```
- **Salida Exitosa (Formato Unidireccional de Lista):**
  ```json
  {
    "data": [
      {
        "id": "UUID",
        "name": "Arroz Diana 1kg",
        "plu": "1001",
        "brand": "Diana",
        "category": "Viveres",
        "price": 4200.00,
        "cost_price": 3500.00,
        "current_stock": 45.00,
        "min_stock": 10.00,
        "measurement_unit": "unidad",
        "is_weighable": false,
        "is_active": true
      }
    ],
    "count": 347
  }
  ```

### 5.2 Operación: Consulta Filtrada de Kardex (`get_inventory_kardex`)
- **Tipo:** Consulta PostgREST / Lectura (READ)
- **Entradas (Query Parameters):**
  ```json
  {
    "product_id": "UUID (Obligatorio)",
    "start_date": "TIMESTAMPTZ (Default: NOW() - INTERVAL '7 days')",
    "end_date": "TIMESTAMPTZ (Default: NOW())",
    "movement_type": "TEXT (Opcional: 'entrada', 'salida', 'venta', 'merma', 'ajuste', 'devolucion')",
    "created_by": "UUID (Opcional, filtro por usuario)",
    "limit": "INTEGER (Default: 20)",
    "offset": "INTEGER (Default: 0)"
  }
  ```
- **Salida Exitosa (Formato Unidireccional de Lista):**
  ```json
  {
    "data": [
      {
        "id": "UUID",
        "movement_type": "merma",
        "quantity": 2.00,
        "reason": "Empaque roto en estantería",
        "created_by": "UUID_EMPLEADO",
        "unit_cost": 3500.00,
        "created_at": "2026-10-14T10:30:00Z"
      }
    ],
    "count": 18
  }
  ```

### 5.3 Operación Escalar: Borrado Lógico Seguro (`rpc_soft_delete_product`)
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Entradas:**
  ```json
  {
    "p_product_id": "UUID (Obligatorio)"
  }
  ```
- **Salida Exitosa (Formato Unidireccional de Acción):**
  ```json
  {
    "success": true,
    "data": {
      "product_id": "UUID",
      "is_active": false,
      "released_plu": "1001",
      "deleted_at": "2026-10-14T15:00:00Z"
    }
  }
  ```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `get_inventory_products`
- **Parámetros `limit` y `offset`:**
  - Código real: `productRepository.ts:183` llama a `baseRepository.getAll(storeId)` sin parámetros de paginación (`limit`, `offset`). La lista completa se descarga en memoria (`inventoryStore.products`).
  - Resultado: **Ausente (Carga Monolítica en Memoria)**.
- **Parámetro `low_stock_only`:**
  - Código real: En `InventoryView.vue:197-200` y `useInventoryFilter.ts`, el filtro se calcula en cliente mediante `inventoryStore.lowStockProducts.length`. No viaja como query param al backend.
  - Resultado: **Ausente en consulta al servidor**.
- **Parámetro `search`:**
  - Código real: En `InventoryView.vue:161-170` y `useInventoryFilter.ts:51`, el filtrado por texto se aplica en JavaScript sobre el array reactivo local en lugar de delegar al backend.
  - Resultado: **Filtrado Client-Side**.

### Operación: `get_inventory_kardex`
- **Parámetros `start_date`, `end_date`, `movement_type`, `created_by`:**
  - Código real: `KardexModal.vue:94` llama a `productRepository.getMovementHistory(props.productId)`. En `productRepository.ts:301-329`, la consulta se realiza con `.from('inventory_movements').select('*, employees(name)').eq('product_id', productId).limit(limit)`. No acepta ni envía rangos de fechas, tipo de movimiento ni usuario.
  - Resultado: **Parámetros Ausentes en Frontend y Repositorio**.

### Operación: `rpc_soft_delete_product`
- **Campo `p_product_id`:**
  - Código real: `productRepository.ts:225-227` invoca `supabase.rpc('rpc_soft_delete_product', { p_product_id: id })`.
  - Resultado: **Presente y Conforme**.

### B2.5 CHECKPOINT Bloque 2
Se verifica que la acción crítica de borrado lógico cumple la firma del RPC. Sin embargo, las consultas de lectura (`get_inventory_products` y `get_inventory_kardex`) carecen de paginación y filtros server-side, descargando datos masivos a la memoria local.

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 Búsqueda de Cálculos Financieros en Cliente:**
  - En `ProductFormModal.vue:110-116`:
    ```typescript
    const margin = computed(() => {
      if (!formData.value.cost || !formData.value.price) return 0;
      const cost = parseFloat(formData.value.cost);
      const price = parseFloat(formData.value.price);
      if (cost === 0) return 0;
      return ((price - cost) / cost) * 100;
    });
    ```
  - En `ProductFormModal.vue:119-126`: `marginLoss` calcula en cliente la pérdida por redondeo de efectivo (`getMarginLoss(price).toNumber()`).
  - En `inventoryStore.ts:341-359`: `registerStockMovement` calcula localmente la suma/resta de stock antes de confirmación del backend.
- **B2.7 CHECKPOINT Bloque 2b:**
  - Métricas de margen y pérdida de margen calculadas en cliente. Se categoriza como hallazgo de severidad media dado que son ayudas visuales de previsualización en el formulario.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del SDD
1. `Cargando Catálogo` -> Skeleton de carga.
2. `Catálogo Vacío` -> Empty State con acción de crear producto.
3. `Cargando Kardex` -> Spinner de carga.
4. `Kardex Vacío` -> Mensaje "No hay movimientos registrados".
5. `Confirmación de Borrado` -> Modal de confirmación (`showDeleteModal`).
6. `Error de Borrado (Existencias / Facturas)` -> Notificación de error propagada al usuario (`toast.error`).

### B3.9 Búsqueda en Código
- **Estado 1:** `InventoryView.vue:206` (`<BaseListSkeleton v-if="inventoryStore.isLoading" ... />`). **Conforme**.
- **Estado 2:** `InventoryView.vue:209-216` (`<BaseEmptyState v-else-if="filteredProducts.length === 0" ... />`). **Conforme**.
- **Estado 3:** `KardexModal.vue:10-13` (`v-if="loading"`). **Conforme**.
- **Estado 4:** `KardexModal.vue:16-19` (`v-else-if="movements.length === 0"`). **Conforme**.
- **Estado 5:** `InventoryView.vue:338-370` (`<BaseModal v-model="showDeleteModal" ... />`). **Conforme**.
- **Estado 6:** `InventoryView.vue:119-121` (`toast.error(e.message || 'Error desconocido al eliminar')`). **Conforme**.

### B3.10 Cruce Explícito
Todos los estados visuales principales cuentan con renderizado reactivo explícito.

### B3.11 CHECKPOINT Bloque 3
Manejo de estados visuales y loading states completo y conforme.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12 Formateo:**
  - `InventoryView.vue:37, 251`: `formatCurrency(product.price)` usando `useCurrencyFormat` (pesos COP sin decimales, con punto).
  - `InventoryView.vue:38, 265`: `formatStock(product.stock, product.measurementUnit)` con composable de cantidades.
- **B4.13 CHECKPOINT Bloque 4:**
  - Conforme con `SPEC-011`.

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 Restricciones del SDD:**
  - Visualización: `canViewInventory`.
  - Gestión/Edición/Eliminación: `canManageInventory` (solo Admin o empleado autorizado).
- **B5.15 Implementación:**
  - En `InventoryView.vue:42-43`: `canViewInventory` y `canManageInventory` desde `authStore`.
  - En `InventoryView.vue:148-150`: `<NoPermissionOverlay v-if="!canViewInventory" ... />`.
  - En `InventoryView.vue:283`: `v-if="canManageInventory"` oculta el botón de eliminar.
  - En `InventoryView.vue:298, 308`: FABs de entrada de mercancía y nuevo producto restringidos con `v-if="canManageInventory"`.
- **B5.16 CHECKPOINT Bloque 5:**
  - Conforme con la matriz de roles y permisos.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | Carga monolítica del catálogo en cliente sin paginación server-side en `productRepository.ts:183` e `InventoryView.vue`, omitiendo los parámetros `limit`, `offset` y `order_by` de SDD-006 §5.1 (`get_inventory_products`). | Bloque 2 (B2.4) | 🔴 Alta |
| UX-2 | Consulta de Kardex en `KardexModal.vue:87-100` y `productRepository.ts:301-329` sin soporte para filtros de rango de fechas (`start_date`, `end_date`), tipo de movimiento (`movement_type`) ni usuario (`created_by`), contraviniendo SDD-006 §5.2. | Bloque 2 (B2.4) | 🟡 Media |
| UX-3 | Conteo e indicador de stock bajo calculado en JavaScript en el cliente (`InventoryView.vue:197-200`) en lugar de solicitar la proyección filtrada con `low_stock_only=true` al backend. | Bloque 2b (B2.6) | 🟡 Media |
| UX-4 | Cálculo de margen comercial (`margin`) y pérdida por redondeo (`marginLoss`) calculado en frontend (`ProductFormModal.vue:110-126`). | Bloque 2b (B2.6) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:**
  - Al identificarse 1 hallazgo de severidad ALTA (UX-1: Carga monolítica sin paginación), el frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. Integrar paginación server-side incremental (`limit`, `offset`) en `productRepository.ts` e `inventoryStore.ts` para catálogos que superen el límite base de 20 productos.
2. Dotar a `KardexModal.vue` de selectores de rango de fechas y tipo de movimiento, transmitiéndolos en la consulta de `get_inventory_kardex`.
3. Reconciliar el filtro de productos con stock bajo para permitir consulta directa mediante `low_stock_only=true`.
