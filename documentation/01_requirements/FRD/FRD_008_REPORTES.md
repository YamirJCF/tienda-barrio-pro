# FRD-008: Resumen Diario Inteligente (Módulo Primario)

### Nombre de la Funcionalidad
Resumen Diario Inteligente / Smart Daily Summary

#### Descripción
Sistema de visualización de información comercial diseñado para usuarios no técnicos. Presenta el estado del negocio en formato conversacional que responde las 3 preguntas fundamentales del tendero: ¿Cuánto vendí?, ¿Dónde está el dinero?, y ¿Qué debo atender?

---

## Principio de Diseño

El usuario DEBE entender el estado de su negocio en **menos de 5 segundos**. Cero porcentajes, cero gráficas complejas, cero terminología técnica.

---

## Reglas de Negocio

> [!IMPORTANT]
> **Políticas Globales Obligatorias:**
> Este módulo DEBE cumplir:
> - [SPEC-011: Estándar de Decimales](../TECH_SPECS/decimal-format-standard.md)

### Políticas de Formato

- Todos los montos se muestran como enteros sin decimales.
- Formato: Separador de miles con punto (ej: $185.500).

---

### Estructura del Resumen

El resumen se compone de 5 zonas jerárquicas (de arriba hacia abajo):

| Zona | Contenido | Prioridad Visual |
|------|-----------|------------------|
| **A. Encabezado** | Fecha + Indicador Semáforo | Pequeña |
| **B. Número Héroe** | Ventas totales del día | MUY GRANDE |
| **C. Desglose de Dinero** | Efectivo / Nequi / Fiado | Media |
| **D. Alertas** | Máximo 2 alertas activas | Destacada |
| **E. Recordatorio** | Acción sugerida para mañana | Destacada |

---

### Indicador Semáforo (Zona A)

Compara ventas de hoy vs promedio de los últimos 7 días:

| Estado | Color | Condición |
|--------|-------|-----------|
| Excelente | Verde | Ventas > promedio + 10% |
| Normal | Amarillo | Ventas entre ±10% del promedio |
| Bajo | Rojo | Ventas < promedio - 10% |

Al tocar el indicador: Modal explicativo con "Hoy vendiste $X, tu promedio es $Y".

---

### Desglose de Dinero (Zona C)

Cada línea es interactiva (tocar para profundizar):

| Línea | Descripción | Al tocar |
|-------|-------------|----------|
| Efectivo | Suma de ventas en efectivo del día | Lista de ventas en efectivo |
| Nequi | Suma de ventas Nequi del día | Lista de ventas Nequi |
| Fiado | Suma de ventas fiadas del día | Ir a lista de clientes con deuda |

---

### Sistema de Alertas (Zona D)

Máximo 2 alertas visibles (las más urgentes). Prioridad:

| Prioridad | Tipo | Condición | Mensaje |
|-----------|------|-----------|---------|
| 1 | Stock Crítico | Stock = 0 | "[Producto] se agotó" |
| 2 | Stock Bajo | Stock < mínimo | "[Producto] casi se acaba (quedan X)" |
| 3 | Fiado Grande | Venta fiado > $50,000 hoy | "Vendiste $X a [Cliente] a crédito" |

Al tocar alerta: Navegar al producto o cliente correspondiente.

---

### Recordatorio Inteligente (Zona E)

Generado automáticamente según prioridad:

| Prioridad | Condición | Mensaje |
|-----------|-----------|---------|
| 1 | Hay ventas Nequi hoy | "Mañana recuerda: Revisar Nequi ($X)" |
| 2 | Hay fiados pendientes | "Mañana recuerda: Cobrar a [Cliente con mayor deuda]" |
| 3 | Hay productos stock bajo | "Mañana recuerda: Pedir [Producto más urgente]" |
| 4 | Ninguna de las anteriores | "¡Todo en orden! Descansa bien 😊" |

---

### Matriz de Permisos

| Zona | Admin | Empleado con `canViewReports` | Empleado sin permiso |
|------|-------|-------------------------------|----------------------|
| Ver Resumen | ✅ | ✅ | ❌ (Bloqueado) |
| Tocar Efectivo/Nequi | ✅ | ✅ | - |
| Tocar Fiado (ir a clientes) | ✅ | ❌ | - |
| Ver Alertas | ✅ | ✅ | - |
| Ver Recordatorio | ✅ | ✅ | - |

---

## Estados de la Interfaz

### Estado: Cargando
- Mostrar esqueleto animado de 3 líneas.
- Duración máxima visible: 3 segundos (mostrar error si excede).

### Estado: Sin Ventas
- Mostrar "$0" con mensaje: "Hoy no has vendido nada aún".
- Mensaje motivacional: "¡Ánimo! Tu primer cliente está por llegar."

### Estado: Error de Conexión
- Mostrar mensaje: "No pudimos cargar el resumen".
- Instrucción: "Revisa tu conexión a internet y vuelve a intentar."
- Botón: "Reintentar"

---

## Lenguaje de la Interfaz

**Regla de Oro:** No usar terminología técnica. Todo en lenguaje conversacional.

| ❌ NO decir | ✅ SÍ decir |
|-------------|-------------|
| "Crecimiento +15.3%" | "Vendiste $20,000 más que ayer" |
| "Total: $185,500" | "Hoy vendiste $185,500" |
| "Método de pago: Cash" | "💵 Efectivo: $120,000 (en caja)" |
| "Stock: 2 / Min: 5" | "Azúcar casi se acaba (quedan 2)" |
| "Pending collections" | "📖 Por cobrar: $20,500" |

---

## Casos de Uso

**Caso A: Consultar Resumen al Cerrar Turno**
- **Actor:** Usuario con permiso de reportes
- **Precondición:** Hay ventas registradas hoy.
- **Flujo Principal:**
    1. Usuario navega a Reportes desde el menú.
    2. Sistema muestra resumen diario con fecha de hoy.
    3. Usuario ve indicador semáforo + monto total + desglose.
    4. Usuario toca "Fiado $20,500".
    5. Sistema navega a lista de clientes con deuda.
- **Postcondición:** Usuario informado del estado del negocio.

**Caso B: Revisar Alertas de Stock**
- **Actor:** Admin
- **Precondición:** Hay productos con stock bajo.
- **Flujo Principal:**
    1. Usuario ve alerta: "Azúcar casi se acaba (quedan 2)".
    2. Toca la alerta.
    3. Sistema navega a la ficha del producto.
    4. Usuario puede registrar entrada de stock.
- **Postcondición:** Usuario atendió la alerta.

---

## Criterios de Aceptación

### Rendimiento
- [ ] El resumen carga en menos de 2 segundos.
- [ ] El indicador semáforo se calcula correctamente vs promedio 7 días.

### UX
- [ ] Usuario entiende el estado del negocio en menos de 5 segundos.
- [ ] Cero números con decimales visibles.
- [ ] Cero porcentajes visibles.
- [ ] Cada línea del desglose responde al toque con feedback visual.
- [ ] Existe estado vacío con mensaje motivacional.
- [ ] Existe estado de carga con esqueleto.

### Funcionalidad
- [ ] Tocar Efectivo muestra lista de ventas del día.
- [ ] Tocar Fiado navega a clientes.
- [ ] Tocar Alerta navega al producto/cliente relacionado.
- [ ] Recordatorio se genera automáticamente según prioridad.
