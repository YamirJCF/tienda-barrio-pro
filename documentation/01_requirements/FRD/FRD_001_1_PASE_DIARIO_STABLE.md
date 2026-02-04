# FRD-001.1: Re-implementación del Pase Diario (Daily Pass)

## 1. Contexto y Objetivo
El objetivo es restaurar la funcionalidad de "Pase Diario" para empleados, eliminando la "Auto-Aprobación" temporal que se había implementado para estabilización. Volvemos al modelo de **Zero Trust** donde el Administrador debe aprobar explícitamente el acceso cada día.

## 2. Reglas de Negocio Restauradas

### 2.1 Flujo "Zero Trust"
1.  **Solicitud**: Al ingresar el PIN, el sistema crea una solicitud en estado `PENDIENTE`.
2.  **Espera**: El empleado es redirigido a la "Sala de Espera" (`GatekeeperPending`).
3.  **Aprobación**: El Administrador recibe la solicitud y debe aprobarla manualmente desde su dashboard.
4.  **Ingreso**: Una vez aprobada, el dispositivo del empleado detecta el cambio (polling) y permite el acceso.

### 2.2 Expiración y Cierre de Caja (Refinado)
> [!IMPORTANT]
> **Cambio de Lógica**: Se desacopla el "Cierre de Caja" de la "Expiración del Pase".

1.  **Validez del Pase**:
    *   El pase es válido hasta las **23:59 del día en curso** (o hasta revocación manual).
    *   **NO expira** automáticamente al cerrar la caja. Esto permite a los empleados realizar tareas de cierre, limpieza o inventario post-venta sin ser expulsados.

2.  **Cierre de Caja (Bloqueo Operativo)**:
    *   Si la caja se cierra (por Admin o Encargado), el sistema pasa a modo **"Solo Lectura Venta"**.
    *   **Escenario "Venta en Curso"**: Si un empleado está en medio de una venta y la caja se cierra remotamente:
        *   El sistema detecta el cambio de estado al intentar procesar el pago.
        *   Muestra error: *"La caja ha sido cerrada. No se puede completar la transacción."*
        *   **NO saca al empleado** a la pantalla de login. Mantiene al usuario en el sistema pero deshabilita funciones monetarias.

3.  **Expulsión (Revocación)**:
    *   **Definición**: Pérdida total de acceso al sistema que obliga al usuario a volver a la pantalla de Login/Esperando Aprobación.
    *   **Causa A - Revocación Manual**:
        *   **Acción**: El Admin cambia el estado del pase a `rejected` desde su panel de control.
        *   **Efecto**: El frontend detecta el cambio en la siguiente verificación (polling de 30s o navegación).
        *   **Resultado**: Cierre de sesión forzado (`logout`) y redirección inmediata a `/login`.
    *   **Causa B - Caducidad Natural (00:00 Horas)**:
        *   **Acción**: El reloj del servidor marca un nuevo día (`CURRENT_DATE > pass_date`).
        *   **Efecto**: Cualquier solicitud al backend será rechazada por RLS o RPC check.
        *   **Resultado**: El usuario es redirigido a solicitar un nuevo pase para el nuevo día.

## 3. Especificaciones Técnicas (Data Architect)

### 3.1 Tabla `daily_passes` (Ya existente)
- `status`: Debe ser `pending` por defecto al crear.
- `device_fingerprint`: Identificador del navegador/dispositivo.

### 3.2 RPC `request_employee_access`
- **Modificación Crítica**: Cambiar el estado inicial de inserción de `'approved'` a `'pending'`.
- Debe retornar el estado actual (`pending`) para que el frontend reaccione.

### 3.3 RPC `approve_daily_pass` (Ya existente)
- Confirmar que simplemente actualiza el estado a `approved`.
- NO debe tener triggers que dependan del estado de la caja (`stores.is_open`) para la validez del token, solo para la operación de venta.

## 4. Impacto en Frontend (UX/UI)

### 4.1 LoginView
- Debe manejar la respuesta `status: 'pending'` redirigiendo a la pantalla de espera, no al dashboard. (Lógica ya existente, solo verificar activacion).

### 4.2 GatekeeperPending
- Debe mantener el polling activo hasta recibir `approved` o `rejected`.

### 4.3 DeviceApprovalModal (Admin - Mejoras)
- **Lista de Pendientes**: Mantener funcionalidad de Aprobar/Rechazar.
- **Lista de Aprobados (NUEVO REQUISITO)**:
    - Actualmente solo muestra el estado. Se debe agregar un botón **[REVOCAR / EXPULSAR]** para cada dispositivo activo.
    - **Acción**: Al hacer clic, llama a `updateAccessRequestStatus(id, 'rejected')`.
    - **UI**: El item debe desaparecer de "Aprobados" o moverse a un historial de "Rechazados recentamente".
    - **Feedback**: Mostrar confirmación "Acceso revocado para [Empleado]".

## 5. Plan de Migración
Se aplicará una modificación a la función RPC existente para detener la auto-aprobación. No se requiere migración de estructura de tablas, solo de lógica (PL/pgSQL).
