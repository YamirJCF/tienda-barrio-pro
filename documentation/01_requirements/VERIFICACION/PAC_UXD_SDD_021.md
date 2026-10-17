# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-021 / SDD-027.01)

> **Componente Auditado:** `frontend/src/views/HistoryView.vue`, `frontend/src/components/history/SaleDetailModal.vue`, `frontend/src/components/history/HistoryItemCard.vue` (y composable `frontend/src/composables/useHistory.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_021_HISTORIALES_MULTICANAL.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_021_HISTORIALES_MULTICANAL.md) (y [`SDD_027_01_REPORTES_CAJA.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_027_01_REPORTES_CAJA.md))  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/HistoryView.vue` (`/history`)
- **Modales y Fichas:**
  - `frontend/src/components/history/SaleDetailModal.vue`
  - `frontend/src/components/history/HistoryItemCard.vue`
- **Capa Lógica:** `frontend/src/composables/useHistory.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.1 Operación: `rpc_obtener_historial_caja_multicanal`
- **Tipo:** RPC Postgres / Consulta Paginada (READ)
- **Payload de Entrada:**
  - `p_store_id` (UUID, Obligatorio)
  - `p_session_id` (UUID, Opcional)
  - `p_payment_method` (TEXT: 'all', 'efectivo', 'digitales', 'nequi', 'daviplata')
  - `p_start_date` (TIMESTAMPTZ, Opcional)
  - `p_end_date` (TIMESTAMPTZ, Opcional)
  - `p_limit` (INTEGER, Default 50)
  - `p_offset` (INTEGER, Default 0)

- **Payload de Respuesta Exitosa:**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "UUID",
        "session_id": "UUID",
        "movement_type": "ingreso | gasto | pago_proveedor",
        "origin_type": "venta | abono | gasto_opex | abono_proveedor",
        "amount": 45000,
        "payment_method": "efectivo | nequi | daviplata",
        "description": "STRING",
        "sale_id": "UUID | null",
        "ticket_number": 1042,
        "created_at": "TIMESTAMPTZ"
      }
    ],
    "count": 48
  }
  ```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componentes identificados y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_obtener_historial_caja_multicanal`
- **Invocación RPC:**
  - Código real: Cero referencias a `rpc_obtener_historial_caja_multicanal` en todo el proyecto frontend. En `useHistory.ts:283`, la pestaña "Caja" invoca exclusivamente `get_history_caja` (resumen macro de sesiones de arqueo).
  - Resultado: **Discrepancia Crítica (Ausente en Frontend)**.
- **Parámetros del RPC (`p_payment_method`, `p_limit`, `p_offset`):**
  - Código real: Inexistentes en las peticiones de caja.
  - Resultado: **Ausente**.

### Operación: `get_history_ventas` y `get_sale_detail`
- **Invocación RPC:**
  - Código real: En `useHistory.ts:239`, invoca `get_history_ventas` y en `SaleDetailModal.vue:64`, `get_sale_detail`.
  - Resultado: **Presente y Conforme**.

---

## Bloque 2b — Verificación de Límites Financieros y Lógica de Negocio

- **Prohibición de Filtros y Sumatorias Financieras en el Cliente (`POL-DATA-01`):**
  - En `useHistory.ts:104-118`, el filtrado multicanal (`paymentMethodFilter`) se realiza en memoria mediante `.filter(...)` sobre el array plano de items.
  - En `useHistory.ts:145`, el total general (`summary.totalAmount`) se calcula sumando en el navegador con `.reduce((sum, item) => sum + (item.amount || 0), 0)`.
- **Fidelidad al Flujo de Liquidez (`POL-FIN-01` y `RN-021-01`):**
  - Al no invocar `rpc_obtener_historial_caja_multicanal`, no se puede auditar la conciliación micro con extractos bancarios de Nequi/Daviplata para abonos de clientes o egresos.

---

## Bloque 3 — Verificación de Manejo de Errores

| Código de Error SDD | Estado en Código Actual | Tratamiento en UI | Conforme |
|---|---|---|---|
| `UNAUTHORIZED_ROLE` (403) | No capturado específicamente | Mensaje genérico en `error.value`: "Error al cargar el historial" | ❌ No |
| `STORE_ACCESS_DENIED` | Capturado genéricamente | Banner de error en vista | 🟡 Parcial |
| `INVALID_PAYMENT_METHOD` | No validado | Falla silenciosa | ❌ No |

---

## Bloque 4 — Verificación de Estados de Carga e Interacción

- **Skeletons / Loading State:** `HistoryView.vue` y `SaleDetailModal.vue:95-98` implementan spinner de carga durante `isLoading`.
- **Bloqueo de Interacción:** `BaseModal` y botones filtradores bloquean cambios mientras se resuelve la promesa de datos.

---

## Bloque 5 — Resumen de Discrepancias y Plan de Acción

### 5.1 Conteo Mecánico de Hallazgos (Regla 9.1: N = 5)
- **UX-1 (Severidad Alta):** Ausencia de invocación de `rpc_obtener_historial_caja_multicanal`. En `HistoryView.vue` y `useHistory.ts`, la pestaña "Caja" (`currentType === 'cash'`) solo invoca `get_history_caja` (resumen macro de sesiones de arqueo cerradas). Los movimientos atómicos individuales multicanal (`cash_movements` desglosados con origen `venta`, `abono`, `gasto_opex`, `abono_proveedor` y canales `efectivo`, `nequi`, `daviplata`) NUNCA se consultan con `rpc_obtener_historial_caja_multicanal`, impidiendo la conciliación micro con extractos bancarios requerida por `FRD-021` y `RN-021-01`.
- **UX-2 (Severidad Alta):** Filtrado multicanal y suma total resueltos en memoria del cliente. En `useHistory.ts:104-118` y `145`, el filtro de canal monetario (`paymentMethodFilter`) y el monto total de la vista (`summary.totalAmount`) se calculan en el navegador mediante `.filter(...)` y `.reduce(...)` sobre un array plano descargado sin paginación server-side, violando el principio de Backend Authority (`POL-DATA-01` y Regla Global 2.1).
- **UX-3 (Severidad Media):** Ausencia del contrato canónico de paginación `{ data, count }`. `useHistory.ts` acumula filas en un arreglo reactivo `items = ref<HistoryItem[]>([])` y deduce el conteo localmente (`items.value.length`), ignorando la paginación formal `p_limit` / `p_offset` provista por `rpc_obtener_historial_caja_multicanal`.
- **UX-4 (Severidad Media):** Inconsistencia en subfiltros digitales. `HistoryView.vue:63-72` define `digitalPaymentOptions` ('Nequi', 'Daviplata'), pero en `useHistory.ts:112-114` la lógica solo agrupa `paymentMethodFilter === 'digital'` agrupando ambos canales sin permitir aislar exclusivamente uno de ellos en consultas combinadas.
- **UX-5 (Severidad Baja):** Ausencia de acciones de reembolso parcial o anulación directa en el visor de ticket de venta (`SaleDetailModal.vue`), forzando una visualización pasiva read-only que no expone la compensación contable inmutable de `SDD_006_02` (`rpc_procesar_reembolso_item`).

---

### 5.2 Auto-Chequeo Anti-Sesgo (Regla 9.4)
- **9.1 Invariante de Reconciliación:** $N = 5$ hallazgos documentados en el Bloque 5.1 y citados exactamente.
- **9.2 No-Fusión de Dimensiones:** El correcto funcionamiento de `get_history_ventas` no compensa la ausencia total de `rpc_obtener_historial_caja_multicanal`.
- **9.3 Cita de Fuentes:** Las discrepancias se sustentan en `useHistory.ts:104-118, 145, 277-293`, `HistoryView.vue:63-72` y `SaleDetailModal.vue`.
- **9.4 Veredicto:** 🟡 **CON OBSERVACIONES (5 discrepancias detectadas)**.

---

## 📌 Instrucción para el Orquestador (Etapa 4)

1. En `frontend/src/composables/useHistory.ts`:
   - En la pestaña "Caja", incorporar la llamada a `supabase.rpc('rpc_obtener_historial_caja_multicanal', { p_store_id, p_session_id, p_payment_method, p_start_date, p_end_date, p_limit, p_offset })` para mostrar el flujo micro de movimientos de liquidez multicanal.
   - Migrar el filtrado por método de pago (`p_payment_method`) y las agregaciones de total (`count`, `totalAmount`) hacia el servidor, eliminando `.reduce(...)` y `.filter(...)` del cliente.
2. En `frontend/src/views/HistoryView.vue`:
   - Conectar los botones de canal ("Efectivo", "Digitales", "Nequi", "Daviplata") como disparadores de recarga server-side.
3. En `frontend/src/components/history/SaleDetailModal.vue`:
   - Añadir triggers o botones de acción para anulación de venta (`rpc_anular_venta`) y reembolso de ítem (`rpc_procesar_reembolso_item`) cuando el usuario posea permisos administrativos.
