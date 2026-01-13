# Modal de Checkout (CheckoutModal)

## Descripción
Modal de proceso de pago que aparece al finalizar una venta. Permite seleccionar método de pago (Efectivo, Nequi, Fiado) y completar la transacción.

## Activación
Se abre desde `POSView` al presionar botón **"COBRAR"** cuando el carrito tiene items.

---

## Flujo de Usuario

### Pago en Efectivo
1. Tab **"Efectivo"** activo por defecto
2. Ingresa monto recibido usando numpad (incluye tecla 000)
3. Sistema calcula vueltos automáticamente
4. Si monto < total → Muestra "Falta" en rojo
5. Si monto >= total → Muestra "Vueltos a dar" en verde
6. Click **"CONFIRMAR"** → Venta registrada

### Pago con Nequi/Daviplata
1. Click en tab **"Nequi"**
2. Muestra instrucciones con ícono de QR
3. Opcional: Ingresa referencia (últimos 4 dígitos)
4. Click **"CONFIRMAR"** → Venta registrada

### Venta Fiada
1. Click en tab **"Fiado"**
2. Buscar cliente por nombre/cédula
3. Click en cliente para seleccionar
4. Ve tarjeta con:
   - Nombre y cédula del cliente
   - Crédito disponible
   - Advertencia si excede límite (pero permite continuar)
5. Click **"CONFIRMAR"** → Venta y deuda registradas

---

## Props de Entrada

| Prop | Tipo | Descripción |
|------|------|-------------|
| `modelValue` | `boolean` | Control de visibilidad (v-model) |

## Eventos de Salida

| Evento | Parámetros | Descripción |
|--------|------------|-------------|
| `update:modelValue` | `boolean` | Cierra modal |
| `complete` | `paymentMethod: string, amountReceived?: Decimal, clientId?: number` | Venta completada |

---

## Métodos de Pago

| Método | Valor | Icono | Color |
|--------|-------|-------|-------|
| Efectivo | `cash` | `payments` | Verde esmeralda |
| Nequi | `nequi` | `smartphone` | Rosa |
| Fiado | `fiado` | `menu_book` | Ámbar |

---

## Estado Interno

| Estado | Tipo | Descripción |
|--------|------|-------------|
| `activeMethod` | `'cash' \| 'nequi' \| 'fiado'` | Método de pago activo |
| `amountReceived` | `string` | Monto recibido (efectivo) |
| `nequiReference` | `string` | Referencia Nequi (opcional) |
| `selectedClient` | `Client \| null` | Cliente seleccionado para fiado |
| `clientSearch` | `string` | Query de búsqueda de cliente |

---

## Validaciones de Completar Venta

| Método | Condición para `canComplete` |
|--------|------------------------------|
| Efectivo | `amountReceived` ingresado Y `change >= 0` |
| Nequi | Siempre habilitado |
| Fiado | `selectedClient !== null` |

---

## Cálculos Automáticos

### Vueltos (Efectivo)
```typescript
change = amountReceived - total
```

| Condición | Indicador |
|-----------|-----------|
| `change >= 0` | Verde: "Vueltos a dar: $X" |
| `change < 0` | Rojo: "Falta: $X" |

### Crédito Disponible (Fiado)
```typescript
availableCredit = clientsStore.getAvailableCredit(client.id)
hasEnoughCredit = availableCredit >= total
```

---

## Stores Consumidos

### cartStore
| Campo/Método | Tipo | Descripción |
|--------------|------|-------------|
| `total` | `Decimal` | Total del carrito |
| `formattedTotal` | `string` | Total formateado |

### clientsStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `initializeSampleData()` | - | Carga datos de ejemplo |
| `searchClients()` | `query: string` | Buscar clientes |
| `getAvailableCredit()` | `clientId: number` | Crédito disponible |

---

## UI por Método de Pago

### Efectivo
- **Columna izquierda** (5/12):
  - Display de "Dinero Recibido" con cursor parpadeante
  - Feedback de vueltos/falta con colores
  - Botón "Usar monto exacto"
- **Columna derecha** (7/12):
  - Numpad 3x4 (1-9, 000, 0, backspace)

### Nequi
- Ícono grande de QR centrado
- Texto: "Solicita al cliente el pago exacto de $X"
- Input opcional de referencia (4 dígitos)

### Fiado
- **Sin cliente seleccionado**:
  - Campo de búsqueda con ícono
  - Lista scrollable de clientes con:
    - Avatar (iniciales)
    - Nombre y cédula
    - Balance actual (verde al día, rojo si debe)
- **Con cliente seleccionado**:
  - Tarjeta con datos del cliente
  - Crédito disponible
  - Botón para limpiar selección
  - Advertencia si excede límite

---

## Reset al Completar

Al llamar `completeSale()`:
```typescript
amountReceived = '';
nequiReference = '';
selectedClient = null;
clientSearch = '';
activeMethod = 'cash';
close();
```

---

## Diseño del Modal

| Elemento | Descripción |
|----------|-------------|
| Altura | 85vh móvil, 75vh desktop, max 800px |
| Barra superior | Drag handle clickeable para cerrar |
| Header | Total a pagar con formato grande |
| Tabs | Grid 3 columnas con indicador de activo |
| Body | Contenido dinámico según método |
| Footer | Botón CONFIRMAR con color según método |

---

## Animaciones

| Elemento | Animación |
|----------|-----------|
| Modal entrada | `opacity` + `slideUp` |
| Modal salida | `opacity` + `slideDown` |
| Tabs | Indicador inferior animado |
