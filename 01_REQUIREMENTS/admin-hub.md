# Hub de Administración (AdminHubView)

## Descripción
Centro de administración que agrupa funciones de gestión del negocio, reportes y configuración.

## Ruta
`/admin`

## Flujo de Usuario

### Navegación por Tabs
1. Usuario accede a la vista
2. Ve dos tabs:
   - **Gestión**: Funciones administrativas
   - **Reportes**: Estadísticas y análisis

### Tab Gestión
Muestra tarjetas de acceso rápido:
- **Control de Dinero**: Caja y gastos
- **Equipo y Tienda**: Empleados y configuración

### Tab Reportes
Muestra componente `ReportsContent`:
- Selector de período (Hoy/Semana/Mes)
- Resumen de ventas totales
- Desglose por método de pago
- Ranking de productos

## Secciones Disponibles

### Control de Dinero
| Opción | Descripción | Estado |
|--------|-------------|--------|
| Cerrar Caja / Arqueo | Control de caja | Placeholder |
| Nuevo Gasto | Registrar gastos | Placeholder |

### Equipo y Tienda
| Opción | Descripción | Ruta |
|--------|-------------|------|
| Empleados y Permisos | Gestión de empleados | `/employees` |
| Configuración del Negocio | Ajustes generales | Placeholder |
| Dispositivos Autorizados | Gestión de dispositivos | Placeholder |

## Datos de Entrada (Stores Consumidos)

### salesStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `openingCash` | `Decimal` | Base inicial de caja |
| `todayStats` | `DailyStats` | Estadísticas del día |

## Navegación

### Desde
- Dashboard (botón "Admin")
- BottomNav

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Dashboard | Botón ← | `/` |
| Empleados | Click "Empleados y Permisos" | `/employees` |

## Componentes Utilizados
- `ReportsContent.vue` - Contenido de reportes
- `BottomNav.vue` - Navegación inferior

## Stores Utilizados
- `useSalesStore`
- `useInventoryStore` (para reportes)
