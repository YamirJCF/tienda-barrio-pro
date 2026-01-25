# Detalle de Cliente (ClientDetailView)

## Descripción
Vista que muestra información detallada de un cliente, su saldo, límite de crédito, historial de transacciones y permite registrar abonos.

## Ruta
`/clients/:id`

## Flujo de Usuario

### Ver Información
1. Usuario accede desde lista de clientes
2. Ve hero header con:
   - Nombre y cédula formateada
   - Saldo pendiente (grande, centrado)
   - Barra de progreso de crédito usado (`creditUsagePercent`)
   - Crédito disponible (`availableCredit`)

### Ver Historial
1. Scroll hacia abajo sección "Movimientos Recientes"
2. Ve lista de movimientos:
   - Compras (rojo, icono carrito, aumentan deuda)
   - Pagos/Abonos (verde, icono pagos, reducen deuda)
3. Cada movimiento muestra fecha formateada y monto

### Registrar Abono
1. Click en botón sticky "REGISTRAR ABONO"
2. Se abre modal de pago (Teleport)
3. Ingresa monto del abono
4. Click "Confirmar"
5. Se registra la transacción y actualiza el saldo

### Eliminar Cliente
1. Click en icono de 3 puntos (⋮) en header
2. Se despliega dropdown menú
3. Click "Eliminar cliente"
4. Confirma en modal de confirmación
5. Cliente y transacciones eliminados
6. Redirige a `/clients`

---

## Datos de Entrada (Route Params)

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `id` | `number` | ID del cliente a mostrar |

---

## Datos de Entrada (Stores Consumidos)

### useClientsStore
| Método | Parámetros | Retorno |
|--------|------------|---------|
| `getClientById()` | `id` | `Client` |
| `getClientTransactions()` | `id` | `ClientTransaction[]` |
| `getAvailableCredit()` | `id` | `Decimal` |
| `initializeSampleData()` | - | void |

---

## Datos de Salida (Hacia Stores)

### useClientsStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `registerPayment()` | `clientId, amount, description` | Registra abono |
| `deleteClient()` | `id` | Elimina cliente y transacciones |

---

## Computed Properties

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `creditUsagePercent` | `number` | Porcentaje de crédito usado (0-100) |
| `availableCredit` | `Decimal` | Crédito disponible |

---

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

---

## Navegación

### Desde
- Lista de Clientes (click en cliente)

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Lista Clientes | Botón ← (goBack) | `/clients` |

---

## Modales Inline
- **Modal de Abono**: Campo numérico + botones Cancelar/Confirmar
- **Modal de Eliminación**: Confirmación con advertencia y botones Cancelar/Eliminar
- **Dropdown Menú**: Opciones contextuales (eliminar)

## Stores Utilizados
- `useClientsStore`
