# Documento de Requisitos Funcionales (FRD)

## SPEC-010: Política de Redondeo Empresarial

---

### Descripción

Este documento define la política de redondeo de montos monetarios para garantizar que todos los valores calculados sean **cobrables en efectivo colombiano**. El problema identificado es que los productos vendidos por peso generan decimales largos debido a cálculos de punto flotante (ej: `$1.447,58...`), lo cual no corresponde a ninguna denominación física.

> [!IMPORTANT]
> **Principio Fundamental**: El redondeo debe ocurrir **en el momento del cálculo**, no solo en la visualización. Esto garantiza integridad de datos y evita discrepancias entre lo mostrado y lo almacenado.

---

### Denominaciones del Peso Colombiano

El sistema de monedas y billetes en Colombia es:

| Tipo | Denominación | Descripción |
|------|--------------|-------------|
| **Moneda** | $50 | Mínima denominación en circulación |
| Moneda | $100 | - |
| Moneda | $200 | - |
| Moneda | $500 | - |
| Moneda | $1.000 | - |
| **Billete** | $2.000 | - |
| Billete | $5.000 | - |
| Billete | $10.000 | - |
| Billete | $20.000 | - |
| Billete | $50.000 | - |
| Billete | $100.000 | Máxima denominación |

> [!NOTE]
> La moneda de **$50 es la unidad mínima cobrable**, por lo tanto todos los montos deben redondearse a **múltiplos de $50**.

---

### Reglas de Negocio

#### RN-01: Redondeo a Múltiplos de $50
Todos los montos monetarios (subtotales, totales) deben redondearse a **múltiplos de $50 pesos colombianos**.

#### RN-02: Estrategia de Redondeo Híbrida (Beneficio al Cliente)

> [!IMPORTANT]
> **Principio**: Beneficiar al cliente en casos donde la diferencia es pequeña, pero proteger el margen cuando la diferencia es significativa.

**Regla**: Calcular el residuo (`valor % 50`):
- Si **residuo ≤ 25** → Redondear **hacia abajo** (cliente gana)
- Si **residuo > 25** → Redondear **hacia arriba** (más cercano)

**Ejemplos:**
| Valor Calculado | Residuo | Dirección | Valor Final |
|-----------------|---------|-----------|-------------|
| $1.447 | 47 > 25 | ⬆️ Arriba | **$1.450** |
| $1.423 | 23 ≤ 25 | ⬇️ Abajo | **$1.400** |
| $1.426 | 26 > 25 | ⬆️ Arriba | **$1.450** |
| $1.525 | 25 ≤ 25 | ⬇️ Abajo | **$1.500** |

#### RN-03: Punto de Redondeo (Sistema Sincronizado)

> [!IMPORTANT]
> El redondeo debe aplicarse en **todos** los puntos donde se ingresan o calculan montos.

| Componente | Operación | Momento |
|------------|-----------|--------|
| **Inventario** | Crear/Editar producto | Al guardar `price` |
| **POS** | Agregar producto pesable | Al calcular `subtotal` |
| **Checkout** | Calcular total | Suma de subtotales redondeados |
| **Vueltos** | Calcular cambio | Después de la resta |

#### RN-04: Fórmula de Redondeo Híbrido

```javascript
// Redondeo híbrido: beneficio al cliente si residuo ≤ 25
roundHybrid50 = (value) => {
  const remainder = value % 50;
  if (remainder <= 25) {
    return Math.floor(value / 50) * 50;  // Hacia abajo
  } else {
    return Math.ceil(value / 50) * 50;   // Hacia arriba
  }
}
```

---

### Casos de Uso

#### CU-01: Agregar Producto por Peso

- **Actor:** Vendedor (POSView)
- **Precondición:** Producto pesable seleccionado, peso ingresado
- **Flujo Principal:**
  1. Usuario ingresa peso (ej: 0.319 lb)
  2. Sistema calcula subtotal: `0.319 × $4.537 = $1.447...`
  3. Residuo = 47 > 25 → **Redondea hacia arriba**: `$1.450`
  4. Sistema agrega item al carrito con subtotal `$1.450`

- **Flujo Alternativo (Beneficio Cliente):**
  1. Usuario ingresa peso (ej: 0.310 lb)
  2. Sistema calcula subtotal: `0.310 × $4.537 = $1.406...`
  3. Residuo = 6 ≤ 25 → **Redondea hacia abajo**: `$1.400`
  4. Cliente paga $6 menos (beneficio visible)

---

### Criterios de Aceptación

- [ ] Al agregar un producto pesable, el subtotal siempre es múltiplo de $50
- [ ] El total de venta en CheckoutModal siempre es múltiplo de $50
- [ ] Los vueltos calculados son múltiplos de $50
- [ ] No se muestran decimales en ningún monto
- [ ] Los valores redondeados corresponden a montos cobrables físicamente

---

## Lista de Tareas de Alto Nivel

1. [ ] Crear función `roundToNearest50()` en `useCurrencyFormat.ts`
2. [ ] Modificar `WeightCalculatorModal.vue`: Aplicar redondeo a `subtotal`
3. [ ] Modificar `cart.ts`: Redondeo defensivo en `addWeighableItem`
4. [ ] Verificar funcionamiento en navegador

---

## Impacto en el Sistema

| Componente | Modificación |
|------------|--------------|
| `useCurrencyFormat.ts` | Nueva función `roundHybrid50()` |
| `ProductFormModal.vue` | Redondear `price` al guardar producto |
| `WeightCalculatorModal.vue` | Redondear `calculatedValue` |
| `cart.ts` | Redondeo defensivo en `addWeighableItem` |
| `inventory.ts` | Redondeo defensivo en `addProduct` y `updateProduct` |

---

## Consideraciones Económicas

> [!TIP]
> **Estrategia Híbrida**: Beneficia al cliente en ~50% de las transacciones sin impactar significativamente el margen.

### Impacto Financiero
| Escenario | Frecuencia | Quién gana |
|-----------|------------|------------|
| Residuo 0-25 | ~50% | Cliente (baja) |
| Residuo 26-49 | ~50% | Tienda (sube) |

- **Pérdida máxima por transacción**: $25
- **Ganancia máxima por transacción**: $24
- **Balance neto estimado**: Leve beneficio al cliente (~$0.50/transacción promedio)
