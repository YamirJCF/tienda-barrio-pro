# DICT-001: Cash Movements (Movimientos de Caja)

**Versión:** 1.0  
**Fecha:** 2026-02-05  
**Autor:** Arquitecto de Producto  
**FRD Relacionado:** [FRD-004: Control de Caja](../FRD/FRD_004_CONTROL_DE_CAJA.md)

---

## Dominio

Control del flujo de efectivo físico durante sesiones de caja. Registra todas las entradas y salidas de dinero en el turno de un cajero.

---

## Valores Permitidos

### `movement_type`

Define el tipo de transacción monetaria en la caja registradora.

| Valor Técnico | Término de Negocio | Semántica | Ejemplos de Uso |
|---------------|-------------------|-----------|-----------------|
| `'ingreso'` | Ingreso de Efectivo | Dinero que **ENTRA** a la caja | • Venta en efectivo<br>• Depósito inicial (apertura)<br>• Ajuste positivo |
| `'gasto'` | Egreso de Efectivo | Dinero que **SALE** de la caja | • Compra a proveedor<br>• Retiro para banco<br>• Anulación de venta (devolución)<br>• Ajuste negativo |

---

## Reglas de Negocio

### 1. Inmutabilidad
Una vez registrado un movimiento, **NO puede editarse ni borrarse**. Si hay un error, se debe crear un movimiento correctivo inverso.

**Ejemplo:**
- Registré `'gasto'` de $5,000 por error
- Corrección: Crear `'ingreso'` de $5,000 con descripción "Corrección error movimiento X"

### 2. Ventas en Efectivo → `'ingreso'`
Toda venta procesada con método de pago `'efectivo'` o `'cash'` genera automáticamente un movimiento tipo `'ingreso'`.

### 3. Anulaciones → `'gasto'`
Cuando se anula una venta en efectivo, se registra un movimiento tipo `'gasto'` (devolución del dinero al cliente).

**Razón:** Desde la perspectiva de la caja, el dinero **sale**, por lo tanto es un gasto.

### 4. Cálculo de Saldo Esperado
```
Saldo Esperado = Base Inicial + SUM(ingresos) - SUM(gastos)
```

---

## Valores NO Permitidos

| Valor Incorrecto | Razón |
|------------------|-------|
| `'entrada'` | Término ambiguo, no definido en FRD |
| `'salida'` | Usar `'gasto'` en su lugar |
| `'venta'` | Redundante, toda venta es un `'ingreso'` |
| `'devolucion'` | Usar `'gasto'` para anulaciones |

---

## Implementación Técnica

### Constraint SQL

**Tabla:** `public.cash_movements`  
**Columna:** `movement_type TEXT NOT NULL`

```sql
ALTER TABLE public.cash_movements 
ADD CONSTRAINT cash_movements_movement_type_check 
CHECK (movement_type IN ('ingreso', 'gasto'));
```

**Estado:** ✅ Implementado (migración inicial)

---

### TypeScript Types

**Archivo:** `frontend/src/types/database.types.ts`

```typescript
// Tabla cash_movements
export interface CashMovement {
  id: string;
  session_id: string;
  movement_type: 'ingreso' | 'gasto'; // Solo estos dos valores
  amount: number;
  description: string;
  sale_id?: string;
  created_at: string;
}

// Type Helper
export type CashMovementType = 'ingreso' | 'gasto';
```

---

### Uso en RPCs

#### ✅ Correcto: `rpc_procesar_venta_v2`

```sql
INSERT INTO public.cash_movements (
    session_id, movement_type, amount, description, sale_id
) VALUES (
    v_session_id, 
    'ingreso',  -- ✅ Valor oficial
    v_total_calculated, 
    'Venta #' || v_ticket_number, 
    v_sale_id
);
```

#### ✅ Correcto: `rpc_anular_venta`

```sql
INSERT INTO public.cash_movements (
    session_id, movement_type, amount, description, sale_id
) VALUES (
    v_session_id, 
    'gasto',  -- ✅ Valor oficial (devolución de dinero)
    v_sale.total, 
    'REVERSO VENTA #' || v_sale.ticket_number, 
    p_sale_id
);
```

---

## Casos de Uso Documentados

### Caso 1: Venta en Efectivo
**Actor:** Empleado  
**Acción:** Procesar venta método `'efectivo'`  
**Resultado Backend:**
```sql
-- Automáticamente se crea:
INSERT INTO cash_movements (movement_type, amount, ...)
VALUES ('ingreso', 1500, ...);
```

### Caso 2: Gasto Manual (Compra Proveedor)
**Actor:** Empleado con permiso  
**Acción:** Registrar salida de $20,000 para proveedor  
**Resultado Backend:**
```sql
INSERT INTO cash_movements (movement_type, amount, description)
VALUES ('gasto', 20000, 'Compra verduras Proveeduría X');
```

### Caso 3: Anulación de Venta
**Actor:** Admin  
**Acción:** Anular venta #1234 de $3,500  
**Resultado Backend:**
```sql
-- RPC rpc_anular_venta crea:
INSERT INTO cash_movements (movement_type, amount, description)
VALUES ('gasto', 3500, 'REVERSO VENTA #1234');
```

---

## Historial de Cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1.0 | 2026-02-05 | Arquitecto | Definición inicial tras bug de `'entrada'` |

---

## Referencias

- **FRD-004:** Control de Caja (línea 96 define "ingreso/gasto")
- **Migración:** `20260201174500_secure_gatekeeper_backend.sql` (usa oficial)
- **Bug Histórico:** Migración `20260205160000` usó `'entrada'` (corregido en hotfix)
- **Constraint:** Creado en migración inicial de `cash_movements`

---

## Notas de Arquitectura

### ¿Por qué no "entrada/salida"?

**Decisión:** Preferimos **"ingreso/gasto"** porque:

1. **Claridad contable:** Términos estándar en contabilidad
2. **Consistencia con FRD:** FRD-004 original usa esta terminología
3. **Evita ambigüedad:** "entrada" podría confundirse con "entrada de inventario"
4. **Precedente establecido:** Primera migración usó estos valores

### ¿Por qué anulaciones son "gasto"?

Desde la perspectiva de la **caja física**, cuando se anula una venta en efectivo:
- El dinero **sale** de la caja (se devuelve al cliente)
- Por lo tanto, es un **egreso = gasto**

Esto simplifica la lógica y mantiene solo 2 valores en lugar de 3+ valores especializados.
