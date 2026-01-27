# FRD-007: Sistema de Ventas (Módulo Primario)

### Nombre de la Funcionalidad
Punto de Venta (POS) y Procesamiento de Transacciones

#### Descripción
Sistema central de ventas que permite registrar transacciones comerciales, gestionar el carrito de compras, procesar múltiples métodos de pago y mantener sincronización con el servidor incluso sin conexión.

---

## Reglas de Negocio

> [!IMPORTANT]
> **Políticas Globales Obligatorias:**
> Este módulo DEBE cumplir las siguientes especificaciones técnicas:
> - [SPEC-010: Política de Redondeo](../TECH_SPECS/rounding-policy.md)
> - [SPEC-011: Estándar de Decimales](../TECH_SPECS/decimal-format-standard.md)

### Políticas de Redondeo y Formato

Este módulo cumple las políticas globales de redondeo y formato decimal:

- **Subtotal de productos pesables:** Se redondea al múltiplo de $50 al agregar al carrito.
- **Total de venta:** Es la suma de subtotales (ya redondeados).
- **Vueltas (cambio):** Se redondean con algoritmo híbrido (empate hacia abajo).
- **Montos:** Se muestran sin decimales, con separador de miles.
- **Cantidades unitarias:** Sin decimales.
- **Cantidades por peso:** Máximo 2 decimales.

**Campo de Auditoría:** Cada venta almacena la diferencia entre el total exacto y el total redondeado para trazabilidad fiscal.

---

### Precondiciones para Vender

El POS está **BLOQUEADO** y muestra mensaje si:

| Condición | Mensaje | Acción Disponible |
|-----------|---------|-------------------|
| Caja cerrada | "Para vender, primero abre la caja" | Ir a abrir caja |
| Inventario vacío | "Agrega productos antes de vender" | Crear producto |
| Sin permiso de venta | "No tienes permiso para vender" | Volver |

---

### Límites del Carrito

| Parámetro | Valor | Comportamiento al Exceder |
|-----------|-------|---------------------------|
| Máximo items por venta | 50 | Mensaje: "Máximo 50 productos. Procesa esta venta y crea una nueva." |
| Stock disponible | Según inventario | Mensaje: "Stock insuficiente. Disponible: X." (No agrega al carrito) |

---

### Métodos de Pago

| Método | Requisitos | Notas |
|--------|------------|-------|
| **Efectivo** | Monto recibido ≥ Total | Sistema calcula vueltas |
| **Nequi/Daviplata** | Ninguno (confianza) | Referencia opcional (últimos 4 dígitos) |
| **Fiado (Crédito)** | Cliente registrado en sistema | Ver FRD-009 para reglas de cupo |

---

### Matriz de Permisos

| Acción | Admin | Empleado con `canSell` | Empleado sin `canSell` |
|--------|-------|------------------------|------------------------|
| Acceder al POS | ✅ | ✅ | ❌ (Bloqueado) |
| Agregar items al carrito | ✅ | ✅ | ❌ |
| Procesar venta Efectivo/Nequi | ✅ | ✅ | ❌ |
| Procesar venta Fiado | ✅ | ✅ | ❌ |
| Ver historial de ventas (hoy) | ✅ | ✅ | ❌ |
| **Anular venta** | ✅ | ❌ | ❌ |

---

### Sincronización sin Conexión

- **Con conexión:** La venta se procesa inmediatamente en el servidor.
- **Sin conexión:** La venta se almacena localmente y se sincroniza cuando hay conexión.
- **Estado de Sincronización:** Cada venta tiene estado: sincronizado, pendiente, o fallido.

---

## Flujo de Venta

1. Usuario en POS ingresa PLU con teclado numérico o busca por nombre
2. Producto encontrado → Se agrega al carrito
3. Subtotales se calculan con redondeo aplicado
4. Stock se valida en cada agregado
5. Usuario pulsa "COBRAR" → Se abre modal de checkout
6. Usuario selecciona método de pago:
   - Efectivo → Ingresa monto recibido → Ve vueltas
   - Nequi → Confirma directamente
   - Fiado → Selecciona cliente → Sistema valida cupo
7. Usuario confirma → Venta procesada
8. Stock descontado, carrito limpiado
9. Mensaje: "Venta registrada. Ticket #XXX"

---

## Casos de Uso

**Caso A: Venta Rápida por PLU**
- **Actor:** Empleado con permiso de venta
- **Precondición:** Caja abierta, producto existente.
- **Flujo Principal:**
    1. Digita PLU en teclado numérico.
    2. Sistema encuentra producto.
    3. Pulsa "Agregar" → Item aparece en carrito.
    4. Pulsa "Cobrar" → Modal de checkout.
    5. Selecciona "Efectivo" → Ingresa monto recibido.
    6. Sistema calcula y muestra vueltas.
    7. Confirma → Venta procesada.
- **Postcondición:** Venta registrada, stock descontado, ticket generado.

**Caso B: Venta a Crédito (Fiado)**
- **Actor:** Empleado con permiso de venta
- **Precondición:** Caja abierta, cliente registrado.
- **Flujo Principal:**
    1. Agrega items al carrito.
    2. Pulsa "Cobrar" → Selecciona "Fiado".
    3. Busca cliente por nombre o identificación.
    4. Sistema muestra: "Crédito disponible: $X / Límite: $Y".
    5. Si hay cupo suficiente → Confirma.
    6. Sistema registra venta → Actualiza deuda del cliente.
- **Postcondición:** Venta registrada, deuda del cliente actualizada.

**Caso C: Anulación de Venta (Solo Admin)**
- **Actor:** Admin
- **Precondición:** Venta existe en el sistema.
- **Flujo Principal:**
    1. Admin navega a historial de ventas.
    2. Selecciona venta a anular.
    3. Pulsa "Anular" → Modal de confirmación.
    4. Ingresa razón obligatoria: "Cliente devolvió producto".
    5. Sistema revierte stock, registra anulación en auditoría.
- **Postcondición:** Venta anulada, stock revertido, razón registrada.

---

## Requisitos de Datos (Para Equipo Data)

**Entidad Venta:**
- Identificador único
- Número de ticket (secuencial para UI)
- Relación con Tienda
- Relación con Empleado
- Relación con Cliente (si fiado)
- Items (estructura con productos, cantidades, precios)
- Total
- Método de pago
- Monto recibido (si efectivo)
- Vueltas
- Diferencia de redondeo
- Estado de sincronización
- Estado de anulación
- Usuario que anuló (si aplica)
- Razón de anulación (si aplica)
- Timestamps

---

## Criterios de Aceptación

- [ ] POS bloqueado si caja cerrada, inventario vacío o sin permiso.
- [ ] Validación de stock impide agregar items sin existencia.
- [ ] Límite de 50 items por venta con mensaje informativo.
- [ ] Redondeo a $50 aplicado en subtotales y total.
- [ ] Venta Fiado valida cupo disponible del cliente.
- [ ] Botón "Anular" solo visible para Admin.
- [ ] Ventas sin conexión se almacenan y sincronizan automáticamente.
- [ ] Cada venta genera número de ticket secuencial.
- [ ] La diferencia de redondeo se registra en cada venta.
