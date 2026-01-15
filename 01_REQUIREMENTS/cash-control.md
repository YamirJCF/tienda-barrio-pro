# Control de Caja (CashControlView)

## Descripción
Vista de gestión de caja que permite abrir la jornada con un monto base y realizar el arqueo de cierre comparando el efectivo esperado vs el contado.

## Ruta
`/cash-control`

## Estados de la Vista

Esta vista tiene **dos estados mutuamente excluyentes** basados en `salesStore.isStoreOpen`:

| Estado | Condición | Acción Principal |
|--------|-----------|------------------|
| **Apertura** | `isStoreOpen === false` | Iniciar jornada con monto base |
| **Cierre/Arqueo** | `isStoreOpen === true` | Contar efectivo y cerrar turno |

---

## Flujo de Usuario

### Estado 1: Apertura de Caja (Iniciar Jornada)

1. Usuario accede desde Dashboard (toggle) o Admin Hub
2. Ve pantalla "Iniciar Jornada" con mensaje de bienvenida
3. Ingresa el monto de **Base / Sencillo Inicial** en el campo numérico
4. Click en **"Abrir Caja"**
5. Sistema registra apertura con el monto ingresado
6. Redirige a `/admin`

### Estado 2: Arqueo de Caja (Cierre de Turno)

1. Usuario accede desde Dashboard (toggle al cerrar) o Admin Hub
2. Ve **Resumen del Sistema** (solo lectura):
   - Base Inicial (+)
   - Ventas Efectivo (+)
   - Salidas / Gastos (-)
   - **Debe haber en Cajón** (total calculado)
3. Ingresa el monto **realmente contado** en el campo "¿Cuánto contaste?"
4. Sistema muestra feedback visual:
   - ✅ **Verde**: "¡Caja Cuadrada!" (diferencia = 0)
   - ⚠️ **Rojo**: "Hay una diferencia - Faltante: -$X" (diferencia < 0)
   - ℹ️ **Azul**: "Hay un sobrante - Excedente: +$X" (diferencia > 0)
5. Click en **"Cerrar Turno y Guardar"**
6. Sistema cierra la caja y limpia gastos del día
7. Redirige a `/admin`

---

## Datos de Entrada (Stores Consumidos)

### useSalesStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `isStoreOpen` | `boolean` | Estado de la tienda (abierta/cerrada) |
| `openingCash` | `Decimal` | Monto base de apertura |
| `todayCash` | `Decimal` | Total de ventas en efectivo del día |

### useExpensesStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `todayTotal` | `Decimal` | Total de gastos/salidas del día |

---

## Datos de Salida (Hacia Stores)

### useSalesStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `openStore()` | `Decimal` (monto base) | Registra apertura de jornada |
| `closeStore()` | - | Registra cierre de jornada |

### useExpensesStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `clearTodayExpenses()` | - | Limpia gastos del día al cerrar |

---

## Lógica de Negocio

### Fórmula de Efectivo Esperado

```typescript
expectedCash = openingCash + todayCash - todayExpenses
```

Donde:
- `openingCash`: Base inicial de apertura
- `todayCash`: Ventas del día pagadas en efectivo
- `todayExpenses`: Gastos/salidas registradas

### Cálculo de Diferencia

```typescript
difference = closingAmount - expectedCash
```

| Resultado | Estado | Mensaje |
|-----------|--------|---------|
| `difference === 0` | ✅ Cuadrada | "¡Caja Cuadrada! Perfecto" |
| `difference < 0` | ⚠️ Faltante | "Hay una diferencia - Faltante: -$X" |
| `difference > 0` | ℹ️ Sobrante | "Hay un sobrante - Excedente: +$X" |

---

## Navegación

### Desde
| Origen | Acción | Contexto |
|--------|--------|----------|
| Dashboard | Toggle "Cerrar Tienda" | Cuando `isStoreOpen === true` |
| Admin Hub | Click "Control de Caja" | Acceso directo |

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Admin Hub | Botón ← | `/admin` |
| Admin Hub | Después de Abrir Caja | `/admin` |
| Admin Hub | Después de Cerrar Turno | `/admin` |

---

## Conexión con Dashboard

> [!IMPORTANT]
> Esta vista es el **destino del toggle de apertura/cierre** del Dashboard.

| Acción en Dashboard | Comportamiento |
|---------------------|----------------|
| Toggle cuando tienda **CERRADA** | Abre **Modal de Apertura** en Dashboard |
| Toggle cuando tienda **ABIERTA** | Navega a `/cash-control` para **Arqueo** |

El flujo completo de cierre es:
1. Dashboard → Toggle "Cerrar" → Navega a `/cash-control`
2. CashControlView → Arqueo → "Cerrar Turno"
3. Redirige a `/admin`
4. Dashboard ahora muestra tienda CERRADA

---

## Campos de Entrada del Usuario

### Estado Apertura
| Campo | ID | Tipo | Placeholder | Validación |
|-------|----|------|-------------|------------|
| Base Inicial | `initial-base` | `number` | "0" | Acepta decimales |

### Estado Cierre
| Campo | ID | Tipo | Placeholder | Validación |
|-------|----|------|-------------|------------|
| Monto Contado | `real-count` | `number` | "0" | Acepta decimales |

---

## Componentes UI Utilizados
- Header con botón de retroceso
- Tarjeta de resumen (solo lectura)
- Input numérico con símbolo de moneda
- Mensajes de feedback con iconos contextuales
- Botón de acción principal

## Stores Utilizados
- `useSalesStore`
- `useExpensesStore`

## Composables Utilizados
- Ninguno (formateo inline)

---

## Comportamiento de Autofocus

| Estado | Campo Enfocado |
|--------|----------------|
| Apertura | Input de base inicial |
| Cierre | Input de monto contado |

---

## Resumen Visual de Cierre

| Línea | Descripción | Color | Signo |
|-------|-------------|-------|-------|
| Base Inicial | `salesStore.openingCash` | Verde | + |
| Ventas Efectivo | `salesStore.todayCash` | Verde | + |
| Salidas / Gastos | `expensesStore.todayTotal` | Rojo | - |
| **Debe haber en Cajón** | `expectedCash` (calculado) | Negro/Bold | = |
