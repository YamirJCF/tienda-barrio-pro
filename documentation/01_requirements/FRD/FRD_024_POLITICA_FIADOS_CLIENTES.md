# FRD-024: Política de Cuentas por Cobrar (Fiados de Clientes)

### Límite Contable y Bandeja de Promesas de Pago

#### Descripción
Este documento detalla la política arquitectónica para el manejo de los "Fiados" (cuentas por cobrar a clientes). Establece el modelo de "Bandeja de Recordatorios" donde la promesa de pago opera en un entorno puramente informativo, aislado del flujo de caja diario, garantizando que el sistema central reconozca únicamente el dinero que cambia de manos en el presente operativo.

---

## Reglas de Negocio
1. **Aislamiento de la Promesa de Pago:** El registro de una venta bajo modalidad de crédito (fiado) TIENE PROHIBIDO inyectar falsos positivos en el cuadre del turno actual. La caja central ignorará la transacción en términos monetarios, evitando descuadres entre el saldo teórico y el dinero físico o digital real.
2. **Impacto Logístico Inmediato:** A pesar del aislamiento financiero, el sistema DEBE registrar la salida física de la mercancía. El inventario se reducirá de manera inmediata en el momento de la venta a crédito, garantizando el control de existencias.
3. **Registro en la Bandeja de Pendientes:** El valor monetario de la mercancía entregada a crédito DEBE anotarse en la cuenta individual del cliente. Este registro funciona exclusivamente como una libreta de apuntes ("post-it" virtual) que documenta la deuda a favor del establecimiento.
4. **Transformación de Promesa a Liquidez (El Abono):** En el instante en que el cliente entrega dinero para abonar o saldar su deuda, el sistema DEBE realizar dos acciones simultáneas e inseparables: descontar el monto del "post-it" del cliente, y generar un registro oficial de "Ingreso por Abono" en el flujo de caja del turno actual. Solo en este momento el dinero entra a la contabilidad central.

---

## Casos de Uso

**Caso A: Venta a Crédito (El Fiado)**
- **Actor:** Administrador o Empleado con permiso **`Fiar y cobrar abonos`** (`FRD-003-01`).
- **Precondición:** Un cliente activo solicita llevar productos dentro de su cupo disponible comprometiéndose a pagar en el futuro.
- **Flujo Principal:**
  1. El usuario autorizado registra los productos y selecciona la modalidad de crédito (Fiado).
  2. El servidor verifica el permiso `Fiar y cobrar abonos`, descuenta los productos de la bodega y estampa la **firma individual** del usuario.
  3. El servidor anota el monto adeudado en el historial de cuentas por cobrar del cliente.
  4. El servidor finaliza la transacción sin enviar ninguna notificación de ingreso a la Caja Dedicada POS ($0 en caja).
- **Flujo Alternativo:** Si el usuario no tiene el permiso `Fiar y cobrar abonos` o el monto supera el cupo disponible, el servidor rechaza la operación.
- **Postcondición:** El inventario se actualiza, la deuda del cliente queda registrada con firma individual, y la Caja Dedicada POS se mantiene intacta.

**Caso B: Recepción de Abono**
- **Actor:** Administrador o Empleado con permiso **`Fiar y cobrar abonos`** (`FRD-003-01`).
- **Precondición:** Un cliente con deuda previa se acerca al establecimiento y entrega dinero por cualquiera de los canales válidos (**Efectivo, Nequi o Llave BRE**) con Caja Dedicada POS abierta.
- **Flujo Principal:**
  1. El usuario autorizado busca la cuenta del cliente y registra la recepción del abono seleccionando el canal de ingreso.
  2. El servidor deduce el monto entregado de la libreta de apuntes del cliente con la **firma individual** del usuario.
  3. El servidor inyecta el valor del abono como un ingreso real y tangible en el canal seleccionado del turno de Caja Dedicada POS que se encuentra abierto.
- **Flujo Alternativo:** Si la caja está cerrada o el usuario no posee el permiso `Fiar y cobrar abonos`, el servidor aborta la operación.
- **Postcondición:** La deuda del cliente disminuye y el dinero ingresa formalmente al canal correspondiente del turno activo.

---

## Criterios de Aceptación
- [ ] **CA-FRD-024-01:** El sistema TIENE PROHIBIDO sumar el monto de una venta a crédito al total de ingresos reportados en el cuadre de caja del día en que se origina.
- [ ] **CA-FRD-024-02:** El sistema DEBE garantizar que la reducción de inventario ocurra en tiempo real durante la venta a crédito.
- [ ] **CA-FRD-024-03:** Todo dinero recibido como pago de una deuda pasada DEBE registrarse obligatoriamente como un ingreso en el turno de caja vigente al momento del pago.
