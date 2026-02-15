# FRD: Módulo de Reportes e Historiales Inteligentes
## Functional Requirements Document

---

**Proyecto:** Tienda de Barrio Pro  
**Módulo:** Reportes e Historiales  
**Versión:** 1.0  
**Fecha:** 15 de Febrero, 2026  
**Autor:** Arquitecto de Requisitos Senior  
**Estado:** Propuesta para Aprobación

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Análisis del Estado Actual](#2-análisis-del-estado-actual)
3. [Problema de Negocio](#3-problema-de-negocio)
4. [Objetivos y Métricas de Éxito](#4-objetivos-y-métricas-de-éxito)
5. [Solución Propuesta](#5-solución-propuesta)
6. [Arquitectura de Datos](#6-arquitectura-de-datos)
7. [Especificación Funcional](#7-especificación-funcional)
8. [Casos de Uso Detallados](#8-casos-de-uso-detallados)
9. [Requisitos No Funcionales](#9-requisitos-no-funcionales)
10. [Análisis Costo-Beneficio](#10-análisis-costo-beneficio)
11. [Roadmap de Implementación](#11-roadmap-de-implementación)
12. [Riesgos y Mitigación](#12-riesgos-y-mitigación)
13. [Criterios de Aceptación](#13-criterios-de-aceptación)
14. [Apéndices](#14-apéndices)

---

## 1. Resumen Ejecutivo

### 1.1. Contexto

El sistema actual de Reportes e Historiales tiene una **infraestructura técnica sólida** (6 tipos de historiales, RPCs especializadas, datos limpios) pero **bajo valor de negocio** para el usuario final. Los tenderos tienen acceso a logs técnicos pero no a información accionable para tomar decisiones estratégicas.

### 1.2. Oportunidad

Transformar el módulo de Reportes e Historiales en el **centro de inteligencia de negocio** de la aplicación, permitiendo al tendero:
- **Ver ganancias reales**, no solo ventas brutas
- **Identificar productos estrella** y productos estancados
- **Optimizar inventario** con datos de rotación
- **Detectar anomalías** en caja y comportamiento de empleados
- **Tomar decisiones** basadas en tendencias, no en intuición

### 1.3. Propuesta de Valor

**"De Logs Técnicos a Decisiones de Negocio"**

Convertir datos transaccionales en insights accionables mediante 3 niveles de reportes:

1. **Dashboard Ejecutivo** → Decisiones estratégicas (qué comprar, qué promocionar)
2. **Reportes Operativos** → Operación diaria (evitar faltantes de stock)
3. **Auditoría Detallada** → Investigación de discrepancias

### 1.4. Impacto Esperado

| Métrica | Estado Actual | Meta |
|---------|---------------|------|
| Tiempo para ver ganancia neta | No disponible | < 3 segundos |
| Decisiones de compra informadas | 0% (intuición) | 80% (basadas en datos) |
| Detección de faltantes de caja | Reactiva (al cierre) | Proactiva (en tiempo real) |
| Uso del módulo de Reportes | < 5% de usuarios | > 60% de usuarios |

---

## 2. Análisis del Estado Actual

### 2.1. Inventario de Funcionalidad Existente

#### Reportes Actuales

| Reporte | Ubicación | Frecuencia de Uso | Valor Aportado |
|---------|-----------|-------------------|----------------|
| **Daily Summary** | AdminHub | Alta | ⭐⭐⭐ Moderado (solo ventas brutas) |
| **Smart Supply** | AdminHub | Media | ⭐⭐⭐⭐ Alto (pero de solo lectura) |
| **Historiales** | HistoryView | Baja | ⭐⭐ Bajo (logs técnicos) |

#### Historiales Actuales

| Tipo | Fuente de Datos | Caso de Uso Real |
|------|-----------------|------------------|
| Ventas | `sales` | Verificar ticket anulado |
| Caja | `cash_sessions` | Investigar faltante |
| Compras | `inventory_movements` | Rastrear entrada de mercancía |
| Auditoría | `audit_logs` | Detectar acceso no autorizado |
| Gastos | `expenses` | Contabilizar egresos |
| Precios | `price_change_logs` | Revisar histórico de ajustes |

### 2.2. Problemas Identificados

#### Problema Crítico #1: Ceguera de Márgenes

**Descripción:** El sistema no tiene el costo de compra de productos.

**Evidencia Técnica:**
- Tabla `products` NO tiene columna `cost` o `purchase_price`
- Tabla `sale_items` guarda `unit_price` (venta) pero NO `unit_cost`
- RPC `get_daily_summary` solo suma ventas, matemáticamente imposible calcular ganancia

**Impacto en Negocio:**
- El tendero NO sabe si está ganando o perdiendo dinero
- No puede identificar productos con bajo margen
- Decisiones de precio basadas en intuición, no en datos

**Clasificación:** 🔴 **BLOQUEANTE** para Dashboard Ejecutivo

---

#### Problema Crítico #2: Información Sin Contexto

**Descripción:** Los historiales muestran transacciones pero no patrones.

**Ejemplos:**
- Ver "50 ventas en el día" NO dice "¿qué productos se vendieron más?"
- Ver "Faltante de $20,000 en caja" NO dice "¿cuándo ocurre usualmente?"
- Ver "100 productos en inventario" NO dice "¿cuáles están estancados?"

**Impacto en Negocio:**
- El tendero pierde tiempo analizando manualmente
- No puede anticipar problemas (ej: stock bajo antes de que ocurra)
- Decisiones reactivas en lugar de proactivas

**Clasificación:** 🟡 **IMPORTANTE** para UX y retención

---

#### Problema #3: UI No Accionable

**Descripción:** Los historiales son listas estáticas sin acciones.

**Evidencia:**
- Hacer clic en una venta NO muestra detalle de productos
- No hay búsqueda por ticket, cliente o producto
- Filtros rígidos (Hoy/Ayer/Semana/Mes), no rangos personalizados
- Smart Supply muestra sugerencias pero no permite crear Orden de Compra

**Impacto en Negocio:**
- Frustración del usuario (información inaccesible)
- Bajo uso del módulo (< 5% de engagement)

**Clasificación:** 🟡 **IMPORTANTE** para adopción

---

### 2.3. Fortalezas a Mantener

✅ **Arquitectura Backend-First:** Cálculos en RPC garantizan consistencia  
✅ **Separación de Responsabilidades:** Reportes vs Historiales tienen propósitos distintos  
✅ **Datos Limpios:** Soft delete, audit trail, integridad referencial  
✅ **Smart Supply:** Ya identifica productos críticos (solo necesita mejora de UX)

---

## 3. Problema de Negocio

### 3.1. Preguntas Sin Responder

El tendero necesita responder estas preguntas **críticas para su negocio**:

#### Preguntas Financieras (Urgentes)

| Pregunta | Estado Actual | Impacto en Negocio |
|----------|---------------|---------------------|
| ¿Cuánto **gané** hoy? (no vendí) | ❌ No responde | No sabe si el negocio es rentable |
| ¿Qué productos me dan más **utilidad**? | ❌ No responde | Invierte en productos equivocados |
| ¿Cuánto tengo en **efectivo** vs **bancos**? | ⚠️ Existe pero oculto | Problemas de flujo de caja |
| ¿Quién me debe dinero? | ⚠️ En otro módulo | Cartera vencida sin cobrar |

#### Preguntas Operativas (Estratégicas)

| Pregunta | Estado Actual | Impacto en Negocio |
|----------|---------------|---------------------|
| ¿Qué productos se están **acabando ahora**? | ✅ Smart Supply | Funciona, mantener |
| ¿Qué productos **NO se venden**? | ❌ No responde | Inventario estancado |
| ¿Mis ventas suben o bajan vs semana pasada? | ⚠️ Solo semáforo 7 días | Análisis superficial |
| ¿Algún empleado tiene comportamiento sospechoso? | ⚠️ Log de auditoría sin análisis | Detección tardía de fraude |

### 3.2. Costo de Oportunidad

**Sin este módulo mejorado:**
- Tendero toma decisiones a ciegas
- Compra productos que no rotan
- No cobra fiados vencidos
- Descubre robos después de meses

**Con este módulo:**
- Decisiones basadas en datos
- Inventario optimizado (menos capital inmovilizado)
- Flujo de caja predecible
- Detección temprana de anomalías

---

## 4. Objetivos y Métricas de Éxito

### 4.1. Objetivos de Negocio

| Objetivo | Descripción | Prioridad |
|----------|-------------|-----------|
| **O1** | Permitir al tendero ver **ganancia neta** en tiempo real | 🔴 Crítico |
| **O2** | Identificar **top 10 productos** por ventas y margen | 🔴 Crítico |
| **O3** | Detectar **productos estancados** (0 ventas en 30 días) | 🟡 Importante |
| **O4** | Mostrar **desglose de dinero** (efectivo/bancos/fiado) | 🔴 Crítico |
| **O5** | Comparar ventas **Hoy vs Semana vs Mes** | 🟡 Importante |
| **O6** | Mantener **trazabilidad completa** (auditoría) | 🟢 Mantener |

### 4.2. KPIs de Éxito

| KPI | Métrica | Meta |
|-----|---------|------|
| **Adopción** | % de usuarios que abren Reportes diariamente | > 60% |
| **Time to Insight** | Tiempo para ver ganancia neta | < 3 seg |
| **Decisiones Informadas** | % de compras basadas en Top Ventas/Estancados | > 50% |
| **Satisfacción** | NPS del módulo de Reportes | > 8/10 |

### 4.3. Métricas Técnicas

| Métrica | Target | Justificación |
|---------|--------|---------------|
| **Tiempo de respuesta RPC** | < 500ms | Dashboard debe sentirse instantáneo |
| **Tamaño de payload** | < 50KB | Performance en redes 3G |
| **Disponibilidad** | 99.5% | Datos críticos para operación diaria |

---

## 5. Solución Propuesta

### 5.1. Visión General

**"Dashboard Inteligente de 3 Niveles"**

Transformar el módulo de Reportes e Historiales en una jerarquía de información:

```
┌─────────────────────────────────────┐
│  Nivel 1: Dashboard Ejecutivo       │ ← Decisiones Estratégicas
│  (Vista Principal: FinancialDashboard) │
│  • Ganancia Neta                    │
│  • Top Ventas / Estancados          │
│  • Desglose de Dinero               │
│  • Fiado Pendiente                  │
└─────────────────────────────────────┘
            ↓ "Ver Detalle"
┌─────────────────────────────────────┐
│  Nivel 2: Reportes Operativos       │ ← Operación Diaria
│  (Vista: Daily Summary + Smart Supply)│
│  • Ventas del Turno                 │
│  • Alertas de Stock Bajo            │
│  • Semáforo de Performance          │
└─────────────────────────────────────┘
            ↓ "Investigar"
┌─────────────────────────────────────┐
│  Nivel 3: Auditoría Detallada       │ ← Investigación
│  (Vista: HistoryView)               │
│  • Log Transaccional Completo       │
│  • Filtros Avanzados                │
│  • Búsqueda por Texto               │
└─────────────────────────────────────┘
```

### 5.2. Componentes Nuevos

#### 5.2.1. Dashboard Ejecutivo (Nuevo)

**Inspiración:** Mockup descartado (imagen proporcionada)

**Pantalla Principal:**
```
┌───────────────────────────────────────┐
│  Reportes                          ⋮  │
├───────────────────────────────────────┤
│  [Hoy] [Semana] [Mes]                 │
├───────────────────────────────────────┤
│  ┌─────────────────────────────────┐  │
│  │ Ventas Totales                  │  │
│  │ $850.000                        │  │
│  │                                 │  │
│  │ COSTO MERCANCÍA   GANANCIA NETA │  │
│  │ $600.000          📈 +$250.000  │  │
│  │                                 │  │
│  │ ℹ️ Esto es lo que te queda      │  │
│  │   libre teóricamente            │  │
│  └─────────────────────────────────┘  │
│                                       │
│  ¿DÓNDE ESTÁ EL DINERO?               │
│  ┌──────────┐ ┌──────────┐           │
│  │ 💵       │ │ 📱       │           │
│  │ Efectivo │ │ Nequi/Dav│           │
│  │ $400.000 │ │ $300.000 │           │
│  │ Debe     │ │ En bancos│           │
│  │ estar en │ │          │           │
│  │ cajón    │ │          │           │
│  └──────────┘ └──────────┘           │
│  ┌─────────────────────────────────┐  │
│  │ 📋 Fiado Hoy        [Por cobrar]│  │
│  │ $150.000                        │  │
│  └─────────────────────────────────┘  │
│                                       │
│  DECISIONES DE COMPRA                 │
│  [🔥 Top Ventas] [⚠️ Stock Bajo 2]   │
│  [❄️ Estancados]                      │
│                                       │
│  #1  Arroz Diana           54 UNDS   │
│  ████████████████████████░░░░░░       │
│  #2  Aceite Gourmet 1L     42 UNDS   │
│  █████████████████░░░░░░░░░░░░        │
│  #3  Coca-Cola 1.5L        36 UNDS   │
│  ███████████████░░░░░░░░░░░░░         │
│                                       │
│  [Ver todo el reporte →]              │
└───────────────────────────────────────┘
```

**Diferencias con Mockup Original:**
- Mantiene la estructura visual
- Agrega pestañas Hoy/Semana/Mes (no solo "Hoy")
- "Ver todo el reporte" lleva a vista detallada (no solo lista más larga)

#### 5.2.2. Reportes Operativos (Mejora)

**Cambios mínimos:**
- Mantener Daily Summary actual
- Mantener Smart Supply actual
- Agregar integración: "Crear Orden de Compra" desde Smart Supply

#### 5.2.3. Auditoría Detallada (Mejora)

**Mejoras UX:**
- Agregar búsqueda por texto (ticket, producto, cliente)
- Permitir rangos de fecha personalizados (selector de calendario)
- Mostrar detalle expandido al hacer clic (modal con items de venta)
- Agregar totalizadores por pestaña (ej: "Total vendido en período: $X")

### 5.3. Decisiones de Diseño

#### Decisión #1: Mantener Historiales Distribuidos

**Alternativa Evaluada:** Crear tabla unificada `history`

**Decisión:** Mantener arquitectura actual (6 tablas separadas)

**Justificación:**
- ✅ Cada tipo tiene campos específicos (ventas ≠ auditoría)
- ✅ Performance: Queries especializadas más rápidas
- ✅ Mantenibilidad: Cambios en ventas no afectan auditoría
- ❌ Contra: Complejidad al consultar "todas las actividades del día"

**Acción:** Crear RPC `get_unified_timeline` si se necesita vista consolidada

---

#### Decisión #2: Calcular Ganancia en Backend

**Alternativa Evaluada:** Calcular en frontend sumando costos

**Decisión:** RPC `get_financial_summary` calcula en backend

**Justificación:**
- ✅ Consistencia: Todos ven la misma cifra
- ✅ Performance: SQL optimizado > loops en JS
- ✅ Seguridad: No exponer lógica financiera en cliente
- ✅ Auditabilidad: Logs de RPC rastrean cálculos

---

#### Decisión #3: Priorizar Dashboard sobre Historiales

**Alternativa Evaluada:** Mejorar Historiales primero

**Decisión:** Implementar Dashboard Ejecutivo (Fase 1), luego mejorar Historiales (Fase 3)

**Justificación:**
- ✅ Mayor impacto: Dashboard responde preguntas críticas
- ✅ ROI más alto: 60% de usuarios lo usarán vs 15% de Historiales
- ✅ Diferenciador: Competencia NO tiene ganancia neta visible

---

## 6. Arquitectura de Datos

### 6.1. Cambios en Base de Datos

#### 6.1.1. Nueva Columna: `products.cost`

**Objetivo:** Rastrear costo de compra para calcular márgenes

**Cambios:**

```
Tabla: products
Columnas Nuevas:
  • cost                  DECIMAL(10,2)  NOT NULL DEFAULT 0
  • last_purchase_price   DECIMAL(10,2)
  • last_purchase_date    TIMESTAMPTZ
  
Índices:
  • idx_products_cost ON products(cost) WHERE cost > 0
```

**Cálculo de `cost`:**
- **Método:** Costo Promedio Ponderado (Weighted Average Cost)
- **Fórmula:** `cost = (stock_anterior * costo_anterior + entrada * costo_entrada) / (stock_anterior + entrada)`
- **Actualización:** Al registrar entrada en `inventory_movements`

**Ejemplo:**
```
Estado inicial: 10 unidades a $1,000 = $10,000
Entrada: 20 unidades a $1,200 = $24,000
Nuevo cost = ($10,000 + $24,000) / (10 + 20) = $1,133.33
```

---

#### 6.1.2. Nueva Columna: `sale_items.unit_cost`

**Objetivo:** Guardar costo histórico al momento de la venta (para calcular margen a posteriori)

**Cambios:**

```
Tabla: sale_items
Columnas Nuevas:
  • unit_cost  DECIMAL(10,2)  NOT NULL DEFAULT 0
  
Índices:
  • idx_sale_items_unit_cost ON sale_items(unit_cost)
```

**Justificación:**
- Si el costo cambia después de la venta, necesitamos el costo **al momento de venta**
- Permite calcular ganancia histórica precisa (ej: "Cuánto gané en Diciembre 2024")

---

#### 6.1.3. Nuevas Columnas: `inventory_movements`

**Objetivo:** Rastrear valor monetario de entradas/salidas

**Cambios:**

```
Tabla: inventory_movements
Columnas Nuevas:
  • unit_cost   DECIMAL(10,2)
  • total_cost  DECIMAL(10,2)
```

**Casos de Uso:**
- Entrada: Guardar precio de compra al proveedor
- Salida: Guardar costo promedio al momento de la venta
- Permite rastrear: "¿Cuánto invertí en inventario este mes?"

---

### 6.2. Nuevas RPCs (Backend)

#### RPC #1: `get_financial_summary`

**Propósito:** Dashboard Ejecutivo - Ventas, Costos, Ganancias

**Parámetros:**
```sql
p_store_id    UUID        (obligatorio)
p_start_date  DATE        (default: CURRENT_DATE)
p_end_date    DATE        (default: CURRENT_DATE)
```

**Retorno (JSONB):**
```json
{
  "total_sales": 850000,
  "total_cost": 600000,
  "net_profit": 250000,
  "profit_margin": 29.41,
  "money_breakdown": {
    "cash": 400000,
    "transfer": 300000,
    "credit": 150000
  },
  "fiado_pendiente": 150000,
  "traffic_light": {
    "status": "green",
    "message": "🚀 ¡Vas un 15% arriba de tu promedio!"
  }
}
```

**Lógica:**
1. Suma `sales.total` (WHERE `is_voided = FALSE`)
2. Suma `sale_items.quantity * sale_items.unit_cost`
3. Calcula `net_profit = total_sales - total_cost`
4. Desglose por `sales.payment_method`
5. Suma `clients.pending_balance` para fiado
6. Compara con promedio 7 días para semáforo

---

#### RPC #2: `get_top_selling_products`

**Propósito:** Identificar productos estrella y estancados

**Parámetros:**
```sql
p_store_id    UUID        (obligatorio)
p_start_date  DATE        (default: CURRENT_DATE)
p_end_date    DATE        (default: CURRENT_DATE)
p_limit       INTEGER     (default: 10)
```

**Retorno (Table):**
```sql
product_id      UUID
product_name    TEXT
units_sold      INTEGER
revenue         DECIMAL(10,2)
profit          DECIMAL(10,2)
stock_remaining INTEGER
stock_status    TEXT ('critical' | 'low' | 'ok')
```

**Lógica:**
1. JOIN `products` ⟷ `sale_items` ⟷ `sales`
2. GROUP BY `product_id`
3. SUM(`quantity`) AS `units_sold`
4. SUM(`subtotal`) AS `revenue`
5. SUM(`quantity * (unit_price - unit_cost)`) AS `profit`
6. ORDER BY `units_sold DESC`
7. Clasificar stock: `critical` si <= `min_stock`, `low` si <= `min_stock * 1.5`

---

#### RPC #3: `get_stagnant_products`

**Propósito:** Identificar productos sin ventas en X días

**Parámetros:**
```sql
p_store_id       UUID        (obligatorio)
p_days_threshold INTEGER     (default: 30)
```

**Retorno (Table):**
```sql
product_id         UUID
product_name       TEXT
last_sale_date     DATE
days_stagnant      INTEGER
stock_value        DECIMAL(10,2)  -- current_stock * cost
```

**Lógica:**
1. LEFT JOIN `products` ⟷ `sale_items` ⟷ `sales`
2. WHERE `last_sale_date < CURRENT_DATE - p_days_threshold` OR `last_sale_date IS NULL`
3. Calcular `stock_value = current_stock * cost` (capital inmovilizado)
4. ORDER BY `days_stagnant DESC`

---

### 6.3. Migración de Datos Existentes

#### Estrategia: Estimación Conservadora

**Problema:** Sistema actual NO tiene costos históricos.

**Opciones:**

| Opción | Pros | Contras |
|--------|------|---------|
| A. Solicitar costos reales al usuario | ✅ Datos precisos | ❌ Fricción, posible abandono |
| B. Estimar con margen estándar (30%) | ✅ Sin fricción | ❌ Impreciso |
| C. Dejar costos en $0 hasta primera compra | ✅ Honesto | ❌ Dashboard no funcional inicialmente |

**Decisión:** Opción B (Estimación) + Flag de Advertencia

**Implementación:**
```sql
-- Migración inicial: Asumir margen del 30%
UPDATE products
SET cost = price * 0.70  -- 70% del precio de venta
WHERE cost = 0;

-- Actualizar sale_items históricos
UPDATE sale_items si
SET unit_cost = (SELECT cost FROM products WHERE id = si.product_id)
WHERE unit_cost = 0;
```

**UI:** Mostrar banner en Dashboard:
```
⚠️ Los costos son estimados. Actualiza los costos reales en Inventario para mayor precisión.
[Ir a Inventario] [No volver a mostrar]
```

---

## 7. Especificación Funcional

### 7.1. Feature #1: Dashboard Ejecutivo

#### F1.1. Pantalla Principal

**Ruta:** `/admin/financial-dashboard`  
**Acceso:** Admin + Empleados con permiso `canViewReports`

**Componentes:**

1. **Header con Pestañas de Período**
   - Botones: [Hoy] [Semana] [Mes]
   - Al cambiar: Recarga datos con nuevo rango de fechas
   - Estado activo: Fondo azul, texto blanco

2. **Card "Ventas Totales"**
   - Hero Number: Ventas totales en grande ($850.000)
   - Subcards: Costo Mercancía | Ganancia Neta
   - Ganancia Neta: Verde con ícono 📈, rojo si negativa con ⚠️
   - Nota informativa: "Esto es lo que te queda libre teóricamente"

3. **Sección "¿Dónde Está el Dinero?"**
   - Cards horizontales:
     - Efectivo (💵) + "Debe estar en cajón"
     - Nequi/Daviplata (📱) + "En bancos"
   - Card adicional si `fiado_pendiente > 0`:
     - Fiado Hoy (📋) + Badge "Por cobrar"

4. **Sección "Decisiones de Compra"**
   - Sub-pestañas: [🔥 Top Ventas] [⚠️ Stock Bajo] [❄️ Estancados]
   - Lista de productos con ranking (#1, #2, #3...)
   - Barra visual de intensidad (roja para top, amarilla para medio, gris para bajo)
   - Unidades vendidas alineadas a la derecha
   - Botón "Ver todo el reporte →" lleva a vista detallada

#### F1.2. Interacciones

| Acción | Resultado |
|--------|-----------|
| Cambiar pestaña (Hoy/Semana/Mes) | Recarga datos, actualiza todas las cards |
| Clic en "Ver todo el reporte" | Navega a `/admin/reports/detailed` con filtro activo |
| Clic en producto en Top Ventas | Muestra modal con gráfico de tendencia de ventas |
| Clic en badge "Stock Bajo" | Cambia a sub-pestaña Stock Bajo |

#### F1.3. Estados de Carga

- **Cargando:** Skeleton screens en cards
- **Error:** Banner rojo "No se pudieron cargar los datos. [Reintentar]"
- **Sin Datos:** Mensaje "No hay ventas en este período" con ilustración

---

### 7.2. Feature #2: Detalle de Top Ventas

**Ruta:** `/admin/reports/detailed?tab=top_sales`

**Contenido:**
- Tabla completa con columnas:
  - Ranking | Producto | Unidades Vendidas | Ingresos | Ganancia | Stock Actual
- Filtros:
  - Período (selector de rango)
  - Categoría de producto (dropdown)
- Gráfico de barras: Top 10 productos
- Exportación: CSV (si se aprueba feature)

---

### 7.3. Feature #3: Productos Estancados

**Ruta:** `/admin/reports/detailed?tab=stagnant`

**Contenido:**
- Lista de productos sin ventas en 30 días
- Columnas:
  - Producto | Última Venta | Días Sin Vender | Stock Actual | Valor Inmovilizado
- Acciones:
  - [Hacer Promoción] → Sugiere descuento (ej: "Rebaja 20% para liquidar")
  - [Marcar para Devolución] → Agrega a lista de devolución a proveedor

---

### 7.4. Feature #4: Mejoras en Historiales

#### F4.1. Búsqueda Global

- Input de texto arriba de las pestañas
- Placeholder: "Buscar ticket, producto o cliente..."
- Búsqueda en tiempo real (debounce 300ms)
- Resultados resaltados en amarillo

#### F4.2. Filtro de Rango de Fechas

- Reemplazar presets (Hoy/Ayer/Semana/Mes) con:
  - Selector de calendario (DateRangePicker)
  - Presets rápidos como atajos ("Esta semana", "Mes pasado")

#### F4.3. Detalle Expandido

- Clic en venta → Modal con:
  - Ticket completo (productos, cantidades, precios)
  - Método de pago
  - Empleado que vendió
  - Botón "Imprimir Ticket"

---

## 8. Casos de Uso Detallados

### UC-01: Ver Ganancia del Día

**Actor:** Dueño de tienda  
**Precondición:** Sesión activa, tiene permiso `canViewReports`  
**Disparador:** Abre app al final del día

**Flujo Principal:**
1. Usuario navega a "Administración" → "Reportes"
2. Sistema muestra Dashboard Ejecutivo con pestaña "Hoy" activa
3. Sistema llama `get_financial_summary(store_id, today, today)`
4. Sistema muestra:
   - Ventas Totales: $850,000
   - Costo Mercancía: $600,000
   - Ganancia Neta: $250,000 (verde)
5. Usuario ve que ganó $250,000

**Flujo Alternativo 3a: Error en RPC**
- Sistema muestra banner "Error al cargar datos. [Reintentar]"
- Usuario hace clic en "Reintentar" → Regresa a paso 3

**Postcondición:** Usuario conoce su ganancia real, no solo ventas brutas

---

### UC-02: Identificar Productos para Reordenar

**Actor:** Dueño de tienda  
**Precondición:** Dashboard Ejecutivo abierto  
**Disparador:** Usuario quiere saber qué comprar al proveedor

**Flujo Principal:**
1. Usuario observa sección "Decisiones de Compra"
2. Usuario hace clic en sub-pestaña "🔥 Top Ventas"
3. Sistema muestra:
   - #1 Arroz Diana - 54 unidades (barra casi llena)
   - #2 Aceite Gourmet 1L - 42 unidades
   - #3 Coca-Cola 1.5L - 36 unidades
4. Usuario identifica que Arroz Diana es el producto más vendido
5. Usuario hace clic en "Ver todo el reporte"
6. Sistema muestra tabla completa con stock actual:
   - Arroz Diana: 54 vendidos, **5 quedan** (crítico)
7. Usuario decide comprar 100 unidades de Arroz Diana al proveedor

**Flujo Alternativo 6a: Usuario quiere ver tendencia**
- Usuario hace clic en "Arroz Diana" en la fila
- Sistema muestra gráfico de ventas de los últimos 7 días
- Usuario confirma que es tendencia alcista, no pico puntual

**Postcondición:** Usuario toma decisión de compra informada

---

### UC-03: Detectar Productos Estancados

**Actor:** Dueño de tienda  
**Precondición:** Dashboard Ejecutivo abierto  
**Disparador:** Usuario quiere liberar capital inmovilizado

**Flujo Principal:**
1. Usuario hace clic en sub-pestaña "❄️ Estancados"
2. Sistema llama `get_stagnant_products(store_id, 30)`
3. Sistema muestra lista:
   - Shampoo Marca X: 45 días sin venta, 20 unidades, $40,000 inmovilizados
   - Galletas Y: 60 días sin venta, 30 unidades, $30,000
4. Usuario identifica que tiene $70,000 en inventario que no rota
5. Usuario hace clic en "Hacer Promoción" en Shampoo Marca X
6. Sistema sugiere: "Rebaja 20% (nuevo precio: $4,000) para liquidar"
7. Usuario aplica promoción

**Postcondición:** Usuario libera capital para invertir en productos que sí rotan

---

### UC-04: Investigar Faltante de Caja

**Actor:** Dueño de tienda  
**Precondición:** Cierre de caja muestra faltante de $20,000  
**Disparador:** Usuario necesita entender por qué falta dinero

**Flujo Principal:**
1. Usuario navega a "Historial" → Pestaña "Caja"
2. Usuario selecciona rango de fecha (selector de calendario): "Última semana"
3. Sistema muestra sesiones de caja con columnas:
   - Fecha | Empleado | Balance Inicial | Ventas | Balance Final | Diferencia
4. Usuario observa patrón:
   - Martes (Juan): -$5,000
   - Jueves (Juan): -$8,000
   - Viernes (Juan): -$7,000
5. Usuario identifica que Juan tiene faltantes consistentes
6. Usuario hace clic en sesión del Jueves
7. Sistema muestra detalle:
   - Ventas registradas: $100,000
   - Efectivo esperado: $100,000
   - Efectivo contado: $92,000
8. Usuario revisa con Juan, descubre error en conteo de billetes

**Flujo Alternativo 8a: Faltante no justificado**
- Usuario sospecha de fraude
- Usuario navega a "Historial" → Pestaña "Auditoría"
- Usuario filtra por empleado "Juan"
- Usuario revisa log de accesos y transacciones anuladas

**Postcondición:** Usuario identifica causa de faltante y toma acción correctiva

---

## 9. Requisitos No Funcionales

### 9.1. Performance

| Requisito | Target | Medición |
|-----------|--------|----------|
| **RNF-01** | Carga de Dashboard < 2 seg | Time to First Contentful Paint |
| **RNF-02** | Cambio de pestaña < 500ms | Latencia de RPC |
| **RNF-03** | Búsqueda en historiales < 300ms | Query response time |
| **RNF-04** | Soporte de 1,000 productos | Stress test con dataset |

**Estrategias de Optimización:**
- Índices en columnas de filtrado frecuente (`created_at`, `store_id`)
- Paginación en historiales (cargar 50 registros, lazy load al scroll)
- Cache en frontend (TTL 30 segundos para Dashboard)

---

### 9.2. Seguridad

| Requisito | Descripción |
|-----------|-------------|
| **RNF-05** | RLS en todas las RPCs (solo datos del `store_id` del usuario) |
| **RNF-06** | Empleados sin `canViewReports` → 403 Forbidden en `/admin/financial-dashboard` |
| **RNF-07** | Logs de acceso a Dashboard (tabla `audit_logs`) |
| **RNF-08** | Costos NO expuestos a empleados sin `canViewCosts` (futuro) |

---

### 9.3. Usabilidad

| Requisito | Descripción |
|-----------|-------------|
| **RNF-09** | Dashboard debe ser comprensible sin manual (auto-explicativo) |
| **RNF-10** | Ganancias negativas deben mostrar alerta visual (rojo) |
| **RNF-11** | Responsive: Diseñado para móvil primero, tablet/desktop adaptativos |
| **RNF-12** | Feedback inmediato: Skeleton screens durante carga |

---

### 9.4. Mantenibilidad

| Requisito | Descripción |
|-----------|-------------|
| **RNF-13** | Código modular: Cada RPC en archivo de migración separado |
| **RNF-14** | Tests unitarios para cálculos financieros (ganancia, margen) |
| **RNF-15** | Documentación inline en RPCs (comentarios SQL) |

---

## 10. Análisis Costo-Beneficio

### 10.1. Esfuerzo de Implementación

#### Fase 1: Fundación de Costos (Crítico)

| Tarea | Esfuerzo | Complejidad | Riesgo |
|-------|----------|-------------|--------|
| Migración de BD (agregar columnas) | 2 días | Baja | Bajo |
| Modificar RPC de venta (guardar costos) | 3 días | Media | Medio |
| Script de migración de datos | 1 día | Baja | Bajo |
| Testing de regresión | 2 días | Media | Medio |
| **Total Fase 1** | **8 días** | - | - |

#### Fase 2: RPCs de Inteligencia

| Tarea | Esfuerzo | Complejidad | Riesgo |
|-------|----------|-------------|--------|
| RPC `get_financial_summary` | 3 días | Media | Medio |
| RPC `get_top_selling_products` | 2 días | Baja | Bajo |
| RPC `get_stagnant_products` | 2 días | Baja | Bajo |
| Testing de RPCs | 2 días | Media | Bajo |
| **Total Fase 2** | **9 días** | - | - |

#### Fase 3: UI Dashboard

| Tarea | Esfuerzo | Complejidad | Riesgo |
|-------|----------|-------------|--------|
| Store `useFinancialStore` | 2 días | Baja | Bajo |
| Componente `FinancialDashboard.vue` | 5 días | Alta | Medio |
| Sub-componentes (Cards, Tabs, Charts) | 4 días | Media | Bajo |
| Integración con routing | 1 día | Baja | Bajo |
| Testing E2E | 3 días | Media | Medio |
| **Total Fase 3** | **15 días** | - | - |

#### Fase 4: Mejoras en Historiales (Opcional)

| Tarea | Esfuerzo | Complejidad | Riesgo |
|-------|----------|-------------|--------|
| Búsqueda global | 2 días | Media | Bajo |
| Selector de rango de fechas | 1 día | Baja | Bajo |
| Modal de detalle expandido | 2 días | Baja | Bajo |
| **Total Fase 4** | **5 días** | - | - |

**Esfuerzo Total:** 37 días (aprox. 7.4 semanas con 1 desarrollador)

---

### 10.2. Retorno de Inversión

#### Beneficios Cuantificables

| Beneficio | Impacto Estimado | Valor Anual |
|-----------|------------------|-------------|
| **Reducción de inventario estancado** | -15% capital inmovilizado | $500/tendero |
| **Mejora en rotación de productos** | +10% ventas de top productos | $1,200/tendero |
| **Detección temprana de fraude** | Ahorro 1 caso de faltante/año | $300/tendero |
| **Tiempo ahorrado en análisis manual** | 2 horas/semana x $5/hora | $520/tendero |
| **Total por Tendero** | - | **$2,520/año** |

**Con 1,000 usuarios activos:** $2,520,000/año en valor generado

#### Beneficios Cualitativos

- ✅ Diferenciador competitivo (competencia NO muestra ganancia neta)
- ✅ Mayor retención de usuarios (herramienta indispensable)
- ✅ NPS mejorado (usuarios satisfechos recomiendan app)
- ✅ Dato para pricing: Justifica plan Premium

---

### 10.3. Priorización (MoSCoW)

| Prioridad | Features |
|-----------|----------|
| **Must Have** | • Fundación de Costos (Fase 1)<br>• `get_financial_summary` RPC<br>• Dashboard Ejecutivo básico (Ventas, Costos, Ganancia)<br>• Desglose de dinero |
| **Should Have** | • `get_top_selling_products` RPC<br>• Top Ventas visualización<br>• Smart Supply integrado |
| **Could Have** | • `get_stagnant_products` RPC<br>• Productos Estancados<br>• Búsqueda en historiales<br>• Modal de detalle expandido |
| **Won't Have (v1)** | • Exportación a Excel/PDF<br>• Gráficos interactivos (Chart.js)<br>• Alertas automáticas por email |

---

## 11. Roadmap de Implementación

### 11.1. Fases de Desarrollo

```
Semana 1-2: Fase 1 - Fundación de Costos
├─ Sprint Planning & Architecture Review
├─ Migración de Base de Datos
├─ Modificación de RPC de Venta
├─ Script de Migración de Datos
└─ Testing de Regresión

Semana 3-4: Fase 2 - Inteligencia Backend
├─ Implementar get_financial_summary
├─ Implementar get_top_selling_products
├─ Implementar get_stagnant_products
└─ Testing de RPCs

Semana 5-7: Fase 3 - Dashboard UI
├─ Crear useFinancialStore
├─ Componente FinancialDashboard.vue
├─ Sub-componentes (Cards, Charts)
├─ Integración con Router
└─ Testing E2E

Semana 8: Fase 4 - Mejoras Historiales (Opcional)
├─ Búsqueda global
├─ Selector de rangos
└─ Modal de detalle

Semana 9: QA & Launch
├─ Testing de Aceptación
├─ Beta con 10 usuarios
├─ Ajustes finales
└─ Despliegue a Producción
```

### 11.2. Dependencias Críticas

| Fase | Depende De | Bloqueante? |
|------|------------|-------------|
| Fase 2 | Fase 1 completa | ✅ Sí (necesita columnas de costos) |
| Fase 3 | Fase 2 completa | ✅ Sí (UI consume RPCs) |
| Fase 4 | Fase 3 completa | ❌ No (mejoras independientes) |

---

### 11.3. Plan de Rollout

#### Estrategia: Rollout Gradual con Feature Flags

**Semana 1-2 (Alpha):**
- Activar para 1 cuenta de prueba interna
- Validar cálculos de costos y ganancias

**Semana 3-4 (Beta Cerrada):**
- Activar para 10 usuarios seleccionados
- Recopilar feedback cualitativo
- Medir: Tiempo en Dashboard, clicks en Top Ventas

**Semana 5-6 (Beta Abierta):**
- Activar para 100 usuarios (opt-in)
- Comunicación: "Prueba el nuevo Dashboard de Ganancias"
- Monitorear: Errores, performance, NPS

**Semana 7 (General Availability):**
- Activar para todos los usuarios con `canViewReports`
- Anuncio oficial en app y redes sociales
- Tutorial interactivo en primera visita

---

## 12. Riesgos y Mitigación

### 12.1. Riesgos Técnicos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **R1: Performance de RPC con grandes volúmenes** | Media | Alto | • Índices en BD<br>• Paginación en historiales<br>• Testing con 10,000 productos |
| **R2: Datos históricos sin costos** | Alta | Medio | • Estimación conservadora (margen 30%)<br>• Banner de advertencia en UI<br>• Permitir ajuste manual |
| **R3: Incompatibilidad con migraciones antiguas** | Baja | Alto | • Revisar todas las migraciones existentes<br>• Testing en staging con DB de producción |
| **R4: Cálculo de costo promedio incorrecto** | Media | Alto | • Tests unitarios exhaustivos<br>• Validación manual con 10 casos reales |

### 12.2. Riesgos de Negocio

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **R5: Usuarios no entienden "Ganancia Neta"** | Media | Medio | • Tooltip explicativo<br>• Tutorial en primera visita<br>• Video corto en YouTube |
| **R6: Baja adopción del Dashboard** | Baja | Alto | • Notificación push "Conoce tu ganancia real"<br>• Incentivo: "Desbloquea insights premium" |
| **R7: Usuarios cuestionan costos estimados** | Alta | Bajo | • Banner transparente: "Costos estimados, actualízalos"<br>• Link directo a Inventario |

### 12.3. Plan de Contingencia

**Si Fase 1 toma más de 10 días:**
- Priorizar solo columna `products.cost`
- Posponer `sale_items.unit_cost` (calcular margen con costo actual, no histórico)

**Si RPC `get_financial_summary` es lenta (> 2 seg):**
- Implementar tabla de caché `daily_summaries_cache`
- Actualizar cache con trigger al insertar venta
- TTL: 5 minutos

**Si usuarios reportan confusión:**
- A/B Test: Dashboard con tutorial vs sin tutorial
- Medir: Tiempo hasta primera acción, tasa de abandono

---

## 13. Criterios de Aceptación

### 13.1. Criterios Funcionales

#### Dashboard Ejecutivo

- [ ] **AC-01:** Al abrir Dashboard, se muestra Ganancia Neta en < 3 segundos
- [ ] **AC-02:** Ganancia Neta es verde si positiva, roja si negativa
- [ ] **AC-03:** Desglose de dinero suma exactamente el total de ventas
- [ ] **AC-04:** Cambiar pestaña (Hoy/Semana/Mes) actualiza todos los datos
- [ ] **AC-05:** Top Ventas muestra productos ordenados por unidades vendidas (DESC)
- [ ] **AC-06:** Productos con stock crítico tienen badge rojo en Top Ventas

#### Costos

- [ ] **AC-07:** Al registrar entrada de inventario, `products.cost` se actualiza (promedio ponderado)
- [ ] **AC-08:** Al procesar venta, `sale_items.unit_cost` se guarda con valor de `products.cost` actual
- [ ] **AC-09:** Cálculo de ganancia: `SUM(quantity * (unit_price - unit_cost))` coincide con valor mostrado

#### Historiales

- [ ] **AC-10:** Búsqueda por ticket encuentra venta con número exacto
- [ ] **AC-11:** Selector de rango permite elegir cualquier fecha entre 2024-01-01 y hoy
- [ ] **AC-12:** Clic en venta muestra modal con items, cantidades y precios

### 13.2. Criterios No Funcionales

- [ ] **AC-13:** Dashboard carga en < 2 seg con conexión 3G
- [ ] **AC-14:** RPC `get_financial_summary` responde en < 500ms con 1,000 ventas
- [ ] **AC-15:** Empleado sin `canViewReports` recibe 403 al intentar acceder
- [ ] **AC-16:** Dashboard es responsive (mobile, tablet, desktop)

### 13.3. Criterios de QA

- [ ] **AC-17:** Tests unitarios para cálculo de costo promedio (5 casos)
- [ ] **AC-18:** Tests E2E para flujo completo: Login → Dashboard → Ver Top Ventas
- [ ] **AC-19:** Testing manual con 10 usuarios beta sin encontrar bugs críticos
- [ ] **AC-20:** Validación con datos reales: Ganancia calculada coincide con contabilidad manual

---

## 14. Apéndices

### 14.1. Glosario

| Término | Definición |
|---------|------------|
| **Ganancia Neta** | Ventas Totales - Costo de Mercancía Vendida |
| **Margen de Ganancia** | (Ganancia Neta / Ventas Totales) * 100 |
| **Costo Promedio Ponderado** | Método de valoración de inventario: (Valor Stock Anterior + Valor Entrada) / (Cantidad Anterior + Cantidad Entrada) |
| **Producto Estancado** | Producto sin ventas en X días (default: 30 días) |
| **RPC** | Remote Procedure Call - Función ejecutada en backend (Supabase) |
| **RLS** | Row Level Security - Política de seguridad en BD |
| **Fiado Pendiente** | Suma de saldos de clientes con crédito no pagado |

### 14.2. Referencias

- **Arquitectura del Sistema:** `ARCHITECTURE_MAP.md`
- **Estado Actual de Reportes:** `REPORTE_ESTADO_ACTUAL.md`
- **Estado Actual de Historiales:** `HISTORIAL_ESTADO_ACTUAL.md`
- **Límites del Sistema:** `SYSTEM_BOUNDARIES.md`
- **Mockup Original (Descartado):** `1771184053954_image.png`

### 14.3. Contactos

| Rol | Responsabilidad |
|-----|-----------------|
| **Product Owner** | Priorización de features, aprobación de cambios |
| **Tech Lead** | Revisión de arquitectura, code review |
| **Backend Dev** | Implementación de RPCs y migraciones |
| **Frontend Dev** | Implementación de Dashboard y componentes |
| **QA Lead** | Testing de aceptación y regresión |

---

## Historial de Cambios

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 0.1 | 2026-02-15 | Borrador inicial - Análisis de estado actual |
| 0.2 | 2026-02-15 | Propuesta de solución y arquitectura de datos |
| 1.0 | 2026-02-15 | Documento completo para aprobación |

---

## Aprobaciones

| Rol | Nombre | Firma | Fecha |
|-----|--------|-------|-------|
| Product Owner | | | |
| Tech Lead | | | |
| Stakeholder (Usuario Final) | | | |

---

**Fin del Documento**

*Este FRD es un documento vivo. Se actualizará conforme avance la implementación y se reciba feedback de usuarios.*
