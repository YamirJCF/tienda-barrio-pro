# SPEC-011: Estrategia de Caché SWR (HISTÓRICO / DEROGADO)

> [!WARNING]
> **DOCUMENTO HISTÓRICO DEROGADO (SUPERSEDED):**
> Este borrador temprano de enero de 2026 ha sido sustituido de manera oficial y vinculante por:
> - [FRD_028_ALMACENAMIENTO_LOCAL_SEGURO.md](../FRD/FRD_028_ALMACENAMIENTO_LOCAL_SEGURO.md) (v2.0)
> - [SDD_028_ALMACENAMIENTO_LOCAL.md](../SDD/SDD_028_ALMACENAMIENTO_LOCAL.md) (v2.0.0)
> Se conserva exclusivamente para fines de trazabilidad histórica. Estado: 🚫 **DEROGADO**

---

> **Documento de Requisitos Funcionales (FRD)**  
> Versión: 2.0 (Consolidada)  
> Última actualización: 2026-01-20  
> Estado: ✅ **Aprobado por todos los interesados**

---

## Descripción

Este documento define la estrategia de caché **Stale-While-Revalidate (SWR)** para "Tienda de Barrio Pro", optimizada para dispositivos móviles con conectividad variable, manteniendo la integridad de datos bajo la arquitectura Thin Client.

### Justificación

El patrón SWR proporciona:
- **Respuesta instantánea** - Datos del caché inmediatamente
- **Revalidación silenciosa** - Actualización en background
- **Experiencia fluida** - Sin parpadeos ni bloqueos

---

## Reglas de Negocio

### RN-01: Clasificación de Datos por Criticidad

| Nivel | Estrategia | Descripción | Stores |
|-------|------------|-------------|--------|
| **1** | Cache-First | Datos estáticos, TTL infinito | `auth`, `preferences` |
| **2** | SWR | Datos maestros, TTL configurable | `inventory`, `clients`, `employees` |
| **3** | Network-First | Transacciones críticas, TTL 0 | `sales`, `expenses`, `cashControl` |
| **4** | No-Cache | Datos volátiles, solo sesión | `cart` |

### RN-02: Configuración por Store

| Store | TTL | Tabla Supabase | Realtime | Offline Queue |
|-------|-----|----------------|----------|---------------|
| `auth` | ∞ | - (JWT) | ❌ | ❌ |
| `inventory` | 5 min | `products` | ✅ | ❌ |
| `sales` | 0 | `sales` | ✅ | ✅ |
| `cart` | Sesión | - | ❌ | ❌ |
| `clients` | 10 min | `clients` | ✅ | ❌ |
| `employees` | 30 min | `employees` | ❌ | ❌ |
| `expenses` | 1 min | `expenses` | ❌ | ✅ |
| `cashControl` | 0 | `cash_register` | ✅ | ❌ |

### RN-03: Invalidación de Caché

| Trigger | Acción | Stores Afectados |
|---------|--------|------------------|
| Venta completada | Invalidar | `inventory`, `sales`, `cashControl` |
| Login exitoso | Refetch | `inventory`, `clients`, `employees` |
| TTL expirado | Revalidar background | Store correspondiente |
| Evento Realtime | Merge inteligente | Store suscrito |

### RN-04: Cola de Sincronización Offline

- Las transacciones (`sales`, `expenses`) se encolan cuando no hay conexión
- Al reconectar, se procesan en orden FIFO
- **Límite de reintentos:** 5 intentos por transacción
- Transacciones que exceden reintentos van a "Dead Letter Queue"
- El administrador puede reintentar manualmente desde Dead Letter Queue

---

## Consideraciones de Seguridad (Mitigaciones QA)

| ID | Riesgo | Mitigación | Prioridad |
|----|--------|------------|-----------|
| **MIT-01** | Cache Poisoning | Validar estructura y tipos al deserializar localStorage | 🔴 Crítica |
| **MIT-02** | DDoS por reintentos infinitos | Límite de 5 reintentos + Dead Letter Queue | 🔴 Crítica |
| **MIT-03** | Tokens expuestos | No persistir tokens sensibles de `auth` | 🔴 Crítica |
| **MIT-04** | Race conditions | Mutex en función `revalidate()` | 🟡 Alta |
| **MIT-05** | Timestamp manipulable | Preferir timestamp del servidor + campo `version` | 🟡 Alta |
| **MIT-06** | Carritos mezclados | Usar `scopedSessionStorage` para `cart` | 🔵 Normal |
| **MIT-07** | Usuario sin feedback | Indicador visual de modo offline | 🔵 Normal |
| **MIT-08** | localStorage lleno | Cuota con eviction LRU | 🔵 Backlog |
| **MIT-09** | Datos huérfanos | Cleanup periódico de tiendas eliminadas | 🔵 Backlog |

---

## Requisitos de Backend (Supabase)

### Realtime

Habilitar suscripciones en tiempo real para:
- `products` - Cambios de inventario entre dispositivos
- `sales` - Nuevas ventas
- `clients` - Actualizaciones de clientes
- `cash_register` - Estado de apertura/cierre

### Dead Letter Queue

Nueva tabla `sync_queue_failed` para persistir transacciones fallidas:

| Columna | Propósito |
|---------|-----------|
| `action_type` | Tipo de transacción (`sale`, `expense`, etc.) |
| `payload` | Datos originales en JSONB |
| `retry_count` | Número de reintentos realizados |
| `status` | `pending`, `retried`, `discarded`, `manual_resolved` |

### RPCs Requeridos

| RPC | Propósito |
|-----|-----------|
| `get_server_timestamp()` | Obtener timestamp del servidor para TTL |
| `retry_failed_sync()` | Reintentar transacción desde Dead Letter Queue |

### Índices Optimizados

- `idx_products_store_active` - Productos con stock por tienda
- `idx_clients_with_balance` - Clientes con saldo pendiente
- `idx_sales_today` - Ventas del día
- `idx_sync_failed_pending` - Transacciones pendientes de reintento

---

## Componentes UX/UI

### Indicadores Visuales

| Componente | Trigger | Posición | Color |
|------------|---------|----------|-------|
| `SyncIndicator` | `isValidating === true` | Header de vistas | Azul (#3B82F6) |
| `StaleDataBanner` | `isStale && !isValidating` | Debajo del header | Ámbar (#F59E0B) |
| `OfflineBanner` | `!navigator.onLine` | Top fijo (App.vue) | Rojo (#EF4444) |
| `SyncQueueStatus` | `queue.length > 0` | Dashboard | Azul/Rojo |

### Estados de Conexión

| Estado | Visual | Comportamiento |
|--------|--------|----------------|
| Offline | Banner rojo fijo | Persistente |
| Reconectando | Banner ámbar + spinner | Transición |
| Reconectado | Banner verde | Fade out 3s |

### Tokens de Diseño

| Token | Valor | Uso |
|-------|-------|-----|
| `--sync-validating` | #3B82F6 | Spinner de revalidación |
| `--sync-stale` | #F59E0B | Banner datos desactualizados |
| `--sync-offline` | #EF4444 | Banner sin conexión |
| `--sync-success` | #22C55E | Conexión restaurada |

---

## Casos de Uso

### CU-01: Usuario abre vista de inventario

**Actor:** Vendedor  
**Precondición:** Usuario autenticado  
**Flujo Principal:**
1. Sistema muestra datos del caché local inmediatamente
2. Sistema inicia revalidación en background
3. Si hay cambios, UI se actualiza sin parpadeo
4. Indicador de sync desaparece al completar

**Flujo Alternativo (Sin conexión):**
1. Sistema muestra datos del caché con banner "Datos de hace X min"
2. Usuario puede forzar actualización manualmente

### CU-02: Usuario realiza venta sin conexión

**Actor:** Vendedor  
**Precondición:** Tienda abierta, sin conexión a internet  
**Flujo Principal:**
1. Usuario completa venta normalmente
2. Sistema muestra "Transacción guardada localmente"
3. Venta se agrega a cola de sincronización
4. Dashboard muestra "X transacciones pendientes"
5. Al recuperar conexión, sistema sincroniza automáticamente

**Flujo Alternativo (Falla sincronización):**
1. Sistema reintenta hasta 5 veces
2. Si falla, mueve a Dead Letter Queue
3. Notifica al usuario "Transacción falló después de 5 intentos"
4. Admin puede reintentar manualmente desde AdminHub

### CU-03: Evento Realtime actualiza datos

**Actor:** Sistema  
**Precondición:** Usuario online, suscripción activa  
**Flujo Principal:**
1. Otro dispositivo modifica producto
2. Supabase envía evento Realtime
3. Sistema hace merge inteligente del dato específico
4. UI se actualiza sin refetch completo

---

## Criterios de Aceptación

### Funcionalidad
- [ ] Composable `useCache.ts` soporta las 4 estrategias
- [ ] Stores migrados con configuración apropiada
- [ ] Cola offline para `sales` y `expenses`
- [ ] Invalidación automática de `inventory` después de venta
- [ ] Integración con Supabase Realtime

### Seguridad (Mitigaciones)
- [ ] MIT-01: Sanitización de caché implementada
- [ ] MIT-02: Límite de reintentos con Dead Letter Queue
- [ ] MIT-03: Store `auth` no persiste tokens
- [ ] MIT-04: Mutex en revalidación
- [ ] MIT-05: Timestamp del servidor

### UX/UI
- [ ] `SyncIndicator` visible durante revalidación
- [ ] `StaleDataBanner` con tiempo y acción de refresh
- [ ] `OfflineBanner` con 3 estados (offline/reconectando/online)
- [ ] `SyncQueueStatus` con contadores

### Backend
- [ ] Realtime en 4 tablas
- [ ] Tabla `sync_queue_failed` con RLS
- [ ] RPCs `get_server_timestamp` y `retry_failed_sync`
- [ ] Índices optimizados

---

## Impacto en el Sistema

| Componente | Tipo | Descripción |
|------------|------|-------------|
| `src/composables/useCache.ts` | NEW | Composable de caché SWR |
| `src/composables/useOnlineStatus.ts` | NEW | Detección de conexión |
| `src/data/syncQueue.ts` | NEW | Cola de sincronización offline |
| `src/components/ui/SyncIndicator.vue` | NEW | Indicador de revalidación |
| `src/components/ui/StaleDataBanner.vue` | NEW | Banner datos stale |
| `src/components/ui/OfflineBanner.vue` | NEW | Banner sin conexión |
| `src/components/ui/SyncQueueStatus.vue` | NEW | Estado de cola offline |
| `src/stores/*.ts` | MODIFY | Integrar useCache |
| `supabase-schema.sql` | MODIFY | Tabla DLQ + RPCs + índices |
| `04_DESIGN_SYSTEM.md` | MODIFY | Tokens de sincronización |
| `05_COMPONENT_LOGIC.md` | MODIFY | Lógica de componentes sync |

---

## Lista de Tareas de Alto Nivel

### Fase 1: Backend (Prerrequisito)
1. [ ] Ejecutar SQL para crear `sync_queue_failed`
2. [ ] Crear RPCs `get_server_timestamp` y `retry_failed_sync`
3. [ ] Habilitar Realtime en tablas críticas
4. [ ] Agregar RLS a nueva tabla

### Fase 2: Core Frontend
5. [ ] Implementar composable `useCache.ts`
6. [ ] Implementar `syncQueue.ts`
7. [ ] Implementar `useOnlineStatus.ts`
8. [ ] Migrar stores a useCache

### Fase 3: UI/UX
9. [ ] Crear `SyncIndicator.vue`
10. [ ] Crear `StaleDataBanner.vue`
11. [ ] Crear `OfflineBanner.vue`
12. [ ] Crear `SyncQueueStatus.vue`
13. [ ] Integrar en vistas correspondientes

### Fase 4: Verificación
14. [ ] Test: Caché funciona offline
15. [ ] Test: Sincronización al reconectar
16. [ ] Test: Dead Letter Queue funciona
17. [ ] Test: Realtime actualiza UI

---

## Historial de Revisiones

| Fecha | Versión | Autor | Cambios |
|-------|---------|-------|---------|
| 2026-01-20 | v1.0 | Arquitecto | Documento inicial |
| 2026-01-20 | v1.1 | QA | Mitigaciones MIT-01 a MIT-09 |
| 2026-01-20 | v1.2 | Data | Requisitos Backend/Supabase |
| 2026-01-20 | v1.3 | UX | Componentes visuales y tokens |
| 2026-01-20 | v2.0 | Arquitecto | **Consolidación final sin código** |

---

## Referencias

- [SWR - React Hooks for Data Fetching](https://swr.vercel.app/)
- [Supabase Realtime](https://supabase.com/docs/guides/realtime)
- [RFC 5861 - HTTP Cache-Control Extensions](https://datatracker.ietf.org/doc/html/rfc5861)