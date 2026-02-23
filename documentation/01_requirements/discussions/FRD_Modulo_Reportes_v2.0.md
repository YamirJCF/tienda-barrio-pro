# FRD: Módulo de Reportes Inteligentes
## Functional Requirements Document v2.0

---

**Proyecto:** Tienda de Barrio Pro - MVP  
**Módulo:** Reportes e Inteligencia de Negocio  
**Versión:** 2.0  
**Fecha:** 22 de Febrero, 2026  
**Autor:** Arquitecto de Requisitos Senior  
**Estado:** Especificación para Desarrollo

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Problema y Oportunidad](#2-problema-y-oportunidad)
3. [Solución Propuesta](#3-solución-propuesta)
4. [Conceptos Contables Aplicados](#4-conceptos-contables-aplicados)
5. [Arquitectura del Dashboard](#5-arquitectura-del-dashboard)
6. [Casos de Uso Detallados](#6-casos-de-uso-detallados)
7. [Especificación de Métricas](#7-especificación-de-métricas)
8. [Especificación de RPCs](#8-especificación-de-rpcs)
9. [Wireframes y Flujos](#9-wireframes-y-flujos)
10. [Requisitos No Funcionales](#10-requisitos-no-funcionales)
11. [Criterios de Aceptación](#11-criterios-de-aceptación)

---

## 1. Resumen Ejecutivo

### 1.1. Contexto

El módulo de Reportes actual tiene infraestructura técnica sólida pero **bajo valor de negocio**. Los tenderos ven números sin contexto que no les ayudan a tomar decisiones.

### 1.2. Propuesta de Valor

**"Espejo Inteligente, No Consultor"**

Transformar el módulo en un **Dashboard Híbrido** que:
- Aplica conceptos contables avanzados (COGS, Margen Bruto, Rotación)
- Presenta la información en lenguaje claro (sin jerga contable)
- Permite al usuario tomar sus propias decisiones basadas en datos

### 1.3. Audiencia

**Usuario Objetivo:**
- Tendero colombiano con 20+ años de experiencia
- Su negocio funciona sin el sistema (lo usa para ahorrar tiempo)
- Desconfía de "recomendaciones" pero respeta números claros
- Necesita ver sus propios datos sin ruido

### 1.4. Objetivos Medibles

| Objetivo | Métrica Actual | Meta MVP |
|----------|----------------|----------|
| Uso del módulo de Reportes | < 5% engagement | > 40% apertura diaria |
| Tiempo para tomar decisión de compra | Intuición (no medible) | 80% basadas en datos del dashboard |
| Satisfacción con reportes | No medido | NPS > 7/10 |

---

## 2. Problema y Oportunidad

### 2.1. Análisis del Estado Actual

**Módulo Existente:**
- Daily Summary: Muestra ventas brutas (sin ganancia)
- Smart Supply: Identifica stock bajo (útil pero aislado)
- Historiales: Logs técnicos sin análisis

**Problema Central:**

| Pregunta del Usuario | Respuesta Actual | Impacto |
|---------------------|------------------|---------|
| ¿Cuánto **gané** hoy? | "Vendiste $500k" | ❌ No sabe si ganó o perdió |
| ¿Qué producto me conviene? | "Vendiste 50 arroces" | ❌ Unidades ≠ ganancia |
| ¿Dónde está mi dinero? | No responde | ❌ Confusión de flujo de caja |
| ¿Qué productos no se mueven? | No responde | ❌ Capital inmovilizado |

### 2.2. Oportunidad Identificada

Con la **Auditoría de Datos** (`AUDITORIA_DATOS_ANALYTICS.md`) confirmamos que el sistema **YA TIENE** todos los datos necesarios para calcular:

✅ Ganancia Bruta (COGS)  
✅ Margen por producto  
✅ Rotación de inventario  
✅ Días de inventario  
✅ Valor del stock  
✅ Cartera vencida  

**Solo falta presentarlos correctamente.**

---

## 3. Solución Propuesta

### 3.1. Visión General

**Dashboard Híbrido de 3 Secciones:**

```
┌─────────────────────────────────────────┐
│                                         │
│   SECCIÓN 1: Resumen Financiero         │
│   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│   • Ventas Brutas                       │
│   • Ganancia Bruta (COGS aplicado)      │
│   • Margen Promedio                     │
│                                         │
│   SECCIÓN 2: Inteligencia de Productos  │
│   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│   • Top Productos (por ganancia)        │
│   • Productos Estancados                │
│   • Alertas de Stock                    │
│                                         │
│   SECCIÓN 3: Flujo de Dinero            │
│   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│   • Desglose por Método de Pago         │
│   • Fiado Pendiente (Cartera)           │
│   • Cuadre de Caja                      │
│                                         │
└─────────────────────────────────────────┘
```

### 3.2. Principios de Diseño

#### P1: Honestidad Radical
- Si no hay datos confiables, no mostrar la métrica
- Preferir "No disponible" sobre inventar números

#### P2: Lenguaje Claro
- "Ganancia Bruta" → "Lo que ganaste (sin contar gastos)"
- "COGS" → "Costo de lo vendido"
- "Rotación" → "Cada cuántos días se acaba"

#### P3: Decisiones, No Recomendaciones
- ❌ "Deberías vender más arroz"
- ✅ "Arroz genera $50k de ganancia/día"

#### P4: Comparación Temporal
- Siempre mostrar: Hoy vs Ayer / Esta Semana vs Semana Pasada
- Evitar promedios móviles complejos

---

## 4. Conceptos Contables Aplicados

### 4.1. COGS (Costo de Mercancía Vendida)

**Definición Contable:**
> Suma del costo de todos los productos vendidos en un período

**Cómo lo Aplicamos:**

```sql
-- En cada venta, guardamos el unit_cost histórico
INSERT INTO sale_items (unit_price, unit_cost, quantity)
VALUES (2000, 1500, 10);

-- COGS del día = suma de (unit_cost × quantity)
SELECT SUM(unit_cost * quantity) as cogs
FROM sale_items si
JOIN sales s ON s.id = si.sale_id
WHERE s.created_at::date = CURRENT_DATE;
```

**Cómo se lo Mostramos al Usuario:**

```
💰 Ventas del Día:     $850.000
💸 Costo de lo Vendido: $595.000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💚 Ganancia Bruta:     $255.000

ℹ️ Esto es lo que ganaste antes de pagar
   servicios, empleados y otros gastos.
```

---

### 4.2. Margen Bruto

**Definición Contable:**
> Porcentaje de ganancia sobre las ventas: `(Ventas - COGS) / Ventas × 100`

**Cómo lo Aplicamos:**

```sql
-- Margen promedio del negocio
SELECT 
  SUM(total) as ventas,
  SUM(si.unit_cost * si.quantity) as cogs,
  ROUND((1 - SUM(si.unit_cost * si.quantity)::numeric / SUM(total)) * 100, 1) as margen
FROM sales s
JOIN sale_items si ON si.sale_id = s.id;
```

**Cómo se lo Mostramos al Usuario:**

```
📊 Margen Promedio: 30%

Por cada $100 que vendes, te quedan $30
después de pagar lo que costó la mercancía.

📈 Comparación:
   • Esta semana: 30%
   • Semana pasada: 28% (+2%)
```

**Caso de Uso:**
- Si el margen baja de 25% → El usuario sabe que está vendiendo muy barato o comprando muy caro
- Si el margen sube a 40% → Está siendo rentable

---

### 4.3. Rotación de Inventario

**Definición Contable:**
> Velocidad con la que el inventario se convierte en ventas. Medida: Días entre entrada y agotamiento.

**Cómo lo Aplicamos:**

```sql
-- Para cada producto, calcular días promedio de rotación
SELECT 
  p.name,
  AVG(EXTRACT(EPOCH FROM (sale_date - entry_date)) / 86400) as dias_rotacion
FROM products p
JOIN inventory_movements im_in ON im_in.product_id = p.id AND im_in.movement_type = 'entrada'
JOIN sale_items si ON si.product_id = p.id
JOIN sales s ON s.id = si.sale_id
GROUP BY p.id;
```

**Cómo se lo Mostramos al Usuario:**

```
🔥 Productos de Rotación Rápida (< 7 días)
   • Arroz Diana: Se acaba cada 3 días
   • Coca-Cola 1.5L: Se acaba cada 5 días
   
   💡 Estos son tus campeones. Siempre ten stock.

🐌 Productos de Rotación Lenta (> 30 días)
   • Shampoo Marca X: Lleva 45 días en inventario
   • Whisky Premium: Lleva 60 días en inventario
   
   💡 Tienes $450k en productos que no se mueven.
```

**Caso de Uso:**
- Usuario ve que Arroz rota cada 3 días → Debe pedir más seguido en cantidades grandes
- Usuario ve que Shampoo lleva 45 días → Hacer promoción para liquidar

---

### 4.4. Días de Inventario

**Definición Contable:**
> Cuántos días puede seguir vendiendo con el inventario actual sin reabastecerse.

**Cómo lo Aplicamos:**

```sql
-- Días de inventario = Valor del Stock / (COGS Promedio Diario)
WITH cogs_diario AS (
  SELECT AVG(daily_cogs) as cogs_avg
  FROM (
    SELECT DATE(created_at), SUM(si.unit_cost * si.quantity) as daily_cogs
    FROM sales s
    JOIN sale_items si ON si.sale_id = s.id
    WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY DATE(created_at)
  ) sub
)
SELECT 
  SUM(current_stock * cost_price) as valor_inventario,
  SUM(current_stock * cost_price) / cogs_avg as dias_inventario
FROM products, cogs_diario;
```

**Cómo se lo Mostramos al Usuario:**

```
📦 Inventario Actual

Valor total: $1.850.000

⏱️ Tienes mercancía para 23 días
   (Basado en tus ventas de los últimos 30 días)

✅ Estado: Saludable (ideal: 15-30 días)
```

**Casos de Uso:**

| Días de Inventario | Interpretación | Acción Sugerida |
|-------------------|----------------|-----------------|
| < 7 días | ⚠️ Riesgo de quedarse sin stock | Ordenar YA |
| 7-15 días | ⚡ Óptimo (capital no inmovilizado) | Mantener ritmo |
| 15-30 días | ✅ Saludable | Normal |
| > 30 días | 🐌 Demasiado inventario | Liquidar productos lentos |

---

### 4.5. Cartera Vencida (Fiado)

**Definición Contable:**
> Dinero que los clientes deben y que lleva más de X días sin pagar.

**Cómo lo Aplicamos:**

```sql
-- Cartera total y vencida
SELECT 
  SUM(balance) as cartera_total,
  SUM(CASE WHEN last_purchase_date < CURRENT_DATE - INTERVAL '30 days' THEN balance ELSE 0 END) as cartera_vencida
FROM clients
WHERE balance > 0;
```

**Cómo se lo Mostramos al Usuario:**

```
📋 Fiado Pendiente

Total por cobrar: $450.000

⚠️ Cartera Vencida (>30 días): $120.000
   • Juan Pérez: $80.000 (45 días)
   • María López: $40.000 (35 días)

💡 $120k llevan más de un mes sin pagar.
   Considera cobrarles esta semana.
```

**Caso de Uso:**
- Usuario ve que Juan debe $80k hace 45 días → Puede decidir no venderle más a crédito hasta que pague

---

## 5. Arquitectura del Dashboard

### 5.1. Navegación Principal

**Estructura de Pestañas:**

```
┌─────────────────────────────────────┐
│  Reportes                        ⋮  │
├─────────────────────────────────────┤
│  [Hoy] [Semana] [Mes]               │
└─────────────────────────────────────┘
```

**Comportamiento:**
- Al cambiar pestaña → Recarga todas las secciones con nuevo período
- "Hoy" = Fecha actual
- "Semana" = Últimos 7 días
- "Mes" = Últimos 30 días

---

### 5.2. Sección 1: Resumen Financiero

**Objetivo:** Responder "¿Cuánto gané?"

**Componentes:**

```
┌─────────────────────────────────────┐
│ 💰 RESUMEN FINANCIERO               │
├─────────────────────────────────────┤
│                                     │
│  Ventas Totales                     │
│  $850.000                           │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                     │
│  Costo de lo Vendido                │
│  $595.000                           │
│                                     │
│  Ganancia Bruta                     │
│  $255.000  📈 30% margen            │
│                                     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                     │
│  ℹ️ Esto es lo que ganaste antes de │
│     pagar servicios y empleados.    │
│                                     │
│  📊 Comparación con ayer:           │
│     +$50.000 (+24%)                 │
│                                     │
└─────────────────────────────────────┘
```

**Lógica de Colores:**

| Condición | Color | Icono |
|-----------|-------|-------|
| Ganancia > 0 | Verde | 💚 |
| Ganancia = 0 | Amarillo | ⚠️ |
| Ganancia < 0 (costo > ventas) | Rojo | 🔴 |

---

### 5.3. Sección 2: Inteligencia de Productos

**Objetivo:** Responder "¿Qué productos son mis campeones?"

**Sub-pestañas:**

```
[🔥 Top Ganancia] [📊 Top Unidades] [🐌 Estancados] [⚠️ Stock Bajo]
```

#### Sub-pestaña: Top Ganancia

```
┌─────────────────────────────────────┐
│ 🔥 PRODUCTOS CAMPEONES              │
│ (Por ganancia generada)             │
├─────────────────────────────────────┤
│                                     │
│ #1  Aceite Gourmet 1L               │
│     42 unds  |  Margen: 40%         │
│     Ganancia: $84.000               │
│     ████████████████████████░░░░░   │
│                                     │
│ #2  Arroz Diana 500g                │
│     54 unds  |  Margen: 20%         │
│     Ganancia: $54.000               │
│     ███████████████░░░░░░░░░░░░░░   │
│                                     │
│ #3  Coca-Cola 1.5L                  │
│     36 unds  |  Margen: 35%         │
│     Ganancia: $50.400               │
│     ██████████████░░░░░░░░░░░░░░░   │
│                                     │
│ [Ver todos los productos →]         │
│                                     │
│ 💡 Insight:                         │
│ Aceite te deja más utilidad aunque  │
│ vendas menos unidades que Arroz.    │
│                                     │
└─────────────────────────────────────┘
```

**Fórmula de Ordenamiento:**
```sql
ORDER BY (unit_price - unit_cost) * quantity DESC
```

---

#### Sub-pestaña: Top Unidades

```
┌─────────────────────────────────────┐
│ 📊 MÁS VENDIDOS (Por unidades)      │
├─────────────────────────────────────┤
│                                     │
│ #1  Arroz Diana 500g                │
│     54 unidades vendidas            │
│     Rota cada: 3 días ⚡            │
│                                     │
│ #2  Aceite Gourmet 1L               │
│     42 unidades vendidas            │
│     Rota cada: 5 días               │
│                                     │
│ #3  Coca-Cola 1.5L                  │
│     36 unidades vendidas            │
│     Rota cada: 4 días               │
│                                     │
└─────────────────────────────────────┘
```

**Diferencia con Top Ganancia:**
- Muestra volumen de venta (rotación)
- Útil para saber qué comprar en mayor cantidad

---

#### Sub-pestaña: Estancados

```
┌─────────────────────────────────────┐
│ 🐌 PRODUCTOS ESTANCADOS             │
│ (Sin ventas en 30+ días)            │
├─────────────────────────────────────┤
│                                     │
│ Shampoo Marca X                     │
│ 📅 Última venta: hace 45 días       │
│ 📦 Stock actual: 20 unidades        │
│ 💰 Capital inmovilizado: $40.000    │
│                                     │
│ Whisky Premium                      │
│ 📅 Última venta: hace 60 días       │
│ 📦 Stock actual: 3 unidades         │
│ 💰 Capital inmovilizado: $210.000   │
│                                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                     │
│ 💡 Total inmovilizado: $250.000     │
│                                     │
│ Opciones:                           │
│ • Hacer promoción para liquidar     │
│ • Marcar para no reordenar          │
│                                     │
└─────────────────────────────────────┘
```

**Criterio de "Estancado":**
- Productos con última venta > 30 días
- Ordenados por capital inmovilizado (stock × cost_price) DESC

---

#### Sub-pestaña: Stock Bajo

```
┌─────────────────────────────────────┐
│ ⚠️ STOCK BAJO (Riesgo de agotarse)  │
├─────────────────────────────────────┤
│                                     │
│ 🔴 Leche Deslactosada               │
│    Stock: 2 unidades                │
│    Mínimo: 10 unidades              │
│    Rota cada: 2 días ⚡             │
│    💡 Ordenar YA (se acaba mañana)  │
│                                     │
│ 🟡 Pan Tajado                       │
│    Stock: 8 unidades                │
│    Mínimo: 15 unidades              │
│    Rota cada: 3 días                │
│    💡 Ordenar pronto (quedan 2 días)│
│                                     │
│ [Ver Smart Supply completo →]       │
│                                     │
└─────────────────────────────────────┘
```

**Integración con Smart Supply Actual:**
- Mantener lógica existente
- Agregar "días restantes" calculado con rotación

---

### 5.4. Sección 3: Flujo de Dinero

**Objetivo:** Responder "¿Dónde está mi dinero?"

```
┌─────────────────────────────────────┐
│ 💵 ¿DÓNDE ESTÁ EL DINERO?           │
├─────────────────────────────────────┤
│                                     │
│ Efectivo                            │
│ $400.000  (47%)                     │
│ ████████████░░░░░░░░░░░░░░          │
│ 💡 Debe estar en el cajón           │
│                                     │
│ Nequi / Daviplata                   │
│ $300.000  (35%)                     │
│ █████████░░░░░░░░░░░░░░░░░          │
│ 💡 En bancos digitales              │
│                                     │
│ Fiado (Por cobrar)                  │
│ $150.000  (18%)                     │
│ ████░░░░░░░░░░░░░░░░░░░░░░          │
│ 💡 Clientes te deben                │
│                                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                     │
│ Total: $850.000                     │
│                                     │
│ [Ver detalle de fiado →]            │
│                                     │
└─────────────────────────────────────┘
```

**Cálculo:**
- Efectivo: `SUM(total WHERE payment_method = 'efectivo')`
- Nequi/Dav: `SUM(total WHERE payment_method IN ('nequi', 'daviplata'))`
- Fiado: `SUM(total WHERE payment_method = 'fiado')`

---

#### Detalle de Fiado (Modal o Vista Separada)

```
┌─────────────────────────────────────┐
│ 📋 DETALLE DE FIADO                 │
├─────────────────────────────────────┤
│                                     │
│ Total por cobrar: $450.000          │
│                                     │
│ ⚠️ Vencido (>30 días): $120.000     │
│                                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                     │
│ Juan Pérez                          │
│ Debe: $80.000                       │
│ Última compra: hace 45 días         │
│ [Ver historial] [Registrar pago]    │
│                                     │
│ María López                         │
│ Debe: $40.000                       │
│ Última compra: hace 35 días         │
│ [Ver historial] [Registrar pago]    │
│                                     │
│ Carlos Gómez                        │
│ Debe: $30.000                       │
│ Última compra: hace 10 días ✅      │
│ [Ver historial] [Registrar pago]    │
│                                     │
└─────────────────────────────────────┘
```

---

### 5.5. Sección Adicional: Inventario (Nueva)

**Objetivo:** Responder "¿Cuánto capital tengo en mercancía?"

```
┌─────────────────────────────────────┐
│ 📦 INVENTARIO                       │
├─────────────────────────────────────┤
│                                     │
│ Valor Total                         │
│ $1.850.000                          │
│                                     │
│ ⏱️ Días de Inventario: 23 días      │
│                                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                     │
│ Distribución por Rotación           │
│                                     │
│ ⚡ Rápida (< 7 días)                │
│    5 productos  |  $400.000         │
│                                     │
│ ✅ Normal (7-30 días)               │
│    6 productos  |  $1.150.000       │
│                                     │
│ 🐌 Lenta (> 30 días)                │
│    2 productos  |  $300.000         │
│                                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                     │
│ 💡 Insight:                         │
│ Tienes $300k en productos lentos.   │
│ Considera hacer promoción.          │
│                                     │
└─────────────────────────────────────┘
```

---

## 6. Casos de Uso Detallados

### CU-01: Ver Ganancia del Día

**Actor:** Dueño de tienda  
**Frecuencia:** Diaria (al final del turno)  
**Objetivo:** Saber cuánto ganó realmente (no solo cuánto vendió)  
**Precondición:** Usuario logueado con permiso `canViewReports`

#### Flujo Principal

1. Usuario abre la app al final del día
2. Usuario toca el ícono "Administración" en la navegación inferior
3. Sistema muestra AdminHub con pestañas
4. Usuario selecciona pestaña "Reportes"
5. Sistema muestra Dashboard con pestaña "Hoy" activa por defecto
6. Sistema llama RPC `get_financial_summary(store_id, CURRENT_DATE, CURRENT_DATE)`
7. Sistema muestra Sección 1: Resumen Financiero
   - Ventas Totales: $850.000
   - Costo de lo Vendido: $595.000
   - Ganancia Bruta: $255.000 (30% margen) en verde 💚
8. Usuario ve la nota: "Esto es lo que ganaste antes de pagar servicios y empleados"
9. Usuario observa comparación: "+$50.000 (+24%) vs ayer"
10. Usuario interpreta: "Hoy gané $255k, ayer fueron $205k. Voy bien."

#### Flujo Alternativo 6a: Error en RPC

6a1. Sistema no puede conectar con Supabase  
6a2. Sistema muestra banner rojo: "Error al cargar datos. [Reintentar]"  
6a3. Usuario toca "Reintentar"  
6a4. Regresa al paso 6

#### Flujo Alternativo 6b: Sin Ventas en el Día

6b1. RPC retorna ventas = 0  
6b2. Sistema muestra mensaje: "No hay ventas registradas hoy"  
6b3. Sistema muestra ilustración de caja vacía  
6b4. Dashboard permanece visible pero sin datos

#### Postcondición Exitosa

- Usuario conoce su ganancia real (no solo ventas brutas)
- Usuario puede comparar con día anterior
- Usuario entiende que esto NO incluye gastos operativos

#### Postcondición de Fallo

- Usuario ve mensaje de error y puede reintentar
- No se muestran datos incorrectos o desactualizados

---

### CU-02: Identificar Productos Campeones

**Actor:** Dueño de tienda  
**Frecuencia:** Semanal (al planear pedido al proveedor)  
**Objetivo:** Saber qué productos le generan más utilidad (no solo cuáles vende más)  
**Precondición:** Dashboard abierto, pestaña "Semana" activa

#### Flujo Principal

1. Usuario está en Dashboard, pestaña "Hoy"
2. Usuario toca pestaña "Semana"
3. Sistema recarga todas las secciones con período = últimos 7 días
4. Usuario se desplaza hacia abajo hasta Sección 2: Inteligencia de Productos
5. Sistema muestra sub-pestaña "🔥 Top Ganancia" activa por defecto
6. Sistema llama RPC `get_top_products_by_profit(store_id, fecha_inicio, fecha_fin, limit=10)`
7. Sistema muestra lista ordenada:
   - #1 Aceite Gourmet: 42 unds | Margen 40% | Ganancia $84.000
   - #2 Arroz Diana: 54 unds | Margen 20% | Ganancia $54.000
   - #3 Coca-Cola: 36 unds | Margen 35% | Ganancia $50.400
8. Sistema muestra Insight: "Aceite te deja más utilidad aunque vendas menos unidades"
9. Usuario observa que Arroz vendió más unidades (54) pero Aceite generó más ganancia ($84k)
10. Usuario toca "Ver todos los productos →"
11. Sistema navega a vista detallada con tabla completa (todos los productos, no solo top 10)
12. Usuario hace scroll y observa que Shampoo está en posición #47 con ganancia de $500
13. Usuario decide: "Voy a pedir más Aceite y menos Shampoo en mi próximo pedido"

#### Flujo Alternativo 5a: Usuario Quiere Ver por Unidades

5a1. Usuario toca sub-pestaña "📊 Top Unidades"  
5a2. Sistema llama RPC `get_top_products_by_units()`  
5a3. Sistema muestra lista ordenada por cantidad vendida:  
   - #1 Arroz Diana: 54 unidades  
   - #2 Aceite Gourmet: 42 unidades  
5a4. Usuario compara ambas pestañas y confirma que el orden cambió

#### Flujo Alternativo 9a: Usuario No Entiende el Insight

9a1. Usuario toca el ícono "ℹ️" junto al insight  
9a2. Sistema muestra tooltip explicativo:  
   "Ganancia = (Precio - Costo) × Unidades Vendidas  
   Aceite tiene mejor margen (40%) que Arroz (20%)  
   Por eso genera más ganancia con menos ventas"  
9a3. Usuario cierra tooltip

#### Postcondición Exitosa

- Usuario identificó cuáles productos son más rentables
- Usuario tiene criterio para decidir qué reordenar
- Usuario entiende que unidades vendidas ≠ ganancia generada

---

### CU-03: Detectar Capital Inmovilizado

**Actor:** Dueño de tienda  
**Frecuencia:** Mensual (al revisar inventario)  
**Objetivo:** Identificar productos que no se venden para liberar capital  
**Precondición:** Dashboard abierto

#### Flujo Principal

1. Usuario está en Sección 2: Inteligencia de Productos
2. Usuario toca sub-pestaña "🐌 Estancados"
3. Sistema llama RPC `get_stagnant_products(store_id, days_threshold=30)`
4. Sistema muestra lista de productos sin ventas en 30+ días:
   - Shampoo Marca X
     - Última venta: hace 45 días
     - Stock: 20 unidades
     - Capital inmovilizado: $40.000
   - Whisky Premium
     - Última venta: hace 60 días
     - Stock: 3 unidades
     - Capital inmovilizado: $210.000
5. Sistema muestra totalizador: "Total inmovilizado: $250.000"
6. Usuario interpreta: "Tengo $250k durmiendo en mercancía que no se mueve"
7. Usuario toca sobre "Whisky Premium" (el de mayor capital inmovilizado)
8. Sistema muestra modal con detalle del producto:
   - Historial de ventas (gráfico últimos 90 días)
   - Historial de entradas (compras al proveedor)
   - Margen actual: 45%
9. Usuario observa que el Whisky se vende solo 1-2 unidades cada 60 días
10. Usuario decide: "Voy a hacer promoción 20% descuento para liquidar 2 unidades"
11. Usuario toca botón "Ajustar Precio"
12. Sistema navega a vista de edición de producto
13. Usuario cambia precio de $70.000 a $56.000 (20% descuento)
14. Sistema guarda cambio y registra en `price_change_logs`
15. Usuario regresa a Dashboard y ve que Whisky sigue en Estancados (porque el cambio de precio no genera venta inmediata)

#### Flujo Alternativo 10a: Usuario Decide No Reordenar

10a1. Usuario decide no volver a comprar ese producto  
10a2. Usuario toca botón "Marcar para No Reordenar" (futuro)  
10a3. Sistema agrega tag al producto  
10a4. Cuando llegue al stock mínimo, Smart Supply NO sugerirá reorden

#### Flujo Alternativo 7a: Usuario Quiere Más Contexto

7a1. Usuario toca "Ver historial completo"  
7a2. Sistema navega a Historial de Compras  
7a3. Sistema filtra por producto = Whisky  
7a4. Usuario ve que compró 5 unidades hace 90 días a $50k cada una  
7a5. Usuario calcula: Invertí $250k, solo vendí 2 unidades ($140k), tengo $210k inmovilizados  
7a6. Usuario regresa a Dashboard con información completa

#### Postcondición Exitosa

- Usuario identificó productos con capital inmovilizado
- Usuario tomó acción: Promoción o marcar para no reordenar
- Usuario entiende el costo de oportunidad de inventario lento

---

### CU-04: Entender Distribución de Dinero

**Actor:** Dueño de tienda  
**Frecuencia:** Diaria (al cerrar caja)  
**Objetivo:** Saber cuánto dinero tiene disponible y dónde está  
**Precondición:** Dashboard abierto, ventas del día registradas

#### Flujo Principal

1. Usuario está en Dashboard, pestaña "Hoy"
2. Usuario se desplaza hasta Sección 3: Flujo de Dinero
3. Sistema muestra desglose:
   - Efectivo: $400.000 (47%)
   - Nequi/Daviplata: $300.000 (35%)
   - Fiado: $150.000 (18%)
4. Sistema muestra nota: "💡 Debe estar en el cajón" bajo Efectivo
5. Usuario abre la caja física y cuenta billetes
6. Usuario cuenta $380.000 en efectivo (no $400k)
7. Usuario identifica faltante de $20.000
8. Usuario toca "Ver detalle de fiado →"
9. Sistema muestra modal/vista con lista de clientes:
   - Juan Pérez: $80.000 (45 días) ⚠️
   - María López: $40.000 (35 días) ⚠️
   - Carlos Gómez: $30.000 (10 días) ✅
10. Sistema destaca "⚠️ Vencido (>30 días): $120.000"
11. Usuario decide: "Debo cobrarle a Juan y María esta semana"
12. Usuario toca sobre "Juan Pérez"
13. Sistema muestra historial de compras de Juan:
    - 2026-01-08: Compra $50k
    - 2026-01-20: Compra $30k
    - Total: $80k sin pagar
14. Usuario toca botón "Registrar Pago"
15. Sistema muestra formulario de pago
16. Usuario ingresa: Monto = $50.000, Método = Efectivo
17. Sistema llama RPC `register_client_payment()`
18. Sistema actualiza saldo de Juan: $80k → $30k
19. Sistema regresa a lista de fiado, Juan ahora muestra $30k
20. Usuario cierra modal y ve en Sección 3 que Fiado bajó de $150k a $100k

#### Flujo Alternativo 6a: Hay Sobrante en Caja

6a1. Usuario cuenta $420.000 en efectivo (no $400k)  
6a2. Usuario identifica sobrante de $20.000  
6a3. Usuario navega a Historial → Caja  
6a4. Usuario revisa sesión de caja del día  
6a5. Usuario no encuentra explicación  
6a6. Usuario decide: "Tal vez me equivoqué al dar vuelto"

#### Flujo Alternativo 11a: Usuario Quiere Enviar Recordatorio (Futuro)

11a1. Usuario toca "Enviar recordatorio a Juan"  
11a2. Sistema muestra opciones: WhatsApp | SMS  
11a3. Usuario selecciona WhatsApp  
11a4. Sistema abre WhatsApp con mensaje pre-llenado:  
   "Hola Juan, recuerda que tienes un saldo pendiente de $80.000. ¿Cuándo puedes pasar a pagar?"  
11a5. Usuario envía mensaje manualmente

#### Postcondición Exitosa

- Usuario sabe exactamente cuánto dinero tiene disponible
- Usuario identificó cartera vencida y cobró parcialmente
- Usuario entiende que el "fiado" es dinero que NO tiene en mano

---

### CU-05: Comparar Rendimiento Semanal

**Actor:** Dueño de tienda  
**Frecuencia:** Semanal (lunes por la mañana)  
**Objetivo:** Evaluar si el negocio está mejorando o empeorando  
**Precondición:** Al menos 2 semanas de datos en el sistema

#### Flujo Principal

1. Usuario abre Dashboard en lunes por la mañana
2. Usuario toca pestaña "Semana"
3. Sistema carga datos de últimos 7 días (lunes a domingo)
4. Sistema muestra en Sección 1:
   - Ventas Totales: $4.200.000
   - Ganancia Bruta: $1.260.000 (30% margen)
   - Comparación: "+$300k (+31%) vs semana pasada"
5. Usuario ve que las ventas subieron 31% respecto a semana anterior
6. Usuario toca ícono de comparación para ver más detalle
7. Sistema muestra modal con gráfico de barras:
   ```
   Semana Pasada: ████████░░ $3.9M
   Esta Semana:   ████████████ $4.2M
   ```
8. Usuario se desplaza a Sección 2: Inteligencia de Productos
9. Usuario toca "📊 Top Unidades"
10. Sistema muestra productos más vendidos esta semana
11. Usuario observa que Coca-Cola subió de posición #3 a #2
12. Usuario interpreta: "Coca-Cola se está vendiendo más. Debo tener más en stock."
13. Usuario toca pestaña "Mes" para ver tendencia más amplia
14. Sistema carga datos de últimos 30 días
15. Sistema muestra:
    - Ventas Totales: $18.500.000
    - Ganancia Bruta: $5.550.000 (30% margen)
    - Comparación: "+$2M (+12%) vs mes pasado"
16. Usuario confirma que la tendencia es alcista sostenida

#### Flujo Alternativo 5a: Ventas Bajaron

5a1. Sistema muestra: "-$500k (-11%) vs semana pasada" en rojo  
5a2. Usuario se preocupa  
5a3. Usuario revisa Sección 2 para identificar qué productos bajaron  
5a4. Usuario observa que Arroz bajó de 54 a 30 unidades  
5a5. Usuario recuerda: "Ah, se me acabó el Arroz el miércoles y solo reordené el viernes"  
5a6. Usuario concluye: "Perdí ventas por falta de stock. Debo pedir antes."

#### Postcondición Exitosa

- Usuario evaluó rendimiento semanal/mensual
- Usuario identificó tendencias (alcista/bajista)
- Usuario ajustó estrategia de reorden basado en datos

---

### CU-06: Planear Pedido al Proveedor

**Actor:** Dueño de tienda  
**Frecuencia:** Semanal (antes de llamar al proveedor)  
**Objetivo:** Decidir qué productos comprar y en qué cantidad  
**Precondición:** Dashboard abierto, día de pedido al proveedor

#### Flujo Principal

1. Usuario sabe que el proveedor visita mañana
2. Usuario abre Dashboard, pestaña "Semana"
3. Usuario navega a Sección 2: Inteligencia de Productos
4. Usuario revisa 3 sub-pestañas en secuencia:

**Paso 4a: Top Ganancia**
5. Sistema muestra:
   - #1 Aceite Gourmet: $84k ganancia
   - #2 Arroz Diana: $54k ganancia
6. Usuario toma nota: "Aceite es mi campeón, debo pedir más"

**Paso 4b: Stock Bajo**
7. Usuario toca sub-pestaña "⚠️ Stock Bajo"
8. Sistema muestra:
   - 🔴 Leche Deslactosada: 2 unds (mínimo 10)
   - 🟡 Pan Tajado: 8 unds (mínimo 15)
9. Usuario toma nota: "Leche urgente, Pan moderado"

**Paso 4c: Estancados**
10. Usuario toca sub-pestaña "🐌 Estancados"
11. Sistema muestra Shampoo y Whisky con $250k inmovilizados
12. Usuario decide: "NO voy a reordenar Shampoo ni Whisky"

**Paso 5: Consolidación**
13. Usuario crea lista mental de pedido:
    - Aceite Gourmet: 50 unidades (producto campeón)
    - Arroz Diana: 100 unidades (se vende rápido)
    - Leche Deslactosada: 30 unidades (stock crítico)
    - Pan Tajado: 20 unidades (stock bajo)
    - Shampoo: 0 unidades (estancado)
14. Usuario llama al proveedor y hace pedido basado en datos

**Paso 6: Verificación con Días de Inventario**
15. Usuario navega a Sección 3: Inventario (si existe)
16. Sistema muestra: "Días de Inventario: 23 días"
17. Usuario interpreta: "Tengo mercancía para 3 semanas. Está bien."
18. Usuario no necesita hacer pedido masivo (evita sobre-inventario)

#### Flujo Alternativo 13a: Usuario Tiene Presupuesto Limitado

13a1. Usuario calcula costo del pedido: $1.5M  
13a2. Usuario solo tiene $1M disponible  
13a3. Usuario prioriza:  
   - Leche (crítico): $300k  
   - Arroz (campeón): $500k  
   - Aceite (campeón): $200k  
   - Total: $1M  
13a4. Usuario pospone Pan y otros productos para siguiente pedido

#### Postcondición Exitosa

- Usuario hizo pedido informado basado en 3 criterios:
  - Productos campeones (alta ganancia)
  - Stock bajo (evitar faltantes)
  - NO reordenar estancados (liberar capital)
- Usuario optimizó su inversión en inventario

---

### CU-07: Investigar Faltante de Caja

**Actor:** Dueño de tienda  
**Frecuencia:** Ocasional (cuando hay discrepancia en cuadre)  
**Objetivo:** Entender por qué falta o sobra dinero en caja  
**Precondición:** Cierre de caja muestra faltante de $20k

#### Flujo Principal

1. Usuario cierra caja al final del día
2. Sistema muestra en pantalla de cierre:
   - Balance esperado: $400.000
   - Balance contado: $380.000
   - Diferencia: -$20.000 (faltante) 🔴
3. Usuario se preocupa: "¿Dónde están esos $20k?"
4. Usuario guarda la sesión de caja con el faltante registrado
5. Usuario navega a Dashboard
6. Usuario se desplaza a Sección 3: Flujo de Dinero
7. Sistema muestra desglose del día:
   - Efectivo: $400.000 esperado
   - Nequi: $300.000
   - Fiado: $150.000
8. Usuario confirma que el sistema esperaba $400k en efectivo
9. Usuario navega a Historial → Caja
10. Sistema muestra lista de sesiones recientes
11. Usuario toca sesión de hoy
12. Sistema muestra detalle:
    - Apertura: $50.000 (8:00 AM)
    - Ventas en efectivo: $350.000
    - Gastos registrados: $0
    - Esperado al cierre: $400.000
    - Contado real: $380.000
    - Faltante: $20.000
13. Usuario hace clic en "Ver ventas de esta sesión"
14. Sistema muestra todas las ventas en efectivo del día (30 transacciones)
15. Usuario revisa manualmente cada venta buscando anomalías
16. Usuario no encuentra ventas anuladas ni errores obvios
17. Usuario navega a Historial → Ventas
18. Usuario filtra por empleado = "María" (quien cerró la caja)
19. Sistema muestra ventas de María
20. Usuario observa que María vendió $120k en efectivo durante su turno
21. Usuario sospecha que María pudo dar mal el vuelto o no registró un gasto
22. Usuario decide preguntarle a María mañana

#### Flujo Alternativo 15a: Usuario Encuentra Venta Anulada Sospechosa

15a1. Usuario ve venta #235 por $20.000 marcada como anulada  
15a2. Usuario toca sobre la venta  
15a3. Sistema muestra detalle:  
   - Ticket #235  
   - Total: $20.000  
   - Anulada por: Juan (empleado)  
   - Motivo: "Cliente se arrepintió"  
   - Hora: 7:30 PM (casi al cierre)  
15a4. Usuario sospecha: "¿Juan anuló la venta y se quedó con el dinero?"  
15a5. Usuario navega a Historial → Auditoría  
15a6. Usuario filtra eventos por Juan  
15a7. Sistema muestra log:  
   - 7:28 PM: Juan procesó venta #235  
   - 7:30 PM: Juan anuló venta #235  
15a8. Usuario decide revisar cámaras de seguridad para confirmar

#### Flujo Alternativo 9a: Usuario Registró Gasto Pero Olvidó

9a1. Usuario navega a Historial → Gastos  
9a2. Sistema muestra movimiento de caja:  
   - Tipo: Gasto  
   - Monto: $20.000  
   - Descripción: "Pago de luz"  
   - Hora: 2:00 PM  
9a3. Usuario recuerda: "Ah, sí pagué la luz y saqué $20k de caja"  
9a4. Usuario confirma que NO hay faltante, solo gasto registrado  
9a5. Usuario entiende que el sistema restó esos $20k del balance esperado

#### Postcondición Exitosa

- Usuario investigó causa del faltante
- Usuario identificó posible error humano o fraude
- Usuario puede tomar acción correctiva (hablar con empleado, revisar cámaras)

---

### CU-08: Evaluar Salud del Inventario

**Actor:** Dueño de tienda  
**Frecuencia:** Mensual (al planificar estrategia)  
**Objetivo:** Entender si tiene demasiado o muy poco inventario  
**Precondición:** Dashboard abierto, pestaña "Mes"

#### Flujo Principal

1. Usuario abre Dashboard, pestaña "Mes"
2. Usuario navega a Sección nueva: Inventario
3. Sistema muestra:
   - Valor Total del Inventario: $1.850.000
   - Días de Inventario: 23 días
   - Estado: ✅ Saludable (ideal: 15-30 días)
4. Usuario interpreta: "Tengo mercancía para 23 días de venta"
5. Sistema muestra distribución por rotación:
   - ⚡ Rápida (< 7 días): 5 productos | $400k
   - ✅ Normal (7-30 días): 6 productos | $1.150k
   - 🐌 Lenta (> 30 días): 2 productos | $300k
6. Usuario observa que tiene $300k en productos lentos
7. Usuario toca sección "🐌 Lenta"
8. Sistema muestra detalle:
   - Shampoo Marca X: $40k inmovilizados (45 días sin venta)
   - Whisky Premium: $260k inmovilizados (60 días sin venta)
9. Usuario calcula: "16% de mi inventario ($300k / $1.850k) está durmiendo"
10. Usuario decide estrategia:
    - Liquidar Shampoo con 30% descuento
    - Mantener Whisky (producto especial para clientes VIP)
    - NO reordenar Shampoo hasta agotar stock actual

#### Flujo Alternativo 3a: Días de Inventario Muy Bajos (< 7 días)

3a1. Sistema muestra: "⚠️ Riesgo: Solo tienes 5 días de inventario"  
3a2. Usuario interpreta: "Si no hago pedido YA, me quedo sin stock en 5 días"  
3a3. Usuario navega inmediatamente a sub-pestaña "Stock Bajo"  
3a4. Usuario hace pedido urgente al proveedor

#### Flujo Alternativo 3b: Días de Inventario Muy Altos (> 45 días)

3b1. Sistema muestra: "⚠️ Sobre-inventario: Tienes 50 días de mercancía"  
3b2. Usuario interpreta: "Tengo demasiado capital inmovilizado"  
3b3. Usuario decide: "No voy a comprar nada este mes, solo vender lo que tengo"  
3b4. Usuario identifica que compró de más el mes pasado

#### Postcondición Exitosa

- Usuario evaluó salud de su inventario
- Usuario identificó capital inmovilizado
- Usuario ajustó estrategia de compra para optimizar flujo de caja

---

### CU-09: Identificar Oportunidades de Mejora de Margen

**Actor:** Dueño de tienda  
**Frecuencia:** Mensual (al revisar rentabilidad)  
**Objetivo:** Encontrar productos donde puede mejorar el margen  
**Precondición:** Dashboard abierto

#### Flujo Principal

1. Usuario revisa Sección 1: Resumen Financiero
2. Sistema muestra: Margen Promedio: 30%
3. Usuario piensa: "30% está bien, pero ¿puedo mejorarlo?"
4. Usuario navega a Sección 2: Inteligencia de Productos
5. Usuario toca pestaña "🔥 Top Ganancia"
6. Sistema muestra lista con columna "Margen"
7. Usuario ordena mentalmente productos por margen:
   - Aceite Gourmet: 40% margen (alto)
   - Coca-Cola: 35% margen (medio-alto)
   - Arroz Diana: 20% margen (bajo)
8. Usuario identifica que Arroz tiene margen bajo (20%)
9. Usuario piensa: "Arroz se vende mucho pero me deja poco margen"
10. Usuario investiga opciones:
    - Opción A: Subir precio de Arroz (riesgo: perder clientes)
    - Opción B: Negociar mejor precio con proveedor
    - Opción C: Cambiar de proveedor (buscar más barato)
11. Usuario decide: "Voy a negociar con el proveedor"
12. Usuario llama al proveedor y dice: "Vendo 100 unidades de Arroz por semana. ¿Me puede dar mejor precio si compro 200?"
13. Proveedor ofrece descuento de $1,700 → $1,500 por unidad
14. Usuario acepta
15. Próxima semana, usuario recibe Arroz a $1,500
16. Usuario registra entrada en sistema con nuevo costo
17. Sistema actualiza `products.cost_price` de Arroz: $1,700 → $1,500
18. Usuario mantiene precio de venta en $2,000
19. Nuevo margen de Arroz: (2000 - 1500) / 2000 = 25% (antes 20%)
20. Usuario verifica en Dashboard siguiente semana que margen promedio subió de 30% a 32%

#### Flujo Alternativo 10a: Usuario Decide Subir Precio

10a1. Usuario decide subir precio de Arroz de $2,000 a $2,200  
10a2. Usuario edita producto en sistema  
10a3. Sistema registra cambio en `price_change_logs`  
10a4. Usuario observa en siguientes días que ventas de Arroz bajaron de 54 a 40 unidades  
10a5. Usuario concluye: "Subir precio funcionó parcialmente. Vendo menos pero con mejor margen"  
10a6. Usuario calcula: 54 × $500 margen = $27k vs 40 × $700 margen = $28k  
10a7. Usuario confirma que ganó más pese a vender menos unidades

#### Postcondición Exitosa

- Usuario identificó productos con bajo margen
- Usuario tomó acción para mejorar margen (negociación o precio)
- Usuario verificó impacto en margen promedio del negocio

---

### CU-10: Cobrar Cartera Vencida

**Actor:** Dueño de tienda  
**Frecuencia:** Semanal (estrategia de cobro)  
**Objetivo:** Recuperar dinero de clientes morosos  
**Precondición:** Hay clientes con fiado > 30 días

#### Flujo Principal

1. Usuario abre Dashboard, pestaña "Mes"
2. Usuario navega a Sección 3: Flujo de Dinero
3. Sistema muestra:
   - Fiado: $450.000
4. Usuario toca "Ver detalle de fiado →"
5. Sistema muestra modal con lista de clientes:
   - Total por cobrar: $450.000
   - ⚠️ Vencido (>30 días): $120.000
6. Sistema destaca clientes morosos:
   - Juan Pérez: $80.000 (45 días) ⚠️
   - María López: $40.000 (35 días) ⚠️
7. Usuario identifica que Juan es el caso más grave ($80k, 45 días)
8. Usuario toca sobre "Juan Pérez"
9. Sistema muestra historial detallado:
   - 2026-01-08: Compró $50k (pan, leche, arroz)
   - 2026-01-20: Compró $30k (aceite, huevos)
   - Último pago: Nunca
   - Días sin pagar: 45
10. Usuario decide: "Voy a cobrarle a Juan hoy"
11. Usuario cierra sistema y llama a Juan por teléfono
12. Juan promete pasar mañana a pagar
13. Al día siguiente, Juan llega a la tienda
14. Juan paga $50.000 en efectivo
15. Usuario abre sistema, navega a Clientes
16. Usuario busca a Juan en lista de clientes
17. Usuario toca "Registrar Pago"
18. Sistema muestra formulario:
    - Cliente: Juan Pérez
    - Saldo actual: $80.000
    - Monto a pagar: [campo vacío]
    - Método: Efectivo
19. Usuario ingresa: Monto = $50.000
20. Usuario toca "Guardar"
21. Sistema llama RPC `register_client_payment()`
22. Sistema actualiza saldo de Juan: $80k → $30k
23. Sistema registra en `client_transactions`: tipo = 'pago', monto = $50k
24. Sistema muestra confirmación: "Pago registrado. Nuevo saldo: $30.000"
25. Usuario regresa a Dashboard
26. Usuario verifica en Sección 3 que Fiado bajó de $450k a $400k
27. Usuario verifica que Cartera Vencida bajó de $120k a $70k

#### Flujo Alternativo 12a: Juan No Contesta

12a1. Usuario llama a Juan, no contesta  
12a2. Usuario envía mensaje de WhatsApp:  
   "Hola Juan, recuerda tu saldo de $80k. ¿Cuándo puedes pasar?"  
12a3. Juan responde: "Paso el viernes"  
12a4. Usuario espera hasta el viernes

#### Flujo Alternativo 13a: Juan Dice Que No Tiene Dinero

13a1. Juan llega pero dice: "Solo tengo $20k hoy"  
13a2. Usuario acepta pago parcial  
13a3. Usuario registra pago de $20k  
13a4. Sistema actualiza: $80k → $60k  
13a5. Usuario acuerda con Juan: "Pagas $20k cada semana hasta saldar"

#### Flujo Alternativo 15a: Usuario Quiere Bloquear Crédito a Juan

15a1. Usuario decide no venderle más a crédito hasta que pague  
15a2. Usuario navega a perfil de Juan  
15a3. Usuario cambia `credit_limit` de $100k a $0  
15a4. Sistema guarda cambio  
15a5. Próxima vez que Juan intente comprar a crédito, sistema muestra:  
   "Juan Pérez no tiene cupo disponible. Saldo: $60k"

#### Postcondición Exitosa

- Usuario recuperó parte de la cartera vencida
- Usuario redujo riesgo de pérdida por incobrable
- Usuario actualizó estado de deuda en el sistema

---

## 7. Especificación de Métricas

### 7.1. Métricas Financieras

#### M1: Ventas Totales

**Definición:** Suma de todas las ventas NO anuladas en el período

**Fórmula SQL:**
```sql
SELECT COALESCE(SUM(total), 0) as ventas_totales
FROM sales
WHERE store_id = :store_id
AND created_at::date BETWEEN :start_date AND :end_date
AND is_voided = FALSE;
```

**Presentación en UI:**
```
💰 Ventas Totales
$850.000
```

**Interpretación:**
- Dinero facturado (puede incluir fiado)
- NO es lo mismo que efectivo disponible
- NO incluye ventas anuladas

---

#### M2: Costo de Mercancía Vendida (COGS)

**Definición:** Suma del costo histórico de todos los productos vendidos

**Fórmula SQL:**
```sql
SELECT COALESCE(SUM(si.unit_cost * si.quantity), 0) as cogs
FROM sale_items si
JOIN sales s ON s.id = si.sale_id
WHERE s.store_id = :store_id
AND s.created_at::date BETWEEN :start_date AND :end_date
AND s.is_voided = FALSE;
```

**Presentación en UI:**
```
💸 Costo de lo Vendido
$595.000
```

**Interpretación:**
- Lo que le costó al tendero la mercancía que vendió
- Usa `unit_cost` histórico (guardado al momento de la venta)
- Permite calcular ganancia precisa incluso si el costo cambió después

---

#### M3: Ganancia Bruta

**Definición:** Diferencia entre ventas y costo de mercancía vendida

**Fórmula SQL:**
```sql
SELECT 
  COALESCE(SUM(s.total), 0) as ventas,
  COALESCE(SUM(si.unit_cost * si.quantity), 0) as cogs,
  COALESCE(SUM(s.total) - SUM(si.unit_cost * si.quantity), 0) as ganancia_bruta
FROM sales s
JOIN sale_items si ON si.sale_id = s.id
WHERE s.store_id = :store_id
AND s.created_at::date BETWEEN :start_date AND :end_date
AND s.is_voided = FALSE;
```

**Presentación en UI:**
```
💚 Ganancia Bruta
$255.000  📈 30% margen

ℹ️ Esto es lo que ganaste antes de
   pagar servicios y empleados.
```

**Lógica de Color:**
- Verde (💚): ganancia > 0
- Amarillo (⚠️): ganancia = 0
- Rojo (🔴): ganancia < 0 (vendió a pérdida)

---

#### M4: Margen Bruto Porcentual

**Definición:** Porcentaje de ganancia sobre las ventas

**Fórmula:**
```
Margen = (Ganancia Bruta / Ventas Totales) × 100
```

**Fórmula SQL:**
```sql
SELECT 
  CASE 
    WHEN SUM(s.total) > 0 THEN
      ROUND(((SUM(s.total) - SUM(si.unit_cost * si.quantity)) / SUM(s.total) * 100)::numeric, 1)
    ELSE 0
  END as margen_porcentual
FROM sales s
JOIN sale_items si ON si.sale_id = s.id
WHERE s.store_id = :store_id
AND s.created_at::date BETWEEN :start_date AND :end_date
AND s.is_voided = FALSE;
```

**Presentación en UI:**
```
📊 Margen Promedio: 30%

Por cada $100 que vendes,
te quedan $30 después de pagar
lo que costó la mercancía.
```

**Benchmark de Industria:**
- < 20%: Bajo (revisar precios o costos)
- 20-30%: Normal para tienda de barrio
- 30-40%: Saludable
- > 40%: Excelente

---

### 7.2. Métricas de Productos

#### M5: Top Productos por Ganancia

**Definición:** Productos ordenados por ganancia generada (no por unidades)

**Fórmula SQL:**
```sql
SELECT 
  p.id,
  p.name,
  SUM(si.quantity) as units_sold,
  ROUND(AVG((si.unit_price - si.unit_cost) / si.unit_price * 100), 1) as margen_promedio,
  SUM((si.unit_price - si.unit_cost) * si.quantity) as ganancia_total
FROM products p
JOIN sale_items si ON si.product_id = p.id
JOIN sales s ON s.id = si.sale_id
WHERE s.store_id = :store_id
AND s.created_at::date BETWEEN :start_date AND :end_date
AND s.is_voided = FALSE
GROUP BY p.id, p.name
ORDER BY ganancia_total DESC
LIMIT 10;
```

**Presentación en UI:**
```
#1  Aceite Gourmet 1L
    42 unds  |  Margen: 40%
    Ganancia: $84.000
    ████████████████████████░░░░░
```

---

#### M6: Top Productos por Unidades

**Definición:** Productos ordenados por cantidad vendida

**Fórmula SQL:**
```sql
SELECT 
  p.id,
  p.name,
  SUM(si.quantity) as units_sold,
  -- Calcular días de rotación
  CASE 
    WHEN MAX(im.created_at) IS NOT NULL THEN
      ROUND(EXTRACT(EPOCH FROM (MAX(s.created_at) - MAX(im.created_at))) / 86400, 0)
    ELSE NULL
  END as dias_rotacion
FROM products p
JOIN sale_items si ON si.product_id = p.id
JOIN sales s ON s.id = si.sale_id
LEFT JOIN inventory_movements im ON im.product_id = p.id AND im.movement_type = 'entrada'
WHERE s.store_id = :store_id
AND s.created_at::date BETWEEN :start_date AND :end_date
AND s.is_voided = FALSE
GROUP BY p.id, p.name
ORDER BY units_sold DESC
LIMIT 10;
```

---

#### M7: Productos Estancados

**Definición:** Productos sin ventas en 30+ días

**Fórmula SQL:**
```sql
SELECT 
  p.id,
  p.name,
  p.current_stock,
  p.current_stock * p.cost_price as capital_inmovilizado,
  COALESCE(MAX(s.created_at), p.created_at) as ultima_venta,
  EXTRACT(DAY FROM (CURRENT_DATE - COALESCE(MAX(s.created_at), p.created_at)::date)) as dias_sin_venta
FROM products p
LEFT JOIN sale_items si ON si.product_id = p.id
LEFT JOIN sales s ON s.id = si.sale_id AND s.is_voided = FALSE
WHERE p.store_id = :store_id
AND p.deleted_at IS NULL
AND p.current_stock > 0
GROUP BY p.id, p.name, p.current_stock, p.cost_price, p.created_at
HAVING EXTRACT(DAY FROM (CURRENT_DATE - COALESCE(MAX(s.created_at), p.created_at)::date)) > 30
ORDER BY capital_inmovilizado DESC;
```

**Presentación en UI:**
```
🐌 Shampoo Marca X
📅 Última venta: hace 45 días
📦 Stock: 20 unidades
💰 Capital inmovilizado: $40.000
```

---

### 7.3. Métricas de Inventario

#### M8: Valor del Inventario

**Definición:** Suma del valor de todos los productos en stock

**Fórmula SQL:**
```sql
SELECT SUM(current_stock * cost_price) as valor_inventario
FROM products
WHERE store_id = :store_id
AND deleted_at IS NULL;
```

**Presentación en UI:**
```
📦 Valor Total del Inventario
$1.850.000
```

---

#### M9: Días de Inventario

**Definición:** Cuántos días puede seguir vendiendo con el stock actual

**Fórmula SQL:**
```sql
WITH cogs_diario AS (
  SELECT AVG(daily_cogs) as cogs_promedio
  FROM (
    SELECT 
      DATE(s.created_at),
      SUM(si.unit_cost * si.quantity) as daily_cogs
    FROM sales s
    JOIN sale_items si ON si.sale_id = s.id
    WHERE s.store_id = :store_id
    AND s.created_at >= CURRENT_DATE - INTERVAL '30 days'
    AND s.is_voided = FALSE
    GROUP BY DATE(s.created_at)
  ) sub
)
SELECT 
  SUM(p.current_stock * p.cost_price) as valor_inventario,
  CASE 
    WHEN cd.cogs_promedio > 0 THEN
      ROUND(SUM(p.current_stock * p.cost_price) / cd.cogs_promedio, 0)
    ELSE NULL
  END as dias_inventario
FROM products p, cogs_diario cd
WHERE p.store_id = :store_id
AND p.deleted_at IS NULL;
```

**Presentación en UI:**
```
⏱️ Tienes mercancía para 23 días
(Basado en tus ventas de los últimos 30 días)

✅ Estado: Saludable (ideal: 15-30 días)
```

**Interpretación:**

| Días | Estado | Acción |
|------|--------|--------|
| < 7 | ⚠️ Riesgo de agotamiento | Ordenar urgente |
| 7-15 | ⚡ Óptimo | Mantener ritmo |
| 15-30 | ✅ Saludable | Normal |
| > 30 | 🐌 Sobre-inventario | Liquidar productos |

---

#### M10: Rotación de Inventario (por Producto)

**Definición:** Cada cuántos días se agota un producto

**Fórmula SQL:**
```sql
WITH ventas_diarias AS (
  SELECT 
    si.product_id,
    AVG(si.quantity) as promedio_diario
  FROM sale_items si
  JOIN sales s ON s.id = si.sale_id
  WHERE s.store_id = :store_id
  AND s.created_at >= CURRENT_DATE - INTERVAL '30 days'
  AND s.is_voided = FALSE
  GROUP BY si.product_id
)
SELECT 
  p.id,
  p.name,
  p.current_stock,
  vd.promedio_diario,
  CASE 
    WHEN vd.promedio_diario > 0 THEN
      ROUND(p.current_stock / vd.promedio_diario, 0)
    ELSE NULL
  END as dias_para_agotar
FROM products p
LEFT JOIN ventas_diarias vd ON vd.product_id = p.id
WHERE p.store_id = :store_id
AND p.deleted_at IS NULL;
```

**Presentación en UI:**
```
🔥 Arroz Diana
   Se acaba cada 3 días ⚡
   Stock actual: 15 unidades
   
🐌 Whisky Premium
   Se acaba cada 60 días
   Stock actual: 3 unidades
```

---

### 7.4. Métricas de Flujo de Dinero

#### M11: Desglose por Método de Pago

**Definición:** Distribución de ventas según cómo pagaron

**Fórmula SQL:**
```sql
SELECT 
  payment_method,
  COALESCE(SUM(total), 0) as monto,
  ROUND(COALESCE(SUM(total), 0) / (SELECT SUM(total) FROM sales WHERE store_id = :store_id AND created_at::date BETWEEN :start_date AND :end_date AND is_voided = FALSE) * 100, 1) as porcentaje
FROM sales
WHERE store_id = :store_id
AND created_at::date BETWEEN :start_date AND :end_date
AND is_voided = FALSE
GROUP BY payment_method;
```

**Presentación en UI:**
```
Efectivo
$400.000  (47%)
████████████░░░░░░░░░░░░░░
💡 Debe estar en el cajón

Nequi / Daviplata
$300.000  (35%)
█████████░░░░░░░░░░░░░░░░░
💡 En bancos digitales

Fiado (Por cobrar)
$150.000  (18%)
████░░░░░░░░░░░░░░░░░░░░░░
💡 Clientes te deben
```

---

#### M12: Cartera Total y Vencida

**Definición:** Dinero que clientes deben (total y > 30 días)

**Fórmula SQL:**
```sql
SELECT 
  COALESCE(SUM(balance), 0) as cartera_total,
  COALESCE(SUM(CASE 
    WHEN last_purchase_date < CURRENT_DATE - INTERVAL '30 days' 
    THEN balance ELSE 0 
  END), 0) as cartera_vencida,
  COUNT(*) as clientes_con_deuda
FROM clients
WHERE store_id = :store_id
AND balance > 0;
```

**Presentación en UI:**
```
📋 Fiado Pendiente

Total por cobrar: $450.000

⚠️ Cartera Vencida (>30 días): $120.000
   3 clientes deben hace más de un mes

💡 Considera cobrar esta semana.
```

---

## 8. Especificación de RPCs

### RPC-01: get_financial_summary

**Propósito:** Obtener resumen financiero completo para Sección 1 del Dashboard

**Parámetros:**
```sql
p_store_id    UUID        (obligatorio)
p_start_date  DATE        (obligatorio)
p_end_date    DATE        (obligatorio)
```

**Retorno (JSONB):**
```json
{
  "ventas_totales": 850000,
  "cogs": 595000,
  "ganancia_bruta": 255000,
  "margen_porcentual": 30.0,
  "comparacion": {
    "periodo_anterior": {
      "ventas": 800000,
      "ganancia": 205000
    },
    "diferencia_ventas": 50000,
    "porcentaje_cambio": 6.25,
    "tendencia": "alcista"
  },
  "desglose_pago": {
    "efectivo": {
      "monto": 400000,
      "porcentaje": 47.1
    },
    "nequi": {
      "monto": 200000,
      "porcentaje": 23.5
    },
    "daviplata": {
      "monto": 100000,
      "porcentaje": 11.8
    },
    "fiado": {
      "monto": 150000,
      "porcentaje": 17.6
    }
  }
}
```

**Lógica Interna:**
1. Calcular ventas, COGS y ganancia del período solicitado
2. Calcular mismo período anterior (para comparación)
3. Determinar tendencia: alcista si > +5%, bajista si < -5%, estable si entre -5% y +5%
4. Desglosar ventas por método de pago

**Performance:**
- Target: < 500ms
- Optimización: Índices en `sales.created_at`, `sales.store_id`, `sales.payment_method`

---

### RPC-02: get_top_products_by_profit

**Propósito:** Obtener productos ordenados por ganancia generada

**Parámetros:**
```sql
p_store_id    UUID        (obligatorio)
p_start_date  DATE        (obligatorio)
p_end_date    DATE        (obligatorio)
p_limit       INTEGER     (default: 10)
```

**Retorno (TABLE):**
```sql
product_id         UUID
product_name       TEXT
units_sold         NUMERIC
margen_promedio    NUMERIC (porcentaje, ej: 40.5)
ganancia_total     NUMERIC
stock_actual       NUMERIC
stock_status       TEXT ('ok' | 'low' | 'critical')
```

**Ejemplo de Retorno:**
```json
[
  {
    "product_id": "uuid-1",
    "product_name": "Aceite Gourmet 1L",
    "units_sold": 42,
    "margen_promedio": 40.5,
    "ganancia_total": 84000,
    "stock_actual": 15,
    "stock_status": "ok"
  },
  {
    "product_id": "uuid-2",
    "product_name": "Arroz Diana 500g",
    "units_sold": 54,
    "margen_promedio": 20.0,
    "ganancia_total": 54000,
    "stock_actual": 3,
    "stock_status": "critical"
  }
]
```

**Orden:** `ganancia_total DESC`

---

### RPC-03: get_top_products_by_units

**Propósito:** Obtener productos ordenados por unidades vendidas

**Parámetros:** Iguales a RPC-02

**Retorno (TABLE):**
```sql
product_id         UUID
product_name       TEXT
units_sold         NUMERIC
dias_rotacion      INTEGER (nullable)
stock_actual       NUMERIC
```

**Orden:** `units_sold DESC`

---

### RPC-04: get_stagnant_products

**Propósito:** Obtener productos sin ventas en X días

**Parámetros:**
```sql
p_store_id         UUID        (obligatorio)
p_days_threshold   INTEGER     (default: 30)
```

**Retorno (TABLE):**
```sql
product_id              UUID
product_name            TEXT
ultima_venta            DATE
dias_sin_venta          INTEGER
stock_actual            NUMERIC
capital_inmovilizado    NUMERIC (stock × cost_price)
```

**Orden:** `capital_inmovilizado DESC`

**Ejemplo de Retorno:**
```json
[
  {
    "product_id": "uuid-3",
    "product_name": "Whisky Premium",
    "ultima_venta": "2025-12-23",
    "dias_sin_venta": 60,
    "stock_actual": 3,
    "capital_inmovilizado": 210000
  },
  {
    "product_id": "uuid-4",
    "product_name": "Shampoo Marca X",
    "ultima_venta": "2026-01-08",
    "dias_sin_venta": 45,
    "stock_actual": 20,
    "capital_inmovilizado": 40000
  }
]
```

---

### RPC-05: get_inventory_health

**Propósito:** Obtener métricas de salud del inventario

**Parámetros:**
```sql
p_store_id    UUID        (obligatorio)
```

**Retorno (JSONB):**
```json
{
  "valor_total": 1850000,
  "dias_inventario": 23,
  "estado": "saludable",
  "distribucion_rotacion": {
    "rapida": {
      "count": 5,
      "valor": 400000,
      "porcentaje": 21.6
    },
    "normal": {
      "count": 6,
      "valor": 1150000,
      "porcentaje": 62.2
    },
    "lenta": {
      "count": 2,
      "valor": 300000,
      "porcentaje": 16.2
    }
  }
}
```

**Lógica de Estado:**
- `"riesgo"`: dias_inventario < 7
- `"optimo"`: dias_inventario entre 7 y 15
- `"saludable"`: dias_inventario entre 15 y 30
- `"sobre_inventario"`: dias_inventario > 30

**Clasificación de Rotación:**
- Rápida: Producto se agota en < 7 días
- Normal: Producto se agota en 7-30 días
- Lenta: Producto se agota en > 30 días

---

### RPC-06: get_client_ledger_summary

**Propósito:** Obtener resumen de cartera de fiado

**Parámetros:**
```sql
p_store_id    UUID        (obligatorio)
```

**Retorno (JSONB):**
```json
{
  "cartera_total": 450000,
  "cartera_vencida": 120000,
  "clientes_con_deuda": 8,
  "clientes_morosos": 2,
  "top_deudores": [
    {
      "client_id": "uuid-5",
      "client_name": "Juan Pérez",
      "balance": 80000,
      "dias_sin_pagar": 45,
      "ultima_compra": "2026-01-08"
    },
    {
      "client_id": "uuid-6",
      "client_name": "María López",
      "balance": 40000,
      "dias_sin_pagar": 35,
      "ultima_compra": "2026-01-18"
    }
  ]
}
```

---

## 9. Wireframes y Flujos

### 9.1. Flujo de Navegación Principal

```
Usuario abre app
    ↓
Login
    ↓
[POS] [Administración] [Historial]
         ↓ (toca)
    AdminHub
    ↓
[Inventario] [Reportes] [Configuración]
                ↓ (toca)
         FinancialDashboard
         ↓
    [Hoy] [Semana] [Mes]
         ↓
    ┌─────────────────────┐
    │ Sección 1: Resumen  │
    │ Financiero          │
    └─────────────────────┘
    ┌─────────────────────┐
    │ Sección 2:          │
    │ Inteligencia de     │
    │ Productos           │
    └─────────────────────┘
    ┌─────────────────────┐
    │ Sección 3:          │
    │ Flujo de Dinero     │
    └─────────────────────┘
```

---

### 9.2. Wireframe de Sección 1 (Resumen Financiero)

```
┌───────────────────────────────────────────┐
│ 📊 RESUMEN FINANCIERO                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                           │
│   Ventas Totales                          │
│   $850.000                                │
│   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                           │
│   Costo de lo Vendido                     │
│   $595.000                                │
│                                           │
│   Ganancia Bruta                          │
│   $255.000  📈 30% margen                 │
│                                           │
│   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                           │
│   ℹ️ Esto es lo que ganaste antes de     │
│      pagar servicios y empleados.         │
│                                           │
│   📊 Comparación con período anterior:    │
│      +$50.000 (+24%) ↗️                   │
│                                           │
└───────────────────────────────────────────┘
```

**Estados Visuales:**

| Condición | Estilo |
|-----------|--------|
| Ganancia > 0 | Verde 💚, flecha ↗️ |
| Ganancia = 0 | Amarillo ⚠️, sin flecha |
| Ganancia < 0 | Rojo 🔴, flecha ↘️ |
| Comparación positiva | Verde, +X%, ↗️ |
| Comparación negativa | Rojo, -X%, ↘️ |

---

### 9.3. Wireframe de Sección 2 (Inteligencia de Productos)

```
┌───────────────────────────────────────────┐
│ 💡 INTELIGENCIA DE PRODUCTOS              │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                           │
│ [🔥 Top Ganancia] [📊 Top Unidades]      │
│ [🐌 Estancados] [⚠️ Stock Bajo]          │
│                                           │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                           │
│ #1  Aceite Gourmet 1L              [>]   │
│     42 unds  |  Margen: 40%              │
│     Ganancia: $84.000                    │
│     ████████████████████████░░░░░        │
│                                           │
│ #2  Arroz Diana 500g               [>]   │
│     54 unds  |  Margen: 20%              │
│     Ganancia: $54.000                    │
│     ███████████████░░░░░░░░░░░░░░        │
│                                           │
│ #3  Coca-Cola 1.5L                 [>]   │
│     36 unds  |  Margen: 35%              │
│     Ganancia: $50.400                    │
│     ██████████████░░░░░░░░░░░░░░░        │
│                                           │
│ [Ver todos los productos →]               │
│                                           │
│ 💡 Insight:                               │
│ Aceite te deja más utilidad aunque       │
│ vendas menos unidades que Arroz.         │
│                                           │
└───────────────────────────────────────────┘
```

**Interacciones:**
- Tocar sub-pestaña → Cambia contenido de la lista
- Tocar producto (flecha >) → Muestra modal con detalle
- Tocar "Ver todos" → Navega a vista completa con tabla

---

### 9.4. Wireframe de Sección 3 (Flujo de Dinero)

```
┌───────────────────────────────────────────┐
│ 💵 ¿DÓNDE ESTÁ EL DINERO?                 │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                           │
│ Efectivo                                  │
│ $400.000  (47%)                           │
│ ████████████░░░░░░░░░░░░░░                │
│ 💡 Debe estar en el cajón                 │
│                                           │
│ Nequi / Daviplata                         │
│ $300.000  (35%)                           │
│ █████████░░░░░░░░░░░░░░░░░                │
│ 💡 En bancos digitales                    │
│                                           │
│ Fiado (Por cobrar)                        │
│ $150.000  (18%)                           │
│ ████░░░░░░░░░░░░░░░░░░░░░░                │
│ 💡 Clientes te deben                      │
│                                           │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                           │
│ Total: $850.000                           │
│                                           │
│ [Ver detalle de fiado →]                  │
│                                           │
└───────────────────────────────────────────┘
```

**Cálculo de Barras:**
- Ancho de barra = (monto / total) × 100%
- Color: Azul para efectivo/nequi, Naranja para fiado

---

### 9.5. Modal de Detalle de Fiado

```
┌───────────────────────────────────────────┐
│ ← 📋 DETALLE DE FIADO                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                           │
│ Total por cobrar: $450.000                │
│                                           │
│ ⚠️ Vencido (>30 días): $120.000           │
│                                           │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                           │
│ ┌───────────────────────────────────┐    │
│ │ Juan Pérez                    [>] │    │
│ │ Debe: $80.000                     │    │
│ │ ⚠️ Última compra: hace 45 días    │    │
│ └───────────────────────────────────┘    │
│                                           │
│ ┌───────────────────────────────────┐    │
│ │ María López                   [>] │    │
│ │ Debe: $40.000                     │    │
│ │ ⚠️ Última compra: hace 35 días    │    │
│ └───────────────────────────────────┘    │
│                                           │
│ ┌───────────────────────────────────┐    │
│ │ Carlos Gómez                  [>] │    │
│ │ Debe: $30.000                     │    │
│ │ ✅ Última compra: hace 10 días    │    │
│ └───────────────────────────────────┘    │
│                                           │
└───────────────────────────────────────────┘
```

**Interacciones:**
- Tocar cliente → Navega a detalle de cliente con historial completo
- ⚠️ aparece si días sin pagar > 30

---

## 10. Requisitos No Funcionales

### 10.1. Performance

| Requisito | Target | Medición |
|-----------|--------|----------|
| **RNF-01** | Carga inicial de Dashboard < 2 seg | Time to Interactive |
| **RNF-02** | Respuesta de RPC < 500ms | Server response time |
| **RNF-03** | Cambio de pestaña (Hoy/Semana/Mes) < 300ms | UI transition |
| **RNF-04** | Soporte de 10,000 ventas/mes sin degradación | Load testing |

**Estrategias de Optimización:**
- Índices en columnas de filtrado frecuente (`created_at`, `store_id`, `is_voided`)
- Caché en frontend (TTL 60 segundos para Dashboard)
- Lazy loading de sub-pestañas (solo cargar al tocar)

---

### 10.2. Seguridad

| Requisito | Descripción |
|-----------|-------------|
| **RNF-05** | RLS en todas las RPCs (solo datos del `store_id` del usuario) |
| **RNF-06** | Empleados sin `canViewReports` → 403 Forbidden en Dashboard |
| **RNF-07** | Costos NO expuestos a empleados sin `canViewCosts` (futuro) |
| **RNF-08** | Logs de acceso a métricas financieras en `audit_logs` |

---

### 10.3. Usabilidad

| Requisito | Descripción |
|-----------|-------------|
| **RNF-09** | Dashboard comprensible sin manual (tooltips explicativos) |
| **RNF-10** | Ganancias negativas deben mostrar alerta visual (rojo 🔴) |
| **RNF-11** | Responsive: Diseñado mobile-first, adaptativo en tablet/desktop |
| **RNF-12** | Feedback inmediato: Skeleton screens durante carga |
| **RNF-13** | Lenguaje claro: NO usar jerga contable (ej: "COGS" → "Costo de lo vendido") |

---

### 10.4. Mantenibilidad

| Requisito | Descripción |
|-----------|-------------|
| **RNF-14** | Código modular: Cada RPC en archivo de migración separado |
| **RNF-15** | Tests unitarios para cálculos financieros (ganancia, margen) |
| **RNF-16** | Documentación inline en RPCs (comentarios SQL explicativos) |
| **RNF-17** | Componentes reutilizables (Cards, Barras de progreso) |

---

### 10.5. Escalabilidad

| Requisito | Descripción |
|-----------|-------------|
| **RNF-18** | Soportar 1,000 productos por tienda sin degradación |
| **RNF-19** | Soportar 100,000 ventas históricas sin impacto en queries |
| **RNF-20** | Queries optimizadas con EXPLAIN ANALYZE (no full table scans) |

---

## 11. Criterios de Aceptación

### 11.1. Criterios Funcionales

#### Dashboard Principal

- [ ] **AC-01:** Al abrir Dashboard, se muestra Ganancia Bruta en < 2 segundos
- [ ] **AC-02:** Ganancia Bruta es verde (💚) si positiva, roja (🔴) si negativa
- [ ] **AC-03:** Desglose de dinero suma exactamente el total de ventas
- [ ] **AC-04:** Cambiar pestaña (Hoy/Semana/Mes) actualiza todas las secciones
- [ ] **AC-05:** Comparación con período anterior muestra porcentaje correcto
- [ ] **AC-06:** Tooltip "ℹ️" explica que Ganancia Bruta NO incluye gastos operativos

#### Inteligencia de Productos

- [ ] **AC-07:** Top Ganancia ordena productos por `(price - cost) × quantity` DESC
- [ ] **AC-08:** Top Unidades ordena productos por `SUM(quantity)` DESC
- [ ] **AC-09:** Productos con stock crítico tienen badge "⚠️ Stock Bajo"
- [ ] **AC-10:** Productos Estancados muestra solo aquellos sin ventas > 30 días
- [ ] **AC-11:** Capital inmovilizado se calcula como `stock × cost_price`

#### Flujo de Dinero

- [ ] **AC-12:** Desglose por método de pago suma 100% (con tolerancia ±0.1%)
- [ ] **AC-13:** Fiado muestra monto correcto (`SUM(clients.balance)`)
- [ ] **AC-14:** Cartera vencida destaca clientes con última compra > 30 días
- [ ] **AC-15:** Tocar "Ver detalle de fiado" muestra modal con lista de clientes

#### Inventario

- [ ] **AC-16:** Días de Inventario se calcula correctamente (valor / COGS diario)
- [ ] **AC-17:** Estado "Saludable" se muestra si días están entre 15-30
- [ ] **AC-18:** Distribución de rotación clasifica productos correctamente

### 11.2. Criterios No Funcionales

- [ ] **AC-19:** Dashboard carga en < 2 seg con conexión 3G
- [ ] **AC-20:** RPC `get_financial_summary` responde en < 500ms con 1,000 ventas
- [ ] **AC-21:** Empleado sin `canViewReports` recibe 403 al intentar acceder
- [ ] **AC-22:** Dashboard es responsive (mobile 375px, tablet 768px, desktop 1024px+)
- [ ] **AC-23:** Tooltips explicativos en conceptos contables (COGS, Margen, Rotación)

### 11.3. Criterios de QA

- [ ] **AC-24:** Tests unitarios para cálculo de COGS con 5 casos
- [ ] **AC-25:** Tests unitarios para cálculo de Margen con 5 casos (incluyendo margen = 0)
- [ ] **AC-26:** Tests unitarios para Días de Inventario con casos límite (COGS = 0)
- [ ] **AC-27:** Tests E2E para flujo completo: Login → Dashboard → Ver Top Ganancia
- [ ] **AC-28:** Validación manual: Ganancia calculada coincide con contabilidad real

---

## Apéndices

### Apéndice A: Glosario de Términos Contables

| Término Técnico | Definición Clara | Cómo lo Mostramos al Usuario |
|----------------|------------------|------------------------------|
| **COGS** | Cost of Goods Sold (Costo de Mercancía Vendida) | "Costo de lo vendido" |
| **Margen Bruto** | Porcentaje de ganancia sobre ventas | "Margen: 30%" |
| **Rotación** | Velocidad de venta de un producto | "Se acaba cada 3 días" |
| **Días de Inventario** | Cuántos días puede vender sin reabastecerse | "Tienes mercancía para 23 días" |
| **Cartera Vencida** | Dinero que clientes deben hace > 30 días | "⚠️ Clientes morosos" |
| **Capital Inmovilizado** | Dinero invertido en inventario que no se mueve | "Tienes $300k durmiendo en productos" |

### Apéndice B: Referencias

- **Auditoría de Datos:** `AUDITORIA_DATOS_ANALYTICS.md`
- **Arquitectura del Sistema:** `ARCHITECTURE_MAP.md`
- **Estado Actual de Reportes:** `REPORTE_ESTADO_ACTUAL.md`
- **Estado Actual de Historiales:** `HISTORIAL_ESTADO_ACTUAL.md`
- **Límites del Sistema:** `SYSTEM_BOUNDARIES.md`

### Apéndice C: Próximos Pasos

1. **Validación de Stakeholders:** Presentar FRD a equipo y usuario piloto
2. **Priorización Final:** Confirmar Must Have vs Should Have vs Could Have
3. **Estimación de Esfuerzo:** Tech Lead estima tiempo de desarrollo
4. **Creación de Tickets:** Desglosar FRD en User Stories para Jira/GitHub
5. **Kickoff de Desarrollo:** Comenzar con RPC-01 (get_financial_summary)

---

**Fin del Documento**

*Este FRD es un documento vivo. Se actualizará conforme avance el desarrollo y se reciba feedback de usuarios.*
