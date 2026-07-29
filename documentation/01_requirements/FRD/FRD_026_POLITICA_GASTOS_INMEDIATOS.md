# FRD-026: Política de Gastos Generales

### Límite Contable y Ejecución Inmediata (Flujo de Caja Puro)

#### Descripción
Este documento detalla la política arquitectónica para el manejo de los "Gastos Generales" (tales como servicios públicos, transporte, alimentación o anticipos de nómina). A diferencia de las cuentas comerciales (clientes y proveedores), esta política prohíbe explícitamente el uso de bandejas de recordatorios o promesas de pago. El módulo de gastos se define como un mecanismo exclusivo y estricto de extracción instantánea de liquidez del sistema.

---

## Reglas de Negocio
1. **Ausencia de Pasivos por Gastos:** El sistema TIENE PROHIBIDO permitir el registro de un "Gasto Pendiente" o "Gasto por Pagar". Los gastos no poseen una naturaleza logística previa y, por consiguiente, el sistema central es completamente agnóstico a la existencia de un recibo físico o compromiso verbal hasta el momento en que se efectúa el desembolso.
2. **Definición de Gasto como Egreso Líquido:** Un gasto se reconoce financieramente única y exclusivamente en el instante exacto en que el dinero físico o digital abandona las arcas del establecimiento.
3. **Impacto Inmediato y Definitivo:** En el momento de registrar un gasto, el sistema DEBE generar una transacción de egreso real e inmediata en el flujo de caja del turno actual, afectando negativamente el saldo del canal de pago seleccionado.
4. **Dependencia de Fondos (Prohibición de Sobregiro):** En concordancia con las políticas de caja, la ejecución de un gasto DEBE ser abortada por el servidor si el canal seleccionado carece de los fondos líquidos suficientes para cubrir la erogación, protegiendo al sistema de registrar un egreso ficticio.

---

## Casos de Uso

**Caso A: Notificación de Gasto Futuro (Fuera del Sistema)**
- **Actor:** Usuario Operativo / Propietario.
- **Precondición:** El encargado recibe la factura del servicio eléctrico el día lunes, la cual tiene como fecha de vencimiento el día viernes.
- **Flujo Principal:**
  1. El sistema permanece inalterado. El usuario no registra ningún compromiso futuro en el software, manteniendo el control de caja diario puro y libre de falsos pasivos.
- **Flujo Alternativo:** El usuario intenta buscar una opción para "crear un gasto por pagar". El sistema no provee dicha funcionalidad por diseño, forzando al usuario a retener el recibo físico.
- **Postcondición:** La liquidez y los reportes financieros del negocio no sufren contaminación por deudas operativas no ejecutadas.

**Caso B: Ejecución y Registro del Desembolso (El Pago del Gasto)**
- **Actor:** Usuario Operativo.
- **Precondición:** Llega el día viernes. El encargado extrae efectivo del cajón para pagar el servicio eléctrico.
- **Flujo Principal:**
  1. El usuario accede al módulo de registro de gastos e indica el concepto (Servicios Públicos) y el monto exacto extraído, señalando el canal "Efectivo".
  2. El servidor valida la disponibilidad de fondos en el canal Efectivo para el turno actual.
  3. El servidor aprueba la transacción y descuenta el dinero inmediatamente del balance de caja del día en curso.
  4. El servidor documenta la transacción en el historial inmutable de movimientos financieros.
- **Flujo Alternativo:** El usuario indica un canal que no posee saldo suficiente. El servidor interrumpe la operación y exige seleccionar el origen real de los fondos.
- **Postcondición:** El egreso monetario queda asentado oficialmente, reflejando fielmente la reducción de la liquidez del negocio en tiempo real.

---

## Criterios de Aceptación
- [ ] **CA-FRD-026-01:** El sistema carece por completo de interfaces o bases de datos orientadas a almacenar gastos generales en estado "pendiente" o "por pagar".
- [ ] **CA-FRD-026-02:** Todo registro exitoso en el módulo de gastos DEBE generar una disminución matemática inmediata en el efectivo reportado en el arqueo del turno actual.
- [ ] **CA-FRD-026-03:** El sistema DEBE abortar cualquier registro de gasto si el balance resultante del canal asociado a la operación resulta inferior a cero.
