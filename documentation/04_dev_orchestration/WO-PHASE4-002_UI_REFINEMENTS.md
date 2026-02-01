## Orden de Trabajo - Refinamientos de UI (IN-02, PE-05, CL-01)

### Contexto
Corrección de discrepancias visuales y de permisos en módulos de Inventario, Personal y Clientes.

### Estado Git Actual
- Rama a crear: `fix/ux-ui-refinements`
- Comando: `git checkout -b fix/ux-ui-refinements`

---

### Plan de Acción Atómico

#### Tarea 1: Ocultar Costos (IN-02)
**Archivo**: `src/components/inventory/ProductFormModal.vue`
1.  Importar `useAuthStore`.
2.  En el campo "Costo", agregar `v-if="authStore.isAdmin"`.
3.  Asegurar que si se guarda un producto editado por un empleado, el costo existente no se pierda (el payload debe manejar esto o el backend). *Nota: Idealmente el backend ignora el campo si no viene, pero el frontend no debe enviarlo vacío si ya existía.*

#### Tarea 2: Confirmación Desactivación (PE-05)
**Archivo**: `src/views/EmployeeManagerView.vue` (o componente de lista)
1.  En el toggle/switch de "Activo", interceptar el evento `@click` o `@change`.
2.  Si va a desactivar (pasar de true a false), mostrar `BaseModal` de confirmación:
    *   "¿Estás seguro de desactivar a [Nombre]?"
    *   "No podrá acceder al sistema hasta que se reactive."

#### Tarea 3: Cupo en Lista Clientes (CL-01)
**Archivo**: `src/views/ClientListView.vue` (o `ClientCard.vue`)
1.  En la tarjeta de cada cliente, agregar una línea/badge para "Cupo Disponible" o "Cupo Total".
2.  Formato: "Cupo: $X".
3.  Visualmente menos prominente que el Balance (Deuda).

### Bloque de Prompt para Antigravity

```markdown
## Prompt para IN-02, PE-05, CL-01

### Contexto
- `src/components/inventory/ProductFormModal.vue`
- `src/views/EmployeeManagerView.vue`
- `src/views/ClientListView.vue`

### Objetivos
1. **ProductFormModal**: Ocultar input "Costo" si `!authStore.isAdmin`.
2. **EmployeeManagerView**: Agregar diálogo de confirmación antes de desactivar un empleado. Implementar la lógica usando `BaseModal` o `window.confirm` si se prefiere agilidad (pero mejor Modal).
3. **ClientListView**: Mostrar la propiedad `creditLimit` en la tarjeta del cliente, formateada como moneda.
```
