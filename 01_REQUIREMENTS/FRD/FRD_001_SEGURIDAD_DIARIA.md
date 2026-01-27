# FRD-001: Protocolo de Seguridad en Capas ("Zero Trust Daily")

### Nombre de la Funcionalidad
Autenticación de Empleados con Validación de Dispositivo y Pase Diario

#### Descripción
Implementación de un sistema de seguridad basado en Autorización Diaria para el acceso de empleados. El sistema confía en las credenciales del usuario (PIN) pero requiere una aprobación explícita del Administrador cada día para habilitar la operatividad. Se define el comportamiento de la "Sala de Espera".

---

## Reglas de Negocio

1. **Principio de Cero Confianza:**
    - Todo intento de login comienza en estado `PENDIENTE`.
    - Ningún empleado puede operar hasta recibir aprobación del día.

2. **Aprobación Diaria Obligatoria:**
    - El Admin DEBE aprobar explícitamente el ingreso de cada empleado cada día.
    - No existe aprobación automática.

3. **Expiración del Pase Diario:**
    - El pase diario expira cuando se **cierra la caja** del turno.
    - Al cerrar caja, TODOS los pases diarios activos se invalidan automáticamente.
    - Para el siguiente turno, cada empleado DEBE solicitar un nuevo pase.

4. **Sala de Espera Activa:**
    - Si no hay pase diario, el empleado queda en pantalla de espera.
    - **Límite de Insistencia:** El empleado puede reenviar la notificación al Admin máximo **3 veces**.
    - Tras 3 intentos sin respuesta, el sistema bloquea la solicitud y muestra: "Contacte a su supervisor por teléfono".

5. **Huella de Dispositivo (Contexto):**
    - Cada solicitud incluye una identificación del dispositivo para que el Admin sepa desde dónde se pide el acceso.
    - Objetivo INFORMATIVO: No bloquea dispositivos, solo informa al Admin.
    - Ejemplo: "Juan pide entrar desde Dispositivo Nuevo" vs "Juan pide entrar desde Caja Samsung".

6. **Separación de Poderes:**
    - Entrar al sistema (Login con Pase) ≠ Abrir Caja.
    - El pase diario permite ver el sistema.
    - El permiso `canOpenCloseCash` + PIN de caja permite operar el dinero.

---

## Casos de Uso

**Caso A: Flujo Diario Estándar**
- **Actor:** Empleado
- **Precondición:** Credenciales válidas, sin pase diario activo.
- **Flujo Principal:**
    1. Empleado ingresa su alias numérico y PIN.
    2. Sistema valida credenciales.
    3. Si credenciales inválidas → Error, no continúa.
    4. Si credenciales válidas pero SIN pase diario → Pantalla "Esperando autorización del día...".
    5. Sistema envía alerta al Admin: "[Nombre] solicita acceso desde [Dispositivo]".
    6. Admin aprueba el acceso.
    7. Pantalla del empleado se desbloquea automáticamente.
    8. Empleado ve menú principal según sus permisos.
- **Postcondición:** Empleado con pase diario activo, puede operar según permisos.

**Caso B: Insistencia (Admin No Responde)**
- **Actor:** Empleado en Sala de Espera
- **Precondición:** Esperando aprobación por más de 2 minutos.
- **Flujo Principal:**
    1. Empleado espera en Sala de Espera.
    2. Botón "Reenviar Alerta" se habilita tras 2 minutos.
    3. Empleado pulsa (Intento 1/3) → Admin recibe nueva notificación.
    4. Si no hay respuesta tras 5 minutos → Empleado puede pulsar de nuevo (Intento 2/3).
    5. Si no hay respuesta → Empleado pulsa (Intento 3/3).
    6. Si no hay respuesta → Sistema muestra: "Límite de intentos alcanzado. Llame al administrador".
- **Postcondición:** Solicitud bloqueada, empleado debe contactar por otro medio.

**Caso C: Aprobación Remota (Admin fuera de tienda)**
- **Actor:** Administrador
- **Precondición:** Empleado solicitando acceso.
- **Flujo Principal:**
    1. Sistema envía correo electrónico al Admin: "[Nombre] solicita acceso a [Tienda]".
    2. Correo contiene botón "Aprobar Acceso".
    3. Admin pulsa el botón desde su celular (sin necesidad de estar logueado en la app).
    4. Sistema procesa la aprobación y desbloquea al empleado.
    5. Admin recibe confirmación: "Acceso concedido a [Nombre]".
- **Postcondición:** Empleado autorizado remotamente.

**Caso D: Aprobación en Sitio (Admin logueado)**
- **Actor:** Administrador logueado en Dashboard
- **Precondición:** Admin usando el sistema activamente.
- **Flujo Principal:**
    1. Sistema detecta sesión activa del Admin.
    2. Se superpone un modal de alerta en la pantalla del Admin.
    3. Modal muestra: "[Nombre] solicita acceso desde [Dispositivo]. ¿Aprobar?"
    4. Opciones: [Aprobar] | [Rechazar] | [Ignorar]
    5. Si Admin aprueba → Modal desaparece, empleado entra.
    6. Si Admin rechaza → Empleado ve mensaje "Acceso denegado".
- **Postcondición:** Solicitud procesada según decisión del Admin.

---

## Requisitos de Datos (Para Equipo Data)

**Entidad Pase Diario:**
- Identificador único
- Relación con Empleado
- Fecha del pase
- Estado: pendiente/aprobado/rechazado/expirado
- Identificador de dispositivo (huella)
- Contador de reintentos
- Timestamps de solicitud y resolución

---

## Criterios de Aceptación

- [ ] La interfaz de Login no permite operar hasta recibir aprobación del día.
- [ ] El contador de reintentos (máximo 3) se respeta estrictamente.
- [ ] El pase diario expira automáticamente al cerrar la caja.
- [ ] El sistema envía email con enlace de aprobación funcional.
- [ ] Si el Admin está online, la solicitud interrumpe su flujo de trabajo con un modal.
- [ ] El identificador de dispositivo se registra y se muestra al Admin antes de aprobar.
