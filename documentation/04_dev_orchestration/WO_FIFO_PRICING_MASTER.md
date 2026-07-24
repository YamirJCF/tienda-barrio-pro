# Órdenes de Trabajo: Arquitectura FIFO y Precios (Plan Maestro)

A continuación, se desglosa el plan maestro en 4 Órdenes de Trabajo (WO) atómicas. Cada orden está diseñada para ser ejecutada en menos de 20 minutos por el agente Antigravity correspondiente, utilizando las Skills recomendadas.

---

## Orden de Trabajo 1 (WO-FIFO-001) - Backend: Estructura de Datos y RLS

**Skills recomendadas:** `database-architect`, `supabase-admin`

### Estado Git Actual
- Rama a crear: `feat/fifo-db-schema`
- Comando: `git checkout -b feat/fifo-db-schema`

### Plan de Acción Atómico
1. Crear el archivo de migración SQL para la tabla `product_price_history`.
2. Crear el archivo de migración SQL para la tabla `sale_item_batches`.
3. Crear el archivo de migración SQL para añadir la columna `sale_price (DECIMAL 12,2)` a `inventory_batches`.
4. Añadir políticas RLS estrictas (Cierre de `inventory_movements` para INSERTs directos de API).

### Bloque de Prompt para Antigravity
```markdown
## Prompt para Antigravity

### Contexto
Estás actuando como `supabase-admin`. Lee el plan maestro en la carpeta artifacts y el FRD_016. Debes modificar la base de datos de Supabase.

### Objetivo
1. Crea una migración SQL que genere la tabla `product_price_history` (id, product_id, purchase_price, sale_price, created_at, created_by).
2. Crea una migración para generar `sale_item_batches` (id, sale_item_id, batch_id, quantity_consumed, unit_cost, unit_price).
3. Crea una migración para hacer un ALTER TABLE a `inventory_batches` y añadir `sale_price DECIMAL(12,2)`.
4. Aplica RLS estricto a estas nuevas tablas y revoca permisos de INSERT directo en `inventory_movements` para el rol anónimo/autenticado.

### Restricciones
No alteres datos existentes. Usa `IF NOT EXISTS`. No elimines tablas previas.

### Definición de Hecho (DoD)
Los archivos SQL de migración existen en `supabase/migrations/` y pasan la validación de sintaxis.
```

---

## Orden de Trabajo 2 (WO-FIFO-002) - Backend: RPCs y Motor de Ventas

**Skills recomendadas:** `supabase-admin`, `backend-architect`

### Estado Git Actual
- Rama a crear: `feat/fifo-rpcs`
- Comando: `git checkout -b feat/fifo-rpcs`

### Plan de Acción Atómico
1. Desarrollar `rpc_registrar_entrada` que inserte en movimientos y asigne `sale_price` al lote.
2. Desarrollar `rpc_actualizar_precio_lote` para modificar el `sale_price` de un lote específico.
3. Actualizar `rpc_procesar_venta_v2` para iterar sobre `inventory_batches`, consumir stock por FIFO, calcular el subtotal usando el `sale_price` de cada lote y registrar en `sale_item_batches`.

### Bloque de Prompt para Antigravity
```markdown
## Prompt para Antigravity

### Contexto
Activa tu skill `supabase-admin`. Debes escribir la lógica de negocio en la base de datos (RPCs).

### Objetivo
Crea o actualiza las migraciones SQL para:
1. `rpc_registrar_entrada(p_product_id, p_qty, p_purchase_price, p_sale_price, p_user_id)`: inserta movimiento y crea el lote con ambos precios.
2. `rpc_actualizar_precio_lote(p_batch_id, p_new_sale_price)`: actualiza el lote y guarda el log en `product_price_history`.
3. Modificar `rpc_procesar_venta_v2`: Cuando descuenta unidades de un producto, debe leer los lotes por FIFO. Si vende 3 unidades y toma 2 del Lote A ($15) y 1 del Lote B ($20), el subtotal debe ser $50. Debe insertar este desglose en `sale_item_batches`.

### Restricciones
Mantén la atomicidad de las transacciones SQL.

### Definición de Hecho (DoD)
RPCs creados y listos para ser invocados desde el frontend.
```

---

## Orden de Trabajo 3 (WO-FIFO-003) - Frontend: Inventario y Edición de Lotes

**Skills recomendadas:** `frontend-architecture`, `vue3` (o `frontend-design`)

### Estado Git Actual
- Rama a crear: `feat/fifo-inventory-ui`
- Comando: `git checkout -b feat/fifo-inventory-ui`

### Plan de Acción Atómico
1. Modificar `ProductFormModal.vue` para reemplazar el input único de precio por una tabla de "Lotes Activos".
2. Modificar `StockEntryView.vue` para incluir campos de "Precio de Compra" y "Precio de Venta" en las Entradas.
3. Actualizar `productRepository.ts` para consumir `rpc_registrar_entrada` y `rpc_actualizar_precio_lote`.

### Bloque de Prompt para Antigravity
```markdown
## Prompt para Antigravity

### Contexto
Activa `frontend-architecture`. Revisa `ProductFormModal.vue`, `StockEntryView.vue` y `productRepository.ts`.

### Objetivo
1. En `StockEntryView.vue`, cuando el tipo de movimiento sea 'entrada', pide `purchase_price` y `sale_price`. Usa `rpc_registrar_entrada`.
2. En `ProductFormModal.vue`, añade una sección de "Lotes Activos" leyendo de la base de datos, mostrando stock restante y permitiendo editar su `sale_price` vía `rpc_actualizar_precio_lote`.

### Restricciones
Mantén el diseño UX actual. No uses Tailwind si el proyecto usa CSS puro (respeta el stack).

### Definición de Hecho (DoD)
Los componentes compilan sin errores de TypeScript y la UI refleja la gestión por lotes.
```

---

## Orden de Trabajo 4 (WO-FIFO-004) - Frontend: POS e Inteligencia de Precios

**Skills recomendadas:** `frontend-architecture`, `clean-code-guard`

### Estado Git Actual
- Rama a crear: `feat/fifo-pos-cart`
- Comando: `git checkout -b feat/fifo-pos-cart`

### Plan de Acción Atómico
1. Refactorizar `cart.ts` para leer los lotes activos (`inventoryStore.batches`).
2. Modificar `addItem` para dividir el producto en múltiples `CartItem` si cruza el límite de un lote físico.
3. Implementar el `Toast.warning` si hay división de lote/cambio de precio.
4. Actualizar `POSView.vue` para mostrar `(Lote Actual)` en el precio del botón.

### Bloque de Prompt para Antigravity
```markdown
## Prompt para Antigravity

### Contexto
Activa `frontend-architecture`. Revisa `stores/cart.ts` y `POSView.vue`.

### Objetivo
1. En `cart.ts`, `addItem` ya no debe usar el precio global. Debe consultar los lotes del producto (vía store de inventario). Si añado 3 unidades y hay 2 en Lote A y 1 en Lote B, añade DOS elementos al carrito: uno con el precio de A (qty 2) y otro con precio de B (qty 1).
2. Si se divide, dispara una notificación Toast naranja alertando al vendedor.
3. En `POSView.vue`, el precio en el botón del producto debe ser el precio del lote más antiguo disponible.

### Restricciones
No rompas la validación de decimales existente en el carrito.

### Definición de Hecho (DoD)
El carrito se separa automáticamente al cruzar lotes y el total se calcula perfectamente basándose en el precio específico de cada lote físico.
```
