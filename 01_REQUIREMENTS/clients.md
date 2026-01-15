# Lista de Clientes (ClientListView)

## Descripción
Vista que muestra todos los clientes registrados con su saldo pendiente y permite gestionar la cartera de deudores.

## Ruta
`/clients`

## Flujo de Usuario

### Ver Clientes
1. Usuario accede a la vista
2. Ve lista de clientes con:
   - Iniciales/avatar (color generado por nombre)
   - Nombre y cédula formateada (ej: 1.020.304)
   - Saldo pendiente (rojo con borde si debe, verde si al día)
3. Ve el total de deuda en el header (badge rojo)

### Buscar Cliente
1. Escribe en el campo de búsqueda
2. Lista se filtra por nombre o cédula en tiempo real
3. Si no hay resultados, muestra estado vacío

### Agregar Cliente
1. Click en botón FAB (+)
2. Se abre `ClientFormModal`
3. Llena campos requeridos (nombre, cédula)
4. Click "Guardar Cliente"

### Ver Detalle de Cliente
1. Click en tarjeta de cliente
2. Navega a `/clients/:id`

---

## Datos de Entrada (Stores Consumidos)

### useClientsStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `clients` | `Client[]` | Lista de todos los clientes |
| `totalDebt` | `Decimal` | Suma total de deudas |

---

## Datos de Salida (Hacia Stores)

### useClientsStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `initializeSampleData()` | - | Inicializa datos de muestra |
| `searchClients()` | `query: string` | Busca por nombre o cédula |
| `addClient()` | `Client` | Agrega nuevo cliente |

---

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

---

## Navegación

### Desde
- Dashboard (botón "Clientes")
- BottomNav

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Dashboard | Botón ← (goToDashboard) | `/` |
| Detalle Cliente | Click en cliente | `/clients/:id` |

---

## Componentes Utilizados
- `ClientFormModal.vue` - Formulario de cliente
- `BottomNav.vue` - Navegación inferior

## Stores Utilizados
- `useClientsStore`
