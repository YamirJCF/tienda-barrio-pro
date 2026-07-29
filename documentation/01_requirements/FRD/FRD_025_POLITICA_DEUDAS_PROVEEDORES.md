# FRD-025: Política de Cuentas por Pagar (Deudas a Proveedores)

### Límite Contable y Simetría Financiera

#### Descripción
Este documento detalla la política arquitectónica para el manejo de deudas y facturas de proveedores. Al igual que con los clientes, establece el modelo de "Bandeja de Recordatorios", aislando la asunción de pasivos corporativos del flujo de caja diario. Asegura una simetría perfecta en la frontera del sistema: la caja solo reconoce el capital en el momento exacto de su desembolso físico o digital.

---

## Reglas de Negocio
1. **Aislamiento del Pasivo:** El registro de una factura a crédito emitida por un proveedor TIENE PROHIBIDO descontar dinero del cuadre del turno actual o registrarse como un gasto financiero inmediato. La caja central ignorará la deuda para proteger la liquidez reportada.
2. **Impacto Logístico Inmediato:** A pesar del aislamiento financiero, el sistema DEBE registrar la entrada física de la mercancía. El inventario se incrementará de manera inmediata tras la recepción, asegurando que los productos estén disponibles para la venta.
3. **Registro en la Bandeja de Pendientes:** El monto de la factura o deuda adquirida DEBE anotarse en la cuenta del proveedor correspondiente. Este registro opera estrictamente como un recordatorio informativo ("post-it" virtual) de una obligación futura, carente de peso en el flujo de caja del día de la recepción.
4. **Transformación de Promesa a Gasto (El Pago):** En el instante en que el establecimiento desembolsa dinero para abonar o saldar la factura del proveedor, el sistema DEBE ejecutar dos acciones inseparables: reducir el monto adeudado en el "post-it" del proveedor, y generar un registro oficial de "Egreso por Pago" en el flujo de caja del turno actual, afectando la liquidez real.

---

## Casos de Uso

**Caso A: Recepción de Mercancía a Crédito (Asunción de Deuda)**
- **Actor:** Usuario Operativo / Contable.
- **Precondición:** Un proveedor entrega un lote de productos y emite una factura con plazo de pago a quince días.
- **Flujo Principal:**
  1. El usuario registra los productos entregados en el sistema de bodega.
  2. El servidor suma los productos al inventario disponible.
  3. El usuario registra la factura en el módulo de proveedores, indicando el monto y el plazo.
  4. El servidor anota el monto adeudado en la cuenta del proveedor, actuando como recordatorio.
  5. El servidor finaliza el proceso sin generar ningún movimiento de salida de dinero en el módulo de caja del día actual.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El inventario se incrementa, la obligación de pago queda documentada a futuro, y el efectivo de la tienda permanece inalterado.

**Caso B: Desembolso y Pago a Proveedor**
- **Actor:** Usuario Operativo / Contable.
- **Precondición:** Llega la fecha de vencimiento de la factura y el encargado toma dinero de la caja (o del canal digital) para realizar el pago al proveedor.
- **Flujo Principal:**
  1. El usuario localiza la cuenta del proveedor y registra el monto entregado como pago parcial o total.
  2. El servidor deduce el monto entregado del registro de deuda pendiente (el post-it virtual).
  3. El servidor inyecta el valor del desembolso como un egreso real y tangible en el turno de caja vigente, impactando negativamente el saldo del canal de pago seleccionado.
- **Flujo Alternativo:** El usuario intenta pagar una factura por un monto superior a la liquidez del canal seleccionado. El servidor bloquea el pago protegiendo al canal de un sobregiro.
- **Postcondición:** La deuda con el proveedor se reduce o liquida, y el capital sale formalmente del ecosistema financiero del establecimiento.

---

## Criterios de Aceptación
- [ ] **CA-FRD-025-01:** El sistema TIENE PROHIBIDO restar el monto de una factura a crédito del total de efectivo o liquidez del día en que se registra el documento.
- [ ] **CA-FRD-025-02:** El sistema DEBE garantizar que el incremento de inventario ocurra independientemente del momento en que se pague la factura al proveedor.
- [ ] **CA-FRD-025-03:** Todo desembolso de dinero destinado a pagar una deuda pasada DEBE registrarse ineludiblemente como un gasto financiero en el turno de caja que se encuentre abierto en el momento exacto de la erogación.
