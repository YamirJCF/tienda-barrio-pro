# Documento de Requisitos Funcionales (FRD) - Estándar Monetario

**ID:** SPEC-010-REV5
**Título:** Estándar de Integridad Monetaria y Cumplimiento Legal (Ley 1480)
**Versión:** 5.0 (Definitiva - Arquitectura)

## 1. Descripción General
Este estándar define el comportamiento del sistema para garantizar la libertad de precios, la transparencia fiscal y el cumplimiento estricto de la normativa colombiana de protección al consumidor respecto al redondeo de efectivo ("Ley de Vueltas Exactas"). El sistema debe permitir precios exactos (ej. $2.399) pero gestionar automáticamente las discrepancias de redondeo en el cobro en efectivo, alertando al usuario sobre la pérdida financiera (fuga de margen) sin bloquear su operación.

---

## 2. Reglas de Negocio (Business Rules - BR)

### BR-01: Libertad de Fijación de Precios
El sistema permitirá ingresar y guardar cualquier valor numérico positivo (entero o decimal) en los campos de "Precio de Venta" y "Costo", sin restricciones de múltiplos específicos (ej. $2.399 es válido).

### BR-02: Alerta de Ineficiencia Financiera (Nuding)
Si un usuario define un "Precio de Venta" para un producto unitario que no es múltiplo de $50, el sistema debe calcular la pérdida por unidad al venderse en efectivo y mostrar una alerta visual no bloqueante (Warning).
*   **Fórmula de Pérdida**: `Pérdida = Precio - (Floor(Precio / 50) * 50)`
*   **Condición**: `Pérdida > 0`

### BR-03: Integridad del Total Fiscal
El "Total de la Factura" o "Total Fiscal" será siempre la suma matemática exacta de los subtotales de línea, sin redondeos.
*   **Fórmula**: `TotalFiscal = Σ (PrecioUnitario * Cantidad)`

### BR-04: Política de Cobro en Efectivo (Redondeo Legal)
Para pagos en **Efectivo**, el monto a solicitar ("A Pagar") debe redondearse siempre hacia abajo al múltiplo de $50 más cercano (Floor), garantizando que nunca se cobre más que el Total Fiscal.
*   **Fórmula**: `TotalEfectivo = Floor(TotalFiscal / 50) * 50`
*   **Restricción**: `TotalEfectivo <= TotalFiscal`

### BR-05: Cobro Exacto en Medios Digitales
Para pagos digitales (Nequi, Daviplata, Tarjetas), el monto a solicitar ("A Pagar") debe ser exactamente igual al "Total Fiscal". No aplica redondeo.

### BR-06: Trazabilidad del Ajuste
La diferencia entre el `TotalFiscal` y el `TotalEfectivo` debe registrarse en la transacción como "Pérdida por Redondeo" (Rounding Loss) para fines de auditoría y análisis de márgenes.

---

## 3. Casos de Uso (Use Cases)

### CU-01: Gestión de Precios Ineficientes
*   **Actor**: Administrador / Tendero.
*   **Precondición**: El usuario ingresa al formulario de creación/edición de producto.
*   **Flujo Principal**:
    1.  Usuario ingresa Precio de Venta: `$2.399`.
    2.  Sistema detecta que no es múltiplo de 50.
    3.  Sistema muestra alerta amarilla: *"⚠️ Fuga de Margen: Perderás $49 por unidad en pagos en efectivo."*
    4.  Usuario decide guardar el producto tal cual.
    5.  Sistema guarda el precio exacto `$2.399`.

### CU-02: Cobro Mixto (Efectivo vs Digital)
*   **Actor**: Cajero.
*   **Precondición**: Carrito con items que suman `$21.192`.
*   **Flujo Principal**:
    1.  Cajero inicia proceso de cobro (Checkout).
    2.  Sistema muestra "Total Factura: $21.192".
    3.  **Opción A (Efectivo)**:
        *   Cajero selecciona "Efectivo".
        *   Sistema muestra "A Pagar: $21.150" y "Ajuste Legal: -$42".
        *   Cajero recibe billete de $22.000.
        *   Sistema calcula vueltas sobre $21.150 (Vueltas: $850).
    4.  **Opción B (Nequi)**:
        *   Cajero selecciona "Nequi".
        *   Sistema muestra "A Pagar: $21.192".
        *   No hay ajuste.

---

## 4. Impacto en el Sistema

| Componente | Tipo | Descripción de la Modificación Funcional |
| :--- | :--- | :--- |
| **ProductFormModal** | UI/Lógica | Eliminar validaciones de bloqueo. Implementar lógica reactiva para la "Alerta de Fuga de Margen" basada en BR-02. |
| **InventoryStore** | Datos | Garantizar soporte de decimales/enteros exactos en campo `price`. (Verificar consistencia de tipos). |
| **CurrencyUtils** | Lógica | Implementar función centralizada de "Cálculo de Cobro Legal" (`Floor 50`) para reutilización. |
| **CartStore** | Lógica | Implementar computada `fiscalTotal` (Suma exacta) y `cashPayableTotal` (Aplicando BR-04). |
| **CheckoutModal** | UI | Rediseñar visualización de totales para mostrar la dualidad **Total Fiscal** vs **Total a Pagar**, y destacar el **Ajuste Legal**. |
| **SalesStore** | Datos | Ampliar estructura de datos de Venta para persistir: `totalFiscal` (lo facturado), `totalPagado` (lo recibido) y `ajusteRedondeo` (la diferencia). |
| **Receipt/Ticket** | Reporte | El ticket impreso/virtual debe reflejar el Total Fiscal y, si es efectivo, una línea de descuento/ajuste por redondeo. |

---

## 5. Criterios de Aceptación
1.  [ ] Se puede crear un producto con precio `$2.399` y el sistema advierte sobre la pérdida de `$49`.
2.  [ ] Un carrito que suma `$21.192` exige cobro de `$21.192` si se selecciona Nequi.
3.  [ ] El mismo carrito exige cobro de `$21.150` si se selecciona Efectivo.
4.  [ ] La venta final registra que se facturaron `$21.192` pero el ingreso real en efectivo fue `$21.150`.
