# 📋 Órdenes de Trabajo - SPEC-005: Autenticación Unificada IAM

**Fecha:** 2026-01-15  
**Estado:** Listo para Implementación  
**Rama Git:** `feat/auth-unificada-iam`

---

## 🔀 Inicialización Git

```bash
git checkout -b feat/auth-unificada-iam
```

---

## Fase 1: Backend (Supabase)

### Tarea 1.1: Campos de Rate Limiting
**Agente:** `/data`  
**Tiempo estimado:** 10 min

#### Contexto
- Archivo: `02_ARCHITECTURE/supabase-schema.sql`
- Referencia: `01_REQUIREMENTS/auth-unificada-iam.md` sección 6.3

#### Objetivo
Agregar campos para control de intentos fallidos en tabla `employees`.

#### Cambios Requeridos
```sql
ALTER TABLE employees ADD COLUMN IF NOT EXISTS 
  failed_attempts INTEGER DEFAULT 0,
  locked_until TIMESTAMPTZ DEFAULT NULL;
```

#### DoD
- [ ] Campos agregados a schema
- [ ] Índice creado si necesario

---

### Tarea 1.2: Rate Limiting en RPC
**Agente:** `/data`  
**Tiempo estimado:** 15 min

#### Contexto
- Función: `login_empleado_unificado` en `supabase-schema.sql`

#### Objetivo
Agregar lógica de bloqueo tras 5 intentos fallidos.

#### Cambios Requeridos
```sql
-- Al inicio del RPC, después de obtener empleado:
IF v_employee.locked_until > NOW() THEN
  RETURN json_build_object('success', false, 'error_code', 'ACCOUNT_LOCKED',
    'error', 'Cuenta bloqueada. Intenta en 15 minutos.');
END IF;

-- Si credenciales incorrectas:
UPDATE employees SET failed_attempts = failed_attempts + 1,
  locked_until = CASE WHEN failed_attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE NULL END
WHERE id = v_employee.id;

-- Si login exitoso:
UPDATE employees SET failed_attempts = 0, locked_until = NULL WHERE id = v_employee.id;
```

#### DoD
- [ ] Lógica agregada al RPC
- [ ] Nuevo código de error `ACCOUNT_LOCKED` documentado

---

### Tarea 1.3: Limpieza de Sesiones (pg_cron)
**Agente:** `/data`  
**Tiempo estimado:** 10 min

#### Contexto
- Tabla: `employee_sessions`
- TTL: 8 horas

#### Objetivo
Crear job de limpieza diaria.

#### Cambios Requeridos
```sql
-- Habilitar extensión pg_cron (en Supabase Dashboard > Database > Extensions)
-- Crear job:
SELECT cron.schedule('cleanup-sessions', '0 3 * * *', 
  $$DELETE FROM employee_sessions WHERE started_at < NOW() - INTERVAL '8 hours'$$);
```

#### DoD
- [ ] Instrucciones documentadas en schema o README
- [ ] Job configurado en Supabase

---

## Fase 2: Frontend (Vue)

### Tarea 2.1: Composable de Fingerprint
**Agente:** `/orchestrator` → Antigravity  
**Tiempo estimado:** 15 min

#### Contexto
- Crear: `03_SRC/src/composables/useDeviceFingerprint.ts`
- Algoritmo: SHA-256 según SPEC-005 sección 6.1

#### Prompt para Antigravity
```
Crea el archivo src/composables/useDeviceFingerprint.ts con:
- Función generateFingerprint() que retorna Promise<string>
- Usa crypto.subtle.digest con SHA-256
- Datos: navigator.userAgent, screen dimensions, timezone, language
- Exporta como composable con función y valor cacheado
```

#### DoD
- [ ] Archivo creado
- [ ] Exporta `useDeviceFingerprint()`
- [ ] Sin dependencias externas

---

### Tarea 2.2: Estados en Auth Store
**Agente:** `/orchestrator` → Antigravity  
**Tiempo estimado:** 15 min

#### Contexto
- Archivo: `03_SRC/src/stores/auth.ts`
- Referencia: SPEC-005 sección 4

#### Prompt para Antigravity
```
En src/stores/auth.ts agregar:
1. Estado: deviceApproved: ref<'pending' | 'approved' | 'rejected' | null>(null)
2. Estado: storeOpenStatus: ref<boolean>(false)
3. Computed: canAccessPOS = dispositivo aprobado Y tienda abierta
4. Action: setDeviceStatus(status) y setStoreStatus(isOpen)
Mantener toda la lógica existente intacta.
```

#### DoD
- [ ] Estados agregados
- [ ] Computed `canAccessPOS` funcional
- [ ] Build sin errores

---

### Tarea 2.3: Detección de Usuario en Login
**Agente:** `/orchestrator` → Antigravity  
**Tiempo estimado:** 20 min

#### Contexto
- Archivo: `03_SRC/src/views/LoginView.vue`
- Regla: `@` = Admin, sin `@` = Empleado

#### Prompt para Antigravity
```
En src/views/LoginView.vue modificar handleLogin():
1. Detectar si username contiene '@' → flujo Admin (actual)
2. Si NO contiene '@' → flujo Empleado con PIN
3. Manejar nuevos códigos de error:
   - GATEKEEPER_PENDING: mostrar "Dispositivo en espera de aprobación"
   - GATEKEEPER_REJECTED: mostrar "Acceso denegado"
   - ACCOUNT_LOCKED: mostrar "Cuenta bloqueada. Intenta en 15 minutos"
4. Importar y usar useDeviceFingerprint para enviar fingerprint
No cambiar estilos ni estructura del template.
```

#### DoD
- [ ] Detección automática funcionando
- [ ] 3 mensajes de error nuevos
- [ ] Fingerprint enviado en login empleado

---

### Tarea 2.4: Middleware de Router
**Agente:** `/orchestrator` → Antigravity  
**Tiempo estimado:** 10 min

#### Contexto
- Archivo: `03_SRC/src/router/index.ts`
- Bloquear: `/pos` cuando tienda cerrada

#### Prompt para Antigravity
```
En src/router/index.ts, en el beforeEach guard:
1. Importar useAuthStore
2. Si ruta es '/pos' y authStore.storeOpenStatus === false:
   - Redirigir a '/' (dashboard)
   - Mostrar notificación "Inicie jornada para vender"
Mantener guards existentes intactos.
```

#### DoD
- [ ] Guard agregado
- [ ] Redirección funcionando
- [ ] Notificación mostrada

---

### Tarea 2.5: Banner de Tienda Cerrada
**Agente:** `/ux` → definir diseño, luego `/orchestrator` → implementar  
**Tiempo estimado:** 15 min

#### Contexto
- Archivo: `03_SRC/src/views/DashboardView.vue`
- Mostrar cuando: `storeOpenStatus === false`

#### Prompt para Antigravity
```
En DashboardView.vue agregar banner condicional:
1. Mostrar cuando authStore.storeOpenStatus === false
2. Mensaje: "Inicie jornada para vender"
3. Estilo: bg-amber-50, border-amber-200, icono info
4. Posición: después del header, antes de las stats
```

#### DoD
- [ ] Banner visible cuando tienda cerrada
- [ ] Estilo consistente con design system

---

## Fase 3: Seguridad

### Tarea 3.1: Vista Admin para Dispositivos
**Agente:** `/ux` → wireframe, `/orchestrator` → implementar  
**Tiempo estimado:** 30 min

#### Contexto
- Crear: `03_SRC/src/views/DeviceApprovalView.vue` o sección en AdminHub
- Datos: tabla `access_requests`

#### Descripción
Vista donde el admin puede ver solicitudes pendientes y aprobar/rechazar dispositivos.

#### Requisitos
- Lista de solicitudes con: empleado, dispositivo (userAgent resumido), fecha
- Botones: Aprobar (verde), Rechazar (rojo)
- Solo visible para admins

#### DoD
- [ ] Vista creada o integrada en AdminHub
- [ ] Acciones de aprobar/rechazar funcionando
- [ ] Ruta protegida

---

### Tarea 3.2: Badge de Notificación
**Agente:** `/orchestrator` → Antigravity  
**Tiempo estimado:** 10 min

#### Contexto
- Archivo: `03_SRC/src/views/NotificationCenterView.vue`
- Trigger: `access_requests` con `status = 'pending'`

#### Prompt para Antigravity
```
En NotificationCenterView.vue:
1. Agregar sección "Dispositivos Pendientes" para admins
2. Mostrar contador de solicitudes pendientes
3. Link a vista de aprobación de dispositivos
Solo mostrar si authStore.isAdmin === true.
```

#### DoD
- [ ] Sección visible para admins
- [ ] Contador funcional

---

## Fase 4: Validación

### Tarea 4.1: Revisión QA
**Agente:** `/qa`

#### Checklist
- [ ] Rate limiting funciona (5 intentos → bloqueo)
- [ ] Fingerprint es determinista
- [ ] Códigos de error muestran mensajes correctos
- [ ] Admin puede aprobar/rechazar dispositivos
- [ ] Tienda cerrada bloquea POS

---

## Comandos de Cierre

```bash
# Tras completar todas las tareas:
git add .
git commit -m "feat(auth): implement unified IAM with device fingerprinting and rate limiting"
git push origin feat/auth-unificada-iam

# Crear PR y solicitar revisión de /qa
```

---

## Resumen de Asignaciones

| Fase | Tareas | Agente Principal |
|------|--------|------------------|
| Backend | 1.1, 1.2, 1.3 | `/data` |
| Frontend | 2.1-2.5 | `/orchestrator` |
| Seguridad | 3.1, 3.2 | `/ux` + `/orchestrator` |
| Validación | 4.1 | `/qa` |

**Total:** 11 tareas | **Tiempo estimado:** ~2.5 horas
