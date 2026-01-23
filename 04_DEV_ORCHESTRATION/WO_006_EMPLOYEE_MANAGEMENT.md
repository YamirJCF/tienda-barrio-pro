# Orden de Trabajo - Gestión de Empleados (WO-006)

**Referencia:** [QA Audit FRD-003](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/04_DEV_ORCHESTRATION/QA_AUDIT_FRD_003.md)
**Objetivo:** Alinear el módulo de empleados con las Reglas de Negocio del FRD-003, implementando límites duros, unicidad y la matriz de permisos correcta.

---

## 🏗️ Fase 1: Reglas de Negocio (Backend/Store)

### Tarea 1.1: Límite de Empleados y Validación
*   **Rama:** `fix/employee-business-rules`
*   **Objetivo:** Impedir la creación de más de 5 empleados activos y nombres de usuario duplicados.
*   **Prompt Antigravity:**
    ```markdown
    ## Prompt: Reforzar Reglas de Negocio en Employees Store

    ### Contexto
    Archivo: `src/stores/employees.ts`
    
    ### Requerimientos
    1.  **Límite de Equipo:**
        -   Modificar `addEmployee` y `toggleActive` (caso activación).
        -   Si `activeEmployees.length >= 5`: Lanzar error o retornar false.
        -   No permitir crear ni activar el 6to empleado.
    
    2.  **Unicidad:**
        -   Modificar `addEmployee` y `updateEmployee`.
        -   Verificar que `username` no exista ya (case insensitive).
        -   Excluir el propio ID en caso de edición.
    ```

---

## 🏗️ Fase 2: Interfaz de Usuario (UI/UX)

### Tarea 2.1: Bloqueo Visual y Feedback
*   **Rama:** `fix/employee-business-rules`
*   **Objetivo:** Reflejar las restricciones en la vista principal.
*   **Prompt Antigravity:**
    ```markdown
    ## Prompt: UI para Límite de Empleados

    ### Contexto
    Archivo: `src/views/EmployeeManagerView.vue`
    
    ### Cambios
    1.  **Botón "Nuevo Empleado"**:
        -   Deshabilitar si `employeesStore.activeEmployees.length >= 5`.
        -   Mostrar texto secundario o tooltip: "Límite de 5 activos alcanzado".
    2.  **Toggle Switch**:
        -   Manejar el rechazo del store. Si el store impide activar (por límite), revertir el switch visualmente y mostrar alerta/toast.
    ```

### Tarea 2.2: Refactorización de Formulario (Permisos)
*   **Rama:** `fix/employee-permissions-matrix`
*   **Objetivo:** Ajustar los checkboxes a los requerimientos reales (FRD-003).
*   **Prompt Antigravity:**
    ```markdown
    ## Prompt: Corregir Matriz de Permisos

    ### Contexto
    Archivo: `src/components/EmployeeFormModal.vue` y `src/stores/employees.ts` (Interface).
    
    ### Matriz de Permisos Correcta (FRD-003)
    Eliminar "canManageInventory". Implementar lo siguiente:
    1.  `canSell`: Default true, disabled (siempre visible).
    2.  `canViewInventory`: Checkbox opcional.
    3.  `canFiar`: Checkbox opcional (Nuevo).
    4.  `canViewReports`: Checkbox opcional (Nuevo).
    5.  `canOpenCloseCash`: Checkbox opcional (Existente).
    
    ### Acción
    -   Actualizar la interfaz `EmployeePermissions` en el store.
    -   Actualizar el template del modal con los nuevos campos.
    ```
