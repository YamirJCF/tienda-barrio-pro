# FRD-003: Gestión de Empleados y Permisos

### Nombre de la Funcionalidad
Administración de Perfiles de Empleados

#### Descripción
Módulo administrativo que permite al Dueño/Manager crear, editar y desactivar perfiles de empleados. Este módulo es la fuente de verdad para la autenticación (PIN) y la autorización (Permisos) dentro del sistema POS.

#### Reglas de Negocio
1.  **Identificador Único:** Cada empleado debe tener un `username` (email o alias) único dentro de la tienda.
2.  **Autenticación Simple:** El acceso operativo se realiza mediante un **PIN numérico de 4 dígitos**.
    *   Este PIN es local y gestionado por el Admin.
    *   El Admin puede restablecer el PIN en cualquier momento sin intervención del empleado.
3.  **Capacidad de Venta (Default):**
    *   Todo empleado creado TIENE la capacidad de vender por defecto. No es un permiso opcional, es la función base del cargo.
4.  **Permisos Adicionales (Toggles):**
    *   `canViewInventory`: Puede ver stock (pero no editar).
    *   `canFiar`: Puede asignar crédito a clientes.
    *   `canOpenCloseCash`: Puede realizar arqueos de caja (Requiere PIN de Caja del Admin para validación final si así se configura, pero este permiso habilita la *función*).
    *   `canViewReports`: Puede ver métricas básicas.
4.  **Estado Activo/Inactivo:**
    *   No se eliminan empleados para preservar el histórico de ventas.
    *   Se marcan como `isActive: false` para bloquear el acceso inmediato.
5.  **Límite de Equipo (Business Constraints):**
    *   Cada cuenta de Admin tiene un **Límite Estricto de 5 Empleados Activos**.
    *   Si se alcanza el límite (5/5), el botón "Nuevo Empleado" se bloquea.
    *   Para agregar uno nuevo, el Admin DEBE desactivar previamente a uno existente.

#### Casos de Uso

**Caso A: Crear Nuevo Empleado**
- **Actor:** Administrador
- **Precondición:** Tener menos de 5 empleados activos.
- **Flujo:**
    1.  Sistema valida conteo actual de empleados activos.
    2.  Si `count >= 5` -> Muestra error: *"Límite alcanzado. Desactiva un usuario para continuar"*.
    3.  Si `count < 5` -> permite abrir formulario.
    4.  Admin entra a "Equipo" -> "Nuevo Empleado".
    5.  Ingresa Nombre (ej: "Juan Pérez") y Alias/Email (ej: "juan").
    3.  Asigna un PIN inicial de 4 dígitos (ej: "1234").
    4.  Configura los "Checkboxes" de permisos según las responsabilidades.
    5.  Guarda.
    6.  El empleado ya puede intentar login (Sujeto a FRD-001 Seguridad Diaria).

**Caso B: Olvido de PIN**
- **Actor:** Administrador
- **Flujo:**
    1.  Empleado avisa: "Olvidé mi PIN".
    2.  Admin busca al empleado en la lista.
    3.  Pulsa icono de "Llave/Candado".
    4.  Sobrescribe el PIN con uno nuevo.
    5.  Empleado usa el nuevo PIN inmediatamente.

#### Requisitos de Datos (Input para Equipo de Data)
Entidad `employees`:
*   `id` (BigInt/UUID): PK.
*   `store_id` (FK): Relación multitenant.
*   `full_name` (String).
*   `username` (String): Único por tienda.
*   `pin_hash` (String): Hash del PIN de 4 dígitos.
*   `is_active` (Boolean).
*   `permissions` (JSONB): Objeto flexible para toggles { canSell: true, ... }.

#### Criterios de Aceptación
- [ ] El PIN debe ser numérico estricto de 4 dígitos.
- [ ] Al desactivar un empleado, su sesión activa (si existe) debe caducar inmediatamente (Check en backend).
- [ ] El sistema impide duplicar `username` en la misma tienda.
- [ ] **Límite Hardcoded:** El backend rechaza la creación (`INSERT`) o activación (`UPDATE`) si `active_employees >= 5`.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| **EmployeeManagerView** | Ya implementado, requiere revisión de conexión con Supabase. |
| **AuthStore** | Debe consumir los permisos del JSONB al hacer login. |
