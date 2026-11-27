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

4. **Capacidades Operativas Base por Defecto (Subordinadas al Pase Diario, `FRD-003-01` R2):**
    - Todo empleado activo con **Pase Diario** aprobado (`FRD-001`) posee de base, bajo su propia cuenta (1 dispositivo por cuenta) y con su **firma individual obligatoria**:
      - Operar el Punto de Venta (POS) y registrar **Consumo/Retiro personal** (como una venta asignada a su propio perfil; solo el Admin puede elegir a otros) cuando la Caja Dedicada POS está abierta.
      - Registrar **gastos de caja** desde la Caja Dedicada POS cuando está abierta (con fondos en el canal, categoría del gasto y motivo).
      - Registrar **mermas** y **consumo del negocio** ($0 en Caja POS, sin requerir caja abierta).
      - Consultar únicamente **sus propios movimientos del turno actual, con toda su información**.
    - **Restricción de Caja:** Si el turno de caja está cerrado, las operaciones monetarias y ventas del POS quedan bloqueadas.

5. **Cuatro (4) Permisos Delegables (`POL-SEG-03`, gobernados por `FRD-003-01`):**
    - El acceso a funciones delegables se controla estrictamente por 4 interruptores booleanos en el perfil del empleado, todos apagados por defecto y sin jerarquías implícitas (ver alcance completo en `FRD-003-01`):
      1. **`Inventario completo` (`canManageInventory`):** Ver catálogo, stock, costos y Kardex; crear, editar y dar baja lógica a productos; registrar Entradas, **Ajustes por conteo físico** y **Devolución física a proveedor** ($0 en caja y sin tocar Cuentas por Pagar).
      2. **`Fiar y cobrar abonos` (`canFiar`):** Vender a fiado en POS respetando cupo, cobrar abonos con caja abierta y consultar ficha y estado de cuenta de clientes activos. (Crear, editar, cambiar cupos y eliminar clientes es exclusivo del Admin).
      3. **`Abrir/cerrar caja`:** Abrir turno en la Caja Dedicada POS declarando explícitamente la base inicial y cerrar **únicamente el turno que él mismo abrió** bajo **Cierre Asistido** exclusivamente sobre el efectivo físico del cajón evaluado con `P_MARGEN_DESCUADRE_EFECTIVO` (sin PIN adicional; hasta 3 intentos si supera el margen y alerta al Admin al tercer intento, guardando siempre la diferencia exacta al peso).
      4. **`Reembolsos` (`canManageRefunds`):** Ejecutar devoluciones desde el POS (al lado del buscador) con caja abierta y fondos en el canal, en una sola acción mediante la etiqueta opcional **`"merma"`** cuando el producto regresa dañado.
    - *(Nota: No existe permiso de `Ver inventario` separado ni permiso de `Ver reportes` para empleados; todos los reportes del negocio son 100% exclusivos del Administrador).*

6. **Estado Activo/Inactivo y Fotografía Histórica de la Firma (`POL-AUD-01`):**
    - Los empleados NO se eliminan para preservar el histórico de operaciones.
    - Se marcan como "inactivo" para bloquear el acceso inmediato y caducar cualquier sesión activa.
    - Todo movimiento conserva de forma inmutable la **fotografía histórica de la firma** (identificador, nombre y rol vigentes en el instante en que ocurrió el evento), incluso si el empleado es editado o desactivado posteriormente.

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
