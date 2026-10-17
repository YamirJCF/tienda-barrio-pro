# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-003)

> **Componente Auditado:** `frontend/src/views/EmployeeManagerView.vue`, `frontend/src/components/EmployeeFormModal.vue` (y repositorio `frontend/src/data/repositories/employeeRepository.ts`, store `frontend/src/stores/employees.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_003_GESTION_EMPLEADOS.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_003_GESTION_EMPLEADOS.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/EmployeeManagerView.vue` (`/employees`)
- **Modales y Fichas:**
  - `frontend/src/components/EmployeeFormModal.vue` (Formulario de alta y edición de permisos)
- **Capa de Datos y Repositorios:**
  - `frontend/src/data/repositories/employeeRepository.ts`
  - `frontend/src/stores/employees.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz (Payloads y Errores)

### 5.1 Endpoint de Creación: `crear_empleado`
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Payload de Entrada:**
  - `p_store_id` (UUID, Obligatorio)
  - `p_name` (TEXT, 2-100 caracteres)
  - `p_username` (TEXT, único global, patrón `^[a-zA-Z0-9_-]+$`)
  - `p_pin` (TEXT, exactamente 4 dígitos `^[0-9]{4}$`)
  - `p_permissions` (JSONB: `canManageInventory`, `canViewInventory`, `canFiar`, `canOpenCloseCash`, `canViewReports`)
- **Payload de Salida:** `ActionResponse { success: true, data: { employee_id: UUID } }`

### 5.4 Endpoint de Listado Seguro: `rpc_obtener_empleados`
- **Tipo:** RPC Postgres / Lectura (READ)
- **Payload de Entrada:**
  - `p_store_id` (UUID, Obligatorio)
  - `p_include_inactive` (BOOLEAN, Default false)
  - `p_search_query` (TEXT, Opcional)
  - `p_limit` (INTEGER, Default 50)
  - `p_offset` (INTEGER, Default 0)
- **Payload de Salida:** Contrato canónico `{ data: Employee[], count: number }` con máscara de PIN (`pin = ''`).
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componentes identificados y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `crear_empleado`, `actualizar_pin_empleado`, `toggle_empleado_activo`
- **Invocaciones RPC:**
  - Código real: En `employeeRepository.ts:132-138`, `crear_empleado`; en `employeeRepository.ts:179-182`, `actualizar_pin_empleado`; en `employeeRepository.ts:209-212`, `toggle_empleado_activo`.
  - Resultado: **Presente y Conforme**.

### Operación: `rpc_obtener_empleados`
- **Invocación RPC:**
  - Código real: En `employeeRepository.ts:100`, `getAll: (storeId) => baseRepository.getAll(storeId)`. Hace un `SELECT * FROM employees` directo vía PostgREST ignorando `rpc_obtener_empleados`.
  - Resultado: **Discrepancia Crítica**.

---

## Bloque 2b — Verificación de Límites Financieros y Lógica de Negocio

- **Límite de Cupo Máximo (5 Empleados Operativos Activos - RN-7 y RN-013-02):**
  - El backend valida el tope en `crear_empleado` y `toggle_empleado_activo`.
  - En el frontend, `EmployeeManagerView.vue:80-82` bloquea la creación si `activeEmployees.length >= 5` disparando un `alert()` nativo.
- **Exclusión del Dueño (`owner_*`) en Cupo de Empleados (`D-4`):**
  - En `EmployeeManagerView.vue:48` y `employees.ts:22`, se filtra en memoria `!e.username.startsWith('owner_')` para evitar que la cuenta técnica del dueño consuma un cupo en la UI.
- **Erradicación del PIN de Caja Secundario (`SPEC-006`):**
  - Cumplido: no existe segundo PIN para apertura o cierre de turno.

---

## Bloque 3 — Verificación de Manejo de Errores

| Código de Error SDD | Estado en Código Actual | Tratamiento en UI | Conforme |
|---|---|---|---|
| `EMPLOYEE_LIMIT_REACHED` | Capturado en catch | Muestra mensaje de error en formulario | ✅ Sí |
| `USERNAME_ALREADY_EXISTS` | Validado local y backend | Muestra "El nombre de usuario ya está registrado" | ✅ Sí |
| `INVALID_PIN_FORMAT` | Validado local y backend | Regex en frontend y constraint en DB | ✅ Sí |
| `STORE_ACCESS_DENIED` | No capturado específicamente | Mensaje genérico de error | 🟡 Parcial |

---

## Bloque 4 — Verificación de Estados de Carga e Interacción

- **Skeletons / Loading State:** `EmployeeManagerView.vue` utiliza `useAsyncAction` para bloquear el botón de conmutar estado y el cambio de PIN evitando pulsaciones dobles.
- **Modales de Confirmación:** `EmployeeManagerView.vue:99-113` presenta modal explícito de confirmación antes de desactivar un empleado.

---

## Bloque 5 — Resumen de Discrepancias y Plan de Acción

### 5.1 Conteo Mecánico de Hallazgos (Regla 9.1: N = 4)
- **UX-1 (Severidad Alta):** Bypasseo de `rpc_obtener_empleados`. En `employeeRepository.ts:100`, `getAll(storeId)` invoca `baseRepository.getAll(storeId)` que hace un `SELECT * FROM employees` directo vía PostgREST, en lugar de invocar `supabase.rpc('rpc_obtener_empleados', { p_store_id, p_include_inactive, p_search_query, p_limit, p_offset })`. Esto omite la validación obligatoria `assert_store_access` y la paginación formal `{ data, count }`.
- **UX-2 (Severidad Media):** Uso de `alert()` nativo en control de cupo máximo. En `EmployeeManagerView.vue:81`, `alert("Límite de empleados activos alcanzado...")` interrumpe la navegación con un diálogo nativo del navegador en lugar de mostrar un modal informativo o un toast de advertencia.
- **UX-3 (Severidad Media):** Filtrado heurístico del propietario en el cliente. En `EmployeeManagerView.vue:48` y `employees.ts:22`, se filtra en memoria `!e.username.startsWith('owner_')` para que el dueño no consuma visualmente un cupo de empleado, en vez de recibir desde `rpc_obtener_empleados` la lista ya desglosada y el indicador de cupo operacional calculado por el servidor (`D-4`).
- **UX-4 (Severidad Baja):** Ausencia de controles de paginación y búsqueda en servidor en la UI. `EmployeeManagerView.vue` renderiza todos los empleados en una lista plana en memoria sin aprovechar los parámetros `p_search_query`, `p_limit`, `p_offset` del RPC canónico.

---

### 5.2 Auto-Chequeo Anti-Sesgo (Regla 9.4)
- **9.1 Invariante de Reconciliación:** $N = 4$ hallazgos documentados en el Bloque 5.1 y citados exactamente.
- **9.2 No-Fusión de Dimensiones:** El correcto uso de `crear_empleado` y `actualizar_pin_empleado` no disculpa el `SELECT *` directo en `getAll`.
- **9.3 Cita de Fuentes:** Las discrepancias se sustentan en `employeeRepository.ts:100`, `EmployeeManagerView.vue:48, 81` y `employees.ts:22`.
- **9.4 Veredicto:** 🟡 **CON OBSERVACIONES (4 discrepancias detectadas)**.

---

## 📌 Instrucción para el Orquestador (Etapa 4)

1. En `frontend/src/data/repositories/employeeRepository.ts`:
   - Conectar `getAll` a `supabase.rpc('rpc_obtener_empleados', { p_store_id: storeId, p_include_inactive: true })`, retornando el contrato `{ data, count }`.
2. En `frontend/src/views/EmployeeManagerView.vue`:
   - Sustituir `alert()` nativo por un modal o toast de aviso cuando se intente agregar empleados sobre el cupo máximo de 5.
   - Mostrar el contador de cupo oficial (`X/5 empleados activos`).
