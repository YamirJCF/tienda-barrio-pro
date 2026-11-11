# FRD-029: Consentimiento Legal Versionado

> **Estado:** 🟢 Aprobado — Validado contra `ARQ-002` (`POL-PRIV-01`, `POL-AUD-01`, `POL-AUD-02`, `POL-SEG-03`)

### Nombre de la Funcionalidad
Captura, Versionado y Prueba de Aceptación de Documentos Legales

#### Descripción
El sistema debe obtener y conservar la prueba de que cada titular aceptó, de forma libre, previa, expresa e informada, los documentos legales que le aplican: los Términos y Condiciones del servicio y la Política de Tratamiento de Datos Personales al registrar una tienda. Cada documento legal existe en versiones identificadas, y toda aceptación queda ligada a la versión exacta que el titular vio, con fecha y hora del servidor. Cuando una versión nueva cambia la finalidad del tratamiento o las obligaciones del contrato, el sistema exige una nueva aceptación; si el cambio es menor, solo informa. Adicionalmente, cuando en una tienda se da de alta a un cliente en la cartera de crédito (fiados), la acción de guardar el formulario actúa como confirmación y genera automáticamente un registro inmutable con el nombre del usuario que creó al cliente y la fecha y hora exacta del servidor, sin agregar casillas ni textos adicionales en la interfaz.

#### Alcance
| Incluido | Excluido (con su motivo) |
|---|---|
| Registro de tiendas nuevas: dos aceptaciones separadas (Términos y Política de Datos) | **Ventas de contado (Consumidor Final RST):** no recolectan datos personales en la tienda, por lo que no requieren registro de autorización |
| Alta de clientes en cartera de crédito (fiados): el botón de guardar actúa como clic de confirmación y genera un registro inmutable con el usuario creador y la fecha/hora del servidor (sin casillas ni leyendas extra) | **Tiendas ya registradas:** se regularizan automáticamente al publicarse la siguiente versión mayor (RN-13) |
| Versiones mayores y menores de los documentos legales administradas exclusivamente por el dueño de la plataforma | **Empleados y cajeros:** irán en un FRD propio |
| | **Derechos del titular y anonimización:** irán en el FRD-β |
| | **Redacción del texto legal:** es la vía documental (L-01 a L-03), no este FRD |

#### Alcance diferido (registro formal)
| Qué se difiere | Por qué | Cuándo se revisa |
|---|---|---|
| Aceptación de tiendas ya registradas (D-3) | No bloquear la operación actual de los tenderos | Se cierra automáticamente con la siguiente versión mayor publicada (RN-13). Debe revisarse antes si llega una queja o requerimiento de la SIC antes de esa publicación |
| Consentimiento de empleados y cajeros | Corresponde al vínculo laboral del tendero; añade complejidad sin riesgo inmediato | Cuando haya tiendas con empleados registrados en producción |
| Derechos del titular y anonimización | Dependen de que exista primero la base de consentimiento | Al aprobarse este FRD |

---

## Reglas de Negocio

### A. Registro de tienda nueva
1. **RN-01 (Doble aceptación):** El sistema DEBE exigir dos aceptaciones separadas antes de crear la cuenta: una para los Términos y Condiciones y otra para la Política de Tratamiento de Datos. Ambas son obligatorias, porque los datos de la cuenta son estrictamente necesarios para prestar el servicio.
2. **RN-02 (Sin marcado previo):** Las casillas de aceptación NO PUEDEN presentarse marcadas. Solo cuenta como aceptación la acción del propio titular.
3. **RN-03 (Información previa):** Antes de aceptar, el titular DEBE poder consultar el texto completo de la versión vigente de cada documento.
4. **RN-04 (Todo o nada):** Si la aceptación no se puede registrar, la cuenta NO PUEDE crearse y el titular DEBE ver un mensaje de error. No puede existir una cuenta nueva sin su prueba de aceptación.

### B. Prueba de la aceptación
5. **RN-05 (Contenido de la prueba):** Cada aceptación DEBE registrar el titular, el documento, la versión exacta, la fecha y hora del servidor, el origen (canal o dispositivo) y quién la obtuvo (el propio titular o el cajero).
6. **RN-06 (Inmutabilidad):** Una aceptación registrada NO PUEDE modificarse ni borrarse por ningún rol (alineado con POL-AUD-01). Aceptar de nuevo genera un registro adicional y no reemplaza al anterior.

### C. Versiones de los documentos
7. **RN-07 (Versión vigente única):** Cada documento legal DEBE tener una sola versión vigente a la vez.
8. **RN-08 (Texto congelado):** El texto de una versión publicada NO PUEDE modificarse. Cualquier cambio exige publicar una versión nueva.
9. **RN-09 (Autoridad exclusiva de publicación):** Solo el dueño de la plataforma PUEDE publicar versiones de los documentos legales y clasificarlas. Ningún rol de tienda, incluido el administrador, PUEDE publicar, clasificar ni alterar versiones. Al publicar, la versión DEBE clasificarse como **mayor** (cambia la finalidad del tratamiento, el responsable o las obligaciones del contrato) o **menor** (todo lo demás), y esa clasificación NO PUEDE cambiarse después.
10. **RN-10 (Versión mayor):** Ante una versión mayor, el sistema DEBE exigir la nueva aceptación en el siguiente inicio de sesión, antes de permitir operar. NO PUEDE interrumpir una venta que ya esté en curso.
11. **RN-11 (Versión menor):** Una versión menor NO PUEDE bloquear el acceso. El sistema DEBE informar del cambio de forma visible.
12. **RN-12 (Rechazo):** Si el titular no acepta una versión mayor, el sistema NO PUEDE permitirle operar, y DEBE indicarle el canal de atención para consultas o para solicitar el cierre de su cuenta.
13. **RN-13 (Regularización de tiendas preexistentes):** Las tiendas registradas antes de este FRD, que no tienen prueba de aceptación, DEBEN aceptar la siguiente versión mayor que se publique, con las mismas condiciones de RN-10 y RN-12.

### D. Cartera de clientes de crédito (Fiados)
14. **RN-14 (El botón Guardar como confirmación):** Al dar de alta a un cliente en la cartera de crédito (fiados), la acción de presionar el botón de guardado constituye el clic de confirmación del registro de datos (bajo el principio de conducta inequívoca al solicitar la apertura del crédito). El formulario NO PUEDE exigir casillas adicionales ni mostrar leyendas legales debajo del botón de guardado.
15. **RN-15 (Registro inmutable de creación del cliente):** Al guardar un cliente nuevo en la cartera de crédito, el sistema DEBE generar de forma automática, atómica e inmutable un registro probatorio que contenga: la tienda, el cliente creado, el identificador y nombre del usuario del sistema (cajero o administrador) que creó al cliente, y la fecha y hora exacta del servidor.
16. **RN-16 (Exención absoluta en ventas de contado / Consumidor Final RST):** En toda venta de contado ("Cobro Rápido" / Consumidor Final `222222222222`), el sistema NO PUEDE solicitar datos personales ni generar registros de autorización.

---

## Casos de Uso

**Caso A: Registro de tienda nueva con doble aceptación**
- **Actor:** Emprendedor (nuevo dueño de tienda).
- **Precondición:** No tiene cuenta registrada; existe una versión vigente de los Términos y de la Política de Datos.
- **Flujo Principal:**
  1. El usuario ingresa los datos de registro de su tienda.
  2. El sistema presenta dos casillas desmarcadas (Términos y Condiciones, y Política de Tratamiento de Datos), cada una con acceso al texto completo de su versión vigente.
  3. El usuario marca ambas casillas y solicita crear la cuenta.
  4. El sistema registra las dos aceptaciones con la fecha y hora del servidor y crea la cuenta en una sola operación.
- **Flujos Alternativos:**
  - **A1. Falta marcar alguna casilla:** El sistema impide enviar el formulario e indica cuál falta.
  - **A2. Fallo al guardar en el servidor:** La cuenta no se crea y el usuario ve un mensaje de error claro para reintentar (RN-04).
- **Postcondición:** Cuenta de tienda creada con sus dos pruebas inmutables de aceptación.

**Caso B: Publicación de una nueva versión legal**
- **Actor:** Dueño de la plataforma.
- **Precondición:** El nuevo documento legal está redactado.
- **Flujo Principal:**
  1. El dueño de la plataforma registra el nuevo texto legal y lo clasifica como versión **mayor** o **menor**.
  2. El dueño confirma la publicación.
  3. El sistema marca la nueva versión como la única vigente y conserva las anteriores en el historial sin modificarlas.
- **Flujos Alternativos:**
  - **B1. Intento de modificación por otro rol:** Si cualquier usuario o administrador de tienda intenta crear o editar versiones legales, el sistema rechaza la operación (RN-09).
- **Postcondición:** Nueva versión publicada y activa.

**Caso C: Aceptación de una versión mayor al iniciar sesión**
- **Actor:** Administrador de tienda (incluye tiendas antiguas regularizándose según RN-13).
- **Precondición:** El dueño de la plataforma publicó una versión **mayor** que la tienda aún no ha aceptado.
- **Flujo Principal:**
  1. El administrador inicia sesión.
  2. El sistema muestra el aviso de actualización con el texto de la nueva versión y la casilla de aceptación desmarcada.
  3. El administrador marca la casilla y confirma.
  4. El sistema guarda el nuevo registro de aceptación y permite el ingreso normal.
- **Flujos Alternativos:**
  - **C1. Publicación mientras la caja está operando:** Si hay un turno o venta en curso, el sistema no interrumpe la operación; exige la aceptación en el siguiente inicio de sesión (RN-10).
  - **C2. El administrador no acepta:** El sistema no permite acceder al panel operativo y muestra el canal de soporte para consultas o cierre de cuenta (RN-12).
- **Postcondición:** Tienda al día con la versión mayor vigente.

**Caso D: Aviso de versión menor**
- **Actor:** Administrador de tienda.
- **Precondición:** Se publicó una versión **menor**.
- **Flujo Principal:**
  1. El usuario inicia sesión.
  2. El sistema muestra un aviso informativo del cambio sin bloquear la pantalla ni exigir nueva casilla (RN-11).
- **Postcondición:** El usuario continúa operando sin interrupción.

**Caso E: Alta de un cliente nuevo en la cartera de fiados con registro de confirmación**
- **Actor:** Cajero / Administrador de tienda.
- **Precondición:** Un comprador solicita abrir crédito (fiado) entregando sus datos al operario de la tienda; el dispositivo tiene conexión.
- **Flujo Principal:**
  1. El cajero abre el formulario para crear al cliente de fiado, ingresa sus datos (nombre, cédula, teléfono, cupo) y presiona el botón **Guardar** (que actúa como clic de confirmación).
  2. El sistema crea al cliente y, en la misma operación atómica, genera un registro inmutable con el identificador y nombre del usuario que creó al cliente y la fecha y hora exacta del servidor.
- **Flujos Alternativos:**
  - **E1. Fallo al guardar en el servidor:** Si no se puede registrar el cliente o su traza de confirmación, la operación se revierte completa y el cajero ve el mensaje de error.
  - **E2. Sin conexión a internet:** El sistema informa que el alta de nuevos clientes requiere conexión en línea (conforme a `FRD-012-01`).
- **Postcondición:** Cliente creado en cartera junto con su registro probatorio inmutable de quién y cuándo lo dio de alta.

---

## Criterios de Aceptación
- [ ] **CA-029-01 (Doble casilla desmarcada en registro):** Al abrir el formulario de registro de una tienda nueva, las dos casillas (Términos y Condiciones, y Política de Tratamiento de Datos) se muestran desmarcadas por defecto y el registro queda bloqueado hasta que el usuario marque ambas manualmente.
- [ ] **CA-029-02 (Atomicidad de cuenta y aceptación):** Si falla el guardado de cualquiera de las dos aceptaciones en el servidor, la cuenta de la tienda no se crea y el usuario visualiza un mensaje de error explícito.
- [ ] **CA-029-03 (Inmutabilidad del registro de aceptación):** Ningún rol del sistema puede modificar ni eliminar un registro de aceptación o de confirmación existente; toda nueva aceptación crea una fila adicional conservando el historial previo.
- [ ] **CA-029-04 (Exclusividad del dueño de la plataforma):** Cualquier intento de un administrador de tienda o empleado por publicar, editar o clasificar versiones de documentos legales es rechazado por el servidor.
- [ ] **CA-029-05 (Inmutabilidad de versión publicada):** Una vez publicada una versión legal, el sistema impide alterar su texto o su clasificación (mayor/menor), exigiendo crear una versión nueva para cualquier cambio.
- [ ] **CA-029-06 (Bloqueo al iniciar sesión por versión mayor):** Cuando existe una versión mayor vigente no aceptada por la tienda (incluyendo tiendas antiguas sin aceptación previa), el sistema exige su aceptación en el siguiente inicio de sesión antes de permitir operar, sin interrumpir nunca un turno o venta que ya estuviera en curso.
- [ ] **CA-029-07 (Aviso no bloqueante en versión menor):** Cuando se publica una versión menor, el sistema informa el cambio al iniciar sesión sin exigir nueva casilla ni bloquear la operación.
- [ ] **CA-029-08 (Confirmación automática al guardar cliente de fiado):** El formulario de creación de cliente de crédito no muestra casillas de autorización ni leyendas adicionales debajo del botón Guardar, y al presionarlo genera de forma atómica e inmutable el registro con el nombre e identificador del usuario creador y la fecha/hora del servidor.
- [ ] **CA-029-09 (Ventas de contado libres de trazas de datos personales):** Las ventas de contado ("Cobro Rápido" / Consumidor Final RST) se procesan directamente sin solicitar datos personales ni generar registros de autorización.

---

## Requisitos de Datos (Para Equipo Data)

### 1. Catálogo de Versiones de Documentos Legales
Entidad administrada exclusivamente por el dueño de la plataforma que almacena los textos legales oficiales y su historial de versiones.
- **Identificador único de la versión.**
- **Tipo de documento legal:** Distingue entre *Términos y Condiciones del Servicio* y *Política de Tratamiento de Datos Personales (SaaS)*.
- **Código de versión:** Identificador legible de la versión (ej. `1.0`, `1.1`, `2.0`).
- **Clasificación del cambio:** Indica si la versión corresponde a un cambio **Mayor** (exige nueva aceptación) o **Menor** (solo informativo).
- **Contenido íntegro del documento:** El texto legal completo e inmutable que se presenta al titular.
- **Resumen de cambios:** Breve descripción en lenguaje claro de lo que cambió respecto a la versión anterior (para mostrar en los avisos de actualización).
- **Estado de vigencia:** Indica cuál es la única versión activa por cada tipo de documento.
- **Fecha y hora de publicación (Servidor):** Marca temporal exacta en que la versión entró en vigencia.

---

### 2. Registro Inmutable de Aceptaciones de Tiendas (Suscriptores del SaaS)
Bitácora probatoria de solo adición (*Append-Only*) que conserva cada aceptación otorgada por el propietario/administrador de una tienda frente a la plataforma.
- **Identificador único del registro de aceptación.**
- **Tienda vinculada:** Referencia al establecimiento comercial.
- **Usuario aceptante:** Referencia al propietario o administrador que ejecutó el acto de aceptación.
- **Versión del documento aceptado:** Referencia exacta a la versión del documento legal (Términos o Política de Datos) que estaba en pantalla.
- **Fecha y hora exacta de aceptación (Servidor):** Sello de tiempo generado exclusivamente por el servidor.
- **Metadatos de origen (Evidencia técnica):** Información del canal/dispositivo (como dirección de red o identificador de navegador/agente de usuario) capturada al momento de aceptar.

---

### 3. Registro Inmutable de Alta y Confirmación de Clientes de Crédito (Cartera de Fiados)
Bitácora probatoria de solo adición (*Append-Only*) generada automáticamente cuando se presiona el botón de guardar al crear un cliente de crédito.
- **Identificador único del registro.**
- **Tienda responsable:** Establecimiento comercial donde se registró al cliente.
- **Cliente de cartera creado:** Referencia al comprador dado de alta en el módulo de cuentas por cobrar (fiados).
- **Identificador del usuario creador:** Referencia al usuario del sistema (cajero o administrador) que ejecutó el guardado.
- **Nombre del usuario creador:** Nombre completo o visible del usuario del sistema en el momento de crear al cliente (conservado como instantánea histórica).
- **Fecha y hora exacta de creación (Servidor):** Sello de tiempo inmutable generado por el servidor al confirmar el guardado.
