# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-012)

> **Componente Auditado:** `frontend/src/data/syncQueue.ts`, `frontend/src/components/common/ConflictResolver.vue`, `frontend/src/components/common/SyncIndicator.vue`  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_012_SINCRONIZACION_OFFLINE.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_012_SINCRONIZACION_OFFLINE.md) (y [`SDD_028_ALMACENAMIENTO_LOCAL.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_028_ALMACENAMIENTO_LOCAL.md))  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Capa de Sincronización Local:** `frontend/src/data/syncQueue.ts`
- **Componentes de Interfaz de Usuario:**
  - `frontend/src/components/common/SyncIndicator.vue` (Semáforo de conectividad y estado de cola)
  - `frontend/src/components/common/ConflictResolver.vue` (Bandeja de contingencia DLQ y resolución de conflictos)

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. CONTRATOS DE INTERFAZ

### 5.2 Esquema JSON: Petición de Sincronización Diferida (`SincronizarVentaRequest`)
Payload transmitido al procedimiento transaccional de ventas en Supabase (`rpc_procesar_venta_v3`):
```json
{
  "p_store_id": "UUID (Obligatorio)",
  "p_local_id": "UUID (Obligatorio, clave de idempotencia)",
  "p_session_id": "UUID (Obligatorio, turno de caja histórico)",
  "p_client_id": "UUID | null",
  "p_payment_method": "efectivo | nequi | daviplata | fiado",
  "p_amount_received": "NUMERIC | null",
  "p_items": [
    {
      "product_id": "UUID",
      "quantity": 2,
      "unit_price": 5000
    }
  ],
  "p_is_offline_sync": true
}
```
Salida ante reintento de venta ya insertada: `ActionResponse { success: true, data: { sale_id: UUID }, code: 'DUPLICATE_RESOLVED' }`.
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componentes identificados y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: Sincronización de Venta Diferida (`CREATE_SALE`)
- **Invocación RPC en `syncQueue.ts:408-418`:**
  - Código real: Invoca `supabase.rpc('rpc_procesar_venta_v2', rpcPayload)`.
  - Parámetros enviados: `p_store_id`, `p_client_id`, `p_payment_method`, `p_amount_received`, `p_items`.
  - Parámetros faltantes: Omite por completo `p_local_id` (o `p_idempotency_key`), `p_session_id` histórico y la bandera `p_is_offline_sync: true`.
  - Resultado: **Discrepancia Crítica (Riesgo de Duplicidad)**. Si la red cae durante la respuesta y la cola reintenta, el backend no puede identificar que la venta ya fue insertada, duplicando tickets, dinero y deducciones FIFO.

### Operación: `CREATE_CLIENT` en `syncQueue.ts:439-444`
- **Mutación en BD:**
  - Código real: Ejecuta `supabase.from('clients').insert(item.payload)` directamente.
  - Resultado: **Discrepancia Crítica**. Violación de `RN-OFF-01` (solo ventas POS son admitidas offline) y mutación directa omitiendo RPC.

---

## Bloque 2b — Verificación de Límites Financieros y Lógica de Negocio

- **Idempotencia Estricta (`RN-012-01` y `RN-011-03`):**
  - No garantizada en el cliente actual al no enviar `p_local_id` / `p_idempotency_key`.
- **Imputación a Turno de Caja Cerrado (`RN-012-06`):**
  - Al no enviar `p_session_id`, la venta diferida se intenta imputar al turno abierto actual en vez del turno histórico en que ocurrió la transacción física.
- **Respeto a Precios Históricos (`RN-012-04` / `D-6`):**
  - Requiere que el backend consuma el `unit_price` enviado en `p_items` durante la sincronización offline.

---

## Bloque 3 — Verificación de Manejo de Errores

| Código de Error SDD | Estado en Código Actual | Tratamiento en UI | Conforme |
|---|---|---|---|
| `DUPLICATE_RESOLVED` | No manejado en `syncQueue.ts` | Trata cualquier respuesta no estándar como fallo | ❌ No |
| `CREDIT_LIMIT_EXCEEDED` | Capturado como error genérico | Traslada a DLQ | 🟡 Parcial |
| `INSUFFICIENT_STOCK` | Capturado en catch | Traslada a DLQ y permite forzar venta en `ConflictResolver.vue:77-82` | ✅ Sí |
| `sync:auth_required` | No implementado | Falla con 401 sin pausar la cola | ❌ No |

---

## Bloque 4 — Verificación de Estados de Carga e Interacción

- **Semáforo de Sincronización:** `SyncIndicator.vue` muestra estados verde (conectado), azul (sincronizando), rojo (conflictos) y gris (offline).
- **Alerta de Capacidad:** No muestra alerta de advertencia al 80% (40 ventas) ni bloqueo crítico al 100% (50 ventas).

---

## Bloque 5 — Resumen de Discrepancias y Plan de Acción

### 5.1 Conteo Mecánico de Hallazgos (Regla 9.1: N = 4)
- **UX-1 (Severidad Alta):** Bypasseo del contrato idempotente en sincronización offline (`F-3`). En `frontend/src/data/syncQueue.ts:408-418`, la sincronización de ventas diferidas invoca `supabase.rpc('rpc_procesar_venta_v2', rpcPayload)` en lugar de `rpc_procesar_venta_v3`. Además, omite enviar `p_idempotency_key` (o `p_local_id`), `p_session_id` histórico y la bandera `p_is_offline_sync: true`. Ante una desconexión durante la respuesta, el reintento duplica la venta, crea un nuevo ticket y descuenta dos veces el inventario, violando `SDD_012: 5.2` y `RN-012-01`.
- **UX-2 (Severidad Alta):** Inserción directa en tabla `clients` (`F-14`). En `frontend/src/data/syncQueue.ts:439-444`, procesa operaciones `CREATE_CLIENT` mediante `supabase.from('clients').insert(item.payload)` directo vía PostgREST. Esto viola la regla de Backend Authority y `RN-OFF-01`, que estipula que el subsistema offline está restringido exclusivamente a cobros en POS (`CREATE_SALE`), prohibiendo encolar creaciones directas sin RPC seguro.
- **UX-3 (Severidad Media):** Ausencia de semáforo de capacidad de cola de sincronización. En `SyncIndicator.vue:75-81`, el indicador muestra "Sincronizando..." o "Modo Offline", pero no implementa los umbrales de alerta del 80% (advertencia amarilla) y 100% de 50 ventas (bloqueo crítico rojo) con advertencia preventiva exigidos por `RN-OFF-06` y `SDD_012: 4.2`.
- **UX-4 (Severidad Media):** Suspensión de cola por JWT expirado no reflejada en UI. En `syncQueue.ts`, si el token JWT caduca durante una desconexión prolongada, la cola no pasa explícitamente al estado `sync:auth_required` ni despliega el banner de re-autenticación requerida antes de reintentar (`RN-OFF-03`, `RN-R05`).

---

### 5.2 Auto-Chequeo Anti-Sesgo (Regla 9.4)
- **9.1 Invariante de Reconciliación:** $N = 4$ hallazgos documentados en el Bloque 5.1 y citados exactamente.
- **9.2 No-Fusión de Dimensiones:** La presencia del modal `ConflictResolver.vue` no atenúa la ausencia de idempotencia en `syncQueue.ts`.
- **9.3 Cita de Fuentes:** Las discrepancias se sustentan en `syncQueue.ts:408-418, 439-444` y `SyncIndicator.vue:75-81`.
- **9.4 Veredicto:** 🟡 **CON OBSERVACIONES (4 discrepancias detectadas)**.

---

## 📌 Instrucción para el Orquestador (Etapa 4)

1. En `frontend/src/data/syncQueue.ts`:
   - Migrar la invocación a `rpc_procesar_venta_v3` incluyendo: `p_idempotency_key: item.payload.localId || item.id`, `p_session_id: item.payload.sessionId`, y `p_is_offline_sync: true`.
   - Manejar el código `DUPLICATE_RESOLVED` para purgar la venta de la cola con éxito.
   - Descartar o rechazar el encolamiento de `CREATE_CLIENT` offline en conformidad con `RN-OFF-01`.
2. En `frontend/src/components/common/SyncIndicator.vue`:
   - Incorporar advertencia de capacidad de cola (alerta visual naranja al 80% y roja al 100% de 50 transacciones).
