# FRD-013: Gestión de Sesiones

> **Módulo:** Autenticación / Sesiones  
> **Versión:** 2.1 (Enmienda aditiva: Verificación Continua de Sesión — RN-013-09 a RN-013-15)  
> **Fecha:** 2026-10-30  
> **Estado:** ✅ Aprobado y Validado Formalmente (Enmienda v2.1 validada bajo /validate-policy). Las reglas RN-013-01 a RN-013-08 permanecen vigentes e intactas.  
> **Políticas Rectoras:** `POL-SEG-02`, `POL-SEG-03`, `POL-LOG-01`, `POL-AUD-01`, `POL-AUD-02`, `POL-AUD-03`

---

## Descripción

Este documento define las reglas para el ciclo de vida de las sesiones de usuario en el sistema: inicio, relevo de jornada sin logout manual, límites de concurrencia y desacople respecto al estado de la caja de la tienda. Complementa a `FRD-001` (Seguridad Diaria y Pase Diario), `FRD-002` (Registro Admin), `FRD-003` (Gestión de Empleados) y `FRD-017` (Ciclo Contable y Sesiones).

**Principio rector:** Las sesiones de los usuarios son persistentes en sus dispositivos para evitar fricción operativa, pero el acceso a las funciones del negocio está gobernado por la validez del Pase Diario (en colaboradores) y el estado del turno contable de caja (para operaciones monetarias), garantizando que las tareas logísticas no monetarias operen de forma autónoma.

---

## Contexto Operativo y Separación de Poderes

| Rol | Identidad y Credenciales | Autorización de Acceso al Sistema | Autorización de Operaciones Monetarias |
|:---|:---|:---|:---|
| **Administrador** | Cuenta maestra (Correo + Contraseña) | Sesión de cuenta válida | Requiere turno de caja abierto (< `P_MAX_HORAS_TURNO`) |
| **Colaborador** | Identidad de empleado (Alias + PIN) | Pase Diario aprobado vigente (para el día o turno nocturno activo) | Requiere turno de caja abierto (< `P_MAX_HORAS_TURNO`) + permiso específico |

---

## Reglas de Negocio

### RN-013-01: Duración de Sesión y Relevo Automático de Jornada
El sistema asume que en el entorno real de una tienda de barrio los colaboradores y el Administrador no realizan un cierre de sesión manual al culminar su turno de trabajo diario.
- La identidad persistida en el dispositivo permanece asociada al usuario sin cerrarse por el simple paso del tiempo.
- Al abrir la aplicación en un nuevo día calendario, el sistema DEBE evaluar de inmediato el estado del acceso:
  - **Para el Administrador:** Si la sesión maestra ha expirado, el sistema DEBE redirigir limpiamente a la pantalla de ingreso.
  - **Para el Colaborador:** Si el Pase Diario pertenecía al día calendario anterior y la tienda NO cuenta con un turno nocturno abierto, el sistema DEBE transicionar automáticamente la pantalla a la solicitud del nuevo Pase Diario del día, teniendo PROHIBIDO permitir el acceso a módulos operativos o exhibir datos de negocio obsoletos en caché.
- Una sesión solo se termina de forma definitiva cuando:
  1. El usuario ejecuta un cierre de sesión voluntario explícito.
  2. El Administrador desactiva la cuenta del colaborador (`FRD-003`).
  3. El Administrador revoca remotamente el dispositivo (`FRD-015`).

### RN-013-02: Límite de Sesiones Concurrentes por Tienda
El sistema permite un máximo de hasta `P_MAX_EMPLOYEES_PER_STORE` colaboradores y 1 Administrador con sesiones activas simultáneas por tienda (`POL-SEG-03`):
- 1 sesión para el Administrador / Propietario.
- Hasta `P_MAX_EMPLOYEES_PER_STORE` sesiones independientes para colaboradores.

Si se intenta iniciar una sesión que supere la capacidad máxima:
1. El sistema DEBE rechazar el intento de acceso.
2. El sistema DEBE informar: "Límite de dispositivos alcanzado. Cierre sesión en otro dispositivo para continuar."

### RN-013-03: Comportamiento del Cierre de Sesión Voluntario
Cuando un usuario decide cerrar sesión voluntariamente:

| Acción | Administrador | Colaborador |
|:---|:---:|:---:|
| Limpiar credenciales de autenticación local | ✅ SÍ | ✅ SÍ |
| Redirigir a pantalla de ingreso | ✅ SÍ | ✅ SÍ |
| Preservar inventario y catálogo en caché de lectura | ✅ SÍ | ✅ SÍ |
| Preservar lista de clientes en caché de lectura | ✅ SÍ | ✅ SÍ |
| Limpiar carrito de venta en curso | ✅ SÍ | ✅ SÍ |
| Invalidar Pase Diario actual | N/A | ✅ SÍ |
| **Preservar colas de sincronización offline pendientes** | ✅ SÍ | ✅ SÍ |

> **Gobernanza de Almacenamiento:** Bajo ninguna circunstancia el cierre de sesión voluntario puede destruir las colas de sincronización offline (`sync_queue` / DLQ), protegiendo la *POL-AUD-01 (Inmutabilidad Histórica)* y `FRD-028`.

### RN-013-04: Continuidad Operativa e Inmunidad ante Inactividad (Sin Alertas Falsas)
El sistema NO cierra sesiones por inactividad. En una tienda física, los dispositivos pueden permanecer con la pantalla apagada o sin interacción durante periodos prolongados mientras el personal realiza tareas físicas de inventario, recepción de mercancía o atención directa en mostrador.
- El sistema TIENE PROHIBIDO clasificar como abandono o alerta de seguridad (`GHOST`) a un colaborador cuya pantalla se apague o deje de enviar señales periódicas durante la jornada mientras realiza labores de inventario o cuando la caja esté cerrada.
- La ausencia de interacción en labores no monetarias jamás interrumpirá la sesión del colaborador.

### RN-013-05: Cierre Forzado por Desactivación de Cuenta
Cuando el Administrador desactiva a un colaborador (`FRD-003`):
1. El acceso del colaborador DEBE revocarse en tiempo real.
2. Toda petición posterior del dispositivo DEBE ser rechazada por el servidor central.
3. El dispositivo del colaborador DEBE ser redirigido a la pantalla de ingreso con el mensaje: "Tu cuenta ha sido desactivada. Contacta al administrador."

### RN-013-06: Desacople Absoluto entre Cierre de Caja y Pase Diario
Alineado estrictamente con `FRD-001` (Reglas 3, 4 y 13) y la *POL-LOG-01 (Independencia Logística-Financiera)*:
- El cierre ordinario o forzado de la caja de la tienda **TIENE TERMINANTEMENTE PROHIBIDO invalidar los Pases Diarios** de los colaboradores.
- El cierre de caja bloquea de forma exclusiva las operaciones monetarias (ventas POS, egresos, gastos en efectivo, cobro de abonos y anulaciones en efectivo) para todos los roles, incluido el Administrador.
- Los colaboradores con Pase Diario vigente DEBEN conservar pleno acceso a sus funciones no monetarias autorizadas (consulta y toma física de inventario, registro de proveedores, clientes y reportes analíticos).

### RN-013-07: Continuidad de Sesión y Pase en Cruce de Medianoche
Si la tienda mantiene un turno de caja abierto durante la noche (`FRD-017` `RN-017-01`):
- Los Pases Diarios aprobados en el día calendario anterior conservan plena validez operativa después de las `00:00` horas mientras el turno de caja permanezca abierto y no haya superado `P_MAX_HORAS_TURNO`.
- El sistema NO PUEDE interrumpir el trabajo de los colaboradores ni forzarlos a solicitar un nuevo pase en medio de una jornada nocturna activa.

### RN-013-08: Revocación Remota de Dispositivo por el Administrador
El Administrador DEBE poder revocar remotamente el dispositivo de un colaborador específico desde el panel de control (`FRD-015`):
- Al revocar el dispositivo, el servidor cancela el acceso de ese dispositivo, libera el cupo de concurrencia e invalida el Pase Diario correspondiente.
- El colaborador afectado DEBE recibir el aviso: "Tu sesión fue cerrada por el administrador" y ser conducido a la pantalla de ingreso.

### RN-013-09: Verificación Continua de Sesión con la Aplicación Abierta (Enmienda v2.1)
`RN-013-01` define qué ocurre al **abrir** la aplicación. Esta regla cubre el vacío restante: la aplicación que permanece abierta durante horas o días sin cerrarse, de forma indefinida.
1. El sistema DEBE evaluar la vigencia del acceso durante toda la permanencia de la aplicación abierta, sin límite de duración, y no solo al arrancar.
2. La evaluación es obligatoria en cada uno de estos momentos:
   - Al abrir o cargar la aplicación.
   - Cuando la aplicación vuelve a primer plano tras estar oculta o cuando el dispositivo despierta de suspensión.
   - Cuando el dispositivo recupera conectividad.
   - Cuando cambia el estado de autenticación del dispositivo (por ejemplo, la sesión maestra se invalida).
   - Cuando el servidor rechaza cualquier operación por falta de acceso a la tienda.
   - De forma periódica, cada `P_INTERVALO_VERIFICACION_SESION`, mientras la aplicación esté visible y con conexión.
3. Esta verificación **NO es un temporizador de inactividad**. No depende de que el usuario interactúe y NO PUEDE cerrar una sesión que el servidor considera vigente. Es plenamente compatible con `RN-013-04`.

### RN-013-10: Autoridad Única del Servidor sobre la Vigencia (Enmienda v2.1)
1. El servidor es la única fuente de verdad sobre si un usuario tiene acceso vigente. El dispositivo NO PUEDE deducir la vigencia a partir de datos que él mismo guardó (identidad recordada, pase recordado, marca de "autenticado").
2. Con conexión disponible, el dispositivo NO PUEDE exhibir datos de negocio de una pantalla operativa hasta que el servidor haya confirmado el acceso vigente en la evaluación de arranque o de reanudación.
3. El servidor DEBE responder siempre uno de estos cuatro estados, con su motivo: **Vigente**, **Requiere ingreso**, **Requiere pase del día**, **Acceso revocado o cuenta desactivada**.
4. La evaluación aplica a TODOS los roles, incluido el Administrador. Ningún rol queda exento.

### RN-013-11: Definición Única de "Acceso Vigente" (Enmienda v2.1)
1. **Administrador:** tiene acceso vigente mientras su sesión maestra sea válida.
2. **Colaborador:** tiene acceso vigente cuando posee un Pase Diario aprobado del día calendario en curso, o del día calendario anterior si la tienda mantiene un turno de caja abierto con menos de `P_MAX_HORAS_TURNO` (`RN-013-07`).
3. Esta definición DEBE ser la misma para (a) el estado que se informa al dispositivo y (b) la autorización de cada operación que el servidor recibe. Está PROHIBIDO que coexistan dos criterios distintos de vigencia (por ejemplo, una ventana móvil de 24 horas para informar y el día calendario para autorizar), porque produce el síntoma "la pantalla dice que tengo acceso, pero todo falla".

### RN-013-12: Respuesta Ante la Pérdida de Acceso Detectada con la App Abierta (Enmienda v2.1)
Al detectar que el acceso dejó de ser vigente, el sistema DEBE actuar de inmediato según el motivo:

| Motivo reportado por el servidor | Destino | Mensaje al usuario |
|:---|:---|:---|
| Sesión maestra del Administrador vencida o inexistente | Pantalla de ingreso | "Tu sesión terminó. Inicia sesión nuevamente." |
| Colaborador: nuevo día calendario sin turno nocturno abierto | Solicitud de Pase Diario del día | "Comienza un nuevo día. Solicita tu pase para continuar." |
| Cuenta de colaborador desactivada (`RN-013-05`) | Pantalla de ingreso | "Tu cuenta ha sido desactivada. Contacta al administrador." |
| Dispositivo revocado (`RN-013-08`) | Pantalla de ingreso | "Tu sesión fue cerrada por el administrador." |

Reglas comunes:
1. El sistema DEBE ocultar de inmediato los datos de negocio visibles.
2. El carrito de venta en curso se descarta, igual que en el cierre voluntario (`RN-013-03`). Las ventas ya confirmadas y pendientes de sincronizar NO se descartan jamás.
3. Las colas de sincronización offline DEBEN preservarse íntegras y quedar en pausa hasta un nuevo ingreso con conexión (`FRD-012`, `FRD-028`).
4. Si varias operaciones fallan a la vez por la misma causa, el usuario DEBE ver **un solo aviso** y ocurrir **una sola** transición.

### RN-013-13: La Pérdida de Acceso Nunca es Silenciosa (Enmienda v2.1)
1. Ninguna pantalla PUEDE mostrar valores en cero, listas vacías o paneles en blanco como consecuencia de una pérdida de acceso. El usuario DEBE ver el aviso de `RN-013-12`.
2. La pérdida de acceso NO PUEDE confundirse con la falta de conexión. Sin conexión, el sistema NO expulsa al usuario: opera en modo offline conforme a `FRD-012` y lo indica de forma visible.
3. Al recuperar la conexión, el sistema DEBE evaluar el acceso **antes** de sincronizar cualquier cola pendiente.

### RN-013-14: Coherencia entre Pestañas y Ventanas del Mismo Dispositivo (Enmienda v2.1)
Si la pérdida de acceso se detecta en una pestaña o ventana, TODAS las demás del mismo dispositivo DEBEN reflejar el mismo estado sin esperar su propia evaluación.

### RN-013-15: Trazabilidad de la Pérdida de Acceso (Enmienda v2.1)
Cada pérdida de acceso detectada DEBE registrarse como un evento de seguridad (`POL-AUD-02`), con motivo y momento de detección, en cuanto exista conexión. Se registra **un evento por pérdida**, no uno por cada petición rechazada.

---

## Casos de Uso

**Caso A: Inicio de Jornada al Día Siguiente sin Logout Previo**
- **Actor:** Colaborador.
- **Precondición:** El colaborador operó ayer con pase aprobado, se fue a su casa sin cerrar sesión y la caja del día anterior ya fue cerrada por el Administrador.
- **Flujo Principal:**
  1. El colaborador abre la aplicación a las 08:00 AM.
  2. El sistema detecta que el pase almacenado pertenece al día anterior y que no existe un turno nocturno abierto.
  3. El sistema no permite el ingreso directo al Dashboard con datos en caché, sino que redirige automáticamente a la pantalla de solicitud de Pase Diario del día.
  4. El colaborador solicita su pase diario de hoy con un solo toque.
  5. El Administrador aprueba la solicitud y el colaborador ingresa a operar.
- **Postcondición:** Cero sesiones fantasma; seguridad de acceso diario preservada sin fricción.

**Caso B: Realización de Inventario Físico con Caja Cerrada**
- **Actor:** Colaborador con permiso de inventario.
- **Precondición:** El turno de caja fue cerrado a las 07:00 PM. El colaborador tiene pase diario aprobado de hoy.
- **Flujo Principal:**
  1. El colaborador ingresa al módulo de Inventario para realizar el conteo físico de estantes.
  2. El sistema permite el acceso al catálogo y al registro de ajustes de conteo.
  3. Durante el conteo, el colaborador apaga la pantalla del celular por 20 minutos mientras cuenta cajas en bodega.
  4. Al encender la pantalla, la sesión sigue activa y sin alertas de abandono o bloqueo.
- **Postcondición:** Autonomía logística garantizada sin dependencia del estado de la caja ni falsos positivos de seguridad.

**Caso C: Turno Nocturno que Cruza las Doce de la Noche**
- **Actor:** Colaborador y Administrador.
- **Precondición:** Caja abierta a las 09:00 PM con turno activo.
- **Flujo Principal:**
  1. El reloj del sistema marca las 00:00:01 AM (cambio de día calendario).
  2. El colaborador procesa una venta POS a las 00:15 AM.
  3. El sistema valida que el turno de caja sigue abierto y tiene menos de `P_MAX_HORAS_TURNO`.
  4. El servidor acepta la transacción sin exigir un nuevo pase diario ni interrumpir la atención al público.
- **Postcondición:** Continuidad contable y operativa del hecho económico ininterrumpida.

**Caso D: Aplicación del Administrador Abierta Durante Días (Enmienda v2.1)**
- **Actor:** Administrador.
- **Precondición:** El Administrador dejó la aplicación abierta en una tablet o computador durante varios días. La sesión maestra ya no es válida en el servidor.
- **Flujo Principal:**
  1. El Administrador toca la pantalla o el dispositivo vuelve a primer plano.
  2. El sistema evalúa el acceso con el servidor (`RN-013-09`) y recibe "Requiere ingreso".
  3. El sistema oculta los datos de negocio y lleva al Administrador a la pantalla de ingreso con el mensaje de `RN-013-12`.
- **Flujo Alternativo:** Si el dispositivo está sin conexión, el sistema NO expulsa al Administrador; opera en modo offline y evalúa al recuperar la conexión (`RN-013-13`).
- **Postcondición:** El Administrador nunca ve paneles en cero ni errores técnicos; ve el motivo y la acción a seguir.

**Caso E: Colaborador Deja la Aplicación Abierta Toda la Noche (Enmienda v2.1)**
- **Actor:** Colaborador.
- **Precondición:** Se retiró con pase aprobado de ayer; la caja se cerró y no hay turno nocturno abierto. La aplicación quedó abierta toda la noche.
- **Flujo Principal:**
  1. A las 08:00 AM el colaborador despierta el dispositivo.
  2. El sistema evalúa el acceso y recibe "Requiere pase del día".
  3. El sistema lo lleva a la solicitud del Pase Diario con un solo toque (`RN-013-12`), sin mostrar datos del día anterior.
- **Postcondición:** Cero sesiones fantasma, sin necesidad de logout manual.

**Caso F: Varias Pantallas Fallan al Mismo Tiempo (Enmienda v2.1)**
- **Actor:** Cualquier usuario.
- **Precondición:** El acceso se perdió mientras el usuario tenía abierto un tablero que consulta varios reportes a la vez.
- **Flujo Principal:**
  1. Varias consultas son rechazadas simultáneamente por falta de acceso.
  2. El sistema consolida las fallas en una sola evaluación.
  3. El usuario ve un único aviso y una única transición (`RN-013-12`, regla común 4).
- **Postcondición:** El usuario no presencia una cascada de errores.

---

## Criterios de Aceptación
- [ ] **CA-SES-01:** El sistema rechaza el intento de acceso si se excede el límite de `P_MAX_EMPLOYEES_PER_STORE` colaboradores más 1 Administrador.
- [ ] **CA-SES-02:** Abrir la app al día siguiente sin un turno nocturno abierto conduce al colaborador a la solicitud del pase del día, sin cargar pantallas operativas en caché.
- [ ] **CA-SES-03:** El cierre de caja ordinario o forzado NO expira los pases diarios de los colaboradores ni bloquea módulos no monetarios permitidos.
- [ ] **CA-SES-04:** Un colaborador en labores de inventario no sufre cierre de sesión ni alertas de abandono por apagado de pantalla.
- [ ] **CA-SES-05:** Durante un turno abierto de menos de `P_MAX_HORAS_TURNO`, el cambio de día a medianoche no invalida las solicitudes ni bloquea las ventas de los colaboradores.
- [ ] **CA-SES-06:** El cierre de sesión voluntario preserva intactas las colas de sincronización offline pendientes.
- [ ] **CA-SES-07:** Una aplicación del Administrador que permaneció abierta varios días con la sesión maestra inválida, al volver a primer plano, ¿conduce a la pantalla de ingreso con el mensaje de `RN-013-12` sin mostrar paneles en cero?
- [ ] **CA-SES-08:** Una aplicación de colaborador abierta de un día a otro sin turno nocturno abierto, al despertar, ¿conduce a la solicitud del Pase Diario sin mostrar datos del día anterior?
- [ ] **CA-SES-09:** Si el servidor informa un estado de acceso a la interfaz, ¿ese mismo criterio es el que el servidor aplica al autorizar las operaciones (el dispositivo nunca ve "vigente" y recibe un rechazo por falta de acceso)?
- [ ] **CA-SES-10:** Si varias operaciones son rechazadas a la vez por la misma pérdida de acceso, ¿el usuario ve un único aviso y una única transición?
- [ ] **CA-SES-11:** Una pestaña de la aplicación con pantalla visible y sin interacción del usuario durante `P_INTERVALO_VERIFICACION_SESION`, ¿sigue operando sin cierre alguno si el servidor considera vigente el acceso (compatibilidad con `RN-013-04`)?
- [ ] **CA-SES-12:** Un dispositivo sin conexión, ¿permanece operando en modo offline sin ser expulsado, y evalúa el acceso antes de sincronizar al reconectar?
- [ ] **CA-SES-13:** Tras una pérdida de acceso, ¿las ventas confirmadas pendientes de sincronización siguen intactas en la cola y el carrito en curso se descarta?
- [ ] **CA-SES-14:** Si la pérdida de acceso se detecta en una pestaña, ¿las demás pestañas del mismo dispositivo muestran el mismo estado sin consultar por su cuenta?
- [ ] **CA-SES-15:** ¿Se registra exactamente un evento de seguridad por cada pérdida de acceso detectada (no uno por petición rechazada)?
- [ ] **CA-SES-16:** El turno nocturno abierto con menos de `P_MAX_HORAS_TURNO`, al cruzar la medianoche, ¿sigue siendo evaluado como "Vigente" para el colaborador (`RN-013-07` no se degrada)?

---

## Decisiones de Alcance y Trade-offs (Enmienda v2.1)

| Decisión | Por qué (trade-off concreto) | Condición para revisarla |
|:---|:---|:---|
| El carrito en curso se descarta al perder el acceso. | Evita conservar en el dispositivo una intención de venta atada a una identidad ya no válida. El carrito no es un hecho económico; las ventas confirmadas sí se preservan. Costo: el colaborador puede perder una venta a medio armar. | Si se observan pérdidas de ventas en curso frecuentes o quejas reiteradas en operación, evaluar la re-autenticación en sitio sin perder el carrito. |
| Verificación periódica además de las basadas en eventos. | Cubre la pantalla visible sin ningún evento (nadie la toca, el dispositivo no duerme). Costo: tráfico mínimo y constante por dispositivo. | Si el consumo de solicitudes al servidor resulta material frente al límite del plan contratado. |
| No se introduce timeout por inactividad. | `RN-013-04` lo prohíbe: las tablets de tienda permanecen sin interacción durante labores físicas. | Solo con enmienda explícita de `RN-013-04` aprobada por el usuario. |

---

## Requisitos de Datos (Para Equipo Data)
1. **Consulta de estado de acceso:** el servidor DEBE exponer una única consulta de lectura, invocable por cualquier rol autenticado, que devuelva el estado de acceso (uno de los cuatro de `RN-013-10`), el motivo, el rol y la tienda asociada. DEBE reutilizar la misma resolución de tienda y de acceso ya usada para autorizar el resto de operaciones.
2. **Unificación de criterio:** la definición de "Acceso Vigente" de `RN-013-11` DEBE residir en un único lugar del servidor y ser consumida por la consulta anterior y por la autorización de las operaciones. El criterio de ventana móvil de 24 horas existente para informar el estado del pase DEBE desaparecer.
3. **Cobertura de roles:** la consulta DEBE cubrir al Administrador, que hoy no pasa por ninguna verificación de pase.
4. **Parámetro nuevo:** `P_INTERVALO_VERIFICACION_SESION` (propuesto: 5 minutos). Debe registrarse en el diccionario de parámetros.
5. **Evento de seguridad:** se reutiliza el tipo de evento de sesión expirada ya catalogado en la auditoría de seguridad; DEBE permitir registrar el motivo y el momento de detección.
