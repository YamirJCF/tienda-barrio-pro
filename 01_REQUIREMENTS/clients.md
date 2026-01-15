# Lista de Clientes (ClientListView)

## Descripción
Vista que muestra todos los clientes registrados con su saldo pendiente y permite gestionar la cartera de deudores.

## Ruta
`/clients`

## Flujo de Usuario

### Ver Clientes
1. Usuario accede a la vista
2. Ve lista de clientes con:
   - Iniciales/avatar
   - Nombre y cédula
   - Saldo pendiente (rojo si debe, verde si está al día)
3. Ve el total de deuda en el header

### Buscar Cliente
1. Escribe en el campo de búsqueda
2. Lista se filtra por nombre o cédula en tiempo real

### Agregar Cliente
1. Click en botón FAB (+)
2. Se abre `ClientFormModal`
3. Llena campos requeridos (nombre, cédula)
4. Click "Guardar Cliente"

### Ver Detalle de Cliente
1. Click en tarjeta de cliente
2. Navega a `/clients/:id`

## Datos de Entrada (Stores Consumidos)

### clientsStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `clients` | `Client[]` | Lista de todos los clientes |
| `totalDebt` | `Decimal` | Suma total de deudas |

## Datos de Salida (Hacia Stores)

### clientsStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addClient()` | `Client` | Agrega nuevo cliente |
| `searchClients()` | `query` | Busca clientes |

## Estructura de Cliente

```typescript
interface Client {
  id: number;
  name: string;
  cedula: string;
  phone?: string;
  creditLimit: Decimal;
  balance: Decimal;  // Positivo = debe dinero
  createdAt: string;
  updatedAt: string;
}
```

## Navegación

### Desde
- Dashboard (botón "Clientes")
- BottomNav

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Dashboard | Botón ← | `/` |
| Detalle Cliente | Click en cliente | `/clients/:id` |

## Componentes Utilizados
- `ClientFormModal.vue` - Formulario de cliente
- `BottomNav.vue` - Navegación inferior

## Stores Utilizados
- `useClientsStore`
