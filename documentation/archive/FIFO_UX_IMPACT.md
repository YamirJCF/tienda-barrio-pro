# 🎨 Análisis de Impacto UX/UI: Implementación FIFO

## Diagnóstico Actual
El backend ha migrado a una arquitectura de **Lotes (Batches)**, pero el frontend sigue diseñado para un modelo de **Costo Promedio (Plano)**.

### Puntos de Fricción Identificados
1.  **Invisibilidad de Datos**: El usuario sabe que su inventario tiene "capas" de precios, pero la interfaz actual (`InventoryView.vue`) solo muestra un número total. Esto genera desconfianza ("¿Realmente está guardando mis costos viejos?").
2.  **Ambigüedad en Entrada**: En `StockEntryView.vue`, el campo "Costo Unit." parece sugerir que *ese* será el costo de todo el producto, lo cual ya no es cierto (solo es el costo de *esa* entrada).

---

## Estrategia de Integración ("Limpieza y Trazabilidad")

Para integrar la nueva información **sin producir errores** ni saturar la pantalla, proponemos una estrategia de **"Profundidad Progresiva"**.

### 1. Vista de Inventario (Cambios Menores)
No modificaremos la tabla principal drásticamente.
*   **KPI de Costo**: Si decidimos mostrar una columna "Costo", esta debe tener un indicador visual (ej. un icono `ℹ️`) que al pasar el mouse diga: *"Este valor es referencial (Último Costo). El sistema usa FIFO para cálculos de ganancia."*
*   **Acción de Auditoría**: Agregar un botón o opción en el menú de cada producto llamado **"Ver Lotes"**.

### 2. Nueva Vista: Detalles del Historial de Lotes (Nuevo Modal)
Necesitamos un componente `BatchHistoryModal.vue` que responda la pregunta: *"¿Cómo está compuesto mi stock de 20 unidades?"*.

**Diseño Propuesto:**
```
[ Modal: Historial de Lotes de "Manzana Roja" ]
------------------------------------------------
Stock Total: 20 un

| Fecha Adquisición | Cantidad | Costo Unit. | Estado  |
|-------------------|----------|-------------|---------|
| 28/01/2026 (Ayer)| 10 un    | $500        | Activo  | (Se venderá primero 🟢)
| 29/01/2026 (Hoy) | 10 un    | $800        | En cola | (Se venderá después ⚪)
------------------------------------------------
```
*   **Impacto**: Alto valor de confianza para el usuario contable.
*   **Riesgo**: Bajo. Es solo lectura.

### 3. Vista de Entrada de Stock (Feedback)
En `StockEntryView.vue`, al guardar:
*   **Antes**: "Producto actualizado".
*   **Ahora**: "Lote #1234 creado exitosamente".
*   Esta pequeña distinción semántica refuerza el modelo mental de FIFO.

---

## Instrucciones para Desarrollo

### Frontend
1.  **Crear Store**: `useBatchStore` para leer `inventory_batches`.
2.  **Crear Componente**: `BatchHistoryModal.vue`.
3.  **Integrar**: En `InventoryView.vue`, añadir botón en la columna de acciones para abrir este modal.

### Backend (Ya listo)
*   El backend ya expone la tabla `inventory_batches` vía RLS.
*   El frontend solo necesita hacer `supabase.from('inventory_batches').select('*').eq('product_id', id)`.

---

## Conclusión
La "limpieza" se logra **ocultando la complejidad** (FIFO es automático) pero **revelando la trazabilidad** bajo demanda (Modal de Lotes). No rompes la operación diaria del cajero, pero empoderas al auditor/dueño.
