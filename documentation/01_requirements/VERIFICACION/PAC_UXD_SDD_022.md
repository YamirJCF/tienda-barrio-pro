# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-022)

> **Componente Auditado:** `frontend/src/views/ExpensesView.vue` (y repositorios auxiliares `frontend/src/data/repositories/cashRepository.ts`, `frontend/src/data/repositories/expenseRepository.ts`, store `frontend/src/stores/cashRegister.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_022_GASTOS_MULTICANAL.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_022_GASTOS_MULTICANAL.md) (y política [`SDD_026_POLITICA_GASTOS_INMEDIATOS.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_026_POLITICA_GASTOS_INMEDIATOS.md))  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/ExpensesView.vue`
- **Capa de Datos y Repositorios:**
  - `frontend/src/data/repositories/cashRepository.ts`
  - `frontend/src/data/repositories/expenseRepository.ts`
  - `frontend/src/stores/cashRegister.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.1 Operación: `rpc_registrar_gasto_v2`
- **Tipo:** Postgres RPC (Función Almacenada) / Acción (WRITE)
- **Modo:** `SECURITY DEFINER` con Search Path seguro (`SET search_path = public, pg_temp;`).
- **Firma de Entrada:**
  ```json
  {
    "p_session_id": "UUID (Obligatorio — Identificador de la sesión de caja)",
    "p_amount": "NUMERIC (Obligatorio — Monto entero COP > 0)",
    "p_payment_method": "TEXT (Obligatorio — Valores: 'efectivo', 'nequi', 'llave_bre')",
    "p_category": "TEXT (Obligatorio — Valores: 'Servicios', 'Nomina', 'Transporte', 'Mantenimiento', 'Insumos', 'Reembolso')",
    "p_description": "TEXT (Obligatorio — Longitud mínima 3 caracteres, sin contar prefijos)"
  }
  ```
- **Payload de Respuesta Exitosa (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "movement_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "session_id": "b3e1a6c0-1234-4567-89ab-cdef01234567",
      "amount": 15000,
      "payment_method": "nequi",
      "category": "Servicios",
      "description": "[Servicios] [CANAL:nequi] Recibo de energía eléctrica",
      "movement_type": "gasto",
      "created_at": "2026-10-14T14:30:00Z"
    }
  }
  ```
- **Catálogo Exhaustivo de Errores:**
  | Código de Error | Causa de Negocio | Mensaje Técnico / HINT |
  |-----------------|------------------|------------------------|
  | `STORE_ACCESS_DENIED` | Usuario no pertenece a la tienda o carece de sesión válida | El usuario no tiene acceso a esta tienda |
  | `NO_OPEN_SESSION` | La sesión indicada no existe o se encuentra en estado `'closed'` | No existe una sesión de caja activa para registrar el gasto |
  | `SESSION_EXPIRED` | La sesión de caja tiene más de 24 horas transcurridas desde su apertura | La sesión de caja ha expirado (> 24h) y debe reconciliarse antes de registrar egresos |
  | `INVALID_AMOUNT` | El parámetro `p_amount` es menor o igual a cero o nulo | El monto del gasto debe ser un valor numérico estrictamente positivo |
  | `INVALID_PAYMENT_METHOD` | El canal suministrado no corresponde a `'efectivo'`, `'nequi'` ni `'llave_bre'` | Canal de pago no válido. Permitidos: efectivo, nequi, llave_bre |
  | `INVALID_OPEX_CATEGORY` | La categoría no pertenece al catálogo de las 6 categorías autorizadas por SDD-026 | Categoría OPEX no autorizada. Permitidas: Servicios, Nomina, Transporte, Mantenimiento, Insumos, Reembolso |
  | `EMPTY_DESCRIPTION` | La descripción suministrada está vacía o tiene menos de 3 caracteres | La descripción o motivo del gasto es obligatoria (mínimo 3 caracteres) |
  | `INSUFFICIENT_FUNDS` | La liquidez disponible en el canal seleccionado es inferior al monto a desembolsar | Fondos insuficientes en el canal monetario seleccionado |
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_registrar_gasto_v2`
- **Campo `p_session_id`:**
  - Código real: En `cashRegister.ts:324` se pasa `currentSession.value.id`. Sin embargo, en `cashRepository.ts:275` se asigna a `session_id` en una inserción directa a la tabla `cash_movements`. La función RPC `rpc_registrar_gasto_v2` no es invocada.
  - Resultado: **Discrepancia en canal de transporte (Insert directo en lugar de RPC)**.
- **Campo `p_amount`:**
  - Código real: `ExpensesView.vue:54` pasa `new Decimal(newExpense.value.amount)`. `cashRepository.ts:277` lo inserta directamente como `amount`.
  - Resultado: **Presente**.
- **Campo `p_payment_method`:**
  - Código real: Ausente en el formulario de `ExpensesView.vue:133-168`. El componente no tiene selector de método de pago; no se captura `'efectivo'`, `'nequi'` ni `'llave_bre'`. `cashRepository.ts:272-281` ni siquiera envía la columna `payment_method`.
  - Resultado: **Ausente (Falla Crítica de Contrato)**.
- **Campo `p_category`:**
  - Código real: `ExpensesView.vue:28` define `categories = ['General', 'Proveedor', 'Servicios', 'Comida', 'Transporte', 'Mantenimiento']`.
  - Contrato: Las categorías autorizadas en SDD-022 y SDD-026 son estrictamente: `'Servicios'`, `'Nomina'`, `'Transporte'`, `'Mantenimiento'`, `'Insumos'`, `'Reembolso'`. Las opciones `'General'`, `'Proveedor'` y `'Comida'` son inválidas. Además, `cashRepository.ts:272-281` omite el campo `category` en la inserción directa.
  - Resultado: **Discrepancia y Categorías Inválidas (Falla Crítica)**.
- **Campo `p_description`:**
  - Código real: `ExpensesView.vue:55` pasa `newExpense.value.description`. `cashRepository.ts:278` lo envía como `description`.
  - Resultado: **Presente**.

### B2.5 CHECKPOINT Bloque 2
Se identifican omisiones críticas: ausencia total del canal de pago (`p_payment_method`), catálogo de categorías incompatible con SDD-026, y bypass del RPC en favor de una inserción directa a tabla.

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 Búsqueda de Cálculos en Cliente:**
  - En `cashRegisterStore.ts:52-57`:
    ```typescript
    const totalExpenses = computed(() => {
        if (!currentSession.value) return new Decimal(0);
        return currentSession.value.transactions
            .filter(t => t.type === 'expense')
            .reduce((sum, t) => sum.plus(new Decimal(t.amount)), new Decimal(0));
    });
    ```
  - En `ExpensesView.vue:99`:
    ```html
    <p class="text-3xl font-black text-red-500">{{ formatCurrency(totalExpenses) }}</p>
    ```
  - En `cashRegisterStore.ts:31-50`: `balancesByMethod` calcula los saldos restando montos en el frontend sin reconciliar con el backend.
- **B2.7 CHECKPOINT Bloque 2b:**
  - Se detecta agregación client-side de saldos y egresos acumulados. Aunque sirve como preview local, la autoridad del saldo real por canal debe ser garantizada por el backend mediante `rpc_registrar_gasto_v2` con validación de `INSUFFICIENT_FUNDS`.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del Diagrama de Secuencia y Casos de Uso
1. `Caja Cerrada / Sin Sesión` (`NO_OPEN_SESSION`)
2. `Sesión Expirada (> 24 horas)` (`SESSION_EXPIRED`)
3. `Fondos Insuficientes` (`INSUFFICIENT_FUNDS`)
4. `Categoría Inválida` (`INVALID_OPEX_CATEGORY`)
5. `Registro Exitoso` (`200 OK`)

### B3.9 Búsqueda en Código
- **Estado 1 (Caja Cerrada):**
  - Línea real: `ExpensesView.vue:86-94` (`v-if="!isSessionOpen"`, muestra banner de caja cerrada y oculta el FAB de añadir). Manejado visualmente.
- **Estado 2 (Sesión Expirada > 24h):**
  - Línea real: No existe validación ni aviso de sesión expirada en `ExpensesView.vue`. El usuario puede pulsar guardar y, al no llamar al RPC, la inserción directa evade el bloqueo de 24h.
  - Resultado: **Ausente en UI**.
- **Estado 3 (Fondos Insuficientes):**
  - Línea real: No existe chequeo previo ni manejo del error `INSUFFICIENT_FUNDS`. Al hacer insert directo, no se verifica la liquidez del canal.
  - Resultado: **Ausente en UI**.
- **Estado 4 (Categoría Inválida):**
  - Línea real: La UI ofrece opciones no autorizadas (`General`, `Comida`, `Proveedor`).
  - Resultado: **No conforme**.
- **Estado 5 (Registro Exitoso):**
  - Línea real: `ExpensesView.vue:64` (`successMessage: 'Gasto registrado correcto'`). Manejado.

### B3.10 Cruce Explícito
- Estado 1: Sí.
- Estado 2: No.
- Estado 3: No.
- Estado 4: No.
- Estado 5: Sí.

### B3.11 CHECKPOINT Bloque 3
3 de los 5 estados de excepción del negocio no son gestionados ni capturados por el frontend debido al uso de inserción directa a tabla.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12 Formateo Monetario:**
  - En `ExpensesView.vue:5`: `import { useCurrencyFormat } from '../composables/useCurrencyFormat';`
  - En `ExpensesView.vue:99`: `{{ formatCurrency(totalExpenses) }}`
  - En `ExpensesView.vue:115`: `-{{ formatCurrency(expense.amount) }}`
  - En `ExpensesView.vue:136`: `<FormInputCurrency v-model="newExpense.amount" ... />`
- **B4.13 CHECKPOINT Bloque 4:**
  - Cumple con `SPEC-011` usando `FormInputCurrency` y `useCurrencyFormat` (COP sin decimales, separador de miles con punto).

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 Restricción de Rol:**
  - SDD-022 permite registro de gastos tanto a Administradores como a Cajeros con turno abierto.
- **B5.15 Implementación:**
  - Se valida sesión activa con `isSessionOpen` (`ExpensesView.vue:86, 121`).
- **B5.16 CHECKPOINT Bloque 5:**
  - Conforme para permisos generales de caja.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | Inserción directa en tabla `cash_movements` en `cashRepository.ts:272-281` y `expenseRepository.ts:200` evadiendo la invocación a `rpc_registrar_gasto_v2` de SDD-022 §5.1, omitiendo la validación server-side de acceso, expiración de 24h, categoría y liquidez del canal. | Bloque 2 (B2.4) | 🔴 Alta |
| UX-2 | Catálogo de categorías OPEX en `ExpensesView.vue:28` (`['General', 'Proveedor', 'Servicios', 'Comida', 'Transporte', 'Mantenimiento']`) viola SDD-022 §5.1 y SDD-026 §3.1 (solo autoriza `'Servicios'`, `'Nomina'`, `'Transporte'`, `'Mantenimiento'`, `'Insumos'`, `'Reembolso'`). | Bloque 2 (B2.4) | 🔴 Alta |
| UX-3 | Ausencia de selector de canal de pago (`p_payment_method`) en el modal de registro de gasto (`ExpensesView.vue:133-168`), impidiendo registrar egresos multicanal ('efectivo', 'nequi', 'llave_bre'). | Bloque 2 (B2.4) | 🔴 Alta |
| UX-4 | Agregación de gastos y saldos por canal calculada exclusivamente en el frontend (`cashRegisterStore.ts:31-57`) sin reconciliación con el backend. | Bloque 2b (B2.6) | 🟡 Media |
| UX-5 | Captura silenciosa de errores en `expenseRepository.ts:207-208` retornando `null` y enmascarando los códigos de error del backend (`INSUFFICIENT_FUNDS`, `SESSION_EXPIRED`) para el usuario. | Bloque 3 (B3.9) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:**
  - Al detectarse 3 hallazgos de severidad ALTA (UX-1, UX-2, UX-3), el frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. Modificar `cashRepository.ts` / `expenseRepository.ts` para invocar exclusivamente la RPC `rpc_registrar_gasto_v2` con la firma formal de SDD-022 §5.1 (`p_session_id`, `p_amount`, `p_payment_method`, `p_category`, `p_description`).
2. Actualizar el selector de categorías en `ExpensesView.vue` para restringirlo estrictamente a las 6 categorías autorizadas de SDD-026: `'Servicios'`, `'Nomina'`, `'Transporte'`, `'Mantenimiento'`, `'Insumos'`, `'Reembolso'`.
3. Agregar selector visual de método de pago (`'efectivo'`, `'nequi'`, `'llave_bre'`) en el modal de registrar salida (`ExpensesView.vue`).
4. Propagar y mapear los códigos de error del backend (`INSUFFICIENT_FUNDS`, `SESSION_EXPIRED`, etc.) hacia notificaciones comprensibles en la UI.
