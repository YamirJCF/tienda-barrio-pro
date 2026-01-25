# FRD-001: Protocolo de Seguridad en Capas ("Zero Trust Daily")


### Nombre de la Funcionalidad
Autenticación de Empleados con Validación de Dispositivo y Pase Diario

#### Descripción
Implementación de un sistema de seguridad basado en **Autorización Diaria** para el acceso de empleados. El sistema confía en las credenciales del usuario (PIN) pero requiere una **aprobación explícita del Administrador cada día** para habilitar la operatividad ("Pase Diario"). Se define también el comportamiento de la "Sala de Espera".

#### Arquitectura de Seguridad
**Mecanismo Único: Pase Diario (Operativa)**
*   Valida: "¿Tiene permiso para trabajar HOY?"
*   Frecuencia: Diaria (expira a las 24h o al cambio de turno).
*   Valida: "¿Tiene permiso para trabajar HOY?"
*   Frecuencia: Diaria (expira a las 24h o al cambio de turno).
*   Método: Token de sesión vinculado al turno/día.
*   **Contexto (Fingerprint):** Cada solicitud incluye una "Huella de Dispositivo" para que el Admin sepa desde dónde se pide el acceso.

#### Algoritmo de Fingerprint (Referencia Técnica)
Se utilizará una huella ligera basada en navegador (User Agent + Screen + Timezone) hasheada con SHA-256.
*   *Objetivo:* No es bloquear dispositivos desconocidos automáticamente (eso sería muy rígido), sino **informar al Admin** ("Juan pide entrar desde Dispositivo Nuevo" vs "Juan pide entrar desde Caja Samsung").

#### Reglas de Negocio
1.  **Principio de Cero Confianza:** Todo intento de login comienza en estado `PENDING`.
2.  **Aprobación Diaria:** El Admin debe aprobar explícitamente el ingreso de cada empleado cada día.
    *   *Excepción:* Si el Admin configura "Aprobación Automática" para ciertos empleados de alta confianza (Opcional futuro).
3.  **Sala de Espera Activa:**
    *   Si no hay pase diario, el empleado queda en pantalla de espera.
    *   **Rate Limiting de Insistencia:** El empleado puede reenviar la notificación ("¡Sigo aquí!") máximo **3 veces**.
    *   **Abandono de Sistema:** Tras 3 intentos fallidos, el sistema bloquea la solicitud y muestra: *"Contacte a su supervisor por teléfono"*.
4.  **Separación de Poderes:** Entrar al sistema (Login) ≠ Abrir Caja.
    *   El pase diario permite *ver* el sistema.
    *   El permiso `canOpenCloseCash` permite *tocar* el dinero.

#### Casos de Uso

**Caso A: Flujo Diario Estándar**
- **Actor:** Empleado
- **Precondición:** Ninguna (solo credenciales válidas).
- **Flujo:**
    1.  Empleado ingresa PIN.
    2.  Sistema detecta credenciales válidas pero **SIN Pase Diario**.
    3.  Pantalla: *"Esperando autorización del día..."*.
    4.  Admin (en su casa) recibe alerta: *"Juan intenta entrar"*.
    5.  Admin pulsa *"Permitir acceso hoy"*.
    6.  Pantalla del empleado se desbloquea automáticamente (Polling/WebSocket).
    7.  Empleado ve menú principal.

**Caso B: La "Insistencia" (Admin dormido)**
- **Flujo Alternativo:**
    1.  Empleado espera 2 min en Sala de Espera.
    2.  No pasa nada. Botón *"Reenviar Alerta"* se habilita.
    3.  Empleado pulsa (Intento 1/3). Admin recibe nueva notificación sonora.
    4.  Sigue sin respuesta. Pasan 5 min. Empleado pulsa de nuevo (Intento 2/3).
    5.  Si llega a 3/3, sistema muestra: *"Límite de intentos alcanzado. Llame al administrador"*.

**Caso C1: Admin Remoto (Vía Email - "Zero-Touch")**
- **Actor:** Administrador (Fuera de la tienda)
- **Precondición:** Empleado solicita acceso.
- **Flujo:**
    1.  Sistema envía correo inmediato: *"Juan solicita acceso a Caja 1"*.
    2.  Correo contiene botón: **"✅ Aprobar Acceso (Magic Link)"**.
    3.  Admin pulsa el botón desde su celular (incluso sin estar logueado en la App).
    4.  Sistema procesa token del link, aprueba al empleado y muestra página web simple: *"Acceso concedido a Juan"*.

**Caso C2: Admin en Sitio (Interrupción Activa)**
- **Actor:** Administrador (Logueado en Dashboard)
- **Precondición:** Admin está usando el sistema.
- **Flujo:**
    1.  Sistema detecta sesión activa del Admin (WebSocket/Polling).
    2.  **Acción Bloqueante:** Se superpone un Modal de Alerta en la pantalla del Admin.
    3.  Contenido: *"Juan está en la puerta. ¿Deseas aprobar su ingreso?"*.
    4.  Botones: [Aprobar] | [Rechazar] | [Ignorar].
    5.  Admin pulsa [Aprobar] -> Modal desaparece y Empleado entra.

#### Criterios de Aceptación
- [ ] La tabla `daily_access_logs` registra cada solicitud con fecha.
- [ ] La interfaz de Login no permite operar hasta recibir el flag `approved_today`.
- [ ] El contador de "Re-pings" (intentos de llamada) se resetea solo al cambiar de día.
- [ ] **Email Activo:** El sistema envía correos con Magic Link válido (token firmado) para aprobación sin login.
- [ ] **Modal Intrusivo:** Si el Admin está online, la solicitud DEBE interrumpir su flujo de trabajo (Modal z-index máximo).
- [ ] **Auditoría de Dispositivo:** El sistema registra el `device_fingerprint` en la tabla `daily_passes` y se muestra al Admin antes de aprobar.

---

## Lista de Tareas de Alto Nivel
1.  [ ] Crear tabla `daily_passes` en Supabase (empleado_id, fecha, estado).
2.  [ ] Modificar `loginEmpleado` RPC para verificar existencia de pase diario.
3.  [ ] Implementar UI de "Sala de Espera" con botón de reintento limitado.
4.  [ ] Crear vista de Admin "Control de Asistencia Diario".

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| **Supabase** | Nueva tabla `daily_passes` y triggers de limpieza. |
| **AuthStore** | Nueva lógica para consultar estado del pase (`pollAccessStatus`). |
| **LoginView** | Nueva pantalla intermedia "WaitingRoom" entre el PIN y el Dashboard. |
