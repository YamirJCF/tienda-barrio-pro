# FRD-022: Gastos Operativos Multicanal

### Nombre de la Funcionalidad
Registro de Gastos con Origen de Fondos

### Documentos Base (Referencias)
- Amplía y modifica reglas de: `FRD_004_CONTROL_DE_CAJA.md`, `FRD_018_CONTROL_OPERACIONAL_Y_ANALISIS_FINANCIERO.md` y `FRD_019_CUENTAS_POR_PAGAR.md`.

#### Descripción
Permite registrar salidas de dinero (gastos del día y pagos a proveedores) especificando si el pago se realizó con dinero en efectivo del cajón o mediante una transferencia desde las cuentas digitales del negocio, afectando correctamente la conciliación del turno y el saldo esperado correspondiente.

## Reglas de Negocio

1. **Origen de Fondos Obligatorio y Canales Unificados (`POL-FIN-02`):**
   - Al registrar un gasto menor del turno (por cualquier usuario activo con Caja Dedicada POS abierta y firma individual) o un pago interno a proveedor (exclusivo del Administrador según `FRD-019` y `FRD-003-01`), el sistema DEBE exigir la selección del canal que origina los fondos entre los tres únicos canales válidos: **Efectivo, Nequi o Llave BRE**.
   - Todo pago realizado con fondos externos al cajón del turno se marca como **"pago externo / fuera de caja"** (`FRD-019`) y no afecta la Caja Dedicada POS.

2. **Impacto en el Turno (Protección de Saldos por Canal):**
   - Si un gasto menor o pago interno a proveedor se registra en **Efectivo**, DEBE restar únicamente del "Saldo Esperado Efectivo" del turno actual.
   - Si se registra en **Nequi** o **Llave BRE**, DEBE restar únicamente del saldo esperado de ese canal digital en el turno actual.
   - Los egresos digitales NO PUEDEN alterar jamás el cuadre del dinero físico en el cajón.

3. **Restricción de Operación:**
   - Para poder registrar un gasto menor o un pago interno desde la Caja Dedicada POS, independiente del canal, la caja DEBE estar abierta y el canal elegido DEBE tener fondos suficientes.

## Casos de Uso

**Caso A: Pago Interno a Proveedor Pagado con Nequi (Exclusivo Administrador)**
- **Actor:** Administrador (`FRD-019`, `FRD-003-01`).
- **Precondición:** Caja Dedicada POS abierta y fondos suficientes en Nequi.
- **Flujo Principal:**
  1. El Administrador ingresa al módulo de Cuentas por Pagar.
  2. Selecciona abonar/pagar internamente a un proveedor.
  3. Ingresa el monto.
  4. Selecciona "Nequi" en el selector de Canal de Pago (`Efectivo, Nequi o Llave BRE`).
  5. Confirma el pago.
  6. El sistema reduce el saldo de la deuda e inserta un movimiento con la firma del Administrador restando el saldo esperado de Nequi, dejando el saldo esperado de efectivo intacto.

## Criterios de Aceptación
- [ ] El formulario de registro de gastos exige seleccionar de dónde salió el dinero.
- [ ] El RPC de pago a proveedor soporta multicanalidad (`payment_method`).
- [ ] Un gasto/pago digital disminuye el saldo esperado de ese canal, pero no afecta el arqueo físico de la caja (Efectivo).
- [ ] Los gastos/pagos aparecen en el historial de caja etiquetados con su método de origen, permitiendo auditoría.
