# Modal de Formulario de Cliente (ClientFormModal)

## Descripción
Modal para crear o editar información de clientes.

## Activación
- Desde `ClientListView` al presionar FAB (+) o editar cliente

## Flujo de Usuario

### Crear Cliente
1. Usuario abre modal (FAB)
2. Llena campos:
   - Nombre completo (requerido)
   - Cédula (requerido, único)
   - Teléfono (opcional)
   - Cupo máximo de crédito
3. Click "Guardar Cliente"
4. Cliente creado con balance = 0

### Editar Cliente
1. Usuario abre modal (click en cliente)
2. Campos precargados
3. Cédula deshabilitada (no editable)
4. Modifica campos
5. Click "Guardar Cliente"

## Props de Entrada

| Prop | Tipo | Descripción |
|------|------|-------------|
| `modelValue` | `boolean` | Control de visibilidad |
| `clientId` | `number?` | ID del cliente a editar |

## Eventos de Salida

| Evento | Parámetros | Descripción |
|--------|------------|-------------|
| `update:modelValue` | `boolean` | Cierra modal |
| `saved` | `Client` | Cliente guardado |

## Campos del Formulario

| Campo | Tipo | Validación | Requerido |
|-------|------|------------|-----------|
| `name` | `string` | No vacío | ✅ |
| `cedula` | `string` | No vacío, único | ✅ |
| `phone` | `string` | - | ❌ |
| `creditLimit` | `number` | >= 0 | ❌ (default: 0) |

## Datos de Salida

### clientsStore
| Método | Uso |
|--------|-----|
| `addClient()` | Crear nuevo cliente |
| `updateClient()` | Actualizar existente |

## UI/UX

- Campo de cédula destacado con borde azul
- Etiqueta "Requerido" en cédula
- Iconos en cada campo para claridad
- Footer fijo con botones Cancelar/Guardar
