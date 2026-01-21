# Gestión de Empleados (EmployeeManagerView)

## Descripción
Vista para administrar empleados del negocio, sus permisos y accesos al sistema.

## Ruta
`/employees`

## Flujo de Usuario

### Ver Empleados
1. Usuario accede desde Admin Hub
2. Ve lista de empleados con:
   - Iniciales/avatar (color generado por nombre)
   - Nombre
   - Etiqueta "Empleado"
   - Indicador de estado (punto verde = activo)
   - Botón de editar PIN (icono llave)
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
2. Se abre modal de PIN (Teleport)
3. Ingresa nuevo PIN de 4 dígitos (solo números)
4. Click "Guardar"

### Activar/Desactivar Empleado
1. Toggle el switch del empleado
2. Estado cambia inmediatamente
3. Empleado inactivo no puede hacer login
4. Empleado inactivo aparece con opacidad reducida

---

## Datos de Entrada (Stores Consumidos)

### useEmployeesStore
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `employees` | `Employee[]` | Lista de todos los empleados |
| `activeEmployees` | `Employee[]` | Solo empleados activos |

---

## Datos de Salida (Hacia Stores)

### useEmployeesStore
| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `initializeSampleData()` | - | Inicializa datos de muestra |
| `addEmployee()` | `Employee` | Agrega nuevo empleado |
| `updateEmployee()` | `id, data` | Actualiza empleado |
| `toggleActive()` | `id` | Cambia estado activo/inactivo |
| `updatePin()` | `id, newPin` | Cambia PIN del empleado |

---

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
  canSell: boolean;          // ✅ Locked (Siempre true)
  canViewInventory: boolean; // ✅ Implícito (Siempre true)
  canManageInventory?: boolean; // 🆕 Control total de inventario
  canManageClients?: boolean;   // 🆕 Control total de clientes
  canOpenCloseCash?: boolean;   // 🆕 Abrir/Cerrar Caja
  canViewReports: boolean;   // ❌ Hidden (Siempre false)
  canFiar: boolean;          // ❌ Hidden (Siempre false)
}
```

---

## Permisos Configurables (UI)
| Permiso | Variable | Comportamiento |
|---------|----------|----------------|
| **Puede Vender** | `canSell` | ✅ **Bloqueado**. Todo empleado puede vender. |
| **Inventario (Acceso Completo)** | `canManageInventory` | Habilita Crear/Editar/Eliminar productos. |
| **Caja (Abrir/Cerrar)** | `canOpenCloseCash` | Permite abrir la tienda y gestionar cortes de caja. |

> [!NOTE]
> `canViewInventory` es siempre `true`. `canViewReports` y `canFiar` son siempre `false` por defecto y no se muestran en el formulario.

---

## Navegación

### Desde
- Admin Hub → "Empleados y Permisos"

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Admin Hub | Botón ← (goBack) | `/admin` |

---

## Componentes Utilizados
- `EmployeeFormModal.vue` - Formulario de empleado
- `BottomNav.vue` - Navegación inferior
- Modal de PIN (inline, Teleport)

## Stores Utilizados
- `useEmployeesStore`
