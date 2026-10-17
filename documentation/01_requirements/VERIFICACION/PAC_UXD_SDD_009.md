# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-009)

> **Componente Auditado:** `frontend/src/views/ClientListView.vue` y `frontend/src/views/ClientDetailView.vue` (y modal `frontend/src/components/ClientFormModal.vue`, store `frontend/src/stores/clients.ts`, repositorio `frontend/src/data/repositories/clientRepository.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_009_CLIENTES.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_009_CLIENTES.md) (y política [`SDD_024_POLITICA_FIADOS.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_024_POLITICA_FIADOS.md))  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Rutas Principales:**
  - `frontend/src/views/ClientListView.vue`
  - `frontend/src/views/ClientDetailView.vue`
- **Componentes Auxiliares:**
  - `frontend/src/components/ClientFormModal.vue`
- **Capa de Datos y Repositorios:**
  - `frontend/src/stores/clients.ts`
  - `frontend/src/data/repositories/clientRepository.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contratos de Interfaz (Payloads)

### 5.1 Registro Atómico de Abono a Deuda: `registrar_abono`
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Payload de Solicitud:**
  ```json
  {
    "p_client_id": "UUID (Obligatorio)",
    "p_amount": "NUMERIC > 0 (Obligatorio)",
    "p_payment_method": "TEXT (Obligatorio: 'efectivo', 'nequi', 'daviplata')"
  }
  ```
- **Payload de Respuesta Exitosa:**
  ```json
  {
    "success": true,
    "data": {
      "client_id": "UUID",
      "previous_balance": 45000,
      "amount_paid": 25000,
      "new_balance": 20000,
      "payment_method": "efectivo",
      "cash_movement_id": "UUID",
      "session_id": "UUID",
      "created_at": "2026-10-15T02:15:00.000Z"
    }
  }
  ```

### 5.2 Consulta Administrativa de Clientes con Filtros: `rpc_admin_get_clients`
- **Tipo:** RPC Postgres / Lectura (READ)
- **Payload de Solicitud:**
  ```json
  {
    "p_store_id": "UUID (Obligatorio)",
    "p_filter_debt": "TEXT (Opcional: 'todos', 'con_deuda', 'al_dia')",
    "p_include_deleted": "BOOLEAN (Default false)",
    "p_search_query": "TEXT (Opcional)",
    "p_order_by": "TEXT (Default: 'balance_desc')",
    "p_limit": "INTEGER (Default 20)",
    "p_offset": "INTEGER (Default 0)"
  }
  ```
- **Payload de Respuesta Exitosa:**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "UUID",
        "name": "Maria Garcia",
        "id_number": "1098765432",
        "phone": "3109876543",
        "credit_limit": 100000,
        "balance": 20000,
        "credit_available": 80000,
        "credit_usage_pct": 20,
        "is_deleted": false,
        "created_at": "2026-03-29T10:00:00.000Z"
      }
    ],
    "count": 1
  }
  ```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `registrar_abono`
- **Campos `p_client_id`, `p_amount`, `p_payment_method`:**
  - Código real: En `clients.ts:189-193`, invoca `supabase.rpc('registrar_abono', { p_client_id, p_amount, p_payment_method })`.
  - Resultado: **Presente y Conforme**.

### Operación: `rpc_admin_get_clients`
- **Consulta y Paginación Server-Side:**
  - Código real: En `ClientListView.vue:27-32` e `initialize`, el store carga todos los clientes en memoria mediante `baseRepository.getAll(storeId)`. La búsqueda se hace localmente con `clientsStore.searchClients(searchQuery.value)`.
  - Contrato: SDD-009 §5.2 define la función `rpc_admin_get_clients` con filtros de deuda (`p_filter_debt`), búsqueda indexada (`p_search_query`) y paginación (`p_limit`, `p_offset`).
  - Resultado: **RPC Ausente en Frontend (Carga monolítica en memoria)**.

### B2.5 CHECKPOINT Bloque 2
El registro de abono es conforme. Sin embargo, la consulta de clientes no utiliza la RPC administrativa con filtros y paginación del servidor.

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 Búsqueda de Cálculos en Cliente:**
  - En `ClientListView.vue:47-49`: `totalDebt` se calcula reduciendo el array local de clientes en Pinia (`clientsStore.totalDebt`).
  - En `ClientDetailView.vue:75-80`:
    ```typescript
    const availableCredit = computed(() => clientsStore.getAvailableCredit(clientId.value));
    const creditUsagePercent = computed(() => {
      if (!client.value || client.value.creditLimit.isZero()) return 0;
      return client.value.totalDebt.div(client.value.creditLimit).times(100).toNumber();
    });
    ```
    El cupo disponible y el porcentaje de uso de crédito se calculan en JavaScript en lugar de consumir las columnas calculadas `credit_available` y `credit_usage_pct` que el backend entrega en `rpc_admin_get_clients`.
- **B2.7 CHECKPOINT Bloque 2b:**
  - Cálculos financieros de cartera y cupo de crédito realizados en el cliente. Marcado como **Severidad ALTA**.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del SDD
1. `Cargando Cartera` -> Skeleton reactivo.
2. `Sin Clientes Registrados` -> Empty state con botón de añadir.
3. `Cliente con Deuda Pendiente` -> Indicador rojo / Badges 'Debe'.
4. `Cliente al Día` -> Indicador verde / Badge 'Al día'.
5. `Abono Excede Saldo` (`AMOUNT_EXCEEDS_BALANCE`) -> Notificación de validación.

### B3.9 Búsqueda en Código
- **Estado 1:** `ClientListView.vue:159-161` (`<BaseListSkeleton v-if="clientsStore.isLoading" ... />`). **Conforme**.
- **Estado 2:** `ClientListView.vue:210-217` (`<BaseEmptyState v-else ... />`). **Conforme**.
- **Estado 3 y 4:** `ClientListView.vue:169-172, 196-204` (Bordes y badges 'Debe' / 'Al día'). **Conforme**.
- **Estado 5:** `ClientDetailView.vue:156`: `alert(...)` nativo del navegador para bloquear abonos superiores a la deuda.
  - Resultado: **Manejo mediante diálogo nativo no conforme con UX del proyecto**.

### B3.10 Cruce Explícito
- Estado 1: Sí.
- Estado 2: Sí.
- Estado 3: Sí.
- Estado 4: Sí.
- Estado 5: Parcial (alert nativo).

### B3.11 CHECKPOINT Bloque 3
Estados visuales manejados con observación de usabilidad en el diálogo de error de abono.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12 Formateo:**
  - En `ClientListView.vue:77-82` y `ClientDetailView.vue:83-88`:
    ```typescript
    const formatCurrency = (val: Decimal) => {
      return `$${val
        .toDecimalPlaces(0)
        .toString()
        .replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
    };
    ```
  - Implementación manual en lugar de consumir el composable oficial `useCurrencyFormat`.
- **B4.13 CHECKPOINT Bloque 4:**
  - Discrepancia menor por formateo monetario manual.

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 Restricciones:**
  - Creación, edición y eliminación de clientes reservada al Administrador. Cajeros autorizados pueden consultar y registrar abonos.
- **B5.15 Implementación:**
  - `ClientListView.vue:52`: `const canManageClients = computed(() => authStore.isAdmin);`
  - Botón FAB y opciones de edición condicionadas con `v-if="canManageClients"`.
- **B5.16 CHECKPOINT Bloque 5:**
  - Conforme en restricción de rol.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | Carga monolítica y filtrado en memoria local de clientes en `ClientListView.vue:43-45` e `initialize`, prescindiendo de la función `rpc_admin_get_clients` de SDD-009 §5.2 con paginación (`limit`, `offset`) y filtros server-side. | Bloque 2 (B2.4) | 🔴 Alta |
| UX-2 | Deuda global (`totalDebt`), cupo disponible (`availableCredit`) y porcentaje de consumo de crédito (`creditUsagePercent`) calculados en JavaScript en el cliente (`ClientListView.vue:47-49`, `ClientDetailView.vue:75-80`) en lugar de recibir los valores oficiales calculados por el backend en `rpc_admin_get_clients`. | Bloque 2b (B2.6) | 🔴 Alta |
| UX-3 | Uso de cuadro de diálogo modal nativo del navegador `alert(...)` en `ClientDetailView.vue:156` al superar el saldo adeudado, en vez del sistema de notificaciones/toasts. | Bloque 3 (B3.9) | 🟡 Media |
| UX-4 | Formateo monetario artesanal con Regex en `ClientListView.vue:77-82` y `ClientDetailView.vue:83-88` en vez de consumir el composable estándar `useCurrencyFormat` (SPEC-011). | Bloque 4 (B4.12) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:**
  - Al identificarse 2 hallazgos de severidad ALTA (UX-1, UX-2), el frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. Conectar `ClientListView.vue` con la RPC `rpc_admin_get_clients` para búsqueda indexada y paginación incremental en servidor.
2. Consumir directamente los campos `credit_available` y `credit_usage_pct` del payload retornado por la base de datos en `ClientDetailView.vue`, eliminando el cálculo client-side.
3. Reemplazar `alert()` en `ClientDetailView.vue:156` por `showWarning` del composable `useNotifications`.
4. Estandarizar el uso de `useCurrencyFormat` en la cartera de clientes.
