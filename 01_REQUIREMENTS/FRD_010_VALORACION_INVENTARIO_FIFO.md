# Documento de Requisitos Funcionales (FRD)

## 010. Valoración de Inventario FIFO (Lotes)

### Descripción
Implementación de un sistema de **Valoración por Capas (FIFO - First In, First Out)** para el inventario.
El objetivo es mantener la trazabilidad exacta del costo de adquisición de cada lote de mercancía, asegurando que al vender, el sistema descuente primero las unidades más antiguas con su costo original, y luego las nuevas con su nuevo costo, evitando promedios que ocultan la realidad financiera.

### Problema Actual
El modelo actual (`Products` con un único campo `cost_price`) obliga a elegir entre:
1.  **Reemplazo**: El nuevo costo sobrescribe el anterior (Pérdida de valor histórico).
2.  **Promedio Ponderado**: Se calcula un costo medio (El usuario considera esto "malabares" contables).

### Solución Propuesta: Arquitectura de Lotes (Batches)

Se requiere una reestructuración del modelo de datos para soportar "Lotes de Inventario".

#### Nuevas Entidades

**1. Tabla: `inventory_batches` (Lotes)**
Almacena grupos de unidades adquiridas a un costo específico en una fecha específica.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | Identificador único del lote |
| `product_id` | UUID | Referencia al producto |
| `quantity_initial` | DECIMAL | Cantidad original adquirida |
| `quantity_remaining` | DECIMAL | Cantidad actual disponible en el lote |
| `cost_unit` | DECIMAL | Costo unitario real de ese lote |
| `created_at` | TIMESTAMPTZ | Fecha de adquisición (Indispensable para FIFO) |

#### Reglas de Negocio

1.  **Regla de Entrada (Compra/Ajuste Positivo)**:
    *   Toda entrada de inventario genera un **Nuevo Lote** en `inventory_batches`.
    *   No se modifica ningún "costo promedio" en el producto padre (este queda solo como referencia o precio de reposición).

2.  **Regla de Salida (Venta/Ajuste Negativo)**:
    *   El sistema debe buscar los lotes activos (`quantity_remaining > 0`) de ese producto.
    *   Ordenarlos por antigüedad (`created_at ASC`).
    *   Descontar la cantidad requerida del primer lote.
    *   Si el primer lote se agota, continuar con el siguiente (Consumo en cascada).

3.  **Valoración Financiera**:
    *   El "Valor Total del Inventario" es la suma de `(quantity_remaining * cost_unit)` de todos los lotes.

#### Impacto en el Sistema

| Componente | Modificación |
|---|---|
| **Base de Datos** | Creación de tabla `inventory_batches` y disparadores para consumo FIFO. |
| **Backend (Supabase)** | RPC `procesar_venta` debe volverse compleja: iterar sobre lotes para descontar stock. |
| **Frontend (UX)** | `StockEntryView` no necesita cambios visuales mayores, pero su lógica interna llamará al endpoint que crea lotes. |

### Riesgos y Consideraciones
*   **Complejidad**: La lógica de venta pasa de una resta simple (`stock - qty`) a un algoritmo recursivo o iterativo sobre múltiples filas.
*   **Performance**: Consultar saldo requiere sumar lotes. Se recomienda mantener `current_stock` en `products` como campo cacheado (denormalizado) para lectura rápida, pero que la verdad financiera resida en `inventory_batches`.

---

## Plan de Ejecución Inmediato

1.  [ ] Crear migración SQL para tabla `inventory_batches`.
2.  [ ] Migrar stock actual: Crear un "Lote Inicial" para cada producto existente con todo su stock actual y último costo conocido.
3.  [ ] Modificar RPC `procesar_venta` para implementar el algoritmo FIFO.
4.  [ ] Modificar Trigger de `inventory_movements` para que, en lugar de sumar/restar al producto, gestione los lotes.
