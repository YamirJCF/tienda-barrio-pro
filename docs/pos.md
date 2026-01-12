# POS - Punto de Venta (POSView)

## Descripción
Sistema de cobro que permite agregar productos al carrito y procesar ventas con diferentes métodos de pago.

## Ruta
`/pos`

## Flujo de Usuario

### Flujo Principal de Venta
1. Usuario ingresa código PLU en el numpad
2. Presiona "AGREGAR" para añadir producto al carrito
3. Repite para más productos
4. Presiona "COBRAR" para abrir modal de pago
5. Selecciona método de pago y completa la venta

### Flujo de Cantidad Múltiple
**Flujo A (Cantidad primero):**
1. Ingresa cantidad (ej: 3)
2. Presiona "CANT. ×"
3. Ingresa código PLU
4. Presiona "AGREGAR" → Agrega 3 unidades

**Flujo B (Producto primero):**
1. Ingresa código PLU
2. Presiona "CANT. ×"
3. Ingresa cantidad
4. Presiona "AGREGAR" → Agrega la cantidad especificada

### Flujo de Producto Pesable
1. Ingresa código PLU de producto pesable
2. Se abre automáticamente `WeightCalculatorModal`
3. Usuario selecciona modo (peso o valor)
4. Ingresa peso o valor monetario
5. Confirma → Producto se agrega al carrito

## Datos de Entrada (Interacción Usuario)

### Numpad
| Entrada | Tipo | Descripción |
|---------|------|-------------|
| `pluInput` | `string` | Código PLU del producto |
| `pendingQuantity` | `number` | Cantidad a agregar |

## Datos de Salida (Hacia Stores)

### cartStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addItem()` | `{id, name, price, quantity, unit}` | Agrega producto normal |
| `addWeighableItem()` | `{id, name, price, quantity, unit, subtotal}` | Agrega producto pesable |
| `removeItem(index)` | `number` | Elimina item del carrito |
| `clearCart()` | - | Vacía el carrito |

### salesStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addSale()` | `Sale` | Registra la venta completada |

### clientsStore (para fiado)
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addPurchaseDebt()` | `clientId, amount, description, saleId` | Registra deuda del cliente |

## Navegación

### Desde
- Dashboard (botón "Vender")
- BottomNav

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Dashboard | Botón ← | `/` |
| Búsqueda | Botón lupa | Modal |
| Checkout | Botón "COBRAR" | Modal |

## Componentes UI Utilizados
- `NoPermissionOverlay` - Overlay cuando usuario no tiene permiso de venta
- `NoPermissionOverlay` - Overlay cuando tienda está cerrada

## Composables Utilizados
- `useCurrencyFormat` - Formateo de moneda
- `useNotifications` - Notificaciones de venta

## Modales Utilizados
- `CheckoutModal.vue` - Proceso de pago
- `ProductSearchModal.vue` - Búsqueda de productos
- `QuickNoteModal.vue` - Notas rápidas (producto sin código)
- `WeightCalculatorModal.vue` - Calculadora de peso

## Stores Utilizados
- `useCartStore`
- `useInventoryStore`
- `useSalesStore`
- `useClientsStore`
- `useStoreStatusStore`
- `useAuthStore`

