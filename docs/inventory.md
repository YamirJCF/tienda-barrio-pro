# Inventario (InventoryView)

## Descripción
Vista de gestión de productos que permite ver, buscar, agregar y editar productos del inventario.

## Ruta
`/inventory`

## Flujo de Usuario

### Ver Productos
1. Usuario accede a la vista
2. Ve lista de productos con scroll virtual (optimizado para grandes catálogos)
3. Puede buscar por nombre o PLU
4. Puede filtrar por categoría

### Agregar Producto
1. Click en botón FAB (+)
2. Se abre `ProductFormModal`
3. Llena los campos requeridos
4. Click "Guardar"
5. Producto se agrega al inventario

### Editar Producto
1. Click en tarjeta de producto
2. Se abre `ProductFormModal` con datos cargados
3. Modifica los campos deseados
4. Click "Guardar"

## Datos de Entrada (Stores Consumidos)

### inventoryStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `products` | `Product[]` | Lista de todos los productos |
| `lowStockProducts` | `Product[]` | Productos con stock bajo |

## Datos de Salida (Hacia Stores)

### inventoryStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addProduct()` | `Product` | Agrega nuevo producto |
| `updateProduct()` | `id, Partial<Product>` | Actualiza producto existente |
| `deleteProduct()` | `id` | Elimina producto |

## Estructura de Producto

```typescript
interface Product {
  id: number;
  name: string;
  plu: string;
  price: Decimal;
  category: string;
  stock: Decimal;
  minStock: number;
  isWeighable: boolean;
  measurementUnit: 'kg' | 'lb' | 'g' | 'un';
}
```

## Navegación

### Desde
- Dashboard (botón "Productos")
- BottomNav

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Dashboard | Botón ← | `/` |

## Componentes Utilizados
- `ProductFormModal.vue` - Formulario de producto
- `BottomNav.vue` - Navegación inferior
- `RecycleScroller` - Virtual scrolling

## Stores Utilizados
- `useInventoryStore`
