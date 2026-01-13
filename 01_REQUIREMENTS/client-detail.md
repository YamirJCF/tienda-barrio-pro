# Detalle de Cliente (ClientDetailView)

## Descripción
Vista que muestra información detallada de un cliente, su saldo, límite de crédito, historial de transacciones y permite registrar abonos.

## Ruta
`/clients/:id`

## Flujo de Usuario

### Ver Información
1. Usuario accede desde lista de clientes
2. Ve hero header con:
   - Nombre y cédula
   - Saldo pendiente (grande)
   - Barra de progreso de crédito usado
   - Crédito disponible

### Ver Historial
1. Scroll hacia abajo
2. Ve lista de movimientos:
   - Compras (rojo, aumentan deuda)
   - Pagos/Abonos (verde, reducen deuda)

### Registrar Abono
1. Click en botón "REGISTRAR ABONO"
2. Se abre modal de pago
3. Ingresa monto del abono
4. Click "Confirmar"
5. Se registra la transacción y actualiza el saldo

### Eliminar Cliente
1. Click en icono de 3 puntos (⋮)
2. Se despliega menú
3. Click "Eliminar cliente"
4. Confirma en modal
5. Cliente y transacciones eliminados

## Datos de Entrada (Route Params)

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `id` | `number` | ID del cliente a mostrar |

## Datos de Entrada (Stores Consumidos)

### clientsStore
| Método | Parámetros | Retorno |
|--------|------------|---------|
| `getClientById()` | `id` | `Client` |
| `getClientTransactions()` | `id` | `ClientTransaction[]` |
| `getAvailableCredit()` | `id` | `Decimal` |

## Datos de Salida (Hacia Stores)

### clientsStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `registerPayment()` | `clientId, amount, description` | Registra abono |
| `deleteClient()` | `id` | Elimina cliente y transacciones |

## Estructura de Transacción

```typescript
interface ClientTransaction {
  id: number;
  clientId: number;
  type: 'purchase' | 'payment';
  amount: Decimal;
  description: string;
  date: string;
  saleId?: number;
}
```

## Navegación

### Desde
- Lista de Clientes (click en cliente)

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Lista Clientes | Botón ← | `/clients` |

## Componentes Utilizados
- Modal de pago (inline)
- Modal de confirmación de eliminación (inline)
- Dropdown menú de opciones

## Stores Utilizados
- `useClientsStore`
