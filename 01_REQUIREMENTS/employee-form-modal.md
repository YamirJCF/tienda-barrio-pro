# Modal de Formulario de Empleado (EmployeeFormModal)

## Descripción
Modal para crear o editar información de empleados y sus permisos.

## Activación
- Desde `EmployeeManagerView` al presionar FAB (+) o click en empleado

## Flujo de Usuario

### Crear Empleado
1. Usuario abre modal (FAB)
2. Llena campos:
   - Nombre completo
   - Usuario de acceso
   - PIN de 4 dígitos
3. Configura permisos adicionales (opcionales)
4. Click "Guardar"
5. Empleado creado con permisos por defecto

### Editar Empleado
1. Usuario abre modal (click en empleado)
2. Campos precargados
3. Usuario deshabilitado (no editable)
4. Modifica nombre o permisos
5. Click "Guardar"

## Props de Entrada

| Prop | Tipo | Descripción |
|------|------|-------------|
| `modelValue` | `boolean` | Control de visibilidad |
| `employeeId` | `number?` | ID del empleado a editar |

## Eventos de Salida

| Evento | Parámetros | Descripción |
|--------|------------|-------------|
| `update:modelValue` | `boolean` | Cierra modal |
| `saved` | `Employee` | Empleado guardado |

## Campos del Formulario

| Campo | Tipo | Validación | Requerido |
|-------|------|------------|-----------|
| `name` | `string` | No vacío | ✅ |
| `username` | `string` | No vacío, único | ✅ |
| `pin` | `string` | Exactamente 4 dígitos | ✅ |

## Permisos (Checkboxes)

| Permiso | Default (Nuevo) | Descripción |
|---------|-----------------|-------------|
| Puede Vender | ✅ On | Acceso a POS |
| Puede Ver Inventario | ✅ On | Acceso a productos |
| Puede Ver Reportes | ❌ Off | Acceso a estadísticas |
| Puede Fiar | ❌ Off | Puede hacer ventas fiadas |

## Datos de Salida

### employeesStore
| Método | Uso |
|--------|-----|
| `addEmployee()` | Crear nuevo empleado |
| `updateEmployee()` | Actualizar existente |

## UI/UX

- Sección de seguridad destacada en azul
- Input de PIN centrado con tracking amplio
- Permisos como lista de checkboxes claros
- Botones de acción en footer fijo
