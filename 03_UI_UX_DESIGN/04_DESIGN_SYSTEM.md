# 04 - Design System (Guía de Estilo Funcional)

> **Propósito:** Definir tokens de diseño, paleta de colores, tipografía y comportamientos visuales.

---

## 🎨 Paleta de Colores

### Colores Primarios

| Token | Hex | Uso |
|-------|-----|-----|
| `--primary` | `#22C55E` | Acciones principales, estados positivos |
| `--primary-dark` | `#16A34A` | Hover de primary |
| `--primary-light` | `#86EFAC` | Fondos suaves |

### Colores Semánticos

| Token | Hex | Uso |
|-------|-----|-----|
| `--success` | `#22C55E` | Confirmaciones, totales positivos |
| `--warning` | `#F59E0B` | Alertas, stock bajo, crédito limitado |
| `--error` | `#EF4444` | Errores, deudas, faltantes |
| `--info` | `#3B82F6` | Información, enlaces |

### Colores de UI

| Token | Hex | Uso |
|-------|-----|-----|
| `--bg-primary` | `#0F172A` | Fondo principal (dark mode) |
| `--bg-secondary` | `#1E293B` | Tarjetas, modales |
| `--bg-tertiary` | `#334155` | Inputs, hover states |
| `--text-primary` | `#F8FAFC` | Texto principal |
| `--text-secondary` | `#94A3B8` | Texto secundario |
| `--text-muted` | `#64748B` | Placeholders |
| `--border` | `#475569` | Bordes, divisores |

### Colores por Método de Pago

| Método | Color | Token |
|--------|-------|-------|
| Efectivo | Verde | `--payment-cash: #22C55E` |
| Nequi | Fucsia | `--payment-nequi: #EC4899` |
| Fiado | Naranja | `--payment-fiado: #F97316` |

### Colores StatCards

| Stat | Color Icono | Color Fondo |
|------|-------------|-------------|
| Caja Real | `#22C55E` | `#22C55E/10` |
| Ventas Hoy | `#3B82F6` | `#3B82F6/10` |
| Por Cobrar | `#F97316` | `#F97316/10` |
| Inventario | `#A855F7` | `#A855F7/10` |

---

## 🔤 Tipografía

### Font Stack

```css
--font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
--font-mono: 'JetBrains Mono', 'Fira Code', monospace;
```

### Escala Tipográfica

| Token | Size | Weight | Line Height | Uso |
|-------|------|--------|-------------|-----|
| `--text-xs` | 12px | 400 | 1.5 | Badges, captions |
| `--text-sm` | 14px | 400 | 1.5 | Labels, texto secundario |
| `--text-base` | 16px | 400 | 1.5 | Texto body |
| `--text-lg` | 18px | 500 | 1.4 | Subtítulos |
| `--text-xl` | 20px | 600 | 1.3 | Títulos card |
| `--text-2xl` | 24px | 700 | 1.2 | Títulos sección |
| `--text-3xl` | 30px | 700 | 1.1 | Números grandes (totales) |
| `--text-4xl` | 36px | 800 | 1.0 | Display (monto checkout) |

### Variantes de Peso

| Weight | Uso |
|--------|-----|
| 400 (Regular) | Texto body |
| 500 (Medium) | Labels, items de lista |
| 600 (Semibold) | Subtítulos, botones |
| 700 (Bold) | Títulos, totales |
| 800 (Extrabold) | Montos destacados |

---

## 📐 Espaciado y Grid

### Escala de Espaciado

| Token | Value | Uso |
|-------|-------|-----|
| `--space-1` | 4px | Micro separaciones |
| `--space-2` | 8px | Gap íconos, inline |
| `--space-3` | 12px | Gap cards, padding inputs |
| `--space-4` | 16px | Padding containers |
| `--space-5` | 20px | Margin secciones |
| `--space-6` | 24px | Gap grandes |
| `--space-8` | 32px | Separación secciones |

### Grid Layout

```css
/* Mobile (375px) */
.container {
  padding: var(--space-4);
  max-width: 100%;
}

/* Cards Grid */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--space-3);
}

/* Numpad Grid */
.numpad-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-2);
}
```

### Border Radius

| Token | Value | Uso |
|-------|-------|-----|
| `--radius-sm` | 4px | Chips, badges |
| `--radius-md` | 8px | Botones, inputs |
| `--radius-lg` | 12px | Cards, modales |
| `--radius-xl` | 16px | Containers grandes |
| `--radius-full` | 9999px | Avatares, pills |

---

## 🎭 Estados Visuales

### Estados de Botón

| Estado | Transformación |
|--------|----------------|
| Default | - |
| Hover | `brightness(1.1)`, `scale(1.02)` |
| Active | `scale(0.98)` |
| Disabled | `opacity(0.5)`, `cursor: not-allowed` |
| Loading | Spinner + `opacity(0.7)` |

```css
.btn-primary {
  background: var(--primary);
  color: white;
  transition: all 150ms ease;
}

.btn-primary:hover {
  filter: brightness(1.1);
  transform: scale(1.02);
}

.btn-primary:active {
  transform: scale(0.98);
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
```

### Estados de Input

| Estado | Visual |
|--------|--------|
| Default | Border `--border` |
| Focus | Border `--primary`, ring 2px |
| Error | Border `--error`, bg `--error/10` |
| Disabled | bg `--bg-tertiary`, opacity 0.7 |

### Estados de Toggle (Tienda)

| Estado | Visual |
|--------|--------|
| Cerrado | Fondo gris, thumb izquierda, texto "CERRADO" |
| Abierto | Fondo verde, thumb derecha, texto "ABIERTO", candado abierto |
| Transición | Animación 300ms ease-out |

---

## 🔔 Feedback Visual

### Notificaciones Toast

| Tipo | Color | Icono | Duración |
|------|-------|-------|----------|
| Success | `--success` | ✓ | 3s |
| Error | `--error` | ✕ | 5s |
| Warning | `--warning` | ⚠ | 4s |
| Info | `--info` | ℹ | 3s |

```
┌──────────────────────────────────┐
│ [✓] Producto agregado al carrito│
└──────────────────────────────────┘
```

### Skeleton Loading

```css
.skeleton {
  background: linear-gradient(
    90deg,
    var(--bg-secondary) 25%,
    var(--bg-tertiary) 50%,
    var(--bg-secondary) 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

@keyframes shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}
```

### Empty States

```
┌─────────────────────────────────────┐
│                                     │
│           [📦 ilustración]          │
│                                     │
│     No hay productos todavía        │
│                                     │
│  Agrega tu primer producto para     │
│  empezar a vender.                  │
│                                     │
│      [+ Agregar Producto]           │
│                                     │
└─────────────────────────────────────┘
```

---

## 🎬 Animaciones

### Microinteracciones

| Trigger | Animación | Duración |
|---------|-----------|----------|
| Agregar al carrito | Scale bounce | 200ms |
| Eliminar item | Slide out + fade | 300ms |
| Abrir modal | Slide up + fade | 200ms |
| Cerrar modal | Slide down + fade | 150ms |
| Notificación | Slide in desde arriba | 300ms |

### Transiciones Base

```css
/* Transición por defecto */
--transition-fast: 150ms ease;
--transition-base: 200ms ease;
--transition-slow: 300ms ease;

/* Easing functions */
--ease-out-expo: cubic-bezier(0.16, 1, 0.3, 1);
--ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
```

---

## 📱 Iconografía

### Librerías

- **Lucide Vue**: Iconos de línea para UI general
- **Material Symbols**: Iconos de Google para acciones

### Tamaños

| Contexto | Size |
|----------|------|
| Inline con texto | 16px |
| Botones, inputs | 20px |
| StatCards | 24px |
| Header actions | 24px |
| Ilustraciones | 48-64px |

### Iconos Principales

| Función | Icono Lucide | Icono Material |
|---------|--------------|----------------|
| Home | `Home` | `home` |
| Venta | `ShoppingCart` | `shopping_cart` |
| Inventario | `Package` | `inventory_2` |
| Clientes | `Users` | `people` |
| Admin | `Settings` | `settings` |
| Agregar | `Plus` | `add` |
| Eliminar | `Trash2` | `delete` |
| Editar | `Pencil` | `edit` |
| Buscar | `Search` | `search` |
| Cerrar | `X` | `close` |
| Atrás | `ArrowLeft` | `arrow_back` |
| Notificaciones | `Bell` | `notifications` |
| Usuario | `User` | `person` |
| Tienda | `Store` | `store` |
| Dinero | `DollarSign` | `payments` |
| Gráfico | `TrendingUp` | `show_chart` |

---

## 📋 Variantes de Componentes

### Botones

| Variante | Visual | Uso |
|----------|--------|-----|
| Primary | Fondo verde, texto blanco | Acciones principales |
| Secondary | Fondo transparente, borde verde | Acciones secundarias |
| Ghost | Sin fondo, texto verde | Acciones terciarias |
| Danger | Fondo rojo, texto blanco | Eliminar, cancelar |
| Disabled | Opacidad reducida | No disponible |

### Cards

| Variante | Visual |
|----------|--------|
| Default | Fondo `--bg-secondary`, shadow-sm |
| Interactive | + hover elevation, cursor pointer |
| Alert | Borde izquierdo color semántico |
| Selected | Borde `--primary` |

### Badges

| Variante | Color | Uso |
|----------|-------|-----|
| Success | Verde | Stock OK, al día |
| Warning | Amarillo | Stock bajo, límite |
| Error | Rojo | Sin stock, excede crédito |
| Info | Azul | Cantidad, PLU |
| Neutral | Gris | Tags, categorías |
