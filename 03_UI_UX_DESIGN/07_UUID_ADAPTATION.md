# 🎨 Diseño UX/UI - Adaptación a Identificadores Globales (UUID)

> **Fecha**: 2026-01-21  
> **Rol**: Estratega de UX/UI  
> **Contexto**: El sistema migra de IDs numéricos locales a UUIDs para sincronización en la nube  

---

## 📋 Resumen Ejecutivo

Los UUIDs son **ilegibles para el usuario** (36 caracteres alfanuméricos). Este documento define los **Identificadores Funcionales** que el usuario verá en cada módulo crítico, garantizando que NUNCA se exponga un UUID directamente en la interfaz.

> [!IMPORTANT]
> **Regla de Oro UX**: El usuario NUNCA debe ver, escribir ni buscar por UUID. Cada entidad tendrá un identificador amigable.

---

## 1️⃣ Ventas y Recibos (/pos)

### Estado Actual Verificado ✅
El sistema **YA usa** `ticket_number` como identificador visual:
- El esquema SQL define: `ticket_number SERIAL` en tabla `sales`
- POSView muestra: `Ticket #045` en el header

### Decisión UX: CONFIRMADO

| Aspecto | Decisión |
|---------|----------|
| **Historial de ventas** | Mostrar solo `ticket_number` formateado como `#0001`, `#0045`, etc. |
| **Recibo impreso** | Header: `Ticket #0045` - NUNCA el UUID |
| **Modal de checkout** | Confirmar venta mostrando número de ticket |
| **Búsqueda en historial** | Permitir buscar por número de ticket |

### Mapa de Navegación
```
[POS] → [Checkout Modal] → [Confirmación: "Ticket #0045 creado"]
                                    ↓
                           [Historial de Ventas]
                                    ↓
                           [Detalle: Ticket #0045]
```

### Lógica de Componentes
```
📍 POSView.vue
- computed: ticketNumber → salesStore.nextId.toString().padStart(4, '0')
- Muestra: "Ticket #0045"

📍 SalesHistory (futuro)
- Columna principal: "N° Ticket"
- Valor: sale.ticket_number formateado
- UUID: Solo en background para DB queries
```

### Instrucción para el Orquestador
1. **Verificar** que `salesStore` use `ticket_number` del backend, no IDs locales
2. **Crear constraint** en UI: nunca renderizar `sale.id` (UUID) en texto visible
3. **Historial de ventas**: La columna de identificación debe ser `ticket_number`

---

## 2️⃣ Listado de Productos (/inventory)

### Estado Actual Verificado ✅
- InventoryView.vue muestra: `PLU: {{ product.plu }}` (línea 161)
- **NO hay columna visible de ID numérico**
- Esquema SQL: `products.id UUID`, `products.plu TEXT` (único por tienda)

### Decisión UX: CONFIRMADO - Sin cambios necesarios

| Aspecto | Decisión |
|---------|----------|
| **Columna principal** | PLU (Código Rápido) - ya implementado |
| **Columna de ID de BD** | **ELIMINADA** - No existe y no debe agregarse |
| **Búsqueda** | Por nombre o PLU - ya implementado |
| **SKU opcional** | Si se agrega, usar SKU externo (código de barras) |

### Detalle de Pantalla
```
┌─────────────────────────────────────────────┐
│ [←] Buscar producto...            [Filter]  │
├─────────────────────────────────────────────┤
│ [Tag: Todos] [Bebidas] [Lácteos] [Aseo]     │
├─────────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐    │
│  │ Leche Entera Colanta              $5,200│
│  │ Colanta | PLU: 1001                     │
│  │ [Lácteos]                               │
│  │ ────────────────────────────────────    │
│  │ 24 un                        [🗑️]      │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ Arroz Diana 1kg                  $4,800│
│  │ Diana | PLU: 2045                       │
│  │ [Abarrotes]                             │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

> [!NOTE]
> El PLU es numérico y asignado por el usuario (1-4 dígitos). No confundir con UUID.

### Instrucción para el Orquestador
1. **Mantener** el diseño actual de tarjetas de producto
2. **PROHIBIR** agregar columnas o campos que muestren `product.id`
3. **Futuro SKU**: Si se implementa código de barras, usar columna `barcode` separada

---

## 3️⃣ URLs y Navegación

### Cambio Arquitectural
```
ANTES: /clients/15  → /clients/45  → /clients/8546
AHORA: /clients/550e8400-e29b-41d4-a716-446655440000
```

### Análisis de Impacto UX

| Escenario | Impacto | Decisión |
|-----------|---------|----------|
| **Copy-paste URL al navegador** | Bajo | Funciona igual, solo es más largo |
| **Compartir enlace a compañero** | Medio | URLs largas en WhatsApp/SMS se ven feas |
| **Bookmarks del navegador** | Ninguno | El nombre del bookmark es el título de la página |
| **Depuración/Soporte técnico** | Alto positivo | UUID es más útil para debugging |

### Decisión UX: ACEPTABLE ✅

> [!TIP]
> La URL larga es **aceptable** siempre que la interfaz visual esté limpia. El usuario no necesita copiar/pegar URLs en el flujo normal de trabajo.

### Mitigaciones Opcionales (Futuro)
1. **Friendly slug en título de página**: La pestaña del navegador muestra "María García - Clientes" no el UUID
2. **Botón "Copiar Código"**: Si se necesita compartir una referencia, generar código corto temporal
3. **Deep linking QR**: Para compartir, generar QR code que contiene el UUID

### Instrucción para el Orquestador
1. **Rutas Vue Router**: Aceptar UUID como parámetro `:id`
2. **Título de pestaña**: `document.title = "Producto: Leche Colanta"` (nombre humano)
3. **NO crear** sistema de URLs cortas - overhead innecesario para MVP

---

## 4️⃣ Buscadores

### Principio UX Fundamental

> [!CAUTION]
> El usuario **NUNCA** debe necesitar buscar por UUID. Todos los campos de búsqueda deben estar etiquetados con los criterios de búsqueda permitidos.

### Mapeo de Buscadores por Módulo

| Módulo | Campo de Búsqueda | Criterios Válidos | Etiqueta Sugerida |
|--------|-------------------|-------------------|-------------------|
| **POS** | Buscar productos | Nombre, PLU | "Buscar por nombre o PLU" |
| **Inventario** | Header search | Nombre, Marca, PLU | "Buscar producto..." |
| **Clientes** | Lista de clientes | Nombre, Cédula, Teléfono | "Buscar por nombre, cédula o teléfono" |
| **Historial Ventas** | Filtro de ventas | N° Ticket, Fecha | "Buscar por número de ticket" |
| **Empleados** | Admin Hub | Nombre, Usuario | "Buscar por nombre o usuario" |

### Detalle de Pantalla: Ejemplo Cliente
```
┌─────────────────────────────────────────────┐
│ 🔍 Buscar por nombre, cédula o teléfono     │
│ ┌─────────────────────────────────────────┐ │
│ │ maría garcía                            │ │
│ └─────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ Resultado:                                  │
│ ┌─────────────────────────────────────────┐ │
│ │ 👤 María García                         │ │
│ │    CC 1.234.567.890 | 📱 311-234-5678  │ │
│ │    Saldo: $45,000 (Debe)                │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### Instrucción para el Orquestador
1. **Actualizar placeholders** de todos los inputs de búsqueda con criterios explícitos
2. **Eliminar** cualquier referencia a "Código de Sistema" o "ID"
3. **Backend filters**: Asegurar que las APIs nunca requieran UUID como input del usuario

---

## 5️⃣ Tabla de Identificadores Funcionales

| Entidad | UUID (Interno) | Identificador Funcional (Usuario) | Formato Visual |
|---------|----------------|-----------------------------------|----------------|
| **Venta** | `sales.id` | `ticket_number` | `#0001`, `#0045` |
| **Producto** | `products.id` | `plu` | `PLU: 1001`, `PLU: 45` |
| **Cliente** | `clients.id` | `cedula` + `name` | `1.234.567.890 - María García` |
| **Empleado** | `employees.id` | `username` + `name` | `@vendedor1 (Juan Pérez)` |
| **Tienda** | `stores.id` | `name` | `Tienda La Esquina` |
| **Gasto** | `expenses.id` | `fecha` + `descripción` | `21/01 - Compra bolsas` |
| **Movimiento Inv.** | `inventory_movements.id` | `tipo` + `fecha` | `Entrada 21/01/2026` |

---

## 6️⃣ Guía de Implementación para Desarrolladores

### ❌ PROHIBIDO
```vue
<!-- NUNCA hacer esto -->
<span>ID: {{ product.id }}</span>
<p>Código: {{ sale.id }}</p>
<td>{{ client.id }}</td>
```

### ✅ CORRECTO
```vue
<!-- Siempre usar identificadores funcionales -->
<span>PLU: {{ product.plu }}</span>
<p>Ticket: #{{ sale.ticket_number.toString().padStart(4, '0') }}</p>
<td>{{ client.cedula }} - {{ client.name }}</td>
```

### Utilidades Sugeridas
```typescript
// utils/formatters.ts

export const formatTicketNumber = (num: number): string => {
  return `#${num.toString().padStart(4, '0')}`;
};

export const formatClientRef = (client: Client): string => {
  return `${client.cedula} - ${client.name}`;
};

export const formatProductRef = (product: Product): string => {
  return product.plu ? `PLU: ${product.plu}` : product.name;
};
```

---

## 7️⃣ Checklist de Verificación QA

- [ ] **POS**: Ticket muestra `#0045`, no UUID
- [ ] **Inventario**: Productos identificados por PLU o nombre
- [ ] **Clientes**: Identificados por Cédula + Nombre
- [ ] **Búsquedas**: Ningún placeholder sugiere buscar por "ID" o "Código de sistema"
- [ ] **Recibos impresos**: Solo ticket_number visible
- [ ] **URLs**: Aceptan UUID pero UI muestra nombres amigables
- [ ] **Consola/Logs**: UUID puede aparecer en logs de desarrollo (aceptable)

---

## 📝 Resumen de Decisiones

| Pregunta Original | Decisión |
|-------------------|----------|
| ¿Mostrar ID de venta en historial? | **NO** - Usar `ticket_number` (#0045) |
| ¿Columna de ID en inventario? | **NO EXISTE** - Mantener PLU como identificador |
| ¿URLs largas son problema? | **ES ACEPTABLE** - UI limpia compensa |
| ¿Usuario busca por UUID? | **NUNCA** - Etiquetas claras de búsqueda |

---

> **Aprobación requerida**: Este documento define las directrices UX para la migración a UUIDs. Tras aprobación, el Orquestador puede generar Work Orders para implementación.
