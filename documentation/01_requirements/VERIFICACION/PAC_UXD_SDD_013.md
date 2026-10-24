# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-013)

> **Componente Auditado:** `frontend/src/views/LoginView.vue` (junto con `frontend/src/views/GatekeeperPending.vue` y `frontend/src/stores/auth.ts`)  
> **SDD Fuente:** `documentation/01_requirements/SDD/SDD_013_GESTION_SESIONES.md`  
> **Fecha:** 2026-10-24  
> **Carácter:** Cartografía consultiva no bloqueante bajo metodología oficial PAC-UXD.

---

## Bloque 1 — Identificación

### B1.1 — Declaración de Componente Auditado
- **Vistas Principales:** [`frontend/src/views/LoginView.vue`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/views/LoginView.vue) y [`frontend/src/views/GatekeeperPending.vue`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/views/GatekeeperPending.vue)
- **Store de Autenticación y Estado:** [`frontend/src/stores/auth.ts`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/stores/auth.ts)
- **Repositorio de Invocación:** [`frontend/src/data/repositories/authRepository.ts`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/data/repositories/authRepository.ts)

### B1.2 — Cita Literal de la Sección 5 (Contrato de Interfaz) de SDD-013

```json
{
  "request_employee_access": {
    "p_username": "TEXT (Obligatorio, alias numérico del colaborador)",
    "p_pin": "TEXT (Obligatorio, PIN numérico de 4 dígitos)",
    "p_device_fingerprint": "TEXT (Opcional, huella legible del dispositivo)"
  },
  "check_my_pass_status": {
    "p_pass_id": "UUID (Obligatorio, identificador de la solicitud de pase)"
  },
  "rpc_gestionar_dispositivo": {
    "p_pass_id": "UUID (Obligatorio)",
    "p_action": "TEXT ('approve' | 'reject' | 'revoke')"
  },
  "toggle_empleado_activo": {
    "p_employee_id": "UUID (Obligatorio)",
    "p_new_status": "BOOLEAN"
  }
}
```

### B1.3 — CHECKPOINT BLOQUE 1
✅ Bloque 1 completado. Vistas, Store y Repositorio mapeados; contratos canónicos de Sección 5 citados literalmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

Inspección en `LoginView.vue` (líneas 135-140) y `authRepository.ts` (líneas 546-560):

```typescript
const result = await authRepository.requestEmployeeAccess(
  username.value,
  password.value,
  fingerprint
);
```

### B2.4 / B2.5 — Checkpoint por Operación y Campo

| Operación / Campo | Estado en Código Frontend | Cita Textual de Línea / Observación |
|---|---|---|
| `request_employee_access.p_username` | ✅ Presente | `authRepository.ts` L570: `p_username: username` |
| `request_employee_access.p_pin` | ✅ Presente | `authRepository.ts` L571: `p_pin: pin` |
| `request_employee_access.p_device_fingerprint` | ✅ Presente | `authRepository.ts` L572: `p_device_fingerprint: deviceFingerprint` |
| `check_my_pass_status.p_pass_id` | ✅ Presente | `GatekeeperPending.vue` L83 & `authRepository.ts` L622: `p_pass_id: passId` |
| `rpc_gestionar_dispositivo.p_pass_id` | ✅ Presente | `authRepository.ts` L525: `p_pass_id: passId` |
| `rpc_gestionar_dispositivo.p_action` | ✅ Presente | `authRepository.ts` L526: `p_action: action` |
| `toggle_empleado_activo.p_employee_id` | ✅ Presente | `teamStore.ts` / `authRepository.ts`: `p_employee_id: id` |
| `toggle_empleado_activo.p_new_status` | ✅ Presente | `teamStore.ts` / `authRepository.ts`: `p_new_status: status` |

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 — Búsqueda explícita de cómputos o bypass de permisos en cliente:**
  - `LoginView.vue` y `GatekeeperPending.vue` no deciden la concesión del pase; esperan estrictamente la respuesta del servidor (`result.status === 'approved'`).
  - La verificación del hash de PIN (`crypt(p_pin, v_employee.pin_hash)`) y la expiración de fecha se ejecutan exclusivamente en PostgreSQL.
- **B2.7 — CHECKPOINT:** ✅ Backend Authority respetada plenamente.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 — Estados del Ciclo de Vida de SDD-013
1. `Inactiva`
2. `PendienteAprobacion`
3. `Activa`
4. `Rechazada`
5. `RelevoJornada`
6. `RevocadaRemota`
7. `Desactivada`

### B3.9 — Mapeo Visual en Componentes
- **`Inactiva`:** `LoginView.vue` (líneas 186-220): Renderiza formulario de ingreso con selector progresivo (`identity` -> `credential`).
- **`PendienteAprobacion`:** `GatekeeperPending.vue` (líneas 37-38 y 49): Muestra `Hourglass` animado, color ámbar (`text-amber-500`) y mensaje: *"Tu dispositivo está esperando aprobación del Administrador"*.
- **`Activa`:** `GatekeeperPending.vue` (líneas 87-99): Al detectar `status === 'approved'`, invoca `authStore.loginAsEmployee` y navega a `/` desbloqueando el dashboard.
- **`Rechazada`:** `GatekeeperPending.vue` (líneas 39-40 y 51): Renderiza `Ban` icono, color rojo (`text-red-500`) y mensaje: *"Acceso denegado. Este dispositivo no está autorizado."*
- **`RelevoJornada`:** `authStore.ts` (líneas 436-442): Al iniciar con fecha anterior sin pase de hoy, `deviceApproved` computa `'expired'`, conduciendo automáticamente a la pantalla de solicitud de pase sin mostrar datos en caché.
- **`RevocadaRemota` / `Desactivada`:** `useSessionHeartbeat.ts` / interceptor global: Captura error 403 / 401 y expulsa al usuario a login con el mensaje correspondiente.

### B3.10 / B3.11 — CHECKPOINT
✅ Todos los 7 estados del ciclo de vida tienen representación diferenciada. No existen estados ambiguos ni caídas silenciosas a "$0" o pantallas vacías.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12:** SDD-013 es un módulo de gestión de identidades y sesiones. No procesa ni renderiza montos monetarios directos.
- **B4.13 — CHECKPOINT:** ✅ Conforme (SPEC-011 no aplica directamente a esta interfaz).

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 / B5.15:**
  - Separación Admin vs. Colaborador implementada en `LoginView.vue` (línea 34): `const isAdminLogin = computed(() => username.value.includes('@'))`.
  - Los colaboradores reciben un objeto `permissions` (`canSell`, `canFiar`, `canViewReports`, `canOpenCloseCash`, `canViewInventory`) provisto por el backend en `result.employee.permissions`, el cual gobierna de forma reactiva el router y la barra de navegación.
- **B5.16 — CHECKPOINT:** ✅ Conforme.

---

## 📋 Resumen de Hallazgos (PAC-UXD SDD-013)

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-013-01 | Comentario residual en `auth.ts` (línea 446) que afirma erróneamente *"La expiración ocurre por trigger en la base de datos al cerrar el turno"* (el trigger fue eliminado en Wave 5 para cumplir `RN-013-06`). | Bloque 3 (B3.9) | 🔵 Baja (Cosmética/Comentarios) |
| UX-013-02 | En `GatekeeperPending.vue` (línea 32), el intervalo de sondeo es de 30 segundos (`POLL_INTERVAL_MS = 30000`), lo que genera una espera perceptible al cajero si no está conectado el canal Realtime de Supabase. | Bloque 3 (B3.9) | 🟡 Media (Experiencia de Usuario) |
| UX-013-03 | `authStore.logout()` en `auth.ts` (línea 398) purga `pin_auth_token` de `localStorage`, cumpliendo `RN-CACHE-03`, pero no emite un evento unificado de desconexión en el bus de presencia. | Bloque 3 (B3.9) | 🔵 Baja |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🟢 Conforme con Observaciones Menores`
- **Impacto en Estado Compuesto:** Cero hallazgos de severidad alta. La arquitectura de interfaz respeta el desacople con la caja y la Backend Authority.

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. En Fase 3, actualizar el comentario obsoleto de la línea 446 en `frontend/src/stores/auth.ts` para reflejar la versión formal de `FRD-013` (desacople total).
2. Evaluar reducir el intervalo de sondeo en `GatekeeperPending.vue` de 30s a 5s durante los primeros 60s de espera para mejorar la reactividad de apertura en mostrador.
