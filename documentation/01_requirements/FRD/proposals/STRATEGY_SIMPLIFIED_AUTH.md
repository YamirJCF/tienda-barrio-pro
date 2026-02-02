# Estrategia de Simplificación: Acceso de Empleados "Zero-Auth" con Control Estricto

> **Contexto**: Ante la complejidad excesiva de implementar usuarios autenticados (Supabase Auth/RLS) para empleados transitorios, cambiamos a un modelo de "Confianza en el Dispositivo" gestionado por lógica de aplicación simple, pero **reforzado con Aprobación Explicita del Admin**.

## 1. El Cambio de Paradigma

Abandonamos el intento de mapear cada Empleado a un `auth.users` de Supabase.
En su lugar:
1.  **Identidad Global**: El empleado se identifica con un **Alias Numérico Único Global** (ej. Cédula/Teléfono). El sistema infiere su tienda automáticamente.
2.  **Autenticación**: Validación de PIN (Prueba de Conocimiento).
3.  **Autorización (El Candado)**: Validación de **Pase Diario Activo**. Si no existe, se bloquea el acceso y se solicita aprobación al Admin.

> ⚠️ **Nota de Arquitectura**: La unicidad del Alias es CRÍTICA. No pueden existir dos empleados con el mismo alias en ninguna tienda del sistema.

---

## 2. Diagrama de Secuencia: Flujo de Aprobación Obligatoria

Este flujo describe cómo el sistema impide el acceso "silencioso" y fuerza la intervención del Admin.

```mermaid
sequenceDiagram
    autonumber
    participant U as 👤 Empleado
    participant UI as 📱 Frontend (Vue)
    participant API as ⚡ Backend (Supabase RPCs)
    participant DB as 🗄️ Base de Datos
    participant A as 👮 Admin (Dueño)

    Note over U, A: FASE 1: Identificación y Solicitud

    U->>UI: Ingresa Alias (ej. "3001234567")
    UI->>API: rpc('get_employee_public_info', { alias })
    Note right of UI: Busca en TODO el sistema
    API->>DB: SELECT store_id, name FROM employees WHERE alias = ?
    DB-->>API: { store_id: "uuid", name: "Juan" } (O null)
    
    alt Alias No Existe
        API-->>UI: Error: "Usuario no encontrado"
    else Alias Existe
        API-->>UI: Contexto Tienda + Nombre
    end

    U->>UI: Ingresa PIN (4 dígitos)
    UI->>API: rpc('request_employee_access', { alias, pin, store_id })
    
    API->>DB: Valida PIN
    
    alt PIN Incorrecto
        API-->>UI: Error: "Credenciales Incorrectas"
    else PIN Correcto
        API->>DB: ¿Existe Pase Diario 'APPROVED' hoy?
        
        opt NO Existe Pase Aprobado
            API->>DB: INSERT INTO daily_passes (status: 'PENDING')
            API-->>UI: { status: 'PENDING', message: "Esperando aprobación..." }
            Note over UI: UI entra en modo "Polling" o espera
        end
        
        opt YA Existe Pase Aprobado
            API-->>UI: { status: 'APPROVED', token: '...' }
        end
    end

    Note over U, A: FASE 2: La Decisión del Admin

    Note right of A: Admin recibe notificación\no ve lista de pendientes
    A->>API: rpc('approve_daily_pass', { pass_id })
    API->>DB: UPDATE daily_passes SET status = 'APPROVED'

    Note over U, A: FASE 3: Acceso Permitido

    loop Polling / Realtime
        UI->>API: ¿Ya me aprobaron?
    end
    
    API-->>UI: { status: 'APPROVED', employee_data: {...} }
    UI->>UI: Guarda Sesión Local
    UI->>U: **Acceso al Dashboard**
```

## 3. Implicaciones Técnicas

### Base de Datos
- **Constraint**: `ALTER TABLE employees ADD CONSTRAINT unique_alias_global UNIQUE (alias);`
- **Tabla `daily_passes`**: Es la pieza central. Debe tener `employee_id`, `store_id`, `status` (PENDING, APPROVED, REJECTED, CLOSED), `created_at`.

### Frontend
- **Login View**: Debe manejar 3 estados:
    1.  Credenciales Incorrectas.
    2.  Credenciales OK + **Esperando Aprobación** (Bloqueante con spinner/mensaje).
    3.  Credenciales OK + Aprobado (Entra).
- **Persistencia**: Solo se guarda la sesión UNA VEZ que el estado es `APPROVED`.

### Backend (RPCs)
- `get_employee_public_info(alias)`: Retorna nombre y tienda (público).
- `request_employee_access(alias, pin)`: Valida PIN y crea/retorna estado del pase.
- `approve_daily_pass(pass_id)`: Solo ejecutable por Admin (RLS o check de rol).

## 4. Próximos Pasos (Plan de Acción)
1. [ ] **BD**: Aplicar constraint de unicidad global al alias.
2. [ ] **RPC**: Crear `get_employee_public_info` para resolver tienda por alias.
3. [ ] **RPC**: Crear `request_employee_access` que gestione la lógica de PIN + Creación de Pase PENDING.
4. [ ] **Frontend**: Actualizar flujo de Login para soportar la pantalla de "Esperando Aprobación".
