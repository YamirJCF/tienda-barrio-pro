# SPEC-011: Estándar de Formato de Decimales

**Versión:** 1.0  
**Fecha:** 2026-01-19  
**Estado:** Implementado

---

## Descripción

Define el estándar de visualización de cantidades decimales en toda la aplicación para garantizar consistencia UX y legibilidad.

---

## Reglas de Formato

| Tipo de Dato | Decimales | Ejemplo | Uso |
|--------------|-----------|---------|-----|
| **Dinero ($)** | 0 | $5,100 | Siempre entero, separador de miles |
| **Stock (un)** | 0 | 10 | Unidades siempre enteras |
| **Stock (kg/lb)** | 2 máx | 28.16 | Truncar trailing zeros |
| **Stock (g)** | 0 | 454 | Gramos siempre enteros |
| **Cantidad genérica** | 2 máx | 5.50 | Para carrito, historial |

---

## Implementación Técnica

### Composable: `useQuantityFormat.ts`

```typescript
import { useQuantityFormat } from '../composables/useQuantityFormat';
const { formatStock, formatQuantity } = useQuantityFormat();

// Para stock con unidad específica
formatStock(product.stock, product.measurementUnit)  // "28.16"

// Para cantidad genérica
formatQuantity(item.quantity)  // "5.50"
```

---

## Archivos Actualizados

| Archivo | Función Usada |
|---------|---------------|
| `InventoryView.vue` | formatStock |
| `StockEntryView.vue` | formatStock |
| `HistoryView.vue` | formatQuantity |
| `ReportsContent.vue` | formatStock |
| `POSView.vue` | formatQuantity (local) |
| `CheckoutModal.vue` | formatQuantity (local) |
| `ProductFormModal.vue` | formatQuantity (local) |
| `WeightCalculatorModal.vue` | toFixed(3) para cálculo |

---

## Criterios de Aceptación

- [x] Composable `useQuantityFormat.ts` creado
- [x] Stocks en lista de inventario formateados
- [x] Stocks en búsqueda formateados
- [x] Cantidades en historial formateadas
- [x] Build exitoso sin errores

---

## Notas

- La precisión interna con `Decimal.js` se mantiene intacta
- El formateo solo se aplica en la capa de presentación (UI)
- Los cálculos nunca se afectan por el redondeo visual
