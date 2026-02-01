# Auditoría de Cumplimiento: FRD-004 Control de Caja & PIN

**Estado General:** 🔴 NO CUMPLE (Fallo de Seguridad Crítico)
**Fecha:** 2026-01-23
**Versión de Código Analizada:** `main`
**Documentos Base:** `FRD_004_CONTROL_DE_CAJA.md`, `FRD_004_1_GESTION_PIN_CAJA.md`

## 🚨 Hallazgos Críticos de Seguridad

### 1. Violación Directa de FRD-004-1 (Caso C: Challenge)
*   **Requerimiento:** El documento `FRD_004_1` establece explícitamente: *"Modal pide: 'PIN de Caja'... Admin digita código 6 dígitos... Sistema valida hash."*
*   **Realidad:** El sistema actual permite abrir y cerrar caja **SIN PIN**. El botón llama directamente a la función operativa, omitiendo por completo la capa de seguridad.
*   **Impacto:** Cualquiera con acceso al dispositivo (incluso si la sesión web quedó abierta) puede cerrar turno o abrir caja sin una "segunda firma" de seguridad.

### 2. "Split Brain" Arquitectónico
Se confirma la existencia de dos lógicas de caja desconectadas:
*   **Lógica Segura (`cashControl.ts`):** Tiene toda la lógica de hashing, intentos y bloqueo, pero NO está conectada a la vista operativa.
*   **Lógica Operativa (`cashRegister.ts`):** Maneja el dinero y la sesión, pero NO tiene ninguna protección por PIN.

## ⚠️ Otros Hallazgos

### 3. Inconsistencia de Persistencia
*   La configuración de PIN se guarda en una clave de LocalStorage (`tienda_pro:cash_events`).
*   El estado de la caja se guarda en otra clave (`tienda-cash-register`).
*   Esto permite estados inconsistentes (ej: Tener PIN configurado pero caja "abierta" en una sesión fantasma).

## 🛑 Plan de Acción Requerido (Bloqueante)

Para cumplir con el estándar estricto de seguridad definido por el User, se debe ejecutar la **WO-007** con el siguiente enfoque MANDATORIO:

1.  **Arquitectura "Centralized State, Distributed Security":**
    *   `cashRegister.ts` -> Única fuente de verdad para el estado (Abierto/Cerrado, Saldos).
    *   `cashControl.ts` -> Único validador de seguridad (Verificar PIN).
    *   **Prohibido:** Que `cashRegister.ts` exponga métodos que modifiquen estado crítico sin pasar por una validación de seguridad (aunque esto se manejará en la UI/Controller).

2.  **UI de Desafío Obligatorio:**
    *   La vista `CashControlView` **DEBE** instanciar un Modal de PIN antes de llamar a `openRegister` o `closeRegister`.
    *   Flujo: `Click` -> `PinModal.show()` -> `User Inputs PIN` -> `cashControl.verify(PIN)` -> `If OK: cashRegister.open()`.
