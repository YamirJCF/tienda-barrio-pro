# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-002 / SDD-002.1)

> **Componente Auditado:** `frontend/src/views/RegisterStoreView.vue`, `frontend/src/views/LoginView.vue`, `frontend/src/components/security/ChangePasswordModal.vue`, `frontend/src/views/auth/UpdatePasswordView.vue`  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_002_REGISTRO_ADMIN.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_002_REGISTRO_ADMIN.md) (y [`SDD_002_1_CAMBIO_CONTRASENA.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_002_1_CAMBIO_CONTRASENA.md))  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Rutas Principales:**
  - `frontend/src/views/RegisterStoreView.vue` (`/register`)
  - `frontend/src/views/LoginView.vue` (`/login`)
  - `frontend/src/views/auth/UpdatePasswordView.vue` (`/update-password`)
- **Modales de Seguridad:**
  - `frontend/src/components/security/ChangePasswordModal.vue`
- **Capa de Datos:**
  - `frontend/src/data/repositories/authRepository.ts`
  - `frontend/src/stores/auth.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz (JSON Schemas)

### 5.1 Payload de Registro de Administrador (`authRepository.registerStore`)
- **Validación de Contraseña:** Mínimo 8 caracteres, al menos una mayúscula y un número (`pattern: ^(?=.*[A-Z])(?=.*\d).+$`).
- **Options Data:** `store_name` (2-50 chars) y `owner_name` (2-100 chars).
- **Respuesta:** `{ user, session: null }` (Requiere verificación de correo electrónico por Magic Link previa al acceso operativo - Política de Acceso Cero).

### 5.2 Cambio y Recuperación de Contraseña (`SDD_002.1`)
- **Challenge Previo:** Verificación de contraseña actual mediante `signInWithPassword(email, currentPassword)` antes de invocar `updateUser({ password })`.
- **Invalidación Masiva Selectiva (`POL-SEC-04`):** Invocación mandatoria de `signOut({ scope: 'others' })` inmediatamente posterior a la actualización de contraseña para purgar sesiones concurrentes en otros dispositivos.
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componentes identificados y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `registerStore`
- **Registro en GoTrue:**
  - Código real: En `RegisterStoreView.vue:120-125`, invoca `authStore.registerStore` enviando `storeName`, `ownerName`, `email`, `password`.
  - Validación de contraseña: En `RegisterStoreView.vue:53`, regex `/^(?=.*[A-Za-z])(?=.*\d).{8,}$/` (mínimo 8 caracteres con letra y número).
  - Resultado: **Presente y Conforme**.

### Operación: `changePassword` en perfil interno
- **Password Challenge:**
  - Código real: En `authRepository.ts:347-359`, ejecuta `signInWithPassword` verificando la contraseña actual. Si falla, retorna error `INVALID_CURRENT_PASSWORD`.
  - Mutación e Invalidación Selectiva:
  - Código real: En `authRepository.ts:362-377`, ejecuta `updateUser({ password })` y luego `signOut({ scope: 'others' })`.
  - Resultado: **Presente y Conforme**.

### Operación: `updatePasswordFromRecovery` en `UpdatePasswordView.vue`
- **Mutación de Contraseña:**
  - Código real: En `UpdatePasswordView.vue:103-105`, invoca `supabase.auth.updateUser({ password: password.value })`.
  - Invalidación Masiva Selectiva:
  - Código real: **Inexistente**. No llama a `signOut({ scope: 'others' })`.
  - Resultado: **Discrepancia Crítica**.

---

## Bloque 2b — Verificación de Límites Financieros y Lógica de Negocio

- **Consistencia en Política de Contraseñas (`POL-SEC-03`):**
  - Mientras `RegisterStoreView.vue:53` exige 8 caracteres con mayúscula y número, `ChangePasswordModal.vue:37` y `UpdatePasswordView.vue:92` solo validan `length >= 6`, permitiendo contraseñas débiles en los flujos de cambio o recuperación.
- **Acceso Cero Pre-Verificación (`RN-002-04`):**
  - Implementado: Tras registrar la tienda, redirige a `/auth/waiting-verification` hasta que el correo es confirmado.
- **Doble Sala de Espera en Login:**
  - En `LoginView.vue:189-191`, el login renderiza condicionalmente `GatekeeperPending.vue` (componente legado con polling de 30s) en vez de `DailyWaitingRoom.vue` (componente oficial Realtime de `SDD_001`).

---

## Bloque 3 — Verificación de Manejo de Errores

| Código de Error SDD | Estado en Código Actual | Tratamiento en UI | Conforme |
|---|---|---|---|
| `INVALID_CURRENT_PASSWORD` | Capturado en repositorio | Muestra "La contraseña actual es incorrecta" | ✅ Sí |
| `user_already_exists` | Mapeado en `RegisterStoreView.vue:129` | "Este correo ya está registrado. Por favor, inicia sesión" | ✅ Sí |
| `INVALID_STORE_PIN` | Implementado en BD | Sin modal dedicado de PIN maestro en frontend | 🟡 Parcial |

---

## Bloque 4 — Verificación de Estados de Carga e Interacción

- **Skeletons / Loading State:** `RegisterStoreView.vue` y `ChangePasswordModal.vue` utilizan `useAsyncAction` para prevenir doble clic y mostrar feedback de carga.
- **Bloqueo de Interacción:** `BaseButton` se deshabilita mientras la petición de registro o cambio de clave está en curso.

---

## Bloque 5 — Resumen de Discrepancias y Plan de Acción

### 5.1 Conteo Mecánico de Hallazgos (Regla 9.1: N = 4)
- **UX-1 (Severidad Alta):** Omisión de invalidación selectiva de sesiones en recuperación de contraseña. En `UpdatePasswordView.vue:103-112`, tras restablecer la contraseña vía Magic Link (`updateUser`), no se invoca `supabase.auth.signOut({ scope: 'others' })`, dejando activas las sesiones concurrentes de la cuenta administrativa en terminales ajenas o extraviadas, violando `POL-SEC-04` y `SDD_002_1: 0.1`.
- **UX-2 (Severidad Alta):** Inconsistencia y laxitud en la política de contraseñas. En `ChangePasswordModal.vue:37` y `UpdatePasswordView.vue:92`, la validación de nueva contraseña solo exige `length >= 6`, omitiendo la directiva global de seguridad `POL-SEC-03` y `SDD_002: 0.1` (mínimo 8 caracteres, al menos una mayúscula y un número) que sí se exige en `RegisterStoreView.vue:53`.
- **UX-3 (Severidad Media):** Duplicidad y desincronización de componentes de Sala de Espera en `LoginView.vue`. En `LoginView.vue:189-191`, el login renderiza condicionalmente el componente legado `GatekeeperPending.vue` (con polling agresivo de 30s) en lugar de utilizar la vista oficial `DailyWaitingRoom.vue` gobernada por Supabase Realtime y `daily_passes` de `SDD_001`.
- **UX-4 (Severidad Baja):** Verificación de PIN maestro de tienda sin componente dedicado para rescate presencial. `rpc_verify_store_pin` está definido en base de datos (`stores.store_pin_hash`), pero el frontend carece de un modal reutilizable de "PIN Maestro" para desbloquear ventas forzadas o arqueos fuera de horario presenciales por el dueño.

---

### 5.2 Auto-Chequeo Anti-Sesgo (Regla 9.4)
- **9.1 Invariante de Reconciliación:** $N = 4$ hallazgos documentados en el Bloque 5.1 y citados exactamente.
- **9.2 No-Fusión de Dimensiones:** El correcto funcionamiento de `changePassword` en el repositorio no mitiga la omisión de `signOut({ scope: 'others' })` en `UpdatePasswordView.vue` ni la debilidad del validador de contraseñas.
- **9.3 Cita de Fuentes:** Las discrepancias se sustentan en `UpdatePasswordView.vue:92, 103-112`, `ChangePasswordModal.vue:37`, `RegisterStoreView.vue:53` y `LoginView.vue:189-191`.
- **9.4 Veredicto:** 🟡 **CON OBSERVACIONES (4 discrepancias detectadas)**.

---

## 📌 Instrucción para el Orquestador (Etapa 4)

1. En `frontend/src/views/auth/UpdatePasswordView.vue`:
   - Homologar la validación de contraseña a la política estricta de 8 caracteres con mayúscula y número (`/^(?=.*[A-Za-z])(?=.*\d).{8,}$/`).
   - Invocar `await supabase.auth.signOut({ scope: 'others' })` inmediatamente después de actualizar la contraseña.
2. En `frontend/src/components/security/ChangePasswordModal.vue`:
   - Ajustar `newPasswordError` para exigir la misma expresión regular de fortaleza de contraseña.
3. En `frontend/src/views/LoginView.vue`:
   - Reemplazar el montaje de `GatekeeperPending.vue` por `DailyWaitingRoom.vue` o unificar en un único componente canónico de sala de espera.
