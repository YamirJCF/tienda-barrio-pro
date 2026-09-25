# FRD-003: Gestión de Empleados y Permisos

### Nombre de la Funcionalidad
Administración de Perfiles de Empleados

#### Descripción
Módulo administrativo que permite al Dueño/Manager crear, editar y desactivar perfiles de empleados. Este módulo es la fuente de verdad para la autenticación (PIN) y la autorización (Permisos) dentro del sistema POS.

---

## Reglas de Negocio

1. **Identificador Único Global:**
    - Cada empleado DEBE tener un **alias numérico único** (número de identificación o teléfono).
    - Este alias es único a nivel de TODAS las tiendas del sistema, no solo dentro de una tienda.
    - **Justificación:** Garantiza que empleados de diferentes tiendas no se confundan durante la autenticación, permitiendo redireccionarlos correctamente a su tienda.

2. **Datos Obligatorios del Empleado:**
    - Nombre completo (para identificación humana).
    - Alias numérico (cédula o teléfono).
    - PIN de acceso de 4 dígitos.

3. **Autenticación Simple:**
    - El acceso operativo se realiza mediante un PIN numérico de 4 dígitos.
    - Este PIN es local y gestionado por el Admin.
    - El Admin puede restablecer el PIN en cualquier momento sin intervención del empleado.

4. **Capacidad de Venta por Defecto (Subordinada al Pase Diario):**
    - Todo empleado creado TIENE la capacidad base de operar el Punto de Venta (POS).
    - **Restricción Zero Trust:** Esta capacidad está bloqueada por defecto cada día. El empleado DEBE obtener un **Pase Diario** aprobado por el Admin (FRD-001) para poder ingresar al sistema.
    - **Restricción de Caja:** Si el turno de caja está cerrado, la capacidad de venta se degrada a "Solo Lectura" (no puede procesar pagos).

5. **Permisos Adicionales (POL-SEG-03):**
    - El acceso a funciones privilegiadas se controla estrictamente por booleanos (toggles) en el perfil del empleado. No hay jerarquías implícitas.
    - `canManageInventory`: Permite crear/editar productos, registrar Entradas de mercancía y procesar Reembolsos. (Nivel de riesgo: Alto).
    - `canViewInventory`: Permite buscar y consultar stock (Nivel de riesgo: Bajo).
    - `canFiar`: Permite seleccionar el método de pago "Fiado" para clientes en el POS.
    - `canOpenCloseCash`: Permite abrir y cerrar el turno de caja (requiere PIN adicional).
    - `canViewReports`: Permite ver el reporte parcial del turno activo.

6. **Estado Activo/Inactivo:**
    - Los empleados NO se eliminan para preservar el histórico de ventas.
    - Se marcan como "inactivo" para bloquear el acceso inmediato.
    - Al desactivar un empleado, cualquier sesión activa DEBE caducar inmediatamente.

7. **Límite de Equipo:**
    - Cada cuenta de Admin tiene un límite máximo de empleados activos definido por el parámetro `P_MAX_EMPLOYEES_PER_STORE`.
    - Si se alcanza este límite, el sistema DEBE bloquear la creación o activación de nuevos empleados.
    - Para agregar uno nuevo, el Admin DEBE desactivar previamente a uno existente.
    - Este límite se valida a nivel de servidor (RLS/RPC).

8. **Navegación del Listado de Empleados:**
   - El listado DEBE mostrar por defecto únicamente los empleados en estado **activo**.
   - El Admin DEBE poder activar un filtro para incluir empleados **inactivos** en la vista.
   - El listado DEBE permitir búsqueda por nombre o alias numérico.
   - Los empleados inactivos DEBEN distinguirse visualmente (ej. texto atenuado, badge "Inactivo").

---

## Casos de Uso

**Caso A: Crear Nuevo Empleado**
- **Actor:** Administrador
- **Precondición:** Tener menos de 5 empleados activos.
- **Flujo Principal:**
    1. Sistema valida conteo actual de empleados activos.
    2. Si hay 5 o más activos → Muestra error: "Límite alcanzado. Desactiva un usuario para continuar".
    3. Si hay menos de 5 → Permite abrir formulario.
    4. Admin ingresa: Nombre completo, Alias numérico (cédula/teléfono).
    5. Admin asigna PIN inicial de 4 dígitos.
    6. Admin configura los permisos adicionales según responsabilidades.
    7. Sistema valida unicidad global del alias numérico.
    8. Si el alias ya existe en alguna tienda → Error: "Este identificador ya está registrado en el sistema".
    9. Si el alias es único → Guarda empleado.
- **Postcondición:** Empleado creado, puede intentar login sujeto a aprobación diaria (ver FRD-001).

**Caso B: Restablecimiento de PIN**
- **Actor:** Administrador
- **Precondición:** Empleado existe en el sistema.
- **Flujo Principal:**
    1. Empleado notifica: "Olvidé mi PIN".
    2. Admin busca al empleado en la lista.
    3. Admin selecciona opción "Restablecer PIN".
    4. Admin ingresa nuevo PIN de 4 dígitos.
    5. Sistema actualiza el PIN inmediatamente.
- **Postcondición:** Empleado puede usar el nuevo PIN de inmediato.

**Caso C: Desactivar Empleado**
- **Actor:** Administrador
- **Precondición:** Empleado activo en el sistema.
- **Flujo Principal:**
    1. Admin selecciona empleado y elige "Desactivar".
    2. Sistema muestra confirmación: "¿Desactivar a [Nombre]? Perderá acceso inmediatamente."
    3. Admin confirma.
    4. Sistema marca empleado como inactivo.
    5. Sistema invalida cualquier sesión activa del empleado.
- **Postcondición:** Empleado no puede acceder al sistema hasta ser reactivado.

---

## Requisitos de Datos (Para Equipo Data)

**Entidad Empleado:**
- Identificador único
- Relación con Tienda (multitenant)
- Nombre completo
- Alias numérico (único global)
- Hash del PIN de 4 dígitos
- Estado activo/inactivo
- Permisos (estructura flexible para toggles)

---

## Criterios de Aceptación

- [ ] El alias numérico es único a nivel global del sistema (todas las tiendas).
- [ ] El PIN DEBE ser numérico estricto de 4 dígitos.
- [ ] Al desactivar un empleado, su sesión activa caduca inmediatamente.
- [ ] El sistema rechaza la creación o activación si se supera el límite `P_MAX_EMPLOYEES_PER_STORE`.
- [ ] El rechazo por límite ocurre en el servidor (Base de datos), no solo en la interfaz.
- [ ] Al buscar empleado por alias, el sistema lo redirige a la tienda correcta.
- [ ] El listado de empleados muestra por defecto solo los activos, con opción de incluir inactivos.
- [ ] El listado permite búsqueda por nombre o alias numérico.
