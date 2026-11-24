# Contexto C8 — Acceso y Ciclo de Cuenta (Blindado — Regla 11)

> [!CAUTION]
> **SOLO CARTOGRAFÍA DE REFERENCIA — BLINDADO POR REGLA 11 ([`.agent/AGENTS.md`](../../../.agent/AGENTS.md#L93-L106))**  
> Todas las rutas, vistas y flujos de correo/autenticación de este contexto permanecen **INMUTABLES**. **Está prohibido modificarlos en Ola 2** o introducir cambios para pruebas locales sin autorización explícita del usuario y plan de validación end-to-end contra Supabase Cloud.

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Cubrir el ciclo externo y de entrada a la aplicación: inicio de sesión (Admin por correo/contraseña y Empleado por usuario/PIN), registro atómico de nueva tienda (`handle_new_user_atomic`), verificación de correo electrónico, recuperación/actualización de contraseña y sala de espera por aprobación inicial de dispositivo.

### 1.2 Inventario Cartográfico (`7 Rutas Blindadas + 1 Subvista Embebida`)

| Ruta | Vista (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Guard real en `router/index.ts` |
|---|---|---|---|---|
| `/login` | [`LoginView.vue`](../../../frontend/src/views/LoginView.vue) | `blindada` | `F` | `guest` |
| *(embebida en `/login`)* | [`GatekeeperPending.vue`](../../../frontend/src/views/GatekeeperPending.vue) | `blindada` | `F` | Renderizada en `LoginView.vue` (L12, L194) cuando `deviceApproved` es `pending`/`rejected` |
| `/register-store` | [`RegisterStoreView.vue`](../../../frontend/src/views/RegisterStoreView.vue) | `blindada` | `F` | `guest` *(excepción si autenticado sin `storeId`, L235)* |
| `/forgot-password` | [`ForgotPasswordView.vue`](../../../frontend/src/views/ForgotPasswordView.vue) | `blindada` | `F` | `guest` |
| `/check-email` | [`CheckEmailView.vue`](../../../frontend/src/views/CheckEmailView.vue) | `blindada` | `F` | `requiresAuth` |
| `/auth/waiting-verification` | [`WaitingRoomView.vue`](../../../frontend/src/views/auth/WaitingRoomView.vue) | `blindada` | `F` | `guest` (`requiresAuth: false`) |
| `/update-password` | [`UpdatePasswordView.vue`](../../../frontend/src/views/auth/UpdatePasswordView.vue) | `blindada` | `F` | `public` (`requiresAuth: false`) |
| `/:pathMatch(.*)*` | [`AuthCallbackView.vue`](../../../frontend/src/views/auth/AuthCallbackView.vue) | `blindada` | `F` | `public` (`requiresAuth: false`) |

---

## §2. Matriz ORCA (Referencia de Solo Lectura)

```text
Sesión de Usuario [Admin | Empleado]
  ├── Cuenta / Tienda (Registro atómico en servidor -> /register-store)
  ├── Verificación de Correo (/check-email | /auth/waiting-verification)
  └── Dispositivo Pendiente (GatekeeperPending.vue -> polling hasta aprobación)
        │
        └──(autenticado + aprobado + tienda)──> Shell Operativo (/)
```

- **Frontera con `C7`:** Una vez autenticado, si el dispositivo requiere pase diario recurrente ya en sesión activa, el router delega a `/daily-waiting-room` (`C7`); la espera inicial durante login vive embebida en `GatekeeperPending.vue` (`C8`).

---

## §3. Breadboard Actual de Referencia (Sin Cambios)

```text
[Acceso No Autenticado]
  ├── /login (LoginView.vue):
  │     ├── Admin: Correo + Contraseña ──> valida email confirmado (L242-261) ──> / o /auth/waiting-verification
  │     ├── Empleado: Usuario + PIN ──> si deviceApproved pending/rejected -> [GatekeeperPending.vue] (L194)
  │     └── Enlaces: /register-store | /forgot-password
  ├── /register-store (RegisterStoreView.vue):
  │     └── Alta atómica handle_new_user_atomic ──> /check-email o /auth/waiting-verification
  └── /forgot-password ──(SMTP Cloud)──> /:pathMatch(.*)* (AuthCallbackView) ──> /update-password ──> /login
```

---

## §4. Matriz de Señalización de Referencia (`N1–N5`)

| Nivel | Comportamiento Actual Registrado | Nota de Blindaje |
|---|---|---|
| **N1 — Inline** | Validaciones de formulario de credenciales, registro y nueva contraseña. | Solo referencia cartográfica (Regla 11). |
| **N2 — Toast Efímero** | `CheckEmailView.vue` (L11) y `WaitingRoomView.vue` (L126) usan `vue-toastification` (congelado en `baselineDebt.legacyToastImportsAllowed`). | No migrar en Ola 2 sin autorización explícita sobre `C8`. |
| **N3 / N5 — Estado y Compuertas** | Pantallas completas `Arquetipo F` (`GatekeeperPending`, `CheckEmailView`, `WaitingRoomView`). | Inmutables salvo autorización expresa. |

---

## §5. Deuda Diferida Documentada (Regla 7 — Trade-off y Condición de Revisión)

> **Decisión arquitectónica (Regla 7 + Regla 11):** Ningún ítem de `C8` entra a la consolidación de Ola 2. Se registra formalmente como deuda diferida deliberada:

| ID | Qué se decidió diferir | Por qué (Trade-off concreto) | Condición futura de revisión |
|---|---|---|---|
| **C8-D1** | Mantener la coexistencia de `/check-email` (`CheckEmailView.vue`) y `/auth/waiting-verification` (`WaitingRoomView.vue`), así como sus importaciones de `vue-toastification` congeladas en `baselineDebt` (`CheckEmailView.vue` L11, `WaitingRoomView.vue` L126). | **Estabilidad de Auth/SMTP en producción sobre limpieza de rutas:** unificar vistas de verificación o alterar toasts sin pruebas SMTP reales en Supabase Cloud introduce riesgo de regresión en alta de cuentas y confirmación de correo (`Regla 11`). | Abrir ventana dedicada únicamente con **autorización explícita del usuario** y plan de pruebas E2E ejecutado contra Supabase Cloud real. |
| **C8-D2** | Conservar temporalmente los emojis (`🔒`, `📱`, `🚫`) en el mapa de mensajes amigables de [`LoginView.vue`](../../../frontend/src/views/LoginView.vue#L47-L49). | **Aislamiento de flujo crítico de acceso sobre alineación estética menor (`DESIGN.md`):** evitar cualquier toque accidental al componente que alberga login y `GatekeeperPending.vue`. | Limpiar únicamente si el usuario autoriza expresamente tocar `LoginView.vue` en una intervención específica de `C8`. |
