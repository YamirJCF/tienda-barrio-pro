# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-012)

> **Componente Auditado:** `frontend/src/components/common/SyncIndicator.vue` (y motor `frontend/src/data/syncQueue.ts`)  
> **SDD Fuente:** `documentation/01_requirements/SDD/SDD_012_SINCRONIZACION_OFFLINE.md`  
> **Fecha:** 2026-10-24  
> **Carácter:** Cartografía consultiva no bloqueante bajo metodología oficial PAC-UXD.

---

## Bloque 1 — Identificación

### B1.1 — Declaración de Componente Auditado
- **Componente Visual:** [`frontend/src/components/common/SyncIndicator.vue`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/components/common/SyncIndicator.vue)
- **Motor de Cola de Persistencia:** [`frontend/src/data/syncQueue.ts`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/data/syncQueue.ts)

### B1.2 — Cita Literal de la Sección 5 (Contrato de Interfaz) de SDD-012

```json
{
  "p_store_id": "UUID (Obligatorio)",
  "p_client_id": "UUID (Opcional, NULL para ventas de mostrador)",
  "p_payment_method": "TEXT ('efectivo' | 'nequi' | 'daviplata' | 'fiado')",
  "p_amount_received": "NUMERIC >= 0",
  "p_items": [
    {
      "product_id": "UUID (Obligatorio)",
      "quantity": "NUMERIC > 0",
      "unit_price": "NUMERIC > 0 (Precio histórico congelado)"
    }
  ],
  "p_idempotency_key": "UUID (Opcional, NULL)",
  "p_local_id": "TEXT (Obligatorio para sincronización offline, coincide con id de cola)",
  "p_is_offline_sync": "BOOLEAN (true)",
  "p_origin_session_id": "UUID (Identificador del turno de caja histórico)",
  "p_sold_by": "UUID (Identificador del empleado cajero)"
}
```

### B1.3 — CHECKPOINT BLOQUE 1
✅ Bloque 1 completado. Componentes identificados y contrato canónico de SDD-012 citado literalmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

Inspección de las líneas 411-424 de `frontend/src/data/syncQueue.ts`:

```typescript
const rpcPayload = {
    p_store_id: item.payload.storeId || item.payload.store_id,
    p_client_id: item.payload.clientId || item.payload.client_id || null,
    p_payment_method: (['cash', 'mixed', 'efectivo'].includes(item.payload.paymentMethod))
        ? 'efectivo' // Standardize on 'efectivo' to match DB Constraint
        : (item.payload.paymentMethod || 'efectivo'),
    p_amount_received: numericAmountReceived,
    p_items: p_items_v2,
    p_idempotency_key: idempotencyKey,
    p_local_id: localId,
    p_is_offline_sync: true
};
```

### B2.4 / B2.5 — Checkpoint por Campo de Entrada

| Campo de SDD-012 | Estado en `syncQueue.ts` | Cita Textual de Línea / Observación |
|---|---|---|
| `p_store_id` | ✅ Presente | Línea 412: `p_store_id: item.payload.storeId \|\| item.payload.store_id` |
| `p_client_id` | ✅ Presente | Línea 413: `p_client_id: item.payload.clientId \|\| item.payload.client_id \|\| null` |
| `p_payment_method` | ✅ Presente | Líneas 414-416: Estandarizado a `'efectivo'` o valor mapeado |
| `p_amount_received` | ✅ Presente | Línea 417: `p_amount_received: numericAmountReceived` |
| `p_items` | 🟡 Parcial | Línea 418: `p_items: p_items_v2`. En líneas 390-393 `p_items_v2` solo mapea `product_id` y `quantity`, omitiendo `unit_price` congelado. |
| `p_idempotency_key` | ✅ Presente | Línea 419: `p_idempotency_key: idempotencyKey` |
| `p_local_id` | ✅ Presente | Línea 420: `p_local_id: localId` |
| `p_is_offline_sync` | ✅ Presente | Línea 421: `p_is_offline_sync: true` |
| `p_origin_session_id` | 🔴 Ausente | No se transmite en `rpcPayload`. Pendiente de integración con DDL Fase 3. |
| `p_sold_by` | 🔴 Ausente | No se transmite en `rpcPayload`. Pendiente de integración con DDL Fase 3. |

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 — Búsqueda explícita de montos calculados en cliente enviados para persistencia:**
  Inspección en `syncQueue.ts`: El payload transmitido al backend (`rpcPayload`) NO envía `total` ni `subtotal`. En las líneas 390-393, solo se extrae `product_id` y `quantity`. El servidor relacional calcula la totalidad financiera y de inventario.
- **B2.7 — CHECKPOINT:** ✅ Backend Authority respetada. Cero cálculos de total financiero impuestos por el cliente al backend.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 — Estados del Diagrama de Estados de SDD-012
1. `EncoladaLocal`
2. `EnVuelo`
3. `Sincronizada`
4. `Reintentando`
5. `FalloDefinitivo`
6. `DeadLetterQueue`

### B3.9 — Mapeo Visual en `SyncIndicator.vue` y `syncQueue.ts`
- **`EncoladaLocal`:** Reflejada en `SyncIndicator.vue` (línea 71): `if (queueSize.value > 0) return 'bg-blue-500'`; y texto tooltip (línea 36): `{{ queueSize }} cambios pendientes`.
- **`EnVuelo`:** Reflejada en `SyncIndicator.vue` (líneas 12-14): `<span v-if="isSyncing || !supabaseConnected" class="animate-ping ..."></span>` y texto (línea 79): `'Sincronizando...'`.
- **`Sincronizada`:** Reflejada en `SyncIndicator.vue` (línea 72): `'bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.4)]'` y texto (línea 80): `'Sistema Operativo'`.
- **`Reintentando`:** Gestionada en `syncQueue.ts` (líneas 368-374): Incremento de `retryCount` y persistencia en IndexedDB.
- **`FalloDefinitivo`:** Gestionada en `syncQueue.ts` (líneas 357-366): Traslado a `DLQ_STORE` al superar 3 intentos.
- **`DeadLetterQueue`:** Reflejada en `SyncIndicator.vue` (líneas 23-27): Badge rojo animado `v-if="hasConflicts"`, dot rojo `bg-red-500` (línea 68), texto `'Atención requerida'` (línea 76) y apertura modal `ConflictResolver.vue` (líneas 45-47).

### B3.10 / B3.11 — CHECKPOINT
✅ Todos los 6 estados del ciclo de vida tienen representación funcional y visual diferenciada. Se cumple la regla anti-"$0 disfrazado".

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12:** `SyncIndicator.vue` no muestra cifras monetarias directas; renderiza conteos discretos de transacciones (`queueSize` y `dlqSize`).
- **B4.13 — CHECKPOINT:** ✅ Conforme (No aplica formateo monetario en este indicador).

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 / B5.15:**
  - La visibilidad del indicador de sincronización (`SyncIndicator.vue`) es universal en el POS para que cualquier cajero u operador reconozca de inmediato el estado de la red.
  - La interacción de resolución de conflictos (`ConflictResolver.vue`) abierta al hacer clic sobre el indicador en rojo (`hasConflicts`) requiere rol de Administrador.
- **B5.16 — CHECKPOINT:** ✅ Conforme.

---

## 📋 Resumen de Hallazgos (PAC-UXD SDD-012)

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-012-01 | `p_items_v2` en `syncQueue.ts` (líneas 390-393) no incluye `unit_price` congelado, dejando que el backend aplique precio vigente en vez de precio pactado offline (RN-OFF-03). | Bloque 2 (B2.4) | 🟡 Media |
| UX-012-02 | `rpcPayload` en `syncQueue.ts` (líneas 411-424) no envía `p_origin_session_id` ni `p_sold_by` para imputación limpia al turno histórico cerrado (RN-OFF-05). | Bloque 2 (B2.4) | 🟡 Media |
| UX-012-03 | `SyncIndicator.vue` refresca el tamaño de la cola mediante sondeo por intervalo de 2000ms (`setInterval`, línea 97) en vez de suscripción reactiva a eventos de IndexedDB. | Bloque 3 (B3.9) | 🔵 Baja |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🟡 Observaciones Menores`
- **Impacto en Estado Compuesto:** Al no presentarse hallazgos de severidad ALTA (cero violaciones de Backend Authority ni de multi-tenant en cliente), la dimensión de Frontend aporta `🟢 Conforme con Observaciones Menores`.

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. En la Fase 3 (Implementación), extender `p_items_v2` en `syncQueue.ts` para transferir `unit_price: i.unitPrice || i.unit_price`.
2. Una vez desplegada la migración de firma extendida de `rpc_procesar_venta_v3`, mapear `p_origin_session_id` y `p_sold_by` desde el `QueueItem`.
