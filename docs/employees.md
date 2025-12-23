# Gestión de Empleados (EmployeeManagerView)

## Descripción
Vista para administrar empleados del negocio, sus permisos y accesos al sistema.

## Ruta
`/employees`

## Flujo de Usuario

### Ver Empleados
1. Usuario accede desde Admin Hub
2. Ve lista de empleados con:
   - Iniciales/avatar
   - Nombre
   - Etiqueta "Empleado"
   - Indicador de estado (punto verde = activo)
   - Toggle de activación

### Agregar Empleado
1. Click en botón FAB (+)
2. Se abre `EmployeeFormModal`
3. Llena campos:
   - Nombre completo
   - Usuario de acceso
   - PIN de 4 dígitos
4. Configura permisos (checkboxes)
5. Click "Guardar"

### Editar Empleado
1. Click en tarjeta de empleado
2. Se abre modal con datos cargados
3. Modifica campos deseados
4. Click "Guardar"

### Cambiar PIN Rápido
1. Click en icono de llave 🔑
2. Se abre modal de PIN
3. Ingresa nuevo PIN de 4 dígitos
4. Click "Guardar"

### Activar/Desactivar Empleado
1. Toggle el switch del empleado
2. Estado cambia inmediatamente
3. Empleado inactivo no puede hacer login

## Datos de Entrada (Stores Consumidos)

### employeesStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `employees` | `Employee[]` | Lista de todos los empleados |
| `activeEmployees` | `Employee[]` | Solo empleados activos |

## Datos de Salida (Hacia Stores)

### employeesStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `addEmployee()` | `Employee` | Agrega nuevo empleado |
| `updateEmployee()` | `id, data` | Actualiza empleado |
| `toggleActive()` | `id` | Cambia estado activo/inactivo |
| `updatePin()` | `id, newPin` | Cambia PIN del empleado |

## Estructura de Empleado

```typescript
interface Employee {
  id: number;
  name: string;
  username: string;
  pin: string;  // 4 dígitos
  permissions: EmployeePermissions;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

interface EmployeePermissions {
  canSell: boolean;         // Por defecto: true
  canViewInventory: boolean; // Por defecto: true
  canViewReports: boolean;   // Por defecto: false
  canFiar: boolean;          // Por defecto: false
}
```

## Permisos por Defecto (Nuevo Empleado)
| Permiso | Valor |
|---------|-------|
| Puede Vender | ✅ Sí |
| Puede Ver Inventario | ✅ Sí |
| Puede Ver Reportes | ❌ No |
| Puede Fiar | ❌ No |

## Navegación

### Desde
- Admin Hub → "Empleados y Permisos"

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Admin Hub | Botón ← | `/admin` |

## Componentes Utilizados
- `EmployeeFormModal.vue` - Formulario de empleado
- `BottomNav.vue` - Navegación inferior
- Modal de PIN (inline)

## Stores Utilizados
- `useEmployeesStore`
