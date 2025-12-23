# Dashboard (DashboardView)

## Descripción
Pantalla principal de la aplicación que muestra un resumen del negocio y proporciona accesos rápidos a las funciones principales.

## Ruta
`/` (raíz)

## Flujo de Usuario
1. El usuario abre la aplicación
2. Ve el resumen de ventas del día
3. Puede acceder rápidamente a:
   - **Vender**: Ir al POS
   - **Productos**: Ver inventario
   - **Clientes**: Ver lista de clientes
   - **Admin**: Acceder a administración

## Datos de Entrada (Stores Consumidos)

### salesStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `todayStats` | `DailyStats` | Estadísticas del día actual |
| `sales` | `Sale[]` | Ventas recientes |

### inventoryStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `lowStockProducts` | `Product[]` | Productos con stock bajo |

## Datos de Salida
Esta pantalla no envía datos, solo consume y muestra información.

## Navegación

### Desde
- Cualquier pantalla (BottomNav)

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| POS | Click "Vender" | `/pos` |
| Inventario | Click "Productos" | `/inventory` |
| Clientes | Click "Clientes" | `/clients` |
| Administración | Click "Admin" | `/admin` |

## Componentes Utilizados
- `BottomNav.vue` - Navegación inferior

## Stores Utilizados
- `useSalesStore`
- `useInventoryStore`
