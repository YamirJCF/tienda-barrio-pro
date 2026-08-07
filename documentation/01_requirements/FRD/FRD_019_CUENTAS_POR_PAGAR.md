# FRD-019: Módulo de Cuentas por Pagar (Proveedores)

> **Módulo:** Finanzas / Inventario
> **Versión:** 2.0 (Saneamiento documental 2026-08-07 — eliminadas referencias técnicas, actualizada Regla 1 con decisión D-02)
> **Estado:** 🟡 Validado Localmente

## Descripción
Este módulo provee al tendero una herramienta de control independiente para llevar el registro de sus obligaciones (pasivos) con los proveedores. **El módulo opera como un registro aislado ("libreta de apuntes" digital)**: no genera registros contables automáticos, no extrae dinero de la caja, ni se vincula con los movimientos de inventario. El sistema se mantiene completamente al margen de las deudas producidas por los usuarios, siendo responsabilidad exclusiva del tendero gestionar la actualización manual de estos registros si hay devoluciones de inventario o pagos.

---

## Flujos del Sistema

### Flujo 1: Registro Manual de Deuda (Factura)

El Admin registra formalmente la obligación financiera de manera aislada:

1. El Admin recibe la factura del proveedor.
2. El Admin ingresa al módulo de Cuentas por Pagar.
3. Registra la factura indicando: monto, proveedor y fecha de vencimiento (opcional).
4. El sistema guarda la factura como una deuda pendiente, sin vincularla a ninguna entrada de inventario.

### Flujo 2: Registro Manual de Abono a Proveedor

Cuando el tendero realiza un pago al proveedor:

1. El tendero accede a la lista de deudas pendientes.
2. Selecciona la factura y anota el monto del abono realizado.
3. El sistema reduce el saldo pendiente de la factura en el monto indicado.
4. Si el abono cubre el total, la factura queda registrada como pagada.
> **Nota:** Este abono NO descuenta dinero del módulo de Caja Diaria. Es meramente un apunte de control.

---

## Reglas de Negocio

1. **Aislamiento Total del Sistema (No Contable):** Toda factura formal de proveedor registrada en este módulo es un apunte independiente. NO EXISTE vinculación automática con el módulo de Inventario, ni con el módulo de Caja. Ninguna operación logística (como recibir mercancía a crédito o devolverla) altera estos registros de forma automática.
2. **Fecha de Vencimiento Estimada:** Si no se provee fecha de vencimiento al registrar la factura, el sistema calculará una fecha estimada sumando los días acordados con el proveedor a la fecha de registro.
3. **Abonos Parciales:** Se permite anotar abonos parciales. Una factura solo cambia a estado pagada cuando el monto abonado manualmente cubre el total de la factura.
4. **Sin Vínculo con Caja:** Registrar un abono a un proveedor NO valida el estado de la caja ni genera un egreso en los movimientos de caja (`cash_movements`). Es un proceso ajeno al control estricto de caja diaria.
5. **Estado Inmutable (Vía Consulta):** El estado de una factura (Pendiente, Vencida, Pagada) NO se almacena como campo físico. Se calcula dinámicamente en cada consulta comparando el monto abonado contra el total y la fecha de vencimiento contra la fecha actual.

---

## Casos de Uso

### Caso 1: Registro Aislado de Factura de Proveedor
- **Actor:** Administrador
- **Precondición:** El Admin tiene una factura pendiente de pago.
- **Flujo Principal:**
  1. El Admin accede a la sección de Cuentas por Pagar.
  2. Crea un nuevo registro indicando: monto total, proveedor, fecha de vencimiento.
  3. El sistema guarda el registro de la deuda con estado Pendiente.
- **Postcondición:** La deuda es visible en el listado, pero el inventario y la caja permanecen inalterados.

### Caso 2: Apunte Manual de Abono
- **Actor:** Admin (o empleado con permisos)
- **Precondición:** Existe una factura pendiente registrada en el módulo.
- **Flujo Principal:**
  1. El usuario accede a la lista de cuentas por pagar.
  2. Selecciona una deuda y registra un apunte de abono por un monto específico.
  3. El saldo pendiente de la factura se reduce en el monto ingresado.
  4. Si el monto ingresado iguala el saldo restante, la factura pasa a estado Pagada.
- **Postcondición:** El registro de la factura se actualiza. La caja del sistema no sufre ningún descuento.

---

## Criterios de Aceptación
- [ ] **CA-019-01:** El sistema permite al usuario crear registros de facturas por pagar especificando proveedor, monto y fecha de vencimiento.
- [ ] **CA-019-02:** El sistema permite registrar apuntes de abonos (parciales o totales) a una factura existente.
- [ ] **CA-019-03:** PROHIBICIÓN: El módulo NO debe contener ningún trigger o mecanismo automático que cree deudas al registrar entradas de inventario a crédito.
- [ ] **CA-019-04:** PROHIBICIÓN: El módulo NO debe contener ningún mecanismo de deducción o cascada automática ante devoluciones de inventario.
- [ ] **CA-019-05:** PROHIBICIÓN: Registrar un abono a una factura NO debe descontar fondos de la caja del sistema ni generar un registro en los movimientos de caja.
- [ ] **CA-019-06:** No es posible abonar manualmente un monto que supere el saldo restante de la factura.
- [ ] **CA-019-07:** Toda consulta que exponga facturas debe reflejar el estado (Pendiente, Vencida, Pagada) calculado dinámicamente.
