# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-010)

> **Componente Auditado:** `frontend/src/components/inventory/BatchHistoryModal.vue` y `frontend/src/components/analytics/InventoryValuationCard.vue` (y store `frontend/src/stores/batches.ts`, `frontend/src/stores/inventory.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_010_016_VALORACION_FIFO.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_010_016_VALORACION_FIFO.md) (y política [`SDD_010_HISTORIAL_PRECIOS.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_010_HISTORIAL_PRECIOS.md))  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Rutas Principales:**
  - `frontend/src/components/inventory/BatchHistoryModal.vue`
  - `frontend/src/components/analytics/InventoryValuationCard.vue`
- **Capa de Datos:** `frontend/src/stores/batches.ts` y `frontend/src/stores/inventory.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contratos de Interfaz

### 5.1 Operación: `rpc_actualizar_precio_lote` (Acción - WRITE)
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Payload de Entrada:**
  ```json
  {
    "p_batch_id": "UUID (Obligatorio — Identificador único del lote en inventory_batches)",
    "p_cost_unit": "NUMERIC >= 0 (Obligatorio — Nuevo costo unitario de adquisición)",
    "p_sale_price": "NUMERIC >= 0 (Obligatorio — Nuevo precio de venta al público en COP)"
  }
  ```
- **Payload de Respuesta Exitosa:**
  ```json
  {
    "success": true,
    "data": {
      "batch_id": "UUID",
      "cost_unit": 3500.00,
      "sale_price": 4500.00,
      "updated_at": "2026-10-14T10:00:00Z"
    }
  }
  ```

### 5.2 Regla de Cero Cálculos en Frontend (Flujo Unidireccional - SDD-010-016 §2.3)
1. El Frontend NO calcula lotes ni determina de qué lote sale el stock.
2. El Servidor es la Autoridad Contable (FIFO con bloqueo pesimista en `consume_stock_fifo`).
3. El Frontend NO calcula márgenes: Todo reporte de ganancia bruta, valuación de inventario o margen de utilidad es computado y provisto directamente por las funciones financieras del servidor (`rpc_get_comprehensive_financial_report`).
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_actualizar_precio_lote`
- **Campos `p_batch_id`, `p_cost_unit`, `p_sale_price`:**
  - Código real: `BatchHistoryModal.vue:199` llama a `batchStore.updateBatchPrice(editingBatchId.value, editForm.value.cost_unit, editForm.value.sale_price)`. En `batches.ts:125-129`, se transmiten `p_batch_id`, `p_cost_unit` y `p_sale_price`.
  - Resultado: **Presente y Conforme**.

### B2.5 CHECKPOINT Bloque 2
La firma de la acción de actualización de lote es conforme con el esquema del RPC.

---

## Bloque 2b — Verificación de Backend Authority (Obligatorio)

- **B2.6 Búsqueda de Cálculos en Cliente:**
  - En `InventoryValuationCard.vue:10-32`:
    ```typescript
    const valuation = computed(() => {
      let totalCost = 0;
      let totalRetail = 0;

      inventoryStore.products.forEach(p => {
        const stock = p.stock.toNumber();
        const cost = p.cost ? p.cost.toNumber() : (p.price.toNumber() * 0.7); // Fallback assumption
        const price = p.price.toNumber();

        totalCost += stock * cost;
        totalRetail += stock * price;
      });

      const potentialProfit = totalRetail - totalCost;
      const margin = totalRetail > 0 ? (potentialProfit / totalRetail) * 100 : 0;

      return {
        cost: totalCost,
        retail: totalRetail,
        profit: potentialProfit,
        margin: margin
      };
    });
    ```
  - En `BatchHistoryModal.vue:173-175`:
    ```typescript
    const stockTotal = computed(() => {
      return batchStore.batches.reduce((sum, b) => sum + Number(b.quantity_remaining), 0);
    });
    ```
- **B2.7 CHECKPOINT Bloque 2b:**
  - Se detecta una **violación crítica de Backend Authority**: `InventoryValuationCard.vue` computa en cliente el costo total del inventario, valor de venta, utilidad potencial y margen, usando además una heurística no autorizada (`price * 0.7`) cuando `cost` es nulo, ignorando por completo la sumatoria de lotes FIFO (`SUM(quantity_remaining * cost_unit)`) de `inventory_batches`. Marcado como **Severidad ALTA**.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del Diagrama de Estados (SDD-010-016 §2.2)
1. `LoteCreado / Activo` (`quantity_remaining > 0`) -> Badge verde "Activo".
2. `LoteAgotado` (`quantity_remaining = 0`) -> Badge gris "Agotado".
3. `Cargando Lotes` -> Spinner reactivo.
4. `Sin Lotes` -> Mensaje descriptivo de lista vacía.
5. `Error al Guardar Edición` -> Notificación al usuario.

### B3.9 Búsqueda en Código
- **Estado 1 y 2:** `BatchHistoryModal.vue:89-96` renderiza badge dinámico 'Activo' o 'Agotado'. **Conforme**.
- **Estado 3:** `BatchHistoryModal.vue:20-23` (`v-if="batchStore.isLoading && !editingBatchId"`). **Conforme**.
- **Estado 4:** `BatchHistoryModal.vue:31-33` (`v-else-if="batchStore.batches.length === 0"`). **Conforme**.
- **Estado 5:** En `BatchHistoryModal.vue:203`: `alert(res.error || 'No se pudo actualizar el lote')`. Emplea un diálogo modal nativo del navegador en lugar de la librería de notificaciones/toasts.
  - Resultado: **Manejo de Error No Estándar (alert nativo)**.

### B3.10 Cruce Explícito
- Estado 1: Sí.
- Estado 2: Sí.
- Estado 3: Sí.
- Estado 4: Sí.
- Estado 5: Parcial (alerta nativa síncrona).

### B3.11 CHECKPOINT Bloque 3
Estados visuales manejados, con observación de usabilidad en el diálogo de error.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12 Formateo:**
  - `BatchHistoryModal.vue:65, 75`: `{{ formatCurrency(batch.cost_unit) }}`, `{{ formatCurrency(batch.sale_price) }}` usando `useCurrencyFormat`.
  - `InventoryValuationCard.vue:53, 59, 67`: `formatCurrency(...)` consumido desde `useCurrencyFormat`.
- **B4.13 CHECKPOINT Bloque 4:**
  - Conforme con `SPEC-011`.

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 Restricciones:**
  - Consulta y edición de lotes e historial de precios reservada a roles con `canViewInventory` o `canManageInventory`. Ceguera de costos estricta para cajeros en terminal POS.
- **B5.15 Implementación:**
  - El botón de apertura de `BatchHistoryModal.vue` en `InventoryView.vue:278` y la visualización de la tarjeta de valuación están restringidos al módulo administrativo.
- **B5.16 CHECKPOINT Bloque 5:**
  - Conforme con la protección de costos.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | Cálculo financiero de valuación de inventario, costo total, valor venta, ganancia potencial y margen comercial ejecutado en JavaScript en el cliente (`InventoryValuationCard.vue:10-32`) con fallback empírico (`price * 0.7`), violando el principio de Backend Authority y la valuación oficial FIFO (`SUM(quantity_remaining * cost_unit)` de `inventory_batches`). | Bloque 2b (B2.6) | 🔴 Alta |
| UX-2 | Reducción de existencias totales del producto calculada en el cliente sumando los remanentes de los lotes (`BatchHistoryModal.vue:173-175`). | Bloque 2b (B2.6) | 🟡 Media |
| UX-3 | Empleo de cuadro de diálogo nativo del navegador (`alert(...)`) en `BatchHistoryModal.vue:203` ante fallos de actualización de lote, en vez del sistema unificado de notificaciones toast. | Bloque 3 (B3.9) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:**
  - Al identificarse 1 hallazgo de severidad ALTA (UX-1: Valuación financiera en cliente), el frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. Conectar `InventoryValuationCard.vue` a una función/RPC del backend o reporte financiero consolidado (`rpc_get_comprehensive_financial_report`) que entregue los valores de valuación FIFO y margen real calculados en el servidor, eliminando el cálculo client-side con fallback `price * 0.7`.
2. Reemplazar el `alert()` nativo en `BatchHistoryModal.vue:203` por el composable centralizado `useNotifications` (`showError`).
