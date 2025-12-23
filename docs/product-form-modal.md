# Modal de Formulario de Producto (ProductFormModal)

## Descripción
Modal para crear o editar productos del inventario.

## Activación
- Desde `InventoryView` al presionar FAB (+) o click en producto

## Flujo de Usuario

### Crear Producto
1. Usuario abre modal (FAB)
2. Llena campos:
   - Nombre del producto
   - Código PLU
   - Precio
   - Categoría
   - Stock inicial
   - Stock mínimo (alerta)
3. Configura modo de venta (Unidad o Peso)
4. Si es por peso, selecciona unidad (kg/lb/g)
5. Click "Guardar"

### Editar Producto
1. Usuario abre modal (click en producto)
2. Campos precargados
3. Modifica campos deseados
4. Click "Guardar"

## Props de Entrada

| Prop | Tipo | Descripción |
|------|------|-------------|
| `modelValue` | `boolean` | Control de visibilidad |
| `product` | `Product?` | Producto a editar |

## Eventos de Salida

| Evento | Parámetros | Descripción |
|--------|------------|-------------|
| `update:modelValue` | `boolean` | Cierra modal |
| `saved` | `Product` | Producto guardado |

## Campos del Formulario

| Campo | Tipo | Validación | Requerido |
|-------|------|------------|-----------|
| `name` | `string` | No vacío | ✅ |
| `plu` | `string` | No vacío, único | ✅ |
| `price` | `number` | > 0 | ✅ |
| `category` | `string` | - | ✅ |
| `stock` | `number` | >= 0 | ✅ |
| `minStock` | `number` | >= 0 | ❌ |
| `isWeighable` | `boolean` | - | ❌ |
| `measurementUnit` | `string` | kg/lb/g/un | ❌ |

## Modo de Venta

| Modo | Descripción | Unidades Disponibles |
|------|-------------|---------------------|
| Unidad | Productos por pieza | `un` (fijo) |
| Valor/Peso | Productos pesables | `kg`, `lb`, `g` |

## Datos de Salida

### inventoryStore
| Método | Uso |
|--------|-----|
| `addProduct()` | Crear nuevo producto |
| `updateProduct()` | Actualizar existente |

## Estructura de Producto Guardado

```typescript
{
  id: number,
  name: string,
  plu: string,
  price: Decimal,
  category: string,
  stock: Decimal,
  minStock: number,
  isWeighable: boolean,
  measurementUnit: 'kg' | 'lb' | 'g' | 'un'
}
```

## UI/UX

- Toggle para modo de venta (Unidad/Peso)
- Selector de unidad aparece solo si es pesable
- Campo de precio con símbolo $ prefijado
- Preview de información antes de guardar
