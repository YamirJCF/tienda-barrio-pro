# Orden de Trabajo - Refactor de Seguridad Diaria LOCAL (WO-008)

**Contexto:** Fase 3 (Frontend First). El backend Supabase aún no está activo.
**Objetivo:** Implementar la lógica de "Pase Diario" **simulada robustamente en el cliente** para validar el flujo UX y reglas de negocio antes de la integración real.

---

## 🏗️ Fase 1: Arquitectura "Local Daily Pass" (Store)

### Tarea 1.1: Refactorizar `auth.ts` -> `dailyAccessStatus`
*   **Estado:** Transformar la variable booleana simple en una máquina de estados almacenada en `localStorage`.
*   **Estructura de Datos (Mock Local):**
    ```typescript
    interface DailyPassState {
      status: 'pending' | 'approved' | 'rejected' | 'expired';
      lastApprovedAt: string; // ISO Date
      fingerprint: string;
      requestedAt: string;
    }
    ```
*   **Lógica de Expiración (Simulación Backend):**
    -   Al cargar la app, leer `lastApprovedAt`.
    -   Si `fecha(lastApprovedAt) !== fecha(hoy)`, cambiar estado a `expired` automáticamente.

### Tarea 1.2: Fingerprinting Local
*   **Acción:** Implementar función `getDeviceFingerprint()` usando `navigator.userAgent` y pantalla.
*   **Uso:** Guardar este fingerprint junto con el estado del pase para simular la validación de contexto.

---

## 🏗️ Fase 2: Router & Guards

### Tarea 2.1: Guard Estricto "Sala de Espera"
*   **Lógica del Router:**
    -   Si `isAuthenticated` ES true Y `dailyAccessStatus` NO ES 'approved' -> Redirigir forzosamente a `/daily-waiting-room`.
    -   **Excepción:** Rutas públicas (`/login`) y la propia `/daily-waiting-room`.
*   **Prueba:** Cambiar la fecha del ordenador manualmente debería bloquear el acceso al recargar.

---

## 🏗️ Fase 3: Simulación de Aprobación (Dual Identity)

Dado que no hay backend, el mismo navegador actuará como "Empleado" y "Admin" simultáneamente para la demo.

### Tarea 3.1: Interfaz de Espera Reactiva (`DailyWaitingRoom.vue`)
*   **Polling Simulado:** El componente debe consultar el store cada 5s.
*   **Acción:** Botón "Solicitar Acceso" cambia estado a `pending` y guarda timestamp.

### Tarea 3.2: Interrupción Admin (`AdminInterruptionModal.vue`)
*   **Watcher:** El modal debe "escuchar" cambios en el store (simulando que recibió un socket).
*   **Trigger:** Si el store cambia a `pending` y el usuario actual es Admin, mostrar el modal inmediatamente.
*   **Acción "Aprobar":** Cambia el estado en el store a `approved` y actualiza `lastApprovedAt` a HOY.

---

## ✅ Criterios de Aceptación (Entorno Local)
1.  **Expiración:** Al cambiar la fecha del sistema, el usuario pierde acceso.
2.  **Bloqueo:** Un usuario en estado `pending` NO puede acceder a `/dashboard` escribiendo la URL.
3.  **Flujo:** Solicitar acceso -> Admin (simulado) Aprueba -> Usuario entra automáticamente.
4.  **Aislamiento:** La lógica debe estar encapsulada en `auth.ts` para que mañana solo cambiemos la llamada `localStorage` por `supabase.rpc`.
