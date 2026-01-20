# 05 - Lógica de Componentes

> **Propósito:** Definir cómo deben comportarse los componentes interactivos ante diferentes acciones y estados.

---

## 🔢 Numpad (POS)

### Estructura

```
┌─────┬─────┬─────┐ ┌─────────┐
│  1  │  2  │  3  │ │ CANT. × │
├─────┼─────┼─────┤ ├─────────┤
│  4  │  5  │  6  │ │    ⌫    │
├─────┼─────┼─────┤ ├─────────┤
│  7  │  8  │  9  │ │         │
├─────┼─────┼─────┤ │ AGREGAR │
│  00 │  0  │  .  │ │         │
└─────┴─────┴─────┘ └─────────┘
```

### Lógica de Interacción

| Acción | Estado Inicial | Resultado | Display |
|--------|----------------|-----------|---------|
| Click dígito | `pluInput: ""` | Concatenar dígito | "1234" |
| Click `⌫` | `pluInput: "123"` | Eliminar último | "12" |
| Click `CANT. ×` (sin input) | `pluInput: ""` | Nada | - |
| Click `CANT. ×` (con número) | `pluInput: "3"` | `pendingQuantity: 3` | Badge "3×" |
| Click `CANT. ×` (con PLU activo) | `pluInput: "1234"` | `pendingProduct: producto` | Badge con nombre |
| Click `AGREGAR` (sin input) | `pluInput: ""` | Error toast | "Ingresa un código" |
| Click `AGREGAR` (PLU no existe) | `pluInput: "9999"` | Error toast | "No encontrado: 9999" |
| Click `AGREGAR` (OK) | `pluInput: "1234"` | Agregar al carrito | Success toast |

### Flujos de Cantidad

**Flujo A (Cantidad primero):**
```
1. Input: "3" → Click "CANT. ×"
2. Estado: pendingQuantity = 3, badge ámbar "3×"
3. Input: "1234" → Click "AGREGAR"
4. Resultado: Agrega 3 unidades del producto 1234
5. Reset: pendingQuantity = null
```

**Flujo B (Producto primero):**
```
1. Input: "1234" → Click "CANT. ×"
2. Estado: pendingProduct = {producto}, badge azul "Arroz"
3. Input: "5" → Click "AGREGAR"
4. Resultado: Agrega 5 unidades de Arroz
5. Reset: pendingProduct = null
```

### Estados Visuales

| Estado | Badge | Color Badge |
|--------|-------|-------------|
| Normal | Sin badge | - |
| Cantidad pendiente | "3×" | Ámbar `#F59E0B` |
| Producto pendiente | "Arroz" | Azul `#3B82F6` |

---

## 🪟 Modales

### Comportamiento General

| Evento | Acción |
|--------|--------|
| Click en overlay (fondo) | Cerrar modal |
| Click en handle bar (───) | Cerrar modal |
| Click botón [×] | Cerrar modal |
| Escape key | Cerrar modal |
| Swipe down (móvil) | Cerrar modal |

### Animaciones

```css
/* Entrada */
.modal-enter {
  animation: slideUp 200ms var(--ease-out-expo);
}

@keyframes slideUp {
  from {
    transform: translateY(100%);
    opacity: 0;
  }
  to {
    transform: translateY(0);
    opacity: 1;
  }
}

/* Salida */
.modal-leave {
  animation: slideDown 150ms ease-in;
}
```

### Tipos de Modal

| Modal | Altura | Scroll |
|-------|--------|--------|
| Checkout | 80vh máx | Interno |
| Producto Form | 70vh máx | Interno |
| Búsqueda | 60vh | Lista virtualizada |
| Apertura Jornada | Auto | No |
| Confirmación | Auto | No |

---

## 🔘 Toggle Apertura/Cierre de Tienda

### Estados

```
CERRADO:
┌──────────────────────────────────┐
│ [○]← Desliza para ABRIR      🔒 │
└──────────────────────────────────┘
Fondo: #374151 (gris)
Barra: #6B7280

ABIERTO:
┌──────────────────────────────────┐
│ 🔓 ABIERTO                  →[●]│
└──────────────────────────────────┘
Fondo: #22C55E (verde)
Barra: #16A34A
```

### Lógica de Interacción

| Acción | Estado Actual | Resultado |
|--------|---------------|-----------|
| Click/Drag | CERRADO | Abrir Modal Apertura |
| Click/Drag | ABIERTO | Navegar a `/cash-control` |
| Confirmar Apertura | Modal Abierto | `salesStore.openStore(amount)` |
| Cerrar desde Cash Control | ABIERTO | `salesStore.closeStore()` |

### Animación de Transición

```css
.toggle-track {
  transition: background-color 300ms ease;
}

.toggle-thumb {
  transition: transform 300ms cubic-bezier(0.4, 0, 0.2, 1);
}

.toggle-thumb--active {
  transform: translateX(calc(100% - 40px));
}
```

---

## 📊 StatCards

### Estructura

```
┌─────────────────────────────┐
│ [💵]           Color icono  │
│                             │
│ $125,000      Valor grande  │
│ Caja Real     Label         │
│ (subtítulo)   Opcional      │
└─────────────────────────────┘
```

### Props

| Prop | Tipo | Descripción |
|------|------|-------------|
| `icon` | string | Nombre del icono Material |
| `value` | string | Valor principal formateado |
| `label` | string | Etiqueta descriptiva |
| `subtitle` | string? | Texto secundario opcional |
| `color` | 'green' \| 'blue' \| 'orange' \| 'purple' | Tema de color |

### Lógica Visual

```typescript
const colorClasses = {
  green: {
    icon: 'text-green-500',
    bg: 'bg-green-500/10'
  },
  blue: {
    icon: 'text-blue-500',
    bg: 'bg-blue-500/10'
  },
  orange: {
    icon: 'text-orange-500',
    bg: 'bg-orange-500/10'
  },
  purple: {
    icon: 'text-purple-500',
    bg: 'bg-purple-500/10'
  }
}
```

### Interacción

| Evento | Acción |
|--------|--------|
| Click en "Inventario" card | Navegar a `/inventory` |
| Click en "Por Cobrar" card | Navegar a `/clients` |

---

## 📝 Formularios de Validación

### Validación en Tiempo Real

| Campo | Validación | Feedback |
|-------|------------|----------|
| Nombre tienda | `length >= 3` | ✅ Check verde al validar |
| Email | Formato válido | Error si inválido |
| Contraseña | `length >= 6` | Indicador de fuerza |
| PIN Admin | Exactamente 6 dígitos | Teclado numérico |
| PIN Empleado | Exactamente 4 dígitos | Teclado numérico |
| Precio | `> 0` | Error si <= 0 |
| PLU | `length <= 4` | auto-limit input |

### Estados de Input

```
DEFAULT:
┌─────────────────────────────────┐
│ Nombre del producto             │
└─────────────────────────────────┘
Border: #475569

FOCUS:
┌─────────────────────────────────┐
│ Nombre del producto             │
└─────────────────────────────────┘
Border: #22C55E + ring 2px

ERROR:
┌─────────────────────────────────┐
│ Precio                          │
│ ⚠️ El precio debe ser mayor a 0 │
└─────────────────────────────────┘
Border: #EF4444, bg: #EF4444/10

VALID:
┌─────────────────────────────────┐
│ Tienda de Pedro            [✓] │
└─────────────────────────────────┘
Border: #22C55E, check icon
```

### Botón Submit

```typescript
// Deshabilitado hasta que todo sea válido
const isFormValid = computed(() => {
  return (
    name.value.length >= 3 &&
    email.value.includes('@') &&
    password.value.length >= 6 &&
    pin.value.length === 6
  )
})
```

---

## ⏳ Estados de Carga (Skeletons)

### Skeleton de Lista

```
┌─────────────────────────────────────┐
│ [▓▓▓] ▓▓▓▓▓▓▓▓▓▓▓▓▓▓               │
│       ▓▓▓▓▓▓▓▓▓▓                   │
│       ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓            │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ [▓▓▓] ▓▓▓▓▓▓▓▓▓▓▓▓                 │
│       ▓▓▓▓▓▓▓▓▓▓                   │
│       ▓▓▓▓▓▓▓▓▓▓▓▓▓                │
└─────────────────────────────────────┘
```

### Skeleton de Dashboard

```
┌─────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  Toggle
├─────────────────────────────────────┤
│ ┌──────────┐  ┌──────────┐        │
│ │ ▓▓▓▓▓▓▓▓ │  │ ▓▓▓▓▓▓▓▓ │        │  StatCards
│ │ ▓▓▓▓▓▓▓▓ │  │ ▓▓▓▓▓▓▓▓ │        │
│ └──────────┘  └──────────┘        │
│ ┌──────────┐  ┌──────────┐        │
│ │ ▓▓▓▓▓▓▓▓ │  │ ▓▓▓▓▓▓▓▓ │        │
│ │ ▓▓▓▓▓▓▓▓ │  │ ▓▓▓▓▓▓▓▓ │        │
│ └──────────┘  └──────────┘        │
└─────────────────────────────────────┘
```

### Lógica de Skeleton

```typescript
// Mostrar skeleton durante carga inicial
const isLoading = ref(true)

onMounted(async () => {
  await fetchData()
  isLoading.value = false
})
```

```html
<template>
  <div v-if="isLoading">
    <SkeletonList :count="5" />
  </div>
  <div v-else>
    <ProductList :products="products" />
  </div>
</template>
```

---

## 📭 Empty States

### Configuraciones

| Pantalla | Icono | Título | Descripción | CTA |
|----------|-------|--------|-------------|-----|
| Inventario vacío | 📦 | "Sin productos" | "Agrega tu primer producto..." | "Agregar Producto" |
| Clientes vacío | 👥 | "Sin clientes" | "Registra tu primer cliente..." | "Agregar Cliente" |
| Carrito vacío | 🛒 | "Carrito vacío" | "Agrega productos para vender" | - |
| Historial vacío | 📋 | "Sin transacciones" | "No hay movimientos..." | - |
| Búsqueda sin resultados | 🔍 | "Sin resultados" | "No encontramos..." | "Limpiar búsqueda" |

### Estructura Visual

```
┌─────────────────────────────────────┐
│                                     │
│           [📦 64px]                 │
│                                     │
│     No hay productos todavía        │  text-xl semibold
│                                     │
│  Agrega tu primer producto para     │  text-secondary
│  empezar a vender.                  │
│                                     │
│  ┌─────────────────────────────┐    │
│  │     + Agregar Producto      │    │  Botón opcional
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

---

## 🔒 NoPermissionOverlay

### Estructura

```
┌─────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
│ ▓                                 ▓ │
│ ▓           [⚠️ 48px]             ▓ │
│ ▓                                 ▓ │
│ ▓   No tienes permiso para        ▓ │
│ ▓   realizar ventas               ▓ │
│ ▓                                 ▓ │
│ ▓   ┌─────────────────────────┐   ▓ │
│ ▓   │  Volver al Dashboard   │   ▓ │
│ ▓   └─────────────────────────┘   ▓ │
│ ▓                                 ▓ │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
└─────────────────────────────────────┘

Fondo: rgba(15, 23, 42, 0.95) - casi opaco
```

### Variantes

| Condición | Icono | Mensaje |
|-----------|-------|---------|
| `!canSell` | 🚫 | "No tienes permiso para realizar ventas" |
| `isClosed` | 🔒 | "Tienda Cerrada - No se pueden realizar ventas" |
| `!canViewInventory` | 📦 | "No tienes permiso para ver inventario" |

### Props

```typescript
interface NoPermissionOverlayProps {
  icon: string
  title: string
  description?: string
  buttonText?: string
  buttonAction?: () => void
}
```

---

## 🔔 Sistema de Notificaciones

### Toast Component

```typescript
interface ToastProps {
  type: 'success' | 'error' | 'warning' | 'info'
  message: string
  duration?: number // default 3000ms
  dismissible?: boolean // default true
}
```

### Posicionamiento

```
Mobile:
┌─────────────────────────────────────┐
│ ┌─────────────────────────────────┐ │
│ │ ✓ Producto agregado            │ │  Top center
│ └─────────────────────────────────┘ │
│                                     │
│                                     │
│            (contenido)              │
│                                     │
└─────────────────────────────────────┘
```

### Cola de Notificaciones

```typescript
// Máximo 3 notificaciones visibles
const MAX_TOASTS = 3

// Stack from bottom
const toasts = ref<Toast[]>([])

function addToast(toast: Toast) {
  if (toasts.value.length >= MAX_TOASTS) {
    toasts.value.shift() // Eliminar la más antigua
  }
  toasts.value.push(toast)
  
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== toast.id)
  }, toast.duration)
}
```

---

## ↻ Estados de Sincronización (SPEC-011)

### SyncIndicator

```
┌─────────────────────────────────────┐
│ Inventario              [↻ azul]   │
└─────────────────────────────────────┘
```

| Prop | Tipo | Default | Descripción |
|------|------|---------|-------------|
| `isValidating` | boolean | - | Mostrar/ocultar indicador |
| `variant` | 'minimal' \| 'compact' | 'minimal' | Estilo visual |
| `label` | string | 'Sincronizando' | Texto (solo compact) |

**Lógica:**
```typescript
// Solo mostrar cuando isValidating es true
<SyncIndicator v-if="isValidating" variant="minimal" />
```

**CSS:**
```css
.sync-indicator__icon {
  animation: spin 1s linear infinite;
  color: var(--sync-validating);
}
```

### StaleDataBanner

```
┌─────────────────────────────────────┐
│ ⏰ Datos de hace 10 min [Actualizar]│
└─────────────────────────────────────┘
```

| Prop | Tipo | Descripción |
|------|------|-------------|
| `lastUpdated` | number | Timestamp de última actualización |
| `onRefresh` | () => void | Callback para revalidar |

**Lógica:**
```typescript
// Mostrar cuando stale pero NO validando
<StaleDataBanner 
  v-if="isStale && !isValidating"
  :lastUpdated="lastFetch"
  @refresh="revalidate"
/>

// Calcular tiempo
const timeAgo = computed(() => {
  const mins = Math.floor((Date.now() - lastUpdated) / 60000)
  return mins < 60 ? `hace ${mins} min` : `hace ${Math.floor(mins/60)} h`
})
```

### OfflineBanner

```
Offline:   ┌──📡 Sin conexión - Modo offline──┐  Rojo fijo
Reconect:  ┌──↻ Reconectando...──────────────┐  Ámbar + spin
Online:    ┌──✓ Conexión restaurada──────────┐  Verde fade
```

| Estado | Fondo | Comportamiento |
|--------|-------|----------------|
| `offline` | `--sync-offline` | Persistente |
| `reconnecting` | `--sync-stale` | + Spinner |
| `online` | `--sync-success` | Fade out 3s |

**Lógica:**
```typescript
// Composable useOnlineStatus
const { isOnline, wasOffline } = useOnlineStatus()

// En App.vue (nivel raíz)
<OfflineBanner v-if="!isOnline || showReconnected" />
```

### SyncQueueStatus

```
Pendientes: ┌──📤 3 transacciones pendientes──┐
Fallidas:   ┌──⚠️ 2 transacciones fallidas───┐
```

| Prop | Tipo | Descripción |
|------|------|-------------|
| `pendingCount` | number | Transacciones en cola |
| `failedCount` | number | Transacciones en Dead Letter Queue |
| `onViewFailed` | () => void | Abrir modal de fallidas |

**Lógica:**
```typescript
// Solo mostrar si hay items
<SyncQueueStatus 
  v-if="pendingCount > 0 || failedCount > 0"
  :pendingCount="queue.length"
  :failedCount="failedQueue.length"
/>
```

---

## 📋 Instrucciones para el Orquestador

### Para Frontend Developer

1. Implementar composable `useNotifications()` según spec
2. Crear componente `SkeletonLoader` reutilizable
3. Implementar `NoPermissionOverlay` con props dinámicos
4. Ensure all forms have real-time validation feedback

### Para UI Developer

1. Aplicar Design System tokens con CSS custom properties
2. Implementar animaciones de modales con framer-motion o CSS
3. Crear variantes de Badge component
4. Implementar skeleton shimmer animation

### Para QA

1. Validar todos los flujos de Numpad
2. Probar edge cases de cantidad (0, negativos, decimales)
3. Verificar estados de loading en conexiones lentas
4. Probar empty states para cada lista
