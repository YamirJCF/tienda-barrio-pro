## Orden de Trabajo - Eliminación Segura de Clientes (CL-06)

### Contexto
El sistema actual permite eliminar clientes incluso si tienen deuda pendiente. Esto representa un riesgo financiero grave (pérdida de cuentas por cobrar).
**Objetivo**: Bloquear la eliminación de cualquier cliente cuyo `balance` sea mayor a 0.

### Estado Git Actual
- Rama a crear: `feat/cl-06-safe-deletion`
- Comando: `git checkout -b feat/cl-06-safe-deletion`

---

### Plan de Acción Atómico

#### Tarea 1: Lógica de Negocio (Store)
**Archivo**: `src/stores/clients.ts`
1.  Modificar `deleteClient(id)`:
    -   Validar si `client.balance > 0`.
    -   Si es mayor a 0, retornar `{ success: false, error: 'DEBT_PENDING' }` (o lanzar error controlable).
    -   Si es <= 0, proceder con la eliminación y retornar `{ success: true }`.

#### Tarea 2: Interfaz de Usuario (View)
**Archivo**: `src/views/ClientDetailView.vue`
1.  Modificar `confirmDelete()`:
    -   Verificar `client.balance`.
    -   Si tiene deuda: Mostrar modal de **"Acción Denegada"** (Icono Alerta Rojo, Texto explicativo "El cliente debe $X. Registre el pago total antes de eliminar.").
    -   Si NO tiene deuda: Mostrar el modal de confirmación estándar actual.
2.  Deshabilitar visualmente la opción "Eliminar" en el menú dropdown (opcional, pero mejor UX es dejarla habilitada y explicar por qué no se puede al hacer clic).

### Bloque de Prompt para Antigravity

```markdown
## Prompt para CL-06 (Safe Deletion)

### Contexto
- Store: `src/stores/clients.ts`
- Vista: `src/views/ClientDetailView.vue`

### Requerimientos
1. **Validación en Store**:
   - `deleteClient` debe impedir borrar si `balance > 0`.
   - Retornar boolean o objeto respuesta.

2. **UX en Vista**:
   - Al intentar borrar un cliente moroso:
     - No abrir el "Delete Confirmation".
     - Abrir un nuevo estado de modal `showDebtAlert`.
     - Mensaje: "No se puede eliminar a [Nombre]. Tiene una deuda pendiente de [Monto]. Por favor regularice el saldo primero."
     - Botón único: "Entendido".
```

### Comandos de Consola
```bash
git checkout -b feat/cl-06-safe-deletion
```
