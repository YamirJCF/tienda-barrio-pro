# Entrada de Stock (StockEntryView)

## Descripción
Vista para registrar la entrada de mercancía al inventario. Permite documentar compras a proveedores, actualizar existencias y mantener un registro de costos unitarios.

## Ruta
`/stock-entry`

---

## Flujo de Usuario

### Proceso de Entrada de Mercancía

1. Usuario accede desde Inventario → "Nueva Entrada"
2. Completa datos del **Proveedor** (opcional)
3. Ingresa **Referencia de Factura** (opcional)
4. Selecciona **Tipo de Pago** (Contado/Crédito)
5. **Busca productos** usando la barra de búsqueda inferior
6. Selecciona productos de los resultados → Se agregan a la lista
7. Para cada producto:
   - Ajusta **Cantidad** a recibir
   - Ajusta **Costo Unitario** si difiere del registrado
8. Revisa el **Total Factura** calculado
9. Click **"GUARDAR"**
10. Sistema actualiza stock de cada producto
11. Redirige a `/inventory`

---

## Formulario de Cabecera

| Campo | ID | Tipo | Placeholder | Requerido |
|-------|-----|------|-------------|-----------|
| Proveedor | `supplierName` | `text` | "Distribuidora Central" | No |
| Ref. Factura | `invoiceRef` | `text` | "FAC-2023-891" | No |
| Tipo de Pago | `paymentType` | `toggle` | - | Sí (default: Contado) |

### Tipos de Pago

| Valor | Label | Estilo |
|-------|-------|--------|
| `contado` | Contado | Gris seleccionado |
| `credito` | Crédito | Naranja seleccionado |

---

## Estructura de Item de Entrada

```typescript
interface EntryItem {
    productId: number;
    productName: string;
    quantity: string;      // Cantidad a ingresar
    unitCost: string;      // Costo unitario
    measurementUnit: string;
}
```

---

## Búsqueda de Productos

### Comportamiento
- Input de búsqueda en parte inferior fija
- Dropdown aparece automáticamente al escribir
- Búsqueda por nombre, marca, categoría o PLU
- Usa `inventoryStore.searchProducts(query)`

### Estados del Dropdown

| Condición | Contenido Mostrado |
|-----------|-------------------|
| Productos encontrados | Lista clickeable con stock actual |
| Sin resultados | Mensaje "No existe..." + Botón "Crear Nuevo" |
| Query vacío | Dropdown oculto |

### Selección de Producto
- Click en producto → Se agrega a `entryItems`
- Cantidad inicial: `1`
- Costo inicial: `product.cost` o `product.price`
- Si el producto ya está en la lista → Se ignora (no duplica)

---

## Edición de Items

Para cada producto agregado:

| Campo | Input | Validación |
|-------|-------|------------|
| Cantidad | `number`, step=1, min=0 | Acepta decimales |
| Costo Unitario | `number`, step=100, min=0 | Acepta decimales |

### Cálculo de Subtotal
```typescript
subtotal = quantity * unitCost
```

### Eliminación
- Botón 🗑️ (delete) en cada tarjeta de producto
- Elimina el item del array

---

## Totales Calculados

| Propiedad | Fórmula |
|-----------|---------|
| `totalItems` | `entryItems.length` |
| `totalInvoice` | Σ (quantity × unitCost) de cada item |

---

## Datos de Salida (Hacia Stores)

### useInventoryStore

| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `searchProducts()` | `query: string` | Busca productos por nombre/PLU/marca |
| `updateStock()` | `id: number, quantity: Decimal` | **SUMA** cantidad al stock existente |

### Lógica de `updateStock`
```typescript
// En inventory.ts
updateStock(id: number, quantity: Decimal) {
    product.stock = product.stock.plus(quantity);  // SUMA, no reemplaza
    product.updatedAt = new Date().toISOString();
}
```

> [!IMPORTANT]
> El método `updateStock` **SUMA** la cantidad al stock existente, no lo reemplaza.

---

## Proceso de Guardado

```typescript
saveEntry() {
    // Validación
    if (entryItems.length === 0) {
        alert('Agrega al menos un producto');
        return;
    }

    // Actualizar stock de cada item
    entryItems.forEach(item => {
        const qty = parseFloat(item.quantity);
        if (qty > 0) {
            inventoryStore.updateStock(item.productId, new Decimal(qty));
        }
    });

    // Feedback y navegación
    alert(`✅ Entrada guardada: ${totalItems} productos, $${total} total`);
    router.push('/inventory');
}
```

---

## Navegación

### Desde
| Origen | Acción | Ruta |
|--------|--------|------|
| Inventario | Botón "Nueva Entrada" | `/stock-entry` |

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Inventario | Botón ← | `/inventory` |
| Inventario | Después de Guardar | `/inventory` |

---

## Funcionalidades Adicionales

### Botón "Borrador"
- Visible solo si hay productos agregados
- Click → Confirmación → Limpia lista de productos, proveedor y factura

### Botón "Crear Nuevo" (Producto no encontrado)
- Aparece cuando búsqueda no tiene resultados
- Actualmente muestra `alert()` con mensaje "próximamente"
- Diseñado para abrir modal de creación de producto

---

## Estado Vacío

Si no hay productos agregados:
- Muestra icono de inventario
- Mensaje: "Busca productos abajo para agregarlos"

---

## Componentes UI

- Header con navegación y botón de ayuda
- Tarjeta de información del proveedor
- Toggle de tipo de pago (Contado/Crédito)
- Lista de tarjetas de productos con inputs editables
- Barra de búsqueda fija en parte inferior
- Footer con total de factura y botón GUARDAR

---

## Stores Utilizados
- `useInventoryStore`

---

## Limitaciones Actuales

> [!NOTE]
> La vista actual **NO** persiste:
> - Datos del proveedor
> - Referencia de factura
> - Historial de entradas
> 
> Solo actualiza el stock de los productos.
