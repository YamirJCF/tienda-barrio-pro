# FRD-006-01-02: Alcance y Límites de "Movimientos de Salida"

### El Egreso Físico de Mercancía

#### Descripción
Este documento rige el comportamiento de los "Movimientos de Salida" (reducción manual de stock) dentro del módulo de Inventario. Al igual que con las entradas, las salidas logísticas deben estar estrictamente desvinculadas de cualquier operación de reembolso de caja o cancelación de deudas, funcionando únicamente como un registro de disminución física de productos en bodega.

---

## Reglas de Negocio

1. **Naturaleza Logística Pura:** La función de Salida tiene un único mandato operativo: recibir una cantidad 'X' mayor a cero y restar esa cantidad del stock actual del producto asociado, validando que el stock final no sea negativo.
2. **Ceguera Financiera Absoluta:** Al registrar una salida (ej. devolución a un proveedor), el sistema TIENE PROHIBIDO ingresar dinero automáticamente a la sesión de caja actual, o cancelar una deuda pendiente en el módulo de Cuentas por Pagar.
3. **Desvinculación de Cuentas (El Formulario UI):** Si la interfaz de usuario solicita "Datos del Proveedor" al registrar una salida, este dato es **estrictamente referencial** para auditoría en el Kardex. Devolverle un producto defectuoso al camión no anula mágicamente la factura en el sistema financiero; el usuario debe registrar la nota de crédito o cancelación en el módulo de Proveedores de forma manual o a través de un servicio backend independiente.
4. **Validación de Bloqueo Logístico:** Ningún movimiento de salida (ni siquiera por "Merma") puede dejar el inventario en un número negativo. Si hay 0 unidades en el sistema, no se puede registrar una pérdida de 1 unidad. Se debe realizar primero un ajuste positivo si la realidad física no coincide con el sistema.
5. **Motivos de Salida Permitidos (Trazabilidad):** Toda salida manual DEBE registrar un "Motivo" en el historial de movimientos (Kardex). Se mantienen exclusivamente los siguientes motivos logísticos:
   - **Devolución Proveedor:** Se retorna mercancía (dañada o vencida) al distribuidor.
   - **Pérdida/Merma:** Productos dañados, caducados o extraviados en la tienda.
   - **Consumo Interno:** Productos consumidos por los empleados o dueños del local.
   - **Ajuste Negativo:** Corrección de inventario al encontrar menos unidades físicas que las del sistema (Inventario Físico).

---

## Casos de Uso

**Caso A: Devolución de Mercancía a Proveedor**
- **Actor:** Usuario Operativo / Administrador.
- **Precondición:** El empleado detecta 5 botellas rotas que el proveedor acepta cambiar o reembolsar.
- **Flujo Principal:**
  1. El usuario accede al inventario y registra una "Salida" por 5 botellas seleccionando el motivo "Devolución Proveedor".
  2. El sistema resta las 5 unidades del stock.
  3. *Límite de Dominio:* El inventario no altera el saldo adeudado a ese proveedor ni ingresa dinero a la caja.
  4. Si el proveedor devuelve el dinero en efectivo, el empleado debe ir a la Caja y registrar un "Ingreso Extraordinario". Si el proveedor lo descuenta de la próxima factura, se maneja en el módulo de Cuentas por Pagar.
- **Flujo Alternativo:** El sistema indica que solo hay 3 botellas en stock en el sistema. La operación de salida por 5 es rechazada (Bloqueo Logístico).
- **Postcondición:** El inventario físico cuadra con el del sistema. Las finanzas permanecen intactas hasta que el usuario las afecte deliberadamente.

**Caso B: Registro de Merma (Producto Dañado)**
- **Actor:** Usuario Operativo / Cajero.
- **Precondición:** Un paquete de arroz se rompió en el almacén.
- **Flujo Principal:**
  1. El usuario registra una "Salida" por 1 paquete, con motivo "Pérdida/Merma".
  2. El stock se reduce en 1.
  3. *Límite de Dominio:* El sistema asume una pérdida logística, pero no registra un "Gasto Financiero" en la caja diaria, ya que el dinero ya había salido cuando se compró el arroz inicialmente.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** Inventario depurado, flujo de caja de la jornada actual inalterado.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-01-02-01:** La función de base de datos que procesa la salida de inventario NO DEBE generar ingresos (`cash_movements` tipo 'income') en el turno de caja.
- [ ] **CA-FRD-006-01-02-02:** Los componentes UI que gestionan las salidas (ej. "Nueva Salida") deben tener cualquier formulario de cobro o pago desactivado o eliminado por completo.
- [ ] **CA-FRD-006-01-02-03:** El sistema DEBE rechazar cualquier movimiento de salida si la cantidad solicitada supera el stock disponible en la base de datos en ese instante exacto (previniendo race conditions).
