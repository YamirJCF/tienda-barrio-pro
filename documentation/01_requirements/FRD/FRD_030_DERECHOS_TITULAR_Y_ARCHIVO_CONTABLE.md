# FRD-030: Derechos del Titular y Eliminación Contable Protegida en Cartera

> **Estado:** 🟢 Aprobado — Validado contra `ARQ-002` (`POL-PRIV-02`, `POL-PRIV-01`, `POL-AUD-01`, `POL-AUD-02`, `POL-SEG-03`)

### Nombre de la Funcionalidad
Ejercicio de Derechos de Habeas Data y Eliminación Transparente con Resguardo Contable en Cartera

#### Descripción
El sistema debe permitir atender los derechos legales de los titulares registrados en la cartera de crédito de la tienda (consultar su estado de cuenta, actualizar sus datos y eliminar su registro) mediante una experiencia simple que exponga únicamente la información necesaria para confirmar o negar cada acción. Para el Administrador de la tienda existe una sola acción de borrado (**Eliminar Cliente**). Cuando se solicita eliminar a un cliente, el servidor verifica primero que su saldo pendiente sea exactamente cero; si mantiene deuda activa, niega la acción. Si el saldo es cero, el sistema confirma la eliminación al usuario, mientras que internamente y de forma transparente el servidor resuelve el deber legal contable (Art. 60 del Código de Comercio, Art. 632 del Estatuto Tributario y Art. 2.2.2.25.2.6 del Decreto 1074 de 2015): si el cliente nunca tuvo movimientos, lo borra definitivamente; si tuvo movimientos históricos, conserva en silencio su nombre, cédula y asientos pasados en archivo contable interno (limpiando su teléfono y cupo e impidiendo que aparezca en listas activas). Si en el futuro esa misma persona vuelve a registrarse en la tienda, el sistema procesa el alta con normalidad sin exponer estados internos ni duplicar su cédula.

#### Alcance
| Incluido | Excluido (con su motivo) |
|---|---|
| **Acción única "Eliminar Cliente"** (exclusiva del Administrador) con resolución interna automática según tenga o no movimientos históricos | **Exposición de estados contables internos en la interfaz:** el usuario solo recibe la confirmación o negación de la eliminación/creación, sin jerga ni alertas sobre archivos históricos |
| **Bloqueo estricto de eliminación** cuando el cliente tiene saldo pendiente mayor a cero (deber contractual vigente) | **Destrucción de nombre o cédula en terceros con movimientos contables:** prohibido en el servidor para no dejar huérfanos los soportes de ingresos por abonos en caja |
| **Re-alta transparente sin duplicados** cuando se vuelve a crear un cliente cuya cédula estaba archivada internamente, generando una nueva traza de confirmación (`FRD-029`) | **Módulo de tickets o bandeja PQRS:** alcance diferido por eficiencia; el Administrador ejecuta las acciones directamente sobre la ficha del cliente |
| **Consulta/exportación de estado de cuenta y actualización** de datos del cliente activo | **Ventas de contado (Consumidor Final RST):** no almacenan datos personales de terceros |

#### Alcance diferido (registro formal)
| Qué se difiere | Por qué | Cuándo se revisa |
|---|---|---|
| Bandeja interna de solicitudes/tickets PQRS con cronómetro de plazos | Con bajo volumen de solicitudes en una tienda de barrio, las acciones directas del Administrador en la ficha del cliente resuelven la solicitud en el acto sin complejizar la interfaz | Cuando el volumen supere ~5 solicitudes mensuales por tienda o exista personal dedicado de soporte |
| Purga automática tras vencer el plazo legal de retención contable (5 a 10 años) | Ninguna tienda tiene aún antigüedad de 5 o 10 años de registros históricos en la plataforma | Al cumplirse el primer ciclo de 5 años de operación en producción |

---

## Reglas de Negocio

### A. Acción Única de Eliminación y Resguardo Contable Interno
1. **RN-01 (Bloqueo por deuda activa):** El sistema NO PUEDE permitir eliminar a ningún cliente cuyo saldo pendiente sea mayor a cero (`$0`), por existir un deber contractual de pago vigente (Ley 1266 de 2008 y Art. 2.2.2.25.2.6 del Decreto 1074 de 2015).
2. **RN-02 (Exclusividad del Administrador):** Solo el Administrador de la tienda PUEDE ejecutar la acción de eliminar un cliente. Ningún cajero o empleado operativo PUEDE eliminar clientes de la cartera (`POL-SEG-03`).
3. **RN-03 (Unicidad de la acción y mínima información al usuario):** Frente al usuario existe una única acción (**Eliminar Cliente**). El sistema NO PUEDE exponer en la interfaz distinciones técnicas entre "inactivar" y "borrar", y DEBE limitarse a confirmar que el cliente fue eliminado o a negar la acción si existe saldo pendiente.
4. **RN-04 (Resolución interna en el servidor al eliminar):** Cuando el Administrador elimina a un cliente con saldo igual a `$0`, el servidor DEBE determinar internamente y en silencio el tratamiento del registro según su historial:
   - **Con movimientos históricos (Resguardo contable silencioso):** Si el cliente posee compras a crédito o abonos pasados, el servidor TIENE PROHIBIDO destruir su nombre, su cédula o sus transacciones históricas (Art. 60 C. de Co. y Art. 632 E.T.). Internamente, el servidor DEBE limpiar su teléfono de contacto, fijar su cupo en `$0` y pasarlo a estado archivado para que desaparezca por completo de las listas y búsquedas operativas.
   - **Sin ningún movimiento histórico (Borrado definitivo):** Si el cliente tiene `0 movimientos históricos`, el servidor DEBE eliminarlo definitivamente de la base de datos.

### B. Re-alta Transparente y Unicidad del Tercero
5. **RN-05 (Unicidad de cédula y re-alta silenciosa):** La cédula del cliente es única por tienda (`FRD-009`). Cuando un operador crea un cliente ingresando una cédula:
   - Si la cédula pertenece a un cliente **actualmente activo**, el servidor DEBE negar la creación informando que el cliente ya existe.
   - Si la cédula pertenece a un registro que fue eliminado previamente pero **conservado en archivo contable interno**, el servidor DEBE reutilizar y reactivar silenciosamente ese mismo tercero con los nuevos datos ingresados (nombre, teléfono, cupo) sin arrojar avisos sobre su estado archivado previo, y estampar un nuevo registro inmutable de confirmación con el usuario creador y la fecha/hora del servidor (`FRD-029`, Reglas 14 y 15).

### C. Derechos de Consulta, Actualización y Trazabilidad
6. **RN-06 (Consulta y estado de cuenta):** El sistema DEBE permitir consultar y exportar el historial de movimientos (compras a crédito, abonos realizados y saldo actual) de un cliente activo para entregárselo al titular cuando lo solicite.
7. **RN-07 (Actualización sin alterar saldos ni historia):** El sistema DEBE permitir actualizar los datos del cliente activo (nombre, teléfono o cupo) sin alterar jamás los montos, fechas o saldos de sus transacciones pasadas ni los cierres de caja históricos (`POL-AUD-01`).
8. **RN-08 (Bitácora inmutable en el servidor):** Toda eliminación o re-alta de un cliente DEBE quedar registrada internamente de forma inmutable en la bitácora del servidor con la tienda, el cliente, el usuario ejecutor y la fecha y hora exacta del servidor (`POL-AUD-02`).

---

## Casos de Uso

**Caso A: Intento de eliminar un cliente con deuda pendiente (Negación)**
- **Actor:** Administrador de la tienda.
- **Precondición:** El cliente tiene un saldo pendiente mayor a `$0`.
- **Flujo Principal:**
  1. El Administrador selecciona la opción **Eliminar Cliente** en la ficha del cliente.
  2. El servidor verifica el saldo y detecta que es mayor a `$0`.
  3. El servidor niega la acción y el sistema informa que no es posible eliminar al cliente porque mantiene saldo pendiente (RN-01, RN-03).
- **Postcondición:** El cliente permanece activo sin cambios.

**Caso B: Eliminación exitosa de un cliente con saldo en `$0`**
- **Actor:** Administrador de la tienda.
- **Precondición:** El cliente tiene saldo exactamente igual a `$0`.
- **Flujo Principal:**
  1. El Administrador selecciona **Eliminar Cliente** y confirma la acción.
  2. El servidor verifica que el saldo es `$0`.
  3. Internamente y sin exponer detalles técnicos al usuario, el servidor ejecuta la regla RN-04 (si tenía movimientos históricos, limpia teléfono/cupo y lo archiva ocultándolo de toda lista activa; si tenía `0 movimientos`, lo borra físicamente) y guarda la traza en la bitácora de auditoría (RN-08).
  4. El sistema muestra al Administrador la confirmación de que el cliente fue eliminado (RN-03).
- **Flujos Alternativos:**
  - **B1. Un cajero intenta eliminar al cliente:** El sistema niega la acción por falta de permisos (RN-02).
- **Postcondición:** El cliente desaparece de la cartera activa de la tienda y la contabilidad histórica permanece íntegra.

**Caso C: Creación de un cliente cuya cédula había sido eliminada en el pasado (Re-alta transparente)**
- **Actor:** Cajero / Administrador de la tienda.
- **Precondición:** Una persona que años o meses atrás tuvo crédito y fue eliminada solicita nuevamente abrir crédito con su misma cédula.
- **Flujo Principal:**
  1. El operador abre el formulario de crear cliente, ingresa nombre, cédula, teléfono y cupo, y presiona **Guardar**.
  2. El servidor detecta internamente que la cédula corresponde a un tercero archivado con saldo `$0`.
  3. Sin mostrar alertas adicionales ni exponer información histórica innecesaria, el servidor reactiva el registro único del tercero con los datos nuevos y estampa el nuevo registro inmutable de confirmación con el usuario creador y la fecha/hora del servidor (RN-05).
  4. El sistema confirma que el cliente fue guardado.
- **Flujos Alternativos:**
  - **C1. La cédula pertenece a un cliente que ya está activo hoy:** El servidor niega la acción indicando que el cliente ya se encuentra registrado (RN-05).
- **Postcondición:** El cliente queda activo nuevamente bajo su registro contable único, sin duplicar terceros.

**Caso D: Consulta de estado de cuenta y actualización de datos**
- **Actor:** Administrador / Cajero.
- **Precondición:** El cliente activo solicita conocer sus movimientos o corregir sus datos.
- **Flujo Principal:**
  1. El operador abre la ficha del cliente activo.
  2. Para **consulta**: visualiza o exporta el estado de cuenta (compras a crédito, abonos y saldo actual) (RN-06).
  3. Para **actualización**: edita los datos permitidos y presiona Guardar; el servidor actualiza la ficha sin modificar transacciones pasadas (RN-07).
- **Postcondición:** Datos actualizados o estado de cuenta entregado sin afectar la integridad contable.

---

## Criterios de Aceptación
- [ ] **CA-030-01 (Bloqueo al eliminar con deuda):** Si el Administrador intenta eliminar un cliente con saldo mayor a `$0`, el servidor niega la acción informando únicamente que no se puede eliminar porque tiene saldo pendiente.
- [ ] **CA-030-02 (Exclusividad del Administrador):** Solo el Administrador puede ejecutar la acción de eliminar un cliente.
- [ ] **CA-030-03 (Eliminación transparente con resguardo contable interno):** Cuando el Administrador elimina un cliente con saldo `$0`, el sistema confirma la eliminación con un único mensaje estándar; internamente, si el cliente tenía movimientos históricos, el servidor conserva en silencio su nombre, cédula y movimientos para la contabilidad pasada (limpiando teléfono y cupo e impidiendo que aparezca en listas activas), y si no tenía movimientos, lo borra definitivamente.
- [ ] **CA-030-04 (Re-alta transparente sin exponer estado interno):** Si se crea un cliente cuya cédula estaba archivada internamente, el sistema procesa el guardado como un alta normal sin arrojar avisos de archivo histórico, reactivando internamente el registro contable único y estampando la nueva traza de confirmación (`FRD-029`). Solo si la cédula pertenece a un cliente actualmente activo, el sistema niega el registro por duplicidad.
- [ ] **CA-030-05 (Consulta y actualización de datos):** El sistema permite consultar/exportar el estado de cuenta de un cliente activo y actualizar sus datos (nombre, teléfono, cupo) sin alterar jamás los montos o fechas de transacciones pasadas.
- [ ] **CA-030-06 (Bitácora inmutable en el servidor):** Toda eliminación o re-alta queda registrada internamente en la bitácora de auditoría con el usuario ejecutor y la fecha y hora del servidor.

---

## Requisitos de Datos (Para Equipo Data)

### 1. Estado de Ciclo de Vida Interno en la Entidad Cliente
Atributos internos en la ficha del cliente que el servidor administra de forma transparente sin exponer complejidad al usuario.
- **Estado interno del registro:** Distingue internamente entre cliente **Activo** (visible y operativo en la tienda) y **Archivado Contablemente** (eliminado para el usuario, pero conservado en el servidor porque posee movimientos históricos).
- **Fecha y hora de eliminación (Servidor):** Marca temporal de cuándo fue eliminado por el Administrador (nulo mientras esté activo).
- **Regla de unicidad de cédula por tienda:** La cédula es única por tienda; el servidor utiliza este identificador para reactivar silenciosamente un registro archivado cuando se vuelve a crear, o rechazar si ya está activo.

### 2. Registro en Bitácora de Auditoría de Cartera
Traza inmutable (*Append-Only*) generada en el servidor cuando se elimina o se vuelve a dar de alta un cliente.
- **Identificador único del evento.**
- **Tienda y Cliente asociados.**
- **Tipo de evento interno:** Eliminación (archivado contable o borrado sin movimientos) o Re-alta.
- **Usuario ejecutor:** Identificador y nombre del usuario que realizó la acción.
- **Fecha y hora exacta del servidor.**
