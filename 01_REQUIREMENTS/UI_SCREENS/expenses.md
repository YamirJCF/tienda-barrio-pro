# Gastos / Salidas de Caja (ExpensesView)

## Descripción
Vista para registrar salidas de dinero de la caja (gastos, pagos a proveedores, retiros personales, etc.). Estos gastos se restan del efectivo esperado durante el arqueo de caja.

## Ruta
`/expenses`

---

## Flujo de Usuario

### Registro de Gasto
1. Usuario accede desde Admin Hub → "Nuevo Gasto"
2. Ve display con monto actual ($0)
3. Ingresa el monto usando el **numpad visual** (teclado numérico)
4. Selecciona una **categoría** de las 4 disponibles
5. (Opcional) Agrega una **nota descriptiva**
6. Click en **"REGISTRAR SALIDA"**
7. Sistema muestra confirmación y redirige a `/admin`

---

## Categorías de Gasto

| Valor | Label | Icono | Uso Típico |
|-------|-------|-------|------------|
| `proveedor` | Pago Proveedor | `local_shipping` | Pago a distribuidores |
| `servicios` | Servicios | `electric_bolt` | Luz, agua, internet |
| `retiro` | Retiro Personal | `person` | Retiro del propietario |
| `varios` | Gastos Varios | `inventory_2` | Otros gastos menores |

---

## Datos de Entrada (Usuario)

| Campo | Tipo | Validación | UI |
|-------|------|------------|-----|
| `amount` | `string` → `number` | Requerido, > 0 | Numpad visual |
| `category` | `string` | Requerido | Grid 2x2 de botones |
| `note` | `string` | Opcional | Input de texto |

---

## Datos de Salida (Hacia Stores)

### useExpensesStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addExpense()` | `{ description, amount, category, note }` | Registra nuevo gasto |

---

## Estructura de Gasto

```typescript
interface Expense {
    id: number;
    description: string;    // Label de categoría
    amount: Decimal;
    category: string;       // Valor de categoría
    note: string;           // Nota opcional
    timestamp: string;      // ISO timestamp
    date: string;           // YYYY-MM-DD
}
```

---

## Store: useExpensesStore

### Estado
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `expenses` | `Expense[]` | Lista de todos los gastos |
| `nextId` | `number` | Auto-incremental ID |

### Propiedades Computadas
| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `todayDate` | `string` | Fecha actual (YYYY-MM-DD) |
| `todayExpenses` | `Expense[]` | Gastos del día actual |
| `todayTotal` | `Decimal` | Suma de gastos del día |
| `todayCount` | `number` | Cantidad de gastos del día |

### Métodos
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addExpense()` | `Omit<Expense, 'id' | 'timestamp' | 'date'>` | Crea nuevo gasto |
| `deleteExpense()` | `id: number` | Elimina un gasto |
| `getExpensesByDate()` | `date: string` | Filtra por fecha |
| `getTotalByDate()` | `date: string` | Total de una fecha |
| `clearTodayExpenses()` | - | **Limpia gastos del día** |

---

## Función Crítica: clearTodayExpenses()

> [!IMPORTANT]
> Esta función se ejecuta al **cerrar la caja** en `CashControlView`.

### Trigger
```typescript
// En CashControlView.vue, línea 76
expensesStore.clearTodayExpenses();
```

### Comportamiento
- Elimina todos los gastos del día actual
- Se invoca solo al cerrar turno exitosamente
- Evita doble contabilización en días posteriores

### Flujo de Limpieza
```
Dashboard → Toggle Cerrar → CashControlView → Arqueo OK → clearTodayExpenses() → Redirige a Admin
```

---

## Conexión con Control de Caja

Los gastos afectan directamente el **efectivo esperado** en el arqueo:

```typescript
// Fórmula en CashControlView.vue
expectedCash = openingCash + todayCash - todayExpenses
//                                        ↑
//                          expensesStore.todayTotal
```

---

## Navegación

### Desde
| Origen | Acción | Ruta |
|--------|--------|------|
| Admin Hub | Click "Nuevo Gasto" | `/expenses` |

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Admin Hub | Botón ← | `/admin` |
| Admin Hub | Después de registrar | `/admin` |

---

## Componentes UI Utilizados
- Header con botón de retroceso
- Display de monto (hero con color naranja/rojo)
- Grid 2x2 de categorías con indicador de selección
- Input de nota opcional
- Numpad visual (3x4 grid con C y backspace)
- Botón de acción "REGISTRAR SALIDA"

---

## Interacción del Numpad

| Tecla | Acción |
|-------|--------|
| `0-9` | Agrega dígito al monto |
| `C` | Resetea monto a "0" |
| `backspace` | Elimina último dígito |

### Límites
- Máximo 10 dígitos
- No permite decimales (solo enteros)

---

## Validación de Envío

```typescript
canSubmit = amount !== '0' && selectedCategory !== ''
```

| Condición | Resultado |
|-----------|-----------|
| Monto = 0 | ❌ Botón deshabilitado |
| Sin categoría | ❌ Botón deshabilitado |
| Monto > 0 + Categoría | ✅ Botón habilitado |

---

## Stores Utilizados
- `useExpensesStore`

## Persistencia
```typescript
persist: {
    key: 'tienda-expenses',
    storage: localStorage,
    serializer: expensesSerializer
}
```
