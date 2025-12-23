# Modal de Checkout (CheckoutModal)

## Descripción
Modal de proceso de pago que aparece al finalizar una venta. Permite seleccionar método de pago y completar la transacción.

## Activación
Se abre desde `POSView` al presionar botón "COBRAR"

## Flujo de Usuario

### Pago en Efectivo
1. Tab "Efectivo" activo por defecto
2. Ingresa monto recibido en numpad
3. Sistema calcula vueltos automáticamente
4. Click "CONFIRMAR" → Venta registrada

### Pago con Nequi/Daviplata
1. Click en tab "Nequi"
2. Opcional: Ingresa referencia (4 dígitos)
3. Click "CONFIRMAR" → Venta registrada

### Venta Fiada
1. Click en tab "Fiado"
2. Buscar cliente por nombre/cédula
3. Click en cliente para seleccionar
4. Ve crédito disponible y advertencia si excede límite
5. Click "CONFIRMAR" → Venta y deuda registradas

## Props de Entrada

| Prop | Tipo | Descripción |
|------|------|-------------|
| `modelValue` | `boolean` | Control de visibilidad |

## Eventos de Salida

| Evento | Parámetros | Descripción |
|--------|------------|-------------|
| `update:modelValue` | `boolean` | Cierra modal |
| `complete` | `paymentMethod, amountReceived?, clientId?` | Venta completada |

## Datos Internos

| Estado | Tipo | Descripción |
|--------|------|-------------|
| `activeMethod` | `'cash' \| 'nequi' \| 'fiado'` | Método de pago activo |
| `amountReceived` | `string` | Monto recibido (efectivo) |
| `nequiReference` | `string` | Referencia de Nequi |
| `selectedClient` | `Client \| null` | Cliente para fiado |
| `clientSearch` | `string` | Búsqueda de cliente |

## Validaciones

### Efectivo
- Monto recibido debe ser >= total
- Vueltos calculados automáticamente

### Fiado
- Debe seleccionar un cliente
- Muestra advertencia si excede crédito (pero permite continuar)

## Stores Consumidos

### cartStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `total` | `Decimal` | Total del carrito |
| `formattedTotal` | `string` | Total formateado |

### clientsStore
| Método | Descripción |
|--------|-------------|
| `searchClients()` | Buscar clientes |
| `getAvailableCredit()` | Crédito disponible |

## UI por Método de Pago

### Efectivo
- Numpad para ingresar monto
- Display de monto recibido
- Cálculo de vueltos (verde si positivo, rojo si negativo)
- Botón "Usar monto exacto"

### Nequi
- Ícono grande de QR
- Instrucciones de pago
- Campo opcional de referencia

### Fiado
- Campo de búsqueda de cliente
- Lista scrollable de clientes
- Card de cliente seleccionado con:
  - Nombre y cédula
  - Crédito disponible
  - Advertencia si excede límite
