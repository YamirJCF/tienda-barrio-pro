# Orden de Trabajo - Unificación Control de Caja (WO-007)

**Referencia:** [QA Audit FRD-004](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/04_DEV_ORCHESTRATION/QA_AUDIT_FRD_004.md)
**Objetivo:** Resolver el conflicto de "Split Brain" implementando un modelo de **"Estado Centralizado, Seguridad Distribuida"** que cumpla estrictamente con `FRD_004_1` (Caso C: PIN Challenge Obligatorio).

---

## 🏗️ Fase 1: Arquitectura de Seguridad (Backend/Store)

### Tarea 1.1: Limpieza y Especialización de Stores
*   **Rama:** `fix/cash-control-unification`
*   **Objetivo:** Separar responsabilidades. `cashRegister` (Estado) vs `cashControl` (Seguridad).
*   **Instrucciones Técnicas:**
    1.  **`stores/cashRegister.ts` (La Bóveda):**
        -   Debe contener `state.isOpen`, `state.balance`, `state.transactions`.
        -   Debe tener métodos `openRegister(amount)` y `closeRegister(stats)`.
        -   **NO** debe contener lógica de PIN ni validación de intentos.
    2.  **`stores/cashControl.ts` (El Guardia):**
        -   Debe contener `state.pinHash`, `state.failedAttempts`, `state.lockedUntil`.
        -   Método `verifyPin(inputPin): boolean`.
            -   Si PIN correcto: retorna `true`, resetea intentos.
            -   Si PIN incorrecto: retorna `false`, incrementa intentos, bloquea si >= 3.
        -   **ELIMINAR** métodos `openCash`/`closeCash` de este store (causan duplicidad).

---

## 🏗️ Fase 2: Implementación UX/UI (Frontend)

### Tarea 2.1: Interfaz de Desafío (Pin Challenge)
*   **Rama:** `fix/cash-control-unification`
*   **Objetivo:** Bloquear las acciones críticas en la UI hasta superar el desafío.
*   **Prompt de Implementación:**
    ```markdown
    ## Prompt: Implementar PIN Challenge en Apertura/Cierre

    ### Contexto
    Archivo: `src/views/CashControlView.vue`
    Requerimiento: FRD-004-1 Caso C.

    ### Cambios en UI
    1.  **Componente Modal:**
        -   Reutilizar `PinSetupModal.vue` adaptándolo para recibir una prop `mode="challenge"` O crear un componente ligero `PinChallengeModal.vue`.
        -   Debe tener un keypad numérico y un indicadorde "puntos" (masked input).
    
    2.  **Intercepción de Eventos:**
        -   Al hacer clic en el botón "ABRIR TURNO" -> **Detener flujo**.
        -   Mostrar Modal: "Ingrese PIN de Caja para Autorizar Apertura".
        -   Al ingresar PIN -> Llamar `cashControlStore.verifyPin(pin)`.
        
    3.  **Manejo de Respuesta:**
        -   ✅ **Éxito:** Cerrar modal y ejecutar `cashRegisterStore.openRegister()`. Notificar éxito.
        -   🛑 **Error:** Mostrar "PIN Incorrecto" (shake animation). NO cerrar modal. NO ejecutar apertura.
        -   🔒 **Bloqueo:** Si `cashControlStore.isLocked`, mostrar contador regresivo y deshabilitar input.
    ```

### Tarea 2.2: Reflejo en AdminHub
*   **Objetivo:** Que el Admin vea el estado real.
*   **Acción:** Actualizar `AdminHubView.vue` para que el indicador de "Estado de Caja" se alimente de `cashRegisterStore.isOpen`.

---

## ✅ Criterios de Aceptación y Verificación
1.  Intentar abrir caja sin PIN -> **Imposible** (No ocurre nada o pide PIN).
2.  Ingresar PIN incorrecto 3 veces -> **Bloqueo de UI por 5 min**.
3.  Ingresar PIN correcto -> **Caja se abre y redirige**.
4.  Cierre de caja sigue el mismo protocolo estricto.
