# FRD-013: Gestión de Sesiones

> **Módulo:** Autenticación / Sesiones  
> **Versión:** 2.0  
> **Fecha:** 2026-10-24  
> **Estado:** Borrador Formalizado  
> **Políticas Rectoras:** `POL-SEG-02`, `POL-SEG-03`, `POL-LOG-01`, `POL-AUD-02`

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

---

## Criterios de Aceptación
- [ ] **CA-SES-01:** El sistema rechaza el intento de acceso si se excede el límite de `P_MAX_EMPLOYEES_PER_STORE` colaboradores más 1 Administrador.
- [ ] **CA-SES-02:** Abrir la app al día siguiente sin un turno nocturno abierto conduce al colaborador a la solicitud del pase del día, sin cargar pantallas operativas en caché.
- [ ] **CA-SES-03:** El cierre de caja ordinario o forzado NO expira los pases diarios de los colaboradores ni bloquea módulos no monetarios permitidos.
- [ ] **CA-SES-04:** Un colaborador en labores de inventario no sufre cierre de sesión ni alertas de abandono por apagado de pantalla.
- [ ] **CA-SES-05:** Durante un turno abierto de menos de `P_MAX_HORAS_TURNO`, el cambio de día a medianoche no invalida las solicitudes ni bloquea las ventas de los colaboradores.
- [ ] **CA-SES-06:** El cierre de sesión voluntario preserva intactas las colas de sincronización offline pendientes.
