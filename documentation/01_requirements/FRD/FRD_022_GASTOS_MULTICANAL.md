# FRD-022: Gastos Operativos Multicanal

### Nombre de la Funcionalidad
Registro de Gastos con Origen de Fondos

### Documentos Base (Referencias)
- Amplía y modifica reglas de: `FRD_004_CONTROL_DE_CAJA.md`, `FRD_018_CONTROL_OPERACIONAL_Y_ANALISIS_FINANCIERO.md` y `FRD_019_CUENTAS_POR_PAGAR.md`.

#### Descripción
Permite registrar salidas de dinero (gastos del día y pagos a proveedores) especificando si el pago se realizó con dinero en efectivo del cajón o mediante una transferencia desde las cuentas digitales del negocio, afectando correctamente la conciliación del turno y el saldo esperado correspondiente.

## Reglas de Negocio

1. **Origen de Fondos Obligatorio:**
   - Al registrar un gasto del día o un pago a proveedor (salida de dinero), el sistema DEBE exigir la selección del método de pago que origina los fondos (Ej. Efectivo, Nequi, Daviplata).
   - Esto impacta directamente a la operación de pago a proveedor (definido en FRD-019), la cual ahora DEBE recibir y registrar el método de pago con el que se le pagó a dicho proveedor.

2. **Impacto en el Turno (Protección de Saldos):**
   - Si un gasto o pago a proveedor se registra en Efectivo, DEBE restar únicamente del "Saldo Esperado Efectivo" del turno actual.
   - Si se registra en Nequi, DEBE restar únicamente del "Saldo Esperado Nequi" del turno actual.
   - Los gastos digitales (ej. pagar la mercancía haciendo una transferencia) NO PUEDEN alterar el cuadre del dinero físico en el cajón.

3. **Restricción de Operación:**
   - Para poder registrar un gasto en el sistema, independiente del método de pago, la caja DEBE estar abierta.

## Casos de Uso

**Caso A: Pago a Proveedor Pagado con Nequi**
- **Actor:** Empleado / Admin
- **Precondición:** Caja abierta.
- **Flujo Principal:**
  1. Usuario ingresa al módulo de Cuentas por Pagar.
  2. Selecciona abonar/pagar a un proveedor.
  3. Ingresa el monto.
  4. Selecciona "Nequi" en el selector de Método de Pago.
  5. Confirma el pago.
  6. Sistema ejecuta la operación de pago a proveedor con el nuevo parámetro, la cual reduce el saldo de la deuda e inserta un movimiento en la caja restando el saldo esperado de Nequi, dejando el saldo esperado de efectivo intacto.

## Criterios de Aceptación
- [ ] El formulario de registro de gastos exige seleccionar de dónde salió el dinero.
- [ ] El RPC de pago a proveedor soporta multicanalidad (`payment_method`).
- [ ] Un gasto/pago digital disminuye el saldo esperado de ese canal, pero no afecta el arqueo físico de la caja (Efectivo).
- [ ] Los gastos/pagos aparecen en el historial de caja etiquetados con su método de origen, permitiendo auditoría.
