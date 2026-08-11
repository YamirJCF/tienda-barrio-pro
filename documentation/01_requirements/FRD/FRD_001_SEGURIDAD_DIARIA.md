# FRD-001: Protocolo de Seguridad Diaria y Pase de Acceso

Módulo: Seguridad / Acceso
Versión: 3.0 (Consolidación normativa — absorbe FRD-001.1 y aplica Decisión D-03)
Estado: Propuesta para aprobación
Relación Documental:
- Este documento absorbe y reemplaza a FRD-001.1.
- Este documento se apoya en FRD-002 Autorización Estricta.
- Este documento se relaciona con FRD-004 Control de Caja para la separación entre acceso y operaciones monetarias.

Nota de Transición:
Este documento deroga las reglas de expiración de pase contenidas en versiones anteriores de FRD-001 y en FRD-001.1. La Decisión D-03 establece el desacople definitivo entre cierre de caja y expiración del pase diario.

---

### Nombre de la Funcionalidad
Autenticación Diaria de Empleados con Pase de Acceso y Separación de Controles

#### Descripción
Este documento regula el acceso diario de empleados al sistema bajo el principio de confianza cero. Cada empleado requiere una aprobación explícita del Administrador para ingresar cada día. El pase diario controla únicamente el acceso al sistema; las operaciones monetarias quedan condicionadas adicionalmente al estado de la caja y a los permisos específicos del usuario. El cierre de caja no revoca el pase diario.

---

## Reglas de Negocio

1. **Principio de confianza cero:** Todo intento de acceso comienza en estado pendiente. Ningún empleado puede operar hasta recibir aprobación explícita del día. No existe aprobación automática bajo ninguna condición.

2. **Aprobación diaria obligatoria:** El Administrador DEBE aprobar explícitamente el ingreso de cada empleado cada día. El sistema NO DEBE otorgar acceso sin esta aprobación.

3. **Validez del pase diario:** El pase diario es válido hasta las 23:59 del día en curso. El pase diario expira por caducidad natural al iniciar un nuevo día. El pase diario expira por revocación manual del Administrador. El pase diario NO expira por cierre de caja.

4. **Desacople entre pase y caja:** El cierre de caja NO revoca los pases diarios activos. El cierre de caja bloquea las operaciones monetarias y el sistema de ventas, pero NO fuerza la salida del empleado del sistema. El pase diario controla el acceso al sistema. La caja abierta controla la ejecución de operaciones monetarias. Los permisos del usuario controlan las acciones específicas que puede realizar.

5. **Bloqueo operativo por cierre de caja:** Si la caja está cerrada, el sistema de ventas DEBE estar completamente bloqueado. Esto aplica a todos los roles, incluyendo el Administrador. Un pase diario vigente NO autoriza ventas si la caja está cerrada. Una caja abierta NO autoriza ventas si el pase diario no está aprobado.

6. **Sala de espera activa:** Si no hay pase diario aprobado, el empleado DEBE permanecer en pantalla de espera. El empleado NO puede acceder a ninguna funcionalidad operativa mientras su solicitud esté pendiente.

7. **Límite de insistencia:** El empleado puede reenviar la notificación al Administrador un máximo de tres veces (`P_MAX_ACCESS_ATTEMPTS`). Tras tres intentos sin respuesta, el sistema DEBE bloquear la solicitud. El sistema DEBE mostrar un mensaje que indique al empleado que contacte a su supervisor por otro medio.

8. **Huella de dispositivo informativa:** Cada solicitud de acceso DEBE incluir un identificador del dispositivo desde el cual se realiza la solicitud. Este identificador tiene objetivo exclusivamente informativo. El sistema NO DEBE bloquear dispositivos con base en este identificador. El Administrador DEBE ver el identificador del dispositivo antes de aprobar o rechazar.

9. **Separación de poderes:** El pase diario permite el acceso al sistema. El permiso para abrir y cerrar caja permite operar el dinero dentro del turno. Un pase diario vigente NO otorga automáticamente permiso para operar caja. Un permiso de caja NO sustituye la necesidad de un pase diario aprobado.

10. **Revocación manual:** El Administrador DEBE poder revocar un pase diario aprobado en cualquier momento. La revocación manual produce la pérdida total de acceso del empleado. El sistema DEBE exigir una nueva solicitud de acceso tras la revocación.

11. **Caducidad natural:** Al iniciar un nuevo día, todo pase diario del día anterior DEBE quedar sin efecto. El sistema DEBE exigir una nueva solicitud de acceso para el nuevo día.

12. **Venta en curso con caja cerrada:** Si un empleado está en medio de una venta y la caja se cierra, el sistema DEBE rechazar la operación al momento de procesar el pago. El sistema NO DEBE forzar la salida del empleado. El sistema DEBE deshabilitar las funciones monetarias mientras la caja permanezca cerrada.

13. **Tareas posteriores al cierre:** Un pase diario vigente después del cierre de caja permite al empleado permanecer dentro del sistema. Las tareas que el empleado puede ejecutar quedan sujetas a los permisos del usuario y a las restricciones operativas de cada módulo. El pase diario NO habilita operaciones que otros módulos bloqueen por estado de caja o por ausencia de turno activo.

14. **Autorización estricta:** Toda operación de aprobación, revocación o acceso DEBE validar permisos en el servidor según FRD-002. El servidor NO DEBE confiar en estados, banderas o metadatos enviados por el cliente.

---

## Casos de Uso

**Caso A: Flujo diario estándar**

- **Actor:** Empleado.
- **Precondición:** El empleado tiene credenciales válidas y no tiene pase diario aprobado para el día en curso.
- **Flujo Principal:**
    1. El empleado ingresa sus credenciales personales.
    2. El sistema valida las credenciales.
    3. Si las credenciales son inválidas, el sistema muestra error y no continúa.
    4. Si las credenciales son válidas pero no hay pase diario aprobado, el sistema muestra la pantalla de espera.
    5. El sistema envía una alerta al Administrador indicando el nombre del empleado y el identificador del dispositivo.
    6. El Administrador aprueba el acceso.
    7. El sistema desbloquea la pantalla del empleado.
    8. El empleado accede al menú principal según sus permisos.
- **Flujo Alternativo:**
    - Si el Administrador rechaza la solicitud, el sistema muestra mensaje de acceso denegado.
- **Postcondición:** El empleado tiene pase diario activo y puede operar según sus permisos.

---

**Caso B: Insistencia por ausencia de respuesta**

- **Actor:** Empleado en sala de espera.
- **Precondición:** El empleado está esperando aprobación y el Administrador no ha respondido.
- **Flujo Principal:**
    1. El empleado espera en la sala de espera.
    2. El sistema habilita la opción de reenviar alerta tras `P_WAIT_TIME_RETRY_1` (ej. dos minutos) de espera.
    3. El empleado pulsa reenviar alerta (intento uno de tres).
    4. El sistema envía nueva notificación al Administrador.
    5. Si no hay respuesta tras `P_WAIT_TIME_RETRY_2` (ej. cinco minutos), el empleado puede pulsar de nuevo (intento dos de tres).
    6. Si no hay respuesta, el empleado pulsa por tercera vez (intento tres de tres).
    7. Si no hay respuesta tras el tercer intento, el sistema bloquea la solicitud.
    8. El sistema muestra mensaje indicando que el límite de intentos fue alcanzado y que contacte al administrador por otro medio.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** La solicitud queda bloqueada. El empleado debe contactar al Administrador por otro medio.

---

**Caso C: Aprobación remota**

- **Actor:** Administrador fuera de tienda.
- **Precondición:** Un empleado está solicitando acceso.
- **Flujo Principal:**
    1. El sistema envía una notificación remota al Administrador indicando el nombre del empleado y la tienda.
    2. La notificación contiene una acción para aprobar el acceso.
    3. El Administrador pulsa la acción de aprobación desde su dispositivo.
    4. El sistema procesa la aprobación y desbloquea al empleado.
    5. El Administrador recibe confirmación de acceso concedido.
- **Flujo Alternativo:**
    - Si el Administrador rechaza, el empleado ve mensaje de acceso denegado.
- **Postcondición:** El empleado queda autorizado remotamente.

---

**Caso D: Aprobación en sitio**

- **Actor:** Administrador con sesión activa.
- **Precondición:** El Administrador está usando el sistema activamente y un empleado solicita acceso.
- **Flujo Principal:**
    1. El sistema detecta la sesión activa del Administrador.
    2. El sistema muestra una alerta indicando el nombre del empleado y el identificador del dispositivo.
    3. El sistema ofrece las acciones de aprobar, rechazar o ignorar.
    4. Si el Administrador aprueba, la alerta desaparece y el empleado accede.
    5. Si el Administrador rechaza, el empleado ve mensaje de acceso denegado.
- **Flujo Alternativo:**
    - Si el Administrador ignora la alerta, la solicitud permanece pendiente.
- **Postcondición:** La solicitud queda procesada según la decisión del Administrador.

---

**Caso E: Revocación manual de pase**

- **Actor:** Administrador.
- **Precondición:** Existe un pase diario aprobado y activo.
- **Flujo Principal:**
    1. El Administrador accede al panel de pases activos.
    2. El Administrador selecciona la acción de revocar sobre un pase específico.
    3. El sistema cambia el estado del pase a rechazado.
    4. El sistema detecta el cambio en la siguiente verificación del empleado.
    5. El sistema fuerza el cierre de sesión del empleado.
    6. El sistema redirige al empleado a la pantalla de solicitud de acceso.
    7. El sistema muestra confirmación al Administrador indicando que el acceso fue revocado.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El empleado pierde acceso al sistema. El pase queda registrado como revocado.

---

**Caso F: Venta en curso con cierre de caja**

- **Actor:** Empleado en proceso de venta.
- **Precondición:** El empleado tiene pase diario activo y está en medio de una venta. La caja se cierra remotamente.
- **Flujo Principal:**
    1. El empleado está en medio de una venta.
    2. El Administrador cierra la caja.
    3. El empleado intenta procesar el pago.
    4. El sistema detecta que la caja está cerrada.
    5. El sistema muestra error indicando que la caja ha sido cerrada y que no se puede completar la transacción.
    6. El sistema NO fuerza la salida del empleado.
    7. El sistema deshabilita las funciones monetarias.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** La venta no se completa. El empleado permanece dentro del sistema sin funciones monetarias activas.

---

**Caso G: Caducidad natural por cambio de día**

- **Actor:** Sistema.
- **Precondición:** Existe un pase diario aprobado del día anterior.
- **Flujo Principal:**
    1. El reloj del servidor marca el inicio de un nuevo día.
    2. El sistema detecta que la fecha actual es posterior a la fecha del pase.
    3. El sistema invalida el pase anterior.
    4. Cualquier intento de acceso del empleado es rechazado.
    5. El sistema redirige al empleado a la pantalla de solicitud de nuevo pase.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El pase anterior queda sin efecto. El empleado debe solicitar un nuevo pase para el día en curso.

---

## Criterios de Aceptación

- [ ] CA-FRD-001-01: El sistema no permite operar sin pase diario aprobado.
- [ ] CA-FRD-001-02: Todo intento de acceso comienza en estado pendiente.
- [ ] CA-FRD-001-03: El Administrador aprueba explícitamente el ingreso de cada empleado cada día.
- [ ] CA-FRD-001-04: No existe aprobación automática bajo ninguna condición.
- [ ] CA-FRD-001-05: El pase diario es válido hasta las 23:59 del día en curso.
- [ ] CA-FRD-001-06: El pase diario expira por caducidad natural al iniciar un nuevo día.
- [ ] CA-FRD-001-07: El pase diario expira por revocación manual del Administrador.
- [ ] CA-FRD-001-08: El cierre de caja NO expira el pase diario.
- [ ] CA-FRD-001-09: El cierre de caja bloquea las operaciones monetarias.
- [ ] CA-FRD-001-10: El cierre de caja NO fuerza la salida del empleado del sistema.
- [ ] CA-FRD-001-11: Un pase diario vigente NO autoriza ventas si la caja está cerrada.
- [ ] CA-FRD-001-12: Una caja abierta NO autoriza ventas si el pase diario no está aprobado.
- [ ] CA-FRD-001-13: El contador de reintentos de notificación tiene un máximo definido en `P_MAX_ACCESS_ATTEMPTS`.
- [ ] CA-FRD-001-14: Tras superar el máximo de intentos sin respuesta, el sistema bloquea la solicitud.
- [ ] CA-FRD-001-15: El identificador del dispositivo se registra y se muestra al Administrador antes de aprobar.
- [ ] CA-FRD-001-16: El identificador del dispositivo NO bloquea dispositivos.
- [ ] CA-FRD-001-17: El pase diario NO otorga automáticamente permiso para operar caja.
- [ ] CA-FRD-001-18: El permiso para operar caja NO sustituye la necesidad de un pase diario aprobado.
- [ ] CA-FRD-001-19: El Administrador puede revocar un pase diario aprobado en cualquier momento.
- [ ] CA-FRD-001-20: La revocación manual fuerza el cierre de sesión del empleado.
- [ ] CA-FRD-001-21: Si una venta en curso intenta completarse con caja cerrada, el sistema rechaza la operación.
- [ ] CA-FRD-001-22: Si una venta en curso intenta completarse con caja cerrada, el sistema NO expulsa al empleado.
- [ ] CA-FRD-001-23: Toda operación de aprobación, revocación o acceso valida permisos en el servidor según FRD-002.
- [ ] CA-FRD-001-24: El servidor NO confía en estados, banderas o metadatos enviados por el cliente.
