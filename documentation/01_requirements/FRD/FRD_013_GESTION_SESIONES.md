# FRD-013: Gestión de Sesiones

> **Módulo:** Autenticación / Sesiones  
> **Versión:** 1.0  
> **Fecha:** 2026-01-28  
> **Estado:** Borrador

---

## Descripción

Este documento define las reglas para el ciclo de vida de las sesiones de usuario en el sistema: inicio, duración, cierre voluntario, y límites de concurrencia. Complementa FRD_001 (Pase Diario) y FRD_002 (Registro Admin).

**Principio rector:** Las sesiones son indefinidas pero controladas por el mecanismo de Pase Diario para empleados.

---

## Contexto

| Rol | Mecanismo de Control |
|-----|---------------------|
| **Admin** | Credenciales (email + contraseña) |
| **Empleado** | Credenciales (alias + PIN) + Pase Diario obligatorio |

---

## Reglas de Negocio

### RN-013-01: Duración de Sesión

El sistema NO implementa expiración automática de sesiones por tiempo. Una sesión permanece activa hasta que:
1. El usuario cierra sesión voluntariamente
2. El Admin desactiva la cuenta del empleado (ver FRD_003)
3. Se cierra la caja del turno (para empleados, ver FRD_001)

### RN-013-02: Límite de Sesiones Concurrentes

El sistema permite un máximo de **6 sesiones activas simultáneas** por tienda:
1. 1 sesión de Admin (dueño/manager)
2. 5 sesiones de Empleados

Si se intenta abrir una 7ma sesión:
1. El sistema DEBE rechazar el nuevo intento de login
2. El sistema DEBE mostrar: "Límite de dispositivos alcanzado. Cierre sesión en otro dispositivo para continuar."

### RN-013-03: Comportamiento de Cierre de Sesión (Logout)

Cuando un usuario cierra sesión voluntariamente:

| Acción | Admin | Empleado |
|--------|-------|----------|
| Limpiar credenciales | ✅ SÍ | ✅ SÍ |
| Redirigir a pantalla de login | ✅ SÍ | ✅ SÍ |
| Preservar inventario en caché | ✅ SÍ | ✅ SÍ |
| Preservar lista de clientes en caché | ✅ SÍ | ✅ SÍ |
| Limpiar carrito pendiente | ✅ SÍ | ✅ SÍ |
| Invalidar Pase Diario | N/A | ✅ SÍ |

> **Justificación:** Preservar datos en caché acelera el próximo inicio de sesión al evitar descargas completas. El carrito se limpia por seguridad (evitar que otro usuario complete una venta ajena).

### RN-013-04: Sin Timeout por Inactividad

El sistema NO cierra sesiones por inactividad del usuario. La sesión permanece activa aunque el usuario no interactúe con la aplicación durante horas.

> **Justificación:** En un entorno de tienda, el dispositivo puede estar inactivo mientras el tendero atiende clientes físicamente. Forzar re-login sería contraproducente.

### RN-013-05: Cierre Forzado por Desactivación

Cuando el Admin desactiva un empleado (FRD_003):
1. La sesión activa del empleado DEBE cerrarse inmediatamente
2. El dispositivo del empleado DEBE redirigirse a la pantalla de login
3. El sistema DEBE mostrar: "Tu cuenta ha sido desactivada. Contacta al administrador."

### RN-013-06: Cierre por Cierre de Caja

Cuando se cierra la caja del turno:

1. Todos los Pases Diarios activos de empleados se invalidan
2. El usuario que ejecuta el cierre (Admin o Empleado con permiso) mantiene su sesión activa hasta que decida cerrarla voluntariamente
3. Los empleados SIN permiso de caja DEBEN ver su sesión bloqueada inmediatamente
4. Al día siguiente, TODOS los empleados DEBEN solicitar un nuevo Pase Diario

| Quién cierra | Su sesión | Otros empleados |
|--------------|-----------|-----------------|
| Admin | Permanece activa | Bloqueados |
| Empleado con permiso de caja | Permanece activa | Bloqueados |

> **Nota sobre permisos:** Los permisos se evalúan en tiempo real en cada operación. Si un empleado cerró la caja hoy pero mañana le retiran el permiso de caja, al día siguiente DEBE solicitar Pase Diario como cualquier otro empleado y ya NO podrá ejecutar operaciones de caja.

### RN-013-07: Liberación Manual de Sesión por el Admin

El Administrador DEBE poder cerrar remotamente la sesión activa de un empleado específico para liberar un slot de sesión, sin necesidad de desactivar al empleado (FRD-003) ni cerrar la caja (FRD-027).

- La operación de cierre remoto se ejecuta desde la sección de control de dispositivos descrita en FRD-015 (revocación de dispositivo conectado).
- Al revocar un dispositivo conectado, el sistema DEBE cerrar la sesión asociada, liberar el slot de concurrencia (RN-013-02) e invalidar el Pase Diario del empleado afectado.
- El empleado afectado DEBE ver el mensaje: "Tu sesión fue cerrada por el administrador" y ser redirigido a la pantalla de login.
- El empleado puede solicitar un nuevo Pase Diario para volver a ingresar.

---

## Casos de Uso

### Caso A: Cierre de Sesión Voluntario (Empleado)

- **Actor:** Empleado
- **Precondición:** Sesión activa con Pase Diario válido
- **Flujo Principal:**
    1. Empleado selecciona "Cerrar Sesión" en el menú
    2. Sistema muestra confirmación: "¿Cerrar sesión?"
    3. Empleado confirma
    4. Sistema limpia credenciales locales
    5. Sistema invalida el Pase Diario actual
    6. Sistema redirige a pantalla de login
    7. Los datos de inventario y clientes permanecen en caché
- **Postcondición:** Usuario desautenticado, caché de datos intacta

### Caso B: Cierre de Sesión Voluntario (Admin)

- **Actor:** Admin
- **Precondición:** Sesión activa
- **Flujo Principal:**
    1. Admin selecciona "Cerrar Sesión" en el menú
    2. Sistema muestra confirmación: "¿Cerrar sesión?"
    3. Admin confirma
    4. Sistema limpia credenciales locales
    5. Sistema redirige a pantalla de login
    6. Los datos de inventario y clientes permanecen en caché
- **Postcondición:** Admin desautenticado, caché de datos intacta

### Caso C: Límite de Sesiones Alcanzado

- **Actor:** Empleado o Admin
- **Precondición:** Ya existen 6 sesiones activas en la tienda
- **Flujo Principal:**
    1. Usuario intenta hacer login
    2. Sistema valida credenciales (correctas)
    3. Sistema detecta que hay 6 sesiones activas
    4. Sistema rechaza el login
    5. Sistema muestra: "Límite de dispositivos alcanzado"
    6. Usuario debe cerrar sesión en otro dispositivo primero
- **Postcondición:** Login rechazado, usuario no autenticado

### Caso D: Sesión Interrumpida por Desactivación

- **Actor:** Empleado (afectado) + Admin (ejecutor)
- **Precondición:** Empleado con sesión activa, Admin en panel de gestión
- **Flujo Principal:**
    1. Admin desactiva al empleado desde panel de gestión
    2. Sistema marca empleado como inactivo
    3. Sistema detecta el cambio de estado
    4. En el dispositivo del empleado, la aplicación cierra la sesión automáticamente
    5. Empleado ve mensaje: "Tu cuenta ha sido desactivada"
    6. Empleado es redirigido a pantalla de login
- **Postcondición:** Empleado desautenticado, no puede volver a entrar hasta reactivación

### Caso E: Liberación de Slot de Sesión (Admin)

- **Actor:** Administrador
- **Precondición:** 6 sesiones activas, un nuevo empleado necesita ingresar.
- **Flujo Principal:**
    1. Empleado intenta hacer login → Sistema rechaza: "Límite de dispositivos alcanzado".
    2. Admin accede al centro de notificaciones → sección de control de dispositivos (FRD-015).
    3. Admin identifica un dispositivo inactivo o de un empleado que ya no necesita acceso.
    4. Admin revoca el dispositivo.
    5. Sistema cierra la sesión asociada, libera el slot e invalida el Pase Diario.
    6. Empleado afectado ve: "Tu sesión fue cerrada por el administrador".
    7. El nuevo empleado puede ahora hacer login exitosamente.
- **Postcondición:** Slot liberado, nuevo empleado autenticado.

---

## Criterios de Aceptación

### Límites y Concurrencia
- [ ] El sistema rechaza el 7mo intento de login mostrando mensaje de límite
- [ ] El límite de 6 sesiones se valida en el servidor, no solo en la interfaz
- [ ] Al revocar un dispositivo conectado, la sesión asociada se cierra y el slot de concurrencia se libera.
- [ ] El empleado cuya sesión fue cerrada remotamente ve un mensaje explicativo y es redirigido a login.

### Cierre de Sesión
- [ ] Al cerrar sesión, las credenciales se eliminan del dispositivo
- [ ] Al cerrar sesión, el inventario y clientes permanecen en caché
- [ ] Al cerrar sesión, el carrito pendiente se elimina
- [ ] Al cerrar sesión de empleado, el Pase Diario se invalida

### Desactivación
- [ ] Al desactivar un empleado, su sesión activa se cierra inmediatamente
- [ ] El empleado desactivado ve mensaje explicativo antes de redirigir a login

### Sin Timeout
- [ ] Una sesión inactiva por 24 horas sigue siendo válida (sin expiración automática)

---

## Requisitos de Datos (Para Equipo Data)

### Información de Sesión

El sistema requiere rastrear la siguiente información para cada sesión activa:

| Información | Descripción |
|-------------|-------------|
| Identificador de usuario | Quién inició la sesión |
| Identificador de tienda | A qué tienda pertenece |
| Fecha/hora de inicio | Cuándo se autenticó |
| Identificador de dispositivo | Desde qué navegador/dispositivo |
| Estado | Activa o finalizada |

### Conteo de Sesiones

El sistema DEBE poder consultar rápidamente cuántas sesiones activas tiene una tienda para validar el límite de 6.

---

## Trazabilidad

| Documento | Referencia |
|-----------|------------|
| FRD_001 | Pase Diario - Expiración al cerrar caja |
| FRD_002 | Registro Admin - Credenciales maestras |
| FRD_003 | Gestión de Empleados - Desactivación |
| FRD_011 | Manejo de Errores - Validación de cuenta activa |
