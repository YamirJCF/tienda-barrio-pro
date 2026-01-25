# Dashboard (DashboardView)

## Descripción
Pantalla principal de la aplicación que muestra un resumen del negocio, controla el estado operativo de la tienda (abierta/cerrada), y proporciona accesos rápidos a las funciones principales.

## Ruta
`/` (raíz)

## Flujo de Usuario

### Flujo Principal
1. El usuario abre la aplicación
2. Ve el estado actual de la tienda (Abierto/Cerrado)
3. Si la tienda está cerrada:
   - Puede deslizar el toggle para abrir la tienda
   - Se abre el **Modal de Apertura de Jornada**
   - Ingresa el monto base de caja
   - Confirma la apertura
4. Ve el resumen de ventas del día en las tarjetas de estadísticas
5. Puede acceder rápidamente a:
   - **Vender**: Ir al POS (via BottomNav)
   - **Productos**: Ver inventario
   - **Clientes**: Ver lista de clientes (via BottomNav)
   - **Admin**: Acceder a administración (solo visible para admins)
   - **Notificaciones**: Ver centro de notificaciones (icono en header)

### Flujo de Cierre
1. Si la tienda está abierta, el usuario hace click en el toggle
2. Se redirige a `/cash-control` para hacer el arqueo de caja

### Onboarding (Nuevos Usuarios)
- Si la tienda está cerrada Y no hay productos registrados, se muestra un **Banner de Bienvenida**
- El banner guía al usuario a registrar su primer producto en el inventario

---

## Datos de Entrada (Stores Consumidos)

### useSalesStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `isStoreOpen` | `boolean` | Estado operativo de la tienda |
| `currentCash` | `Decimal` | Efectivo actual en caja |
| `todayTotal` | `Decimal` | Total de ventas del día |
| `todayCount` | `number` | Cantidad de ventas del día |
| `todayFiado` | `Decimal` | Total fiado del día |

### useInventoryStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `totalProducts` | `number` | Cantidad total de productos |
| `lowStockProducts` | `Product[]` | Productos con stock bajo |

### useAuthStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `isAdmin` | `boolean` | Si el usuario actual es administrador |
| `isEmployee` | `boolean` | Si el usuario actual es empleado |
| `currentUser` | `User \| null` | Datos del usuario actual |
| `currentStore` | `Store \| null` | Datos de la tienda actual |

---

## Datos de Salida

### Hacia salesStore
| Acción | Método | Descripción |
|--------|--------|-------------|
| Abrir tienda | `openStore(amount)` | Registra apertura con monto base |

---

## Navegación

### Desde
- Cualquier pantalla (BottomNav)
- Login exitoso

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| POS | Via BottomNav | `/pos` |
| Inventario | Click "Ir al Inventario" / BottomNav | `/inventory` |
| Clientes | Via BottomNav | `/clients` |
| Administración | Click "Gestionar Empleados" o "Configuración" | `/admin` |
| Notificaciones | Click icono campana | `/notifications` |
| Control de Caja | Toggle "Cerrar Tienda" | `/cash-control` |

---

## Funcionalidades Adicionales

### Toggle de Apertura/Cierre de Tienda
- **Componente**: Slider interactivo tipo toggle
- **Estado CERRADO**: Muestra "Desliza para ABRIR" con icono de flecha
- **Estado ABIERTO**: Muestra "ABIERTO" con icono de candado abierto
- **Color**: Verde cuando está abierto, gris oscuro cuando está cerrado
- **Barra indicadora**: Verde cuando abierto, gris cuando cerrado

### Modal de Apertura de Jornada
- **Trigger**: Click en toggle cuando la tienda está cerrada
- **Contenido**:
  - Icono de tienda
  - Título "Iniciar Jornada"
  - Campo numérico para "Base / Sencillo" (monto inicial en caja)
  - Botón "CONFIRMAR APERTURA"
- **Cierre**: Click en overlay o barra superior del modal

### Banner de Onboarding
- **Condición de aparición**: `!isStoreOpen && totalProducts === 0`
- **Contenido**:
  - Título: "¡Bienvenido! Tu tienda está lista."
  - Mensaje: "Paso 1: Agrega tu primer producto para empezar a vender."
  - Botón: "Ir al Inventario" → navega a `/inventory`

### Sección "Gestión de Tienda" (Admin Only)
- **Condición de aparición**: `isAdmin === true`
- **Opciones**:
  - "Gestionar Empleados" → `/admin`
  - "Configuración de Tienda" → `/admin`

---

## Componentes UI Utilizados
- `StatCard` - Tarjetas de estadísticas (Caja Real, Ventas Hoy, Por Cobrar, Inventario)
- `BottomNav` - Navegación inferior
- `UserProfileSidebar` - Sidebar de perfil de usuario

## Composables Utilizados
- `useCurrencyFormat` - Formateo de moneda (`formatWithSign`)

## Stores Utilizados
- `useSalesStore`
- `useInventoryStore`
- `useAuthStore`

---

## Tarjetas de Estadísticas (StatCards)

| Tarjeta | Icono | Color | Valor | Subtítulo |
|---------|-------|-------|-------|-----------|
| Caja Real | `payments` | Verde | `currentCash` | - |
| Ventas Hoy | `show_chart` | Azul | `todayTotal` | `{todayCount} ventas` |
| Por Cobrar | `person` | Naranja | `todayFiado` | - |
| Inventario | `inventory_2` | Púrpura | `{totalProducts} Prod.` | `{lowStockProducts.length} con stock bajo` (si > 0) |
