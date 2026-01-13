# Login (LoginView)

## Descripción
Pantalla de autenticación para acceder al sistema.

## Ruta
`/login`

## Flujo de Usuario

### Login con PIN (Empleado)
1. Usuario selecciona su nombre de la lista
2. Ingresa PIN de 4 dígitos
3. Sistema valida credenciales
4. Si válido → Redirige a Dashboard
5. Si inválido → Muestra error

### Login Dueño/Admin
1. Ingresa credenciales de administrador
2. Acceso completo al sistema

## Datos de Entrada (Usuario)

| Campo | Tipo | Validación |
|-------|------|------------|
| `username` | `string` | Requerido |
| `pin` | `string` | 4 dígitos exactos |

## Datos de Salida (Validación)

### employeesStore
| Método | Parámetros | Retorno |
|--------|------------|---------|
| `validatePin()` | `username, pin` | `Employee \| null` |

## Validaciones

1. **Usuario existe**: Verificar en lista de empleados
2. **Empleado activo**: Solo empleados con `isActive: true`
3. **PIN correcto**: Coincide con el almacenado

## Estados de Error

| Error | Mensaje |
|-------|---------|
| Usuario no encontrado | "Usuario no existe" |
| Empleado inactivo | "Usuario desactivado" |
| PIN incorrecto | "PIN incorrecto" |

## Navegación

### Desde
- Inicio de sesión expirada
- Logout

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Dashboard | Login exitoso | `/` |

## Stores Utilizados
- `useEmployeesStore`

## Notas de Implementación
> ⚠️ Esta vista está parcialmente implementada. La validación con el store de empleados aún requiere integración completa.
