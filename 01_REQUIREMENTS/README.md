# Documentación de Pantallas - Tienda de Barrio

Este directorio contiene la documentación técnica de cada pantalla de la aplicación.

## Arquitectura
| Documento | Descripción |
|-----------|-------------|
| [Arquitectura](./architecture.md) | Estructura del proyecto, componentes UI, composables |
| [Supabase](./architecture-supabase.md) | Plan de migración a Supabase |

## Índice de Pantallas

### Vistas Principales
| Pantalla | Archivo | Descripción |
|----------|---------|-------------|
| Dashboard | [dashboard.md](./dashboard.md) | Pantalla principal con accesos rápidos |
| POS (Punto de Venta) | [pos.md](./pos.md) | Sistema de cobro y ventas |
| Inventario | [inventory.md](./inventory.md) | Gestión de productos |
| Clientes | [clients.md](./clients.md) | Lista y gestión de clientes |
| Detalle Cliente | [client-detail.md](./client-detail.md) | Información y transacciones del cliente |
| Empleados | [employees.md](./employees.md) | Gestión de empleados |
| Administración | [admin-hub.md](./admin-hub.md) | Hub de administración y reportes |
| Login | [login.md](./login.md) | Autenticación de usuarios |

### Componentes Modales
| Modal | Archivo | Descripción |
|-------|---------|-------------|
| Checkout | [checkout-modal.md](./checkout-modal.md) | Modal de cobro con métodos de pago |
| Formulario Cliente | [client-form-modal.md](./client-form-modal.md) | Crear/editar cliente |
| Formulario Empleado | [employee-form-modal.md](./employee-form-modal.md) | Crear/editar empleado |
| Formulario Producto | [product-form-modal.md](./product-form-modal.md) | Crear/editar producto |

## Estructura de Documentación

Cada archivo incluye:
- **Descripción**: Propósito de la pantalla
- **Flujo de Usuario**: Pasos que sigue el usuario
- **Datos de Entrada**: Qué datos envía la pantalla
- **Datos de Salida**: Qué datos espera recibir
- **Stores Utilizados**: Qué stores de Pinia consume
- **Navegación**: Desde/hacia dónde se puede navegar

