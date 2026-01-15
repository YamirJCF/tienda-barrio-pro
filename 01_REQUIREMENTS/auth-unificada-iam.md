# 🔐 Autenticación Unificada e Integridad IAM

**ID:** SPEC-005  
**Prioridad:** Crítica  
**Estado:** Validado para Implementación

---

## 1. Resumen Ejecutivo

Implementación de un sistema de acceso polimórfico que valida la identidad del usuario, la legitimidad del dispositivo (IAM) y el estado operativo de la tienda (Gatekeeper) en un flujo único, optimizando el tiempo de respuesta y garantizando la seguridad financiera.

---

## 2. Flujo de Identificación y Experiencia (UX/UI)

El sistema detecta el rol del usuario basándose exclusivamente en el input de identidad:

| Entrada Detectada | Tipo de Usuario | Credencial | Método de Validación |
|:------------------|:----------------|:-----------|:---------------------|
| Contiene `@`      | **Administrador** | Contraseña | Supabase Auth (Email/Pass) |
| NO contiene `@`   | **Empleado**      | PIN (4 dígitos) | RPC `login_empleado_unificado` |

---

## 3. Lógica del Portero Digital (Gatekeeper de 3 Capas)

Para evitar el **"Deadlock Operativo"** (tienda cerrada que impide el login), la lógica en el servidor (RPC) sigue esta jerarquía:

### Nivel 1: Credenciales (Seguridad)

- **Acción:** Comparar `username` y `pin` (hasheado).
- **Error:** `INVALID_CREDENTIALS` (Bloqueo inmediato).

### Nivel 2: IAM - Control de Dispositivos (Seguridad)

- **Acción:** Verificar aprobación en `access_requests`.
- **Error:** `GATEKEEPER_PENDING`. 
- **UI:** Mostrar: *"Dispositivo en espera de aprobación del Administrador"*.

### Nivel 3: Estado de Tienda (Operativo)

- **Acción:** Verificar si existe un corte de caja abierto (`is_store_open`).
- **Respuesta:** Retornar `success: true` junto con el flag `store_state: { is_open: boolean }`.
- **Comportamiento UI:** Si `is_open == false`, el empleado ingresa al Dashboard pero el acceso al POS está deshabilitado con el mensaje: *"Inicie jornada para vender"*.

---

## 4. Impacto y Mapeo en el Sistema

### 📂 Capa de Datos (02_ARCHITECTURE)

| Archivo | Cambio Requerido |
|---------|------------------|
| `supabase-schema.sql` | Incluir tabla `access_requests` y RPC `login_empleado_unificado` |
| `SECURITY_PROTOCOLS.md` | Actualizar con protocolo "Aprobación de Dispositivos Nuevos" |

### 📂 Capa de Aplicación (03_SRC)

| Archivo | Cambio Requerido |
|---------|------------------|
| `src/stores/auth.ts` | Gestionar estado `deviceApproved` y `storeOpenStatus` |
| `src/views/LoginView.vue` | Sustituir formulario estático por componente de detección de identidad |
| `src/router/index.ts` | Middleware para redirigir a `/dashboard` si se intenta entrar a `/pos` con tienda cerrada |

### 📂 Capa de Orquestación (04_DEV_ORCHESTRATION)

| Archivo | Cambio Requerido |
|---------|------------------|
| `TODO_DASHBOARD.md` | Insertar tareas de validación de PIN y estado de caja |

---

## 5. Análisis de Eficiencia Económica

- **Optimización de Recursos:** Al mover la validación del dispositivo y de la tienda a un solo RPC, reducimos las llamadas a la red en un **50%** por cada sesión iniciada.
- **Continuidad de Negocio:** Se elimina el costo de oportunidad de que un empleado no pueda abrir la tienda si el dueño no está presente para "desbloquear" la app.

---

## Conexiones con Documentación

- **Implementación actual:** [login.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/01_REQUIREMENTS/login.md)
- **Arquitectura Supabase:** [supabase-schema.sql](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/02_ARCHITECTURE/supabase-schema.sql)
- **Protocolos Backend:** [SECURITY_PROTOCOLS.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/02_ARCHITECTURE/SECURITY_PROTOCOLS.md)
