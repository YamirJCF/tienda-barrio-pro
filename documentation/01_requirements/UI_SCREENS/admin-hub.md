# Hub de Administración (AdminHubView)

## Descripción
Centro de administración que agrupa funciones de gestión del negocio, reportes y configuración. Permite controlar el estado operativo de la tienda y acceder a todas las herramientas administrativas.

## Ruta
`/admin`

## Flujo de Usuario

### Navegación por Tabs
1. Usuario accede a la vista
2. Ve dos tabs:
   - **Gestión**: Funciones administrativas (tab por defecto)
   - **Reportes**: Estadísticas y análisis

### Tab Gestión
Muestra secciones organizadas:

#### Sección "Control de Dinero"
| Tarjeta | Estado | Acción |
|---------|--------|--------|
| Caja Abierta/Cerrada | Muestra `isStoreOpen` y `openingCash` | Navega a `/cash-control` |
| Gastos del Día | Acceso a registro de gastos | Navega a `/expenses` |

#### Sección "Equipo y Tienda"
| Opción | Descripción | Ruta |
|--------|-------------|------|
| Empleados y Permisos | Gestión de empleados | `/employees` |
| Configuración del Negocio | Horarios e info general | Placeholder |
| Dispositivos Autorizados | Seguridad de la cuenta | Placeholder |
| Historial de Ventas | Ver transacciones pasadas | Placeholder |

#### Sección "Cerrar Tienda"
- Toggle para estado operativo (diferente de caja)
- Usa `storeStatusStore.isClosed` y `toggleStatus()`
- Permite marcar tienda como "fuera de servicio" temporalmente

### Tab Reportes
Muestra componente `ReportsContent`:
- Selector de período (Hoy/Semana/Mes)
- Resumen de ventas totales
- Desglose por método de pago
- Ranking de productos

---

## Datos de Entrada (Stores Consumidos)

### useSalesStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `isStoreOpen` | `boolean` | Estado de la caja (abierta/cerrada) |
| `openingCash` | `Decimal` | Base inicial de caja |

### useStoreStatusStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `isClosed` | `boolean` | Estado operativo de la tienda |

---

## Datos de Salida

### Hacia storeStatusStore
| Acción | Método | Descripción |
|--------|--------|-------------|
| Toggle estado | `toggleStatus()` | Cambia estado operativo |

---

## Navegación

### Desde
- Dashboard (botón "Admin")
- BottomNav

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Dashboard | Botón ← (goBack) | `/` |
| Control de Caja | Click "Ver Control de Caja" | `/cash-control` |
| Gastos | Click "Ver Gastos" | `/expenses` |
| Empleados | Click "Empleados y Permisos" | `/employees` |

---

## Componentes Utilizados
- `ReportsContent.vue` - Contenido de reportes
- `BottomNav.vue` - Navegación inferior

## Stores Utilizados
- `useSalesStore`
- `useStoreStatusStore`
