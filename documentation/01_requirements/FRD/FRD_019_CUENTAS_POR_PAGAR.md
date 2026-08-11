# FRD-019: Cuentas por Pagar y Política de Pago a Proveedores

### Nombre de la Funcionalidad
Gestión de Obligaciones con Proveedores y Liquidación de Deudas

#### Descripción
Este módulo provee al tendero una herramienta de control para registrar, dar seguimiento y liquidar obligaciones con proveedores. El registro de una deuda nace por acción humana explícita y no afecta la caja ni el inventario. La liquidación se distingue en dos modalidades: abono externo (fondos fuera del sistema) y pago interno (fondos dentro del sistema). Los pagos internos quedan sometidos a las reglas de la Caja Estricta Multicanal definidas en FRD-004.

---

## Reglas de Negocio

1. **Registro manual y consciente:** Toda factura por pagar DEBE ser creada manualmente por un usuario autorizado. El sistema TIENE PROHIBIDO crear deudas automáticamente por entradas de inventario, recepciones de mercancía, devoluciones, ajustes, ventas, mermas o consumo interno.

2. **Independencia logística:** El registro de una factura por pagar NO DEBE aumentar ni disminuir inventario, NO DEBE alterar kardex, NO DEBE alterar lotes y NO DEBE alterar movimientos de entrada o salida. La recepción de mercancía se rige por FRD-006-01-01.

3. **Independencia contable inicial:** El registro de una factura por pagar NO DEBE generar egreso, NO DEBE generar ingreso, NO DEBE afectar la caja, NO DEBE afectar el turno, NO DEBE generar movimiento en los registros de caja y NO DEBE alterar ningún canal de pago. La deuda nace como obligación pendiente.

4. **Vinculación trazable con inventario:** El sistema DEBE permitir crear facturas por pagar sin referencia a inventario. El sistema DEBE permitir asociar manualmente una factura por pagar con una entrada de inventario existente. El sistema NO DEBE autocompletar esta referencia de forma automática. Si el usuario proporciona una referencia, el sistema DEBE validar que la entrada de inventario exista y pertenezca a la misma tienda. Si la referencia no existe o pertenece a otra tienda, el sistema DEBE rechazar la operación. La creación, modificación o eliminación de esta referencia NO DEBE crear deuda automáticamente, NO DEBE modificar inventario, NO DEBE generar movimientos de caja, NO DEBE alterar el saldo pendiente de la factura, NO DEBE alterar el monto total de la factura y NO DEBE alterar el estado calculado de la factura.

5. **Abono externo:** Un abono externo representa una reducción de deuda pagada con fondos externos al control del turno actual. El abono externo DEBE reducir el saldo pendiente de la factura. El abono externo NO DEBE generar movimiento de caja. El abono externo NO DEBE afectar el canal EFECTIVO, NO DEBE afectar el canal NEQUI y NO DEBE afectar el canal LLAVE BRE. El abono externo NO DEBE afectar el arqueo físico. El abono externo NO DEBE requerir turno de caja abierto. El abono externo DEBE quedar registrado como apunte de control.

6. **Pago interno:** Un pago interno representa una reducción de deuda pagada con fondos declarados dentro del sistema. El pago interno DEBE reducir el saldo pendiente de la factura. El pago interno DEBE generar un egreso en el canal seleccionado. El pago interno DEBE requerir turno de caja abierto. El pago interno DEBE requerir selección explícita de canal. El pago interno DEBE requerir validación de fondos por canal. El pago interno NO DEBE usar saldo consolidado. El pago interno NO DEBE generar sobregiro.

7. **Canales válidos para pago interno:** Los canales permitidos para pagos internos son exclusivamente los definidos por FRD-004 Caja Estricta Multicanal: EFECTIVO, NEQUI y LLAVE BRE. El sistema NO DEBE permitir canales adicionales. El sistema NO DEBE aceptar términos genéricos como "canal digital" u "otro canal".

8. **Validación estricta por canal:** Para todo pago interno, el servidor DEBE validar fondos únicamente sobre el canal seleccionado. Si el canal es EFECTIVO, el servidor DEBE validar fondos de EFECTIVO. Si el canal es NEQUI, el servidor DEBE validar fondos de NEQUI. Si el canal es LLAVE BRE, el servidor DEBE validar fondos de LLAVE BRE. El servidor TIENE PROHIBIDO validar contra un saldo total consolidado. El servidor TIENE PROHIBIDO usar saldo de un canal para cubrir otro canal.

9. **Prohibición de sobregiro:** Si el canal seleccionado no tiene fondos suficientes, el pago interno DEBE ser rechazado. El sistema NO DEBE permitir saldo negativo. El sistema NO DEBE prestar saldo entre canales. El sistema NO DEBE completar el pago con otro canal. El sistema NO DEBE registrar el movimiento para corregir después. El sistema NO DEBE asumir ingresos futuros. El sistema NO DEBE asumir transferencias pendientes.

10. **Turno abierto obligatorio para pagos internos:** Para ejecutar un pago interno DEBE existir un turno de caja abierto y vigente. Si no existe turno abierto, el pago interno DEBE rechazarse, NO DEBE generarse movimiento de caja, el sistema DEBE informar claramente la causa y solo se DEBE permitir registrar abonos externos.

11. **Efecto del canal seleccionado:** Cuando el pago interno usa EFECTIVO, el egreso DEBE afectar el saldo esperado físico del turno y DEBE considerarse en el arqueo físico. Cuando el pago interno usa NEQUI o LLAVE BRE, el egreso DEBE afectar el saldo digital del canal correspondiente, NO DEBE alterar el conteo físico de efectivo del cajón y DEBE quedar registrado en el historial del canal.

12. **Inmutabilidad de movimientos de caja:** Los movimientos de caja generados por pagos internos NO DEBEN editarse ni eliminarse. Si existe error, DEBE registrarse un contra-movimiento correctivo. El movimiento original DEBE permanecer visible. La corrección DEBE conservar trazabilidad. Esto se alinea con FRD-004 Control de Caja.

13. **Inmutabilidad de abonos y pagos:** Los abonos externos y pagos internos NO DEBEN editarse ni eliminarse. Si existe error, DEBE registrarse un ajuste auditable. El registro original DEBE permanecer. La corrección DEBE ser explícita y autorizada.

14. **Prohibición de cascada por devoluciones:** Las devoluciones a proveedor NO DEBEN alterar automáticamente las cuentas por pagar. Si una devolución afecta la deuda, el usuario autorizado DEBE registrar manualmente el ajuste. El sistema NO DEBE reducir la deuda automáticamente. El sistema NO DEBE generar abonos automáticos.

15. **Estado calculado dinámicamente:** El estado de una factura NO DEBE depender de un campo físico único. El estado DEBE calcularse en cada consulta a partir del monto total, el monto acumulado abonado o pagado, la fecha de vencimiento y la fecha actual. Los estados posibles son: PENDIENTE, VENCIDA y PAGADA.

16. **Fecha de vencimiento:** La fecha de vencimiento NO es un dato obligatorio para el registro de una factura. Si se registra fecha de vencimiento, la factura DEBE marcarse como VENCIDA si la fecha ya pasó y aún no está pagada. Si no se registra fecha de vencimiento, la factura DEBE permanecer en estado PENDIENTE y NO DEBE calcularse estado VENCIDA por ausencia de fecha.

17. **Límites de monto:** Ninguna factura DEBE registrarse con monto total menor o igual a cero. Ningún abono externo o pago interno DEBE ser menor o igual a cero. Ningún abono externo o pago interno DEBE exceder el saldo pendiente de la factura. Ningún abono externo o pago interno DEBE provocar saldo negativo. Ningún abono externo o pago interno DEBE aplicarse sobre una factura ya pagada.

18. **Autorización estricta:** Toda operación del módulo DEBE validar permisos en el servidor según FRD-002 Autorización Estricta. El servidor NO DEBE confiar en botones visibles, estado del frontend, roles enviados por cliente, variables temporales, banderas de autoridad ni metadatos inyectados por interfaz. La validación DEBE hacerse consultando el perfil real del usuario en la base de datos.

19. **Roles y permisos:** El sistema reconoce dos tipos de usuarios: Admin y Empleado. El Admin DEBE poder ejecutar todas las operaciones del módulo. Un empleado solo DEBE poder ejecutar operaciones para las cuales tenga permiso explícito otorgado por el Admin. El sistema DEBE definir dos permisos funcionales para este módulo: (a) permiso de gestión de cuentas por pagar, que autoriza registrar facturas y registrar abonos externos; (b) permiso de pago con fondos del sistema, que autoriza ejecutar pagos internos. El permiso de pago con fondos del sistema NO DEBE otorgar automáticamente el permiso de apertura y cierre de caja. El permiso de apertura y cierre de caja se rige por FRD-004 Control de Caja.

20. **Registro claro del origen:** Cada reducción de deuda DEBE indicar su origen: EXTERNO o INTERNO. Si el origen es EXTERNO, el registro NO DEBE indicar canal, NO DEBE indicar movimiento de caja y NO DEBE requerir turno abierto. Si el origen es INTERNO, el registro DEBE indicar canal, DEBE indicar movimiento de caja asociado, DEBE indicar turno asociado y DEBE validar fondos.

---

## Casos de Uso

**Caso A: Registro manual de factura por pagar**

- **Actor:** Admin o empleado con permiso de gestión de cuentas por pagar.
- **Precondición:** Existe una obligación con un proveedor.
- **Flujo Principal:**
    1. El usuario accede al módulo de Cuentas por Pagar.
    2. El usuario selecciona la acción de registrar factura.
    3. El usuario ingresa el nombre del proveedor.
    4. El usuario ingresa el monto total.
    5. El usuario ingresa el número de factura si lo conoce. Si no lo conoce, el sistema DEBE permitir continuar sin este dato.
    6. El usuario ingresa la fecha de vencimiento si la conoce. Si no la conoce, el sistema DEBE permitir continuar sin este dato.
    7. El usuario asocia la factura a una entrada de inventario si desea trazabilidad logística. Si no desea asociarla, el sistema DEBE permitir continuar sin este dato.
    8. El usuario confirma la operación.
    9. El sistema valida permisos en servidor.
    10. El sistema registra la factura como pendiente.
- **Flujo Alternativo:**
    - Si el usuario no tiene permiso, el servidor DEBE abortar la operación.
    - Si el monto total es menor o igual a cero, el sistema DEBE rechazar la operación.
    - Si la referencia de inventario es inválida, el sistema DEBE rechazar la operación.
- **Postcondición:** La factura queda registrada. La deuda queda pendiente. No se genera movimiento de caja. No se altera inventario.

---

**Caso B: Registro de abono externo**

- **Actor:** Admin o empleado con permiso de gestión de cuentas por pagar.
- **Precondición:** Existe una factura pendiente y el pago se realizó con fondos externos al sistema.
- **Flujo Principal:**
    1. El usuario accede a la lista de cuentas por pagar.
    2. El usuario selecciona la factura.
    3. El usuario selecciona la acción de abono externo.
    4. El usuario ingresa el monto abonado.
    5. El usuario ingresa una nota descriptiva si lo considera necesario. Si no lo considera necesario, el sistema DEBE permitir continuar sin este dato.
    6. El usuario confirma la operación.
    7. El sistema valida permisos en servidor.
    8. El sistema valida que el monto no exceda el saldo pendiente.
    9. El sistema reduce el saldo pendiente.
    10. El sistema registra el abono con origen EXTERNO.
- **Flujo Alternativo:**
    - Si el usuario no tiene permiso, el servidor DEBE abortar la operación.
    - Si el monto excede el saldo pendiente, el sistema DEBE rechazar la operación.
    - Si el monto es menor o igual a cero, el sistema DEBE rechazar la operación.
- **Postcondición:** La deuda se reduce. No se genera movimiento de caja. No se afecta el turno. No se afecta ningún canal.

---

**Caso C: Pago interno con fondos suficientes**

- **Actor:** Admin o empleado con permiso de pago con fondos del sistema.
- **Precondición:** Existe una factura pendiente y hay turno de caja abierto.
- **Flujo Principal:**
    1. El usuario accede a la lista de cuentas por pagar.
    2. El usuario selecciona la factura.
    3. El usuario selecciona la acción de pago interno.
    4. El usuario ingresa el monto a pagar.
    5. El usuario selecciona uno de los canales válidos: EFECTIVO, NEQUI o LLAVE BRE.
    6. El usuario ingresa una descripción obligatoria para el movimiento de caja.
    7. El usuario confirma la operación.
    8. El sistema valida permisos en servidor.
    9. El sistema valida turno abierto.
    10. El sistema valida saldo pendiente.
    11. El sistema valida fondos disponibles en el canal seleccionado.
    12. El sistema registra el egreso en el canal seleccionado.
    13. El sistema reduce el saldo pendiente de la factura.
    14. El sistema registra el pago con origen INTERNO.
- **Flujo Alternativo:**
    - Si el canal no tiene fondos suficientes, el sistema DEBE rechazar la operación.
    - Si no hay turno abierto, el sistema DEBE rechazar la operación.
    - Si el usuario no tiene permiso, el servidor DEBE abortar la operación.
    - Si el monto excede el saldo pendiente, el sistema DEBE rechazar la operación.
- **Postcondición:** La deuda se reduce o se paga totalmente. Se genera un movimiento de caja. El movimiento queda asociado al turno. El movimiento queda asociado al canal seleccionado. El movimiento NO DEBE editarse ni eliminarse.

---

**Caso D: Pago interno rechazado por fondos insuficientes**

- **Actor:** Admin o empleado con permiso de pago con fondos del sistema.
- **Precondición:** El canal seleccionado no tiene fondos suficientes.
- **Flujo Principal:**
    1. El usuario intenta pagar una factura.
    2. El usuario selecciona canal.
    3. El usuario ingresa monto.
    4. El usuario confirma la operación.
    5. El sistema valida fondos del canal seleccionado.
    6. El sistema detecta insuficiencia de fondos.
    7. El sistema rechaza la operación.
    8. El sistema NO DEBE registrar movimiento de caja.
    9. El sistema NO DEBE reducir la deuda.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** La factura permanece igual. La caja permanece igual. El canal permanece igual.

---

**Caso E: Pago interno sin turno abierto**

- **Actor:** Admin o empleado con permiso de pago con fondos del sistema.
- **Precondición:** No existe turno de caja abierto.
- **Flujo Principal:**
    1. El usuario intenta pagar una factura con fondos del sistema.
    2. El sistema detecta ausencia de turno abierto.
    3. El sistema rechaza el pago interno.
    4. El sistema informa que solo se permite abono externo.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** No hay movimiento de caja. No hay reducción de deuda por pago interno.

---

**Caso F: Operación sin permiso suficiente**

- **Actor:** Empleado sin permiso suficiente.
- **Precondición:** El empleado intenta ejecutar una operación protegida.
- **Flujo Principal:**
    1. El empleado envía la solicitud, incluso si manipula el frontend.
    2. El servidor recibe la petición.
    3. El servidor consulta el perfil real del usuario.
    4. El servidor detecta permiso insuficiente.
    5. El servidor aborta la operación.
    6. El servidor retorna error de autorización.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** No se crea factura. No se registra abono externo. No se registra pago interno. No se genera movimiento de caja.

---

## Criterios de Aceptación

- [ ] CA-FRD-019-01: El sistema permite registrar facturas por pagar con proveedor y monto total.
- [ ] CA-FRD-019-02: El número de factura NO es un dato obligatorio para el registro.
- [ ] CA-FRD-019-03: La fecha de vencimiento NO es un dato obligatorio para el registro.
- [ ] CA-FRD-019-04: El sistema rechaza el registro de una factura con monto total menor o igual a cero.
- [ ] CA-FRD-019-05: El registro de una factura no genera movimiento de caja.
- [ ] CA-FRD-019-06: El registro de una factura no altera inventario.
- [ ] CA-FRD-019-07: El registro de una factura no altera kardex.
- [ ] CA-FRD-019-08: El sistema permite crear facturas por pagar sin referencia a entrada de inventario.
- [ ] CA-FRD-019-09: El sistema permite asociar manualmente una factura por pagar con una entrada de inventario existente.
- [ ] CA-FRD-019-10: El sistema NO autocompleta la referencia a entrada de inventario.
- [ ] CA-FRD-019-11: Si el usuario indica una referencia de inventario inexistente, el sistema rechaza la operación.
- [ ] CA-FRD-019-12: Si el usuario indica una referencia de inventario perteneciente a otra tienda, el sistema rechaza la operación.
- [ ] CA-FRD-019-13: La creación de la referencia de inventario no altera el inventario.
- [ ] CA-FRD-019-14: La modificación de la referencia de inventario no altera el inventario.
- [ ] CA-FRD-019-15: La eliminación de la referencia de inventario no altera el inventario.
- [ ] CA-FRD-019-16: La creación, modificación o eliminación de la referencia de inventario no genera movimientos de caja.
- [ ] CA-FRD-019-17: La creación, modificación o eliminación de la referencia de inventario no altera el monto total de la factura.
- [ ] CA-FRD-019-18: La creación, modificación o eliminación de la referencia de inventario no altera el monto abonado.
- [ ] CA-FRD-019-19: La creación, modificación o eliminación de la referencia de inventario no altera el estado calculado de la factura.
- [ ] CA-FRD-019-20: El módulo NO contiene mecanismos automáticos que creen deudas al registrar entradas de inventario.
- [ ] CA-FRD-019-21: El módulo NO contiene mecanismos automáticos que creen deudas por devoluciones.
- [ ] CA-FRD-019-22: El módulo NO contiene mecanismos automáticos que reduzcan deudas por devoluciones.
- [ ] CA-FRD-019-23: El módulo NO contiene mecanismos automáticos que generen movimientos de caja al registrar una factura.
- [ ] CA-FRD-019-24: El módulo NO contiene mecanismos automáticos que alteren inventario.
- [ ] CA-FRD-019-25: El sistema permite registrar abonos externos parciales o totales.
- [ ] CA-FRD-019-26: Un abono externo reduce el saldo pendiente de la factura.
- [ ] CA-FRD-019-27: Un abono externo no genera movimiento de caja.
- [ ] CA-FRD-019-28: Un abono externo no afecta el canal EFECTIVO.
- [ ] CA-FRD-019-29: Un abono externo no afecta el canal NEQUI.
- [ ] CA-FRD-019-30: Un abono externo no afecta el canal LLAVE BRE.
- [ ] CA-FRD-019-31: Un abono externo no requiere turno de caja abierto.
- [ ] CA-FRD-019-32: Un abono externo no excede el saldo pendiente.
- [ ] CA-FRD-019-33: Un abono externo no registra monto menor o igual a cero.
- [ ] CA-FRD-019-34: Un abono externo no indica canal de pago.
- [ ] CA-FRD-019-35: Un abono externo no indica movimiento de caja.
- [ ] CA-FRD-019-36: El sistema permite registrar pagos internos con fondos del sistema.
- [ ] CA-FRD-019-37: Todo pago interno requiere turno de caja abierto.
- [ ] CA-FRD-019-38: Todo pago interno requiere selección explícita de canal.
- [ ] CA-FRD-019-39: Los canales válidos para pago interno son únicamente EFECTIVO, NEQUI y LLAVE BRE.
- [ ] CA-FRD-019-40: Todo pago interno reduce el saldo pendiente de la factura.
- [ ] CA-FRD-019-41: Todo pago interno genera un movimiento de caja de tipo gasto.
- [ ] CA-FRD-019-42: El movimiento de caja generado por pago interno tiene descripción obligatoria.
- [ ] CA-FRD-019-43: El movimiento de caja generado por pago interno conserva referencia a la factura.
- [ ] CA-FRD-019-44: El movimiento de caja generado por pago interno conserva el canal seleccionado.
- [ ] CA-FRD-019-45: Los pagos internos con EFECTIVO afectan el saldo esperado físico del turno.
- [ ] CA-FRD-019-46: Los pagos internos con NEQUI no afectan el conteo físico de efectivo.
- [ ] CA-FRD-019-47: Los pagos internos con LLAVE BRE no afectan el conteo físico de efectivo.
- [ ] CA-FRD-019-48: Un pago interno no registra monto menor o igual a cero.
- [ ] CA-FRD-019-49: Un pago interno no excede el saldo pendiente.
- [ ] CA-FRD-019-50: Un pago interno no se aplica sobre una factura ya pagada.
- [ ] CA-FRD-019-51: El servidor valida fondos por canal, no por saldo total consolidado.
- [ ] CA-FRD-019-52: Si el canal seleccionado no tiene fondos suficientes, el pago interno se rechaza.
- [ ] CA-FRD-019-53: El sistema no permite usar saldo de un canal para cubrir otro canal.
- [ ] CA-FRD-019-54: El sistema no permite crear canales nuevos desde este módulo.
- [ ] CA-FRD-019-55: El sistema no permite seleccionar canales fuera de EFECTIVO, NEQUI y LLAVE BRE.
- [ ] CA-FRD-019-56: Los movimientos de caja generados por pagos internos no se editan.
- [ ] CA-FRD-019-57: Los movimientos de caja generados por pagos internos no se eliminan.
- [ ] CA-FRD-019-58: Si existe error en un pago interno, la corrección se realiza mediante contra-movimiento.
- [ ] CA-FRD-019-59: Los abonos externos no se editan.
- [ ] CA-FRD-019-60: Los abonos externos no se eliminan.
- [ ] CA-FRD-019-61: Si existe error en un abono externo, la corrección se realiza mediante un ajuste auditable.
- [ ] CA-FRD-019-62: El estado de la factura se calcula dinámicamente.
- [ ] CA-FRD-019-63: Una factura está en estado PAGADA cuando el acumulado abonado o pagado cubre el monto total.
- [ ] CA-FRD-019-64: Una factura está en estado VENCIDA si tiene fecha de vencimiento pasada y no está pagada.
- [ ] CA-FRD-019-65: Una factura sin fecha de vencimiento no se marca como VENCIDA por cálculo automático.
- [ ] CA-FRD-019-66: Una factura está en estado PENDIENTE mientras no esté pagada ni vencida.
- [ ] CA-FRD-019-67: El Admin ejecuta todas las operaciones del módulo.
- [ ] CA-FRD-019-68: Un empleado solo ejecuta operaciones para las cuales tenga permiso explícito.
- [ ] CA-FRD-019-69: El registro de facturas requiere permiso de gestión de cuentas por pagar validado en servidor.
- [ ] CA-FRD-019-70: El registro de abonos externos requiere permiso de gestión de cuentas por pagar validado en servidor.
- [ ] CA-FRD-019-71: El pago interno requiere permiso de pago con fondos del sistema validado en servidor.
- [ ] CA-FRD-019-72: Toda operación valida permisos en el servidor según FRD-002.
- [ ] CA-FRD-019-73: El servidor no confía en banderas de autoridad enviadas por el cliente.
- [ ] CA-FRD-019-74: La ocultación de botones en la interfaz no sustituye la validación de servidor.
- [ ] CA-FRD-019-75: El sistema rechaza explícitamente operaciones sin permiso suficiente.

---

## Requisitos de Datos (Para Equipo Data)

### Entidad: Factura por Pagar

- Identificador único.
- Relación con tienda.
- Nombre del proveedor.
- Número de factura o referencia. Este dato NO es obligatorio.
- Monto total. Este dato es obligatorio y DEBE ser mayor a cero.
- Monto acumulado abonado o pagado.
- Fecha de vencimiento. Este dato NO es obligatorio.
- Referencia logística a una entrada de inventario. Este dato NO es obligatorio. Si se proporciona, DEBE referenciar una entrada de inventario existente y perteneciente a la misma tienda. Esta referencia es estrictamente informativa y NO DEBE disparar efectos contables, financieros ni logísticos.
- Usuario que creó el registro.
- Marcas de tiempo de creación y actualización.

Nota: El estado final de la factura NO DEBE almacenarse como campo físico único. DEBE poder calcularse dinámicamente.

### Entidad: Abono o Pago

- Identificador único.
- Relación con factura por pagar.
- Monto. Este dato es obligatorio y DEBE ser mayor a cero.
- Tipo de origen: EXTERNO o INTERNO.
- Canal de pago. Este dato es obligatorio solo cuando el origen es INTERNO. Los valores válidos son EFECTIVO, NEQUI y LLAVE BRE.
- Relación con movimiento de caja. Este dato es obligatorio solo cuando el origen es INTERNO.
- Relación con turno de caja. Este dato es obligatorio solo cuando el origen es INTERNO.
- Descripción. Este dato es obligatorio solo cuando el origen es INTERNO.
- Usuario que registra.
- Marca de tiempo.

### Entidad: Movimiento de Caja generado por pago interno

Cuando un pago interno genera movimiento de caja, este DEBE contener como mínimo:

- Identificador único.
- Relación con turno de caja.
- Tipo de movimiento: gasto.
- Concepto o subtipo: pago a proveedor.
- Monto. Este dato es obligatorio y DEBE ser mayor a cero.
- Descripción. Este dato es obligatorio.
- Canal de pago. Este dato es obligatorio. Los valores válidos son EFECTIVO, NEQUI y LLAVE BRE.
- Referencia a la factura por pagar.
- Marca de tiempo.
