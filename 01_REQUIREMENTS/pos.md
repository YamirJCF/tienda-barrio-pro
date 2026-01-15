# POS - Punto de Venta (POSView)

## Descripción
Sistema de cobro que permite agregar productos al carrito y procesar ventas con diferentes métodos de pago. Incluye control de acceso por permisos y estado de la tienda.

## Ruta
`/pos`

---

## Guards de Acceso

La vista verifica dos condiciones antes de permitir ventas:

| Condición | Acción | Overlay |
|-----------|--------|---------|
| `!authStore.canSell` | Bloquea acceso | "No tienes permiso para realizar ventas" |
| `storeStatusStore.isClosed` | Bloquea acceso | "Tienda Cerrada - No se pueden realizar ventas" |

> [!IMPORTANT]
> Ambas condiciones muestran `NoPermissionOverlay` y solo permiten volver al Dashboard.

---

## Flujo de Usuario

### Flujo Principal de Venta
1. Usuario ingresa código PLU en el numpad
2. Presiona **"AGREGAR"** para añadir producto al carrito
3. Repite para más productos
4. Presiona **"COBRAR"** para abrir modal de pago
5. Selecciona método de pago y completa la venta

### Flujo de Cantidad Múltiple

**Flujo A (Cantidad primero):**
1. Ingresa cantidad (ej: 3)
2. Presiona **"CANT. ×"** → Badge ámbar "3×" aparece
3. Ingresa código PLU
4. Presiona **"AGREGAR"** → Agrega 3 unidades

**Flujo B (Producto primero):**
1. Ingresa código PLU
2. Presiona **"CANT. ×"** → Badge azul con PLU aparece
3. Ingresa cantidad
4. Presiona **"AGREGAR"** → Agrega la cantidad especificada

### Flujo de Producto Pesable
1. Ingresa código PLU de producto pesable
2. Se abre automáticamente `WeightCalculatorModal`
3. Usuario selecciona modo (peso o valor)
4. Ingresa peso o valor monetario
5. Confirma → Producto se agrega al carrito

---

## Datos de Entrada (Interacción Usuario)

### Estado del Numpad
| Estado | Tipo | Descripción |
|--------|------|-------------|
| `pluInput` | `string` | Código PLU o cantidad ingresada |
| `pendingQuantity` | `number` | Cantidad pendiente (Flujo A) |
| `pendingProduct` | `Product \| null` | Producto pendiente (Flujo B) |
| `isQuantityMode` | `boolean` | Indica Flujo A activo |
| `isProductMode` | `boolean` | Indica Flujo B activo |

---

## Datos de Salida (Hacia Stores)

### cartStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addItem()` | `{id, name, price, quantity}` | Agrega producto normal |
| `addWeighableItem()` | `{id, name, price, quantity, unit, subtotal}` | Agrega producto pesable |
| `removeItem()` | `id: number` | Elimina item del carrito |
| `clearCart()` | - | Vacía el carrito |

### inventoryStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `updateStock()` | `id, quantity` | Descuenta stock (cantidad negativa) |
| `getProductByPLU()` | `plu: string` | Busca producto por PLU |

### salesStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addSale()` | `Sale` | Registra la venta completada |

### clientsStore (para fiado)
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addPurchaseDebt()` | `clientId, amount, description, saleId` | Registra deuda del cliente |

---

## Proceso de Venta Completo

```typescript
completeSale(paymentMethod, amountReceived, clientId) {
    // 1. Prevenir doble-click
    if (isProcessing) return;
    isProcessing = true;

    // 2. Delay de procesamiento (600ms)
    await delay(600);

    // 3. Mapear items del carrito a formato de venta
    const saleItems = cartStore.items.map(...)

    // 4. Calcular vueltos si aplica
    const change = amountReceived?.minus(total);

    // 5. Registrar venta en salesStore
    salesStore.addSale({ items, total, paymentMethod, ... });

    // 6. Si es fiado, registrar deuda
    if (paymentMethod === 'fiado' && clientId) {
        clientsStore.addPurchaseDebt(clientId, total, `Compra ${ticket}`);
    }

    // 7. Limpiar carrito y cerrar modal
    cartStore.clearCart();
    showCheckout = false;

    // 8. Mostrar notificación
    if (navigator.onLine) {
        showSaleSuccess(ticket);
    } else {
        showSaleOffline(ticket);
    }
}
```

---

## Notificaciones

| Evento | Método | Mensaje |
|--------|--------|---------|
| Producto agregado | `showSuccess()` | "3x Arroz agregado" |
| Producto no encontrado | `showError()` | "Producto no encontrado: XXX" |
| Venta exitosa (online) | `showSaleSuccess()` | Ticket confirmado |
| Venta exitosa (offline) | `showSaleOffline()` | Ticket guardado offline |
| Error de venta | `showError()` | "Error al procesar la venta" |

---

## Navegación

### Desde
- Dashboard (botón "Vender")
- BottomNav

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Dashboard | Botón ← | `/` |
| Búsqueda | Botón "Buscar" | Modal |
| Checkout | Botón "COBRAR" | Modal |

---

## Componentes UI Utilizados
- `NoPermissionOverlay` - Bloqueo por permisos o tienda cerrada

## Composables Utilizados
- `useCurrencyFormat` - Formateo de moneda
- `useNotifications` - Notificaciones de feedback

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

---

## Estado de Procesamiento

| Estado | Comportamiento |
|--------|---------------|
| `isProcessing = false` | Botón COBRAR habilitado normalmente |
| `isProcessing = true` | Botón muestra "Procesando..." con spinner |

---

## Botones de Acción

| Botón | Grid Position | Función |
|-------|---------------|---------|
| Numpad 0-9, 00, . | 3x4 grid | Input de PLU/cantidad |
| CANT. × | Derecha sup. | Activa modo cantidad |
| ⌫ (backspace) | Derecha med. | Borra último dígito |
| AGREGAR | Derecha inf. (2 rows) | Añade producto al carrito |
| Buscar | Toolbar | Abre modal de búsqueda |
| Nota | Toolbar | Abre modal de nota rápida |
| COBRAR | Full width | Abre checkout modal |
