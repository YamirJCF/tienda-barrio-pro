# Orden de Trabajo: Integración FIFO en Frontend (WO-PHASE5-004)

**Referencia**: `03_UX_DESIGN/FIFO_UX_IMPACT.md`
**Objetivo**: Revelar la trazabilidad de los Lotes (FIFO) al usuario final mediante "Profundidad Progresiva", sin alterar el flujo de venta rápido.

## Estructura de Ramas
- **Rama Base**: `main`
- **Rama de Trabajo**: `feat/fifo-frontend-integration`

## Desglose de Tareas

### 1. Capa de Datos (Store)
**Objetivo**: Permitir al frontend leer la tabla `inventory_batches`.
*   [ ] Crear `src/stores/batches.ts` (o integrar en `inventory.ts`, pero mejor separado por limpieza).
*   **Acción**: `fetchBatchesByProduct(productId)` -> `SELECT * FROM inventory_batches WHERE product_id = ? ORDER BY created_at ASC`.
*   **Estado**: `currentBatches: InventoryBatch[]`.

### 2. Componente Visual (Modal)
**Objetivo**: Crear el visor de historial.
*   [ ] Crear `src/components/inventory/BatchHistoryModal.vue`.
*   **UI**:
    - Header: Nombre del Producto + Stock Total.
    - Body: Tabla (Fecha, Cantidad Inicial, Restante, Costo Unit., Estado).
    - Styling: Usar `BaseModal`. Row highlight si `quantity_remaining > 0` (Activo).

### 3. Integración en Inventario
**Objetivo**: Punto de entrada al historial.
*   [ ] Modificar `src/views/InventoryView.vue`.
*   **Cambio**: Añadir botón "Ver Lotes" (Icono `Layers` o `List`) en la columna de acciones o al hacer click en el Stock.
*   **Lógica**: Al hacer click -> `batchStore.fetchBatches` -> Abrir Modal.

### 4. Feedback en Entrada de Stock
**Objetivo**: Reforzar mentalidad de "Lotes".
*   [ ] Modificar `src/views/StockEntryView.vue`.
*   **Cambio**: En `saveEntry`, cambiar el mensaje de éxito.
*   **Texto Nuevo**: "Entrada registrada exitosamente. Lotes actualizados correctamente." (Sutil pero efectivo).

---

## Bloques de Código Sugeridos (Prompts)

### Prompt 1: Crear Store de Lotes
```typescript
// Archivo: src/stores/batches.ts
import { defineStore } from 'pinia';
import { supabase } from '@/data/supabaseClient'; // O repository pattern si aplica
// ... Definir interfaz InventoryBatch ...
// ... Implementar fetchBatchesByProduct ...
```

### Prompt 2: BatchHistoryModal
```vue
<!-- Archivo: src/components/inventory/BatchHistoryModal.vue -->
<template>
  <BaseModal title="Historial de Lotes (FIFO)">
    <table class="w-full text-sm">
      <thead class="text-xs uppercase text-gray-500 bg-gray-50">
        <tr>
          <th>Fecha</th>
          <th>Costo Unit.</th>
          <th>Inicial</th>
          <th>Restante</th> <!-- Highlight if > 0 -->
        </tr>
      </thead>
      <!-- v-for batch in batches -->
    </table>
  </BaseModal>
</template>
```

---

## Comandos de Ejecución
```bash
git checkout -b feat/fifo-frontend-integration
# ... Implementar código ...
git add .
git commit -m "feat: implement fifo batch visualization"
```
