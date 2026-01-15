# Inventario (InventoryView)

## Descripción
Vista de gestión de productos que permite ver, buscar, agregar y editar productos del inventario. Protegida por permisos de usuario.

## Ruta
`/inventory`

## Flujo de Usuario

### Ver Productos
1. Usuario accede a la vista
2. Sistema verifica permiso `canViewInventory`
3. Si no tiene permiso → muestra `NoPermissionOverlay`
4. Ve lista de productos con scroll virtual (optimizado para grandes catálogos)
5. Puede buscar por nombre o PLU
6. Puede filtrar por categoría

### Agregar Producto
1. Click en FAB azul (+)
2. Se abre `ProductFormModal`
3. Llena los campos requeridos
4. Click "Guardar"
5. Producto se agrega al inventario

### Editar Producto
1. Click en tarjeta de producto
2. Se abre `ProductFormModal` con datos cargados
3. Modifica los campos deseados
4. Click "Guardar"

### Entrada de Inventario
1. Click en FAB verde (icono inventario)
2. Navega a `/stock-entry`
3. Flujo de entrada masiva de stock

---

## Datos de Entrada (Stores Consumidos)

### useInventoryStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `products` | `Product[]` | Lista de todos los productos |
| `lowStockProducts` | `Product[]` | Productos con stock bajo |

### useAuthStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `canViewInventory` | `boolean` | Permiso para ver inventario |

---

## Datos de Salida (Hacia Stores)

### useInventoryStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `initializeSampleData()` | - | Inicializa datos de muestra |
| `searchProducts()` | `query: string` | Busca productos por nombre/PLU |
| `addProduct()` | `Product` | Agrega nuevo producto |
| `updateProduct()` | `id, Partial<Product>` | Actualiza producto existente |
| `deleteProduct()` | `id` | Elimina producto (con confirmación) |

---

## Estructura de Producto

```typescript
interface Product {
  id: number;
  name: string;
  plu: string;
  brand?: string;
  price: Decimal;
  category: string;
  stock: Decimal;
  minStock: number;
  isWeighable: boolean;
  measurementUnit: 'kg' | 'lb' | 'g' | 'un';
}
```

---

## Navegación

### Desde
- Dashboard (botón "Productos")
- BottomNav

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Dashboard | Botón ← (goBack) | `/` |
| Entrada Stock | FAB verde | `/stock-entry` |

---

## Componentes Utilizados
- `ProductFormModal.vue` - Formulario de producto
- `BottomNav.vue` - Navegación inferior
- `RecycleScroller` - Virtual scrolling para listas largas
- `NoPermissionOverlay` - Overlay cuando usuario no tiene permiso

## Composables Utilizados
- `useCurrencyFormat` - Formateo de moneda (`formatCurrency`)

## Stores Utilizados
- `useInventoryStore`
- `useAuthStore`
