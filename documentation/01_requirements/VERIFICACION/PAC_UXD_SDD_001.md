# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-001 / SDD-015)

> **Componente Auditado:** `frontend/src/views/DailyWaitingRoom.vue`, `frontend/src/components/NotificationSecurityWidget.vue`, `frontend/src/views/NotificationCenterView.vue` (y repositorio `frontend/src/data/repositories/authRepository.ts`, store `frontend/src/stores/devices.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_001_SEGURIDAD_DIARIA.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_001_SEGURIDAD_DIARIA.md) (y [`SDD_015_GESTION_DISPOSITIVOS.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_015_GESTION_DISPOSITIVOS.md))  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Rutas Principales:**
  - `frontend/src/views/DailyWaitingRoom.vue` (Sala de espera para pases en estado `pending`)
  - `frontend/src/views/NotificationCenterView.vue` (Centro de notificaciones del Administrador)
- **Widgets de Seguridad:**
  - `frontend/src/components/NotificationSecurityWidget.vue` (Widget de control de accesos y dispositivos conectados)
- **Capa de Datos y Repositorios:**
  - `frontend/src/data/repositories/authRepository.ts`
  - `frontend/src/stores/devices.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.3 Verificación de Estado de Pase: `check_my_pass_status` / `check_daily_pass_status`
- **Invariante de Fecha y Prohibición de TTL Arbitrario en Cliente:**
  - Toda consulta de estado de pase debe filtrar por `pass_date = (now() AT TIME ZONE 'America/Bogota')::date`.
  - **Prohibición de Fallo Silencioso / TTL Arbitrario (Regla 3 AGENTS.md):** Se prohíbe terminantemente en el frontend (`authRepository.ts`) cualquier filtro de expiración temporal arbitrario sobre `requested_at` (por ejemplo, `requested_at > now() - 5 minutos`). El pase diario solo caduca a las 23:59 del día operativo o por revocación explícita del Administrador (`RN-3`, `RN-10`).
- **Salida Exitosa (`JSONB`):** Retorna `"status": "pending" | "approved" | "rejected" | "expired"` y, si es `"approved"`, el objeto `employee` con sus permisos vigentes.

### 5.4 Resolución y Revocación Administrativa: `aprobar_pase_diario` / `rpc_gestionar_dispositivo`
- **Parámetros de Entrada:**
  - `p_pass_id` (`UUID`, obligatorio)
  - `p_action` (`TEXT`: `'approve'`, `'reject'`, `'revoke'`)
- **Reglas de Transformación en Servidor:**
  1. Obtiene `store_id` del pase y ejecuta `PERFORM public.assert_store_access(v_store_id);`.
  2. Verifica que `auth.uid()` exista en `public.admin_profiles` para esa tienda.
  3. Actualiza `daily_passes.status` a `'approved'` (para `'approve'`) o `'rejected'` (para `'reject'` y `'revoke'`), sellando `resolved_at = now()` y `resolved_by = auth.uid()`.
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componentes identificados y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `getPendingAccessRequests` y `getAuthorizedDevices`
- **Filtro de Fecha y TTL en `authRepository.ts:456-470`:**
  - Código real: `const today = new Date().toISOString().split('T')[0];` y `const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();` con filtro `.gte('requested_at', fiveMinutesAgo)`.
  - Resultado: **Discrepancia Crítica (Doble Infracción)**:
    1. Usa fecha UTC (`new Date().toISOString()`), desfasada 5 horas respecto a `America/Bogota` (después de las 19:00 UTC-5 busca solicitudes del día de mañana).
    2. Aplica TTL arbitrario de 5 minutos (`fiveMinutesAgo`), haciendo desaparecer las solicitudes pendientes si el administrador demora más de 5 minutos en responder.

### Operación: `updateAccessRequestStatus` en `authRepository.ts:525-546`
- **Aprobación (`status === 'approved'`):**
  - Código real: En `authRepository.ts:528-531`, invoca `aprobar_pase_diario` enviando `p_admin_id: reviewedBy` desde el cliente.
  - Resultado: **Parcial**. Debe homologarse a `rpc_gestionar_dispositivo(p_pass_id, 'approve')`.
- **Rechazo / Revocación (`status !== 'approved'`):**
  - Código real: En `authRepository.ts:536-542`, ejecuta `.from('daily_passes').update({ status: 'rejected', resolved_by: reviewedBy }).eq('id', requestId)` directamente vía PostgREST.
  - Resultado: **Discrepancia Crítica**. Mutación directa sobre tabla omitiendo `rpc_gestionar_dispositivo`, validación `assert_store_access` y doble auditoría forense (`audit_logs` + `audit_seguridad`).

---

## Bloque 2b — Verificación de Límites Financieros y Lógica de Negocio

- **Desacople Pase-Caja (`Decisión D-03` / `RN-3` y `RN-4`):**
  - El pase diario no expira con el cierre de turno. El cierre de turno solo bloquea el POS (`NO_OPEN_CASH_SESSION`).
- **Insistencia de 3 Reintentos (`RN-7`):**
  - `DailyWaitingRoom.vue` maneja `maxPings = 3` y un botón para reenviar alerta (`solicitar_pase_diario`).
- **Cierre Forzado en Cliente (`DailyWaitingRoom.vue:85-95`):**
  - `DailyWaitingRoom.vue` implementa un temporizador `EXPIRY_MS = 5 * 60 * 1000` que expulsa al empleado a `/login?reason=timeout`, impidiendo que el empleado continúe en la sala de espera hasta agotar sus 3 intentos de insistencia.

---

## Bloque 3 — Verificación de Manejo de Errores

| Código de Error SDD | Estado en Código Actual | Tratamiento en UI | Conforme |
|---|---|---|---|
| `MAX_RETRIES` | Manejado localmente | Deshabilita botón de ping tras 3 intentos | ✅ Sí |
| `UNAUTHORIZED_ROLE` (403) | Capturado en catch | `logger.error` y retorno false en store | 🟡 Parcial |
| `STORE_ACCESS_DENIED` | No capturado específicamente | Error genérico en consola | ❌ No |
| `ALREADY_PROCESSED` | No capturado | Error genérico | ❌ No |

---

## Bloque 4 — Verificación de Estados de Carga e Interacción

- **Realtime / Polling:** `DailyWaitingRoom.vue:53-74` implementa suscripción Realtime al canal `employee_pass_${passId}` para detectar el paso a `approved` o `rejected` sin polling agresivo.
- **Bloqueo de Interacción:** `NotificationSecurityWidget.vue:67-69` superpone loading overlay durante las mutaciones de aprobación y revocación.

---

## Bloque 5 — Resumen de Discrepancias y Plan de Acción

### 5.1 Conteo Mecánico de Hallazgos (Regla 9.1: N = 5)
- **UX-1 (Severidad Alta):** Filtro de caducidad arbitrario de 5 minutos sobre solicitudes pendientes (`F-6` y `F-15`). En `frontend/src/data/repositories/authRepository.ts:460, 467`, `getPendingAccessRequests` aplica `.gte('requested_at', fiveMinutesAgo)` con una ventana quemada de 5 minutos. Si el administrador no revisa la solicitud en ese lapso, la tarjeta desaparece de la vista sin haber sido resuelta (fallo silencioso, violando `SDD_001: 5.3` y Regla 3 de `AGENTS.md`).
- **UX-2 (Severidad Alta):** Uso de fecha UTC en consultas de `daily_passes`. En `authRepository.ts:458, 494`, calcula `const today = new Date().toISOString().split('T')[0]`. En Colombia (UTC-5), a partir de las 19:00 horas, la fecha UTC pasa al día siguiente, descalzando las consultas contra `pass_date` del servidor y ocultando pases vigentes de la jornada operativa actual (`D-5`).
- **UX-3 (Severidad Alta):** Bypasseo de `rpc_gestionar_dispositivo` en rechazo/revocación (`F-7`). En `authRepository.ts:536-542`, al rechazar o revocar un pase diario ejecuta una mutación directa PostgREST `.from('daily_passes').update({ status: 'rejected', resolved_by: reviewedBy }).eq('id', requestId)`, saltándose la validación `assert_store_access` en servidor, la verificación en `admin_profiles` y el asiento dual obligatorio en `audit_logs` y `audit_seguridad` (`SDD_001: 5.4` y `SDD_015`).
- **UX-4 (Severidad Alta):** Cierre forzado de sesión por timeout arbitrario de 5 minutos en `DailyWaitingRoom.vue`. En `DailyWaitingRoom.vue:85-95`, un temporizador local `EXPIRY_MS = 5 * 60 * 1000` ejecuta `authStore.logout()` y expulsa al empleado a `/login?reason=timeout` si el administrador no responde en 5 minutos, destruyendo el flujo de espera e insistencia de hasta 3 intentos (`RN-7`).
- **UX-5 (Severidad Media):** Omisión de llamada a `rpc_gestionar_dispositivo` con acción `'approve'`. En `authRepository.ts:528-531`, `approveDevice` invoca la función legacy `aprobar_pase_diario` enviando `p_admin_id` desde el cliente en lugar de unificar con `rpc_gestionar_dispositivo(p_pass_id, 'approve')` donde la identidad del administrador es resuelta por `auth.uid()` en base de datos.

---

### 5.2 Auto-Chequeo Anti-Sesgo (Regla 9.4)
- **9.1 Invariante de Reconciliación:** $N = 5$ hallazgos documentados en el Bloque 5.1 y citados exactamente.
- **9.2 No-Fusión de Dimensiones:** La implementación reactiva de Supabase Realtime no compensa el borrado prematuro por TTL de 5 minutos ni el bypass en el update directo de `daily_passes`.
- **9.3 Cita de Fuentes:** Las discrepancias se sustentan en `authRepository.ts:458, 460, 467, 494, 528-542` y `DailyWaitingRoom.vue:85-95`.
- **9.4 Veredicto:** 🟡 **CON OBSERVACIONES (5 discrepancias detectadas)**.

---

## 📌 Instrucción para el Orquestador (Etapa 4)

1. En `frontend/src/data/repositories/authRepository.ts`:
   - Eliminar el filtro `.gte('requested_at', fiveMinutesAgo)` de `getPendingAccessRequests`.
   - Ajustar el cálculo de `today` para usar la zona horaria operativa de Colombia (`America/Bogota`) en lugar de `toISOString()`.
   - Reemplazar la mutación directa `.from('daily_passes').update(...)` y la llamada a `aprobar_pase_diario` por `supabase.rpc('rpc_gestionar_dispositivo', { p_pass_id: requestId, p_action: status === 'approved' ? 'approve' : 'reject' })` (o `'revoke'`).
2. En `frontend/src/views/DailyWaitingRoom.vue`:
   - Remover el temporizador arbitrario `EXPIRY_MS = 5 * 60 * 1000` que expulsa al empleado, permitiendo que la terminal permanezca en la sala de espera hasta que el pase sea aprobado, rechazado o se agoten los pings de reintento.
