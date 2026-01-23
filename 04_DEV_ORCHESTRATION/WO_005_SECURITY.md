# Orden de Trabajo - Seguridad Diaria y Registro (WO-005)

**Referencia:** [Security Design Spec](file:///C:/Users/Windows%2011/.gemini/antigravity/brain/e9ce2044-00c8-4d68-a7f6-bc70f8eb618d/security_design_spec.md)
**Objetivo:** Implementar los flujos de "Sala de Espera Diaria" (Zero Trust) y "Registro con Verificación de Email".

---

## 🏗️ Fase 1: Protocolo de Seguridad Diaria (Zero Trust)

### Tarea 1.1: Componente Sala de Espera (`DailyWaitingRoom.vue`)
*   **Estado Git:** Creación de rama
    *   Comando: `git checkout -b feat/daily-waiting-room`
*   **Plan de Acción:**
    1.  Crear archivo `src/views/DailyWaitingRoom.vue`.
    2.  Implementar layout centrado con estado "Pending".
    3.  Agregar lógica de "Ping" (Botón con Rate Limit de 2 min).
    4.  Implementar polling simulado (mock) que revisa `authStore.deviceStatus`.
*   **Prompt para Antigravity:**
    ```markdown
    ## Prompt: Implementar DailyWaitingRoom
    
    ### Contexto
    Lee: `src/views/GatekeeperPending.vue` (como referencia visual) y `src/stores/auth.ts`.
    
    ### Objetivo
    Crear la vista `src/views/DailyWaitingRoom.vue` que reemplazará a GatekeeperPending.
    Esta vista es la "Sala de Espera" donde el empleado aguarda la aprobación diaria del Admin.
    
    ### Requisitos UI
    1.  **Estado Visual**: Icono de "Reloj de Arena" animado. Titulo: "Esperando autorización del día".
    2.  **Botón de Insistencia ("Ping")**:
        -   Texto: "¡Sigo aquí!"
        -   Comportamiento: Inicia DESHABILITADO. Se habilita tras 2 minutos.
        -   Al hacer click: Emite evento/log y se vuelve a deshabilitar por 5 minutos.
        -   Límite: Máximo 3 clicks. Al llegar al 3ro, bloquear permanentemente y mostrar mensaje "Contacte a su supervisor".
    3.  **Botón Salir**: Siempre habilitado, hace logout.
    
    ### Lógica
    -   Usar `setInterval` cada 15s para consultar `authStore.checkDailyApproval()` (Método que debes crear como stub en el store si no existe).
    -   Si la respuesta es `approved`, redirigir a `/`.
    ```

### Tarea 1.2: Modal de Aprobación Admin (`AdminInterruptionModal.vue`)
*   **Estado Git:** Continuar en `feat/daily-waiting-room`
*   **Plan de Acción:**
    1.  Crear componente `src/components/security/AdminInterruptionModal.vue`.
    2.  Usar `Teleport` al `body` para asegurar z-index máximo.
    3.  Conectar con `authStore` para detectar solicitudes entrantes (mockeadas por ahora).
*   **Prompt para Antigravity:**
    ```markdown
    ## Prompt: Implementar Modal de Interrupción Admin
    
    ### Contexto
    Necesitamos un mecanismo intrusivo para que el Admin apruebe accesos mientras usa la app.
    
    ### Objetivo
    Crear `src/components/security/AdminInterruptionModal.vue`.
    
    ### Requisitos
    1.  **Layout**: Modal centrado con fondo oscuro (backdrop-blur). Z-Index 9999.
    2.  **Contenido**:
        -   Foto/Icono del empleado.
        -   Texto: "Juan Pérez solicita ingreso".
        -   Timer: "Hace 2 min".
    3.  **Acciones**:
        -   [APROBAR]: Cierra modal, emite evento de aprobación.
        -   [IGNORAR]: Cierra modal temporalmente.
    
    ### Integración
    -   Módifical `App.vue` para incluir este componente globalmente. Solo debe mostrarse si `authStore.isAdmin` es true.
    ```

---

## 🏗️ Fase 2: Registro con Verificación (Magic Link)

### Tarea 2.1: Vista Verificación de Email (`CheckEmailView.vue`)
*   **Estado Git:** Nueva rama
    *   Comando: `git checkout -b feat/email-verification`
*   **Plan de Acción:**
    1.  Crear `src/views/CheckEmailView.vue`.
    2.  Vista estática informativa.
    3.  Botón de reenvío con cooldown.
*   **Prompt para Antigravity:**
    ```markdown
    ## Prompt: Implementar CheckEmailView
    
    ### Contexto
    El usuario acaba de registrarse y no debe entrar al Dashboard aún.
    
    ### Objetivo
    Crear `src/views/CheckEmailView.vue`.
    
    ### UI
    1.  Icono central de "Email Enviado".
    2.  Texto: "Revisa tu correo. Hemos enviado un enlace de confirmación."
    3.  Botón "Reenviar correo":
        -   Starts disabled (wait 60s).
        -   Countdown visible: "Reenviar en (59s)".
        -   Enabled after 60s.
    4.  Link "Volver al Login".
    ```

### Tarea 2.2: Refactor Router y Registro
*   **Plan de Acción:**
    1.  Modificar `router/index.ts` para agregar la ruta `/check-email`.
    2.  Modificar `RegisterStoreView.vue` para redirigir a `/check-email` en lugar de `/`.
*   **Prompt para Antigravity:**
    ```markdown
    ## Prompt: Conectar Flujo de Registro
    
    ### Objetivo
    1.  En `src/router/index.ts`, registrar la ruta `/check-email` (pública).
    2.  En `src/views/RegisterStoreView.vue` -> `handleSubmit`:
        -   Cambiar `router.push('/')` por `router.push('/check-email')`.
        -   Asegurar que NO se haga auto-login en el store, o que el usuario quede en estado `pending_verification`.
    ```
