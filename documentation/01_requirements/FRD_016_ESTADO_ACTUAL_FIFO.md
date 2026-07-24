# Documento de Requisitos Funcionales (FRD)

## 016. Estado Actual del Sistema FIFO y Lógica de Precios

> **Fecha de Documentación:** Julio 2026
> **Propósito:** Dejar registro oficial de cómo funciona actualmente el sistema y cuáles son sus falencias arquitectónicas antes de la refactorización (Plan Maestro FIFO).

### 1. Proceso de Guardado de un Nuevo Producto

Cuando se crea un producto por primera vez en el sistema, el costo de compra se transfiere estáticamente al nuevo lote.

```mermaid
sequenceDiagram
    participant UI as Frontend (Vue)
    participant API as Supabase API
    participant DB_P as Tabla: products
    participant DB_M as Tabla: inventory_movements
    participant Trigger as Trigger: bridge_movement_to_batch
    participant DB_B as Tabla: inventory_batches

    UI->>API: POST /products (Datos del producto + Stock Inicial)
    API->>DB_P: INSERT INTO products (price, cost_price, etc)
    API->>DB_M: INSERT INTO inventory_movements (tipo: 'entrada', cantidad)
    Note over DB_M,Trigger: Se dispara automáticamente
    DB_M->>Trigger: AFTER INSERT
    Trigger->>DB_B: INSERT INTO inventory_batches (quantity_initial, cost_unit = products.cost_price)
    Note right of DB_B: El lote nace con el costo<br>estático del producto
    API-->>UI: Producto Creado Exitosamente
```

### 2. Proceso de Agregar Cantidades a un Producto (Nueva Compra)

Cuando llega mercancía nueva, el usuario solo ingresa el costo unitario de esa compra.

```mermaid
sequenceDiagram
    participant UI as Frontend (StockEntryView)
    participant API as Supabase API
    participant DB_M as Tabla: inventory_movements
    participant Trigger as Trigger: bridge_movement_to_batch
    participant DB_B as Tabla: inventory_batches

    UI->>API: POST inventory_movements (tipo: 'entrada', cantidad, reason)
    API->>DB_M: INSERT (tipo: 'entrada', qty: X)
    Note over DB_M,Trigger: Se dispara automáticamente
    DB_M->>Trigger: AFTER INSERT
    Trigger->>DB_B: INSERT INTO inventory_batches (quantity_initial, cost_unit = products.cost_price)
    Note right of DB_B: ⚠️ ALERTA: La base de datos asume<br>el costo estático del catálogo,<br>no guarda un precio de venta<br>específico para el lote.
```

### 3. Proceso de Venta (Consumo de múltiples lotes con costos distintos)

El motor actual maneja las cantidades FIFO correctamente, pero destruye la trazabilidad de los costos.

```mermaid
sequenceDiagram
    participant UI as Frontend (POS)
    participant RPC as rpc_procesar_venta_v2
    participant DB_S as Tabla: sale_items
    participant DB_M as Tabla: inventory_movements
    participant Trigger as Trigger: bridge_movement
    participant FIFO as rpc_consume_stock_fifo
    participant DB_B as Tabla: inventory_batches

    UI->>RPC: Ejecutar Venta (Producto, Qty: 3)
    RPC->>DB_S: INSERT sale_items (qty: 3, unit_price: products.price, unit_cost: 0)
    Note right of DB_S: ⚠️ ALERTA: La venta queda registrada<br>sin costo real (unit_cost = 0)
    RPC->>DB_M: INSERT inventory_movements (tipo: 'salida', qty: 3)
    DB_M->>Trigger: AFTER INSERT
    Trigger->>FIFO: Llama a consumir lotes
    FIFO->>DB_B: UPDATE Lote 1 (Descuenta 2)
    FIFO->>DB_B: UPDATE Lote 2 (Descuenta 1)
    Note right of FIFO: El FIFO funciona físicamente,<br>pero su información de costos<br>jamás se devuelve a la venta.
    RPC-->>UI: Venta Exitosa
```

### 4. Análisis del "Error Contable del Precio de Venta"

**Falla Estructural:** El precio de venta (`price`) es una columna global en la tabla `products`.

**¿Por qué genera un error contable?**
1. Un tendero compra un producto a $1000 y lo vende a $1500 (Lote 1).
2. Sube la inflación. El tendero compra más stock a $1200 (Lote 2) y actualiza el precio de venta global a $1700.
3. El POS automáticamente forzará a que el Lote 1 (viejo) se venda a $1700.
4. Contablemente, el margen del Lote 1 se infla artificialmente. El sistema anula la capacidad del tendero de aplicar una estrategia de precios respetando el stock original adquirido a menor costo.

**Conclusión:** Un sistema FIFO real en retail debe amarrar el "Precio de Compra" y el "Precio de Venta" directamente al lote (`inventory_batches`), de modo que el POS pueda despachar el producto respetando las políticas de precio de la partida física exacta que el cliente se está llevando.
