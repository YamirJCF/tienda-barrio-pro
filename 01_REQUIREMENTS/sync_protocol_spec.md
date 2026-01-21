# SPEC-012: Protocolo de Sincronización Offline-First

> **Documento de Requisitos Funcionales (FRD)**  
> Versión: 1.0  
> Fecha: 2026-01-21  
> Estado: ✅ Validado por QA

---

## Descripción

Este documento define las **reglas del juego** cuando un dispositivo con transacciones offline vuelve a tener conexión. Establece la estrategia de resolución de conflictos y el manejo de casos de borde críticos.

---

## Decisión Arquitectónica: Optimistic UI

> [!IMPORTANT]
> **Estrategia Seleccionada**: Optimistic UI con Server Authority

| Aspecto | Decisión | Justificación |
|---------|----------|---------------|
| **UX** | Mostrar éxito inmediato | Cajero no espera confirmación → +velocidad de venta |
| **Conflictos** | Servidor es fuente de verdad | Frontend nunca "gana" un conflicto |
| **Stock Negativo** | Permitido temporalmente | Se reconcilia al sincronizar |

### Riesgo Aceptado

El stock puede quedar negativo entre el momento de la venta offline y la sincronización. El servidor reconcilia y notifica discrepancias.

---

## Reglas de Sincronización por Entidad

### Tabla de Estrategias

| Entidad | Estrategia | Dir. de Sync | Conflicto Posible |
|---------|------------|--------------|-------------------|
| `sales` | Queue FIFO | Cliente → Server | Stock insuficiente |
| `products` | Server Authority | Server → Cliente | Precios desactualizados |
| `clients` | Merge | Bidireccional | Crédito excedido |
| `employees` | Server Authority | Server → Cliente | Ninguno |
| `cash_register` | Queue FIFO | Cliente → Server | Arqueo duplicado |

---

## Reglas de Negocio

### RN-01: Cola de Sincronización FIFO

Las transacciones offline se procesan **en orden de creación**, no de reconexión.

```
Cola: [Venta-10:30, Gasto-10:35, Venta-10:40]
Sync: Procesa Venta-10:30 primero, luego Gasto, luego última Venta
```

### RN-02: First-Sync-Wins (Conflicto de Stock)

> [!CAUTION]
> **Mitigación QA R-03**: Regla para conflictos de "última unidad"

Cuando dos dispositivos offline venden la misma última unidad:

| Orden | Acción | Resultado |
|-------|--------|-----------|
| 1ª venta sincronizada | ✅ Se confirma | Stock = 0 |
| 2ª venta sincronizada | ❌ Se rechaza | Error `STOCK_INSUFFICIENTE_SYNC` |
| | Venta a Dead Letter Queue | Admin revisa manualmente |

### RN-03: Venta Rechazada Post-Confirmación

> [!CAUTION]
> **Mitigación QA R-01**: Política crítica para Optimistic UI

Si el servidor **rechaza** una venta que ya se mostró como "exitosa" al cliente:

**Flujo de Compensación:**

1. **Notificación Inmediata**: Toast persistente "⚠️ Venta #045 requiere revisión"
2. **Estado en Historial**: Venta marcada como `PENDIENTE_REVISION` (color ámbar)
3. **Bloqueo Suave**: La venta NO cuenta para el arqueo de caja hasta resolver
4. **Acción Admin**: Aprobar (forzar) o Anular con razón documentada
5. **Si Anula**: Registrar como "Venta Anulada - Conflicto de Sync"

**UI de Notificación:**

```
┌────────────────────────────────────────┐
│ ⚠️ Venta #045 requiere atención       │
│                                        │
│ El stock de "Leche Colanta" se agotó  │
│ antes de sincronizar esta venta.       │
│                                        │
│ [Ver Detalles]  [Ir a Historial]       │
└────────────────────────────────────────┘
```

### RN-04: Límite de Transacciones Offline

| Límite | Valor | Acción al Exceder |
|--------|-------|-------------------|
| Ventas offline | 50 transacciones | Bloquear nuevas ventas, mostrar "Sincroniza para continuar" |
| Tiempo offline | 24 horas | Warning, permitir continuar |
| Items por venta | Sin límite | N/A |

### RN-05: Prioridad de Sincronización

Cuando se reconecta, el orden de sync es:

1. **Ventas** (crítico: afecta inventario y caja)
2. **Gastos** (afecta caja)
3. **Pagos de Fiado** (afecta balance de clientes)
4. **Ajustes de Inventario** (menos urgente)

---

## Casos de Uso

### CU-01: Venta Offline Exitosa

**Actor**: Cajero  
**Precondición**: Sin conexión, stock local > 0

1. Cajero registra venta normalmente
2. Sistema muestra "Venta completada ✓" (optimistic)
3. Venta se agrega a cola offline
4. Dashboard muestra badge "1 pendiente de sync"
5. Al reconectar, sistema sincroniza en background
6. Badge desaparece al completar

### CU-02: Conflicto de Stock al Sincronizar

**Actor**: Sistema  
**Precondición**: 2 cajeros vendieron el último item offline

1. Cajero A sincroniza primero → ✅ Venta confirmada
2. Cajero B sincroniza después → ❌ Stock insuficiente
3. Venta B va a Dead Letter Queue
4. Notificación a Cajero B: "Venta #X requiere revisión"
5. Admin (o Cajero B) ve venta marcada en ámbar
6. Admin decide: Aprobar (crear stock negativo) o Anular

### CU-03: Dead Letter Queue - Resolución Manual

**Actor**: Admin  
**Precondición**: Transacción en DLQ

1. Admin accede a "Transacciones Fallidas" en AdminHub
2. Ve tabla con: Fecha, Tipo, Monto, Error, Reintentos
3. Opciones: [Reintentar] [Descartar] [Ver Detalle]
4. Si Descarta: Registra razón obligatoria
5. Si Reintenta: Sistema intenta sync nuevamente

---

## Criterios de Aceptación

### Funcionalidad
- [ ] Cola offline persiste en IndexedDB (no localStorage)
- [ ] Sync automático al detectar reconexión
- [ ] Límite de 50 transacciones offline
- [ ] Prioridad: Ventas > Gastos > Pagos > Ajustes

### Seguridad
- [ ] Transacciones firmadas con timestamp cliente + versión
- [ ] Servidor valida orden temporal
- [ ] DLQ tiene RLS (solo admin ve todas las tiendas)

### UI/UX
- [ ] Badge de "pendientes" en Dashboard
- [ ] Toast persistente para ventas rechazadas
- [ ] Estado `PENDIENTE_REVISION` visible en historial
- [ ] Indicador de sync en header (spinner)

---

## Impacto en el Sistema

| Componente | Tipo | Descripción |
|------------|------|-------------|
| `src/data/syncQueue.ts` | NEW | Cola offline con IndexedDB |
| `src/composables/useOfflineSync.ts` | NEW | Lógica de reconexión |
| `src/components/SyncBadge.vue` | NEW | Indicador de pendientes |
| `src/stores/sales.ts` | MODIFY | Agregar cola offline |
| `supabase-schema.sql` | MODIFY | Tabla `sync_queue_failed` |

---

## Referencias

- [cache-strategy.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/01_REQUIREMENTS/cache-strategy.md) - Estrategia SWR base
- [QA_AUDIT_ARCHITECTURE_NORMALIZATION.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/04_DEV_ORCHESTRATION/QA_AUDIT_ARCHITECTURE_NORMALIZATION.md) - Mitigaciones R-01, R-03
