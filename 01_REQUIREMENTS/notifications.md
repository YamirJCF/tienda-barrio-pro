# Sistema de Notificaciones

> **Estado:** ✅ APROBADO PARA IMPLEMENTACIÓN  
> **Versión:** 1.1 Final (con mitigaciones QA)  
> **Fecha:** 2026-01-15  
> **Revisores:** Arquitecto de Producto, UX/UI Designer, Arquitecto de Datos, QA y Auditoría

---

## Descripción

Sistema dual de notificaciones que combina mensajes toast (feedback inmediato) con un Centro de Notificaciones persistente para alertas del sistema.

---

## Subsistemas

### 1. Notificaciones Toast (Implementado ✅)
Mensajes temporales que aparecen en pantalla durante 3-5 segundos.

### 2. Centro de Notificaciones (Por Implementar 🔧)
Vista persistente con historial de alertas del sistema.

**Ruta:** `/notifications`

---

## Reglas de Negocio

1. Las notificaciones toast desaparecen automáticamente después de su duración
2. Las notificaciones del Centro persisten hasta ser leídas o eliminadas
3. El badge del Dashboard muestra el conteo de notificaciones no leídas
4. Cuando no hay notificaciones no leídas, el badge no se muestra
5. Los timestamps se muestran en formato relativo ("Hace 5 min", "Ayer")
6. Cada tipo de notificación tiene icono y color distintivo
7. **[QA]** `title` máximo 100 caracteres, `message` máximo 500 caracteres
8. **[QA]** Stock bajo genera notificación **una sola vez** por producto (flag `notifiedLowStock`)
9. **[QA]** Notificaciones de seguridad expiran en 24h si no hay respuesta
10. **[QA]** Rate limit: máximo 5 notificaciones por tipo por minuto


---

## Catálogo de Notificaciones Toast

| Componente | Evento Disparador | Mensaje | Tipo | Icono | Duración |
|------------|-------------------|---------|------|-------|----------|
| `POSView` | Venta completada (online) | `¡Venta {ticket} guardada!` | success | check_circle | 3s |
| `POSView` | Venta completada (offline) | `Venta {ticket} guardada localmente` | warning | cloud_off | 4s |
| `POSView` | PLU no encontrado | `Producto no encontrado: {plu}` | error | error | 5s |
| `POSView` | Producto agregado | `{cantidad}x {nombre} agregado` | success | check_circle | 3s |
| `Router` | POS bloqueado por tienda cerrada | `Inicie jornada para vender` | warning | storefront | 4s |
| `useNetworkStatus` | Conexión perdida | `Sin conexión a internet` | warning | wifi_off | 4s |
| `useNetworkStatus` | Conexión restaurada | `Conexión restaurada` | info | wifi | 3s |

---

## Catálogo de Notificaciones del Centro

| Tipo | Icono | Color | Evento Disparador | Título | Mensaje | Accionable |
|------|-------|-------|-------------------|--------|---------|------------|
| `security` | shield | Rojo | Solicitud de acceso | Solicitud de Acceso | {empleado} intenta acceder desde {dispositivo} | Sí |
| `inventory` | inventory_2 | Naranja | Stock < min_stock | Stock Bajo: {producto} | Quedan {cantidad} unidades | No |
| `finance` | payments | Verde | Cierre de caja exitoso | Cierre de Caja | Arqueo completado. Balance: ${monto} | No |
| `finance` | payments | Verde | Venta fiado registrada | Venta a Crédito | {cliente} tiene nueva deuda de ${monto} | No |
| `general` | store | Azul | Tienda abierta | Jornada Iniciada | Tienda abierta con base de ${monto} | No |

---

## Estructura de Datos

### Notificación del Centro (Corregido)

```typescript
interface SystemNotification {
    id: string;                                          // UUID único
    type: 'security' | 'inventory' | 'finance' | 'general';
    icon: string;                                        // Material Symbol name
    title: string;
    message: string;
    createdAt: string;                                   // ISO timestamp
    isRead: boolean;
    actionable?: boolean;
    metadata?: {
        productId?: string;    // UUID (corregido de number)
        clientId?: string;     // UUID
        saleId?: string;       // UUID
        amount?: number;       // Decimal (corregido de string)
    };
}
```

### Notificación Toast (Existente)

```typescript
interface ToastNotification {
    id: number;
    type: 'success' | 'error' | 'info' | 'warning';
    message: string;
    icon?: string;
    duration: number;
}
```

---

## Store de Notificaciones (Nuevo)

### Estado
| Estado | Tipo | Descripción |
|--------|------|-------------|
| `notifications` | `SystemNotification[]` | Lista de notificaciones persistentes |

### Getters
| Getter | Tipo | Descripción |
|--------|------|-------------|
| `unreadCount` | `number` | Cantidad de no leídas |
| `hasUnread` | `boolean` | ¿Hay al menos una no leída? |
| `sortedByDate` | `SystemNotification[]` | Ordenadas por fecha descendente |

### Acciones
| Acción | Parámetros | Descripción |
|--------|------------|-------------|
| `addNotification()` | `Omit<SystemNotification, 'id' | 'createdAt'>` | Agrega nueva notificación |
| `markAsRead()` | `id: string` | Marca una como leída |
| `markAllAsRead()` | - | Marca todas como leídas |
| `removeNotification()` | `id: string` | Elimina una notificación |
| `clearAll()` | - | Elimina todas las notificaciones |

### Persistencia
- Almacenamiento: `localStorage` con key `app_notifications`
- Límite: Máximo 50 notificaciones (las más antiguas se eliminan)
- TTL: Notificaciones mayores a 30 días se eliminan automáticamente

### Validación de Entrada (QA)

```typescript
// Implementar en addNotification()
const isValidNotification = (n: Partial<SystemNotification>): boolean => {
  if (!n.title || n.title.length > 100) return false;
  if (!n.message || n.message.length > 500) return false;
  if (!['security', 'inventory', 'finance', 'general'].includes(n.type!)) return false;
  if (n.metadata?.productId && !isValidUUID(n.metadata.productId)) return false;
  if (n.metadata?.clientId && !isValidUUID(n.metadata.clientId)) return false;
  return true;
};
```

### Resiliencia (QA)

| Escenario | Comportamiento |
|-----------|----------------|
| localStorage lleno | Eliminar notificaciones más antiguas hasta liberar espacio |
| Datos corruptos | Try/catch + reset graceful (`localStorage.removeItem`) |
| Tipo inválido | Defaultear a tipo `general` |
| Hidratación fallida | Retornar array vacío sin crashear |

---

## Casos de Uso

### UC-01: Ver Notificaciones
- **Actor:** Usuario autenticado
- **Precondición:** Usuario en cualquier vista autenticada
- **Flujo Principal:**
  1. Usuario hace click en icono de campana (Dashboard)
  2. Sistema navega a `/notifications`
  3. Usuario ve lista ordenada por fecha con timestamps relativos
  4. Cada notificación muestra icono según tipo
  5. Notificaciones no leídas tienen fondo azul y borde izquierdo
- **Flujo Alternativo:** Si no hay notificaciones, muestra estado vacío

### UC-02: Recibir Notificación de Stock Bajo
- **Actor:** Sistema
- **Precondición:** Producto con `min_stock` definido
- **Flujo Principal:**
  1. Se actualiza el stock de un producto
  2. Stock queda por debajo del `min_stock`
  3. Sistema crea notificación tipo `inventory` con icono `inventory_2`
  4. Badge del Dashboard se actualiza

### UC-03: Recibir Notificación de Cierre de Caja
- **Actor:** Sistema
- **Precondición:** Tienda abierta con ventas
- **Flujo Principal:**
  1. Administrador completa el arqueo de caja
  2. Sistema registra el cierre exitoso
  3. Sistema crea notificación tipo `finance` con icono `payments`
  4. Badge del Dashboard se actualiza

### UC-04: Marcar Todas como Leídas
- **Actor:** Usuario autenticado
- **Precondición:** Existen notificaciones no leídas
- **Flujo Principal:**
  1. Usuario está en `/notifications`
  2. Click en "Marcar todo leído"
  3. Sistema marca todas como `isRead: true`
  4. Badge del Dashboard desaparece

---

## Criterios de Aceptación

- [ ] Store `useNotificationsStore` creado con persistencia localStorage
- [ ] Badge en Dashboard muestra conteo real de no leídas
- [ ] Badge se oculta cuando no hay notificaciones sin leer
- [ ] Notificación de stock bajo se genera cuando stock < min_stock
- [ ] Notificación de cierre de caja se genera tras arqueo exitoso
- [ ] Centro de Notificaciones muestra datos del store (no estáticos)
- [ ] Botón "Marcar todo leído" funciona correctamente
- [ ] Cada tipo muestra icono y color distintivo
- [ ] Timestamps muestran formato relativo (Hace X min, Ayer)

---

## Lista de Tareas de Alto Nivel

### MVP (Fase 1)
1. [ ] Crear `stores/notificationsStore.ts` con persistencia localStorage
2. [ ] Crear helper `formatRelativeTime(date)` en composables
3. [ ] Modificar `stores/inventory.ts` - disparar notificación en stock bajo
4. [ ] Modificar `stores/sales.ts` - disparar notificación en cierre de caja
5. [ ] Modificar `views/NotificationCenterView.vue` - conectar a store
6. [ ] Modificar `views/DashboardView.vue` - badge dinámico con conteo
7. [ ] Verificar funcionamiento end-to-end

### Post-MVP (Fase 2)
- [ ] Agrupación por día (Hoy, Ayer, Anteriores)
- [ ] Filtros por categoría
- [ ] Swipe-to-dismiss en móvil

---

## Impacto en el Sistema

| Componente | Modificación |
|------------|--------------|
| `stores/notificationsStore.ts` | **NUEVO** - Store Pinia con persistencia |
| `composables/useRelativeTime.ts` | **NUEVO** - Helper para timestamps relativos |
| `stores/inventory.ts` | Agregar llamada a `notificationsStore.addNotification()` |
| `stores/sales.ts` | Agregar llamada en `closeStore()` |
| `views/NotificationCenterView.vue` | Conectar a store, eliminar datos estáticos |
| `views/DashboardView.vue` | Badge condicional con `unreadCount` |

---

## Iconografía por Tipo

| Tipo | Material Symbol | Color Fondo | Color Icono |
|------|-----------------|-------------|-------------|
| `security` | `shield` | `bg-red-100` | `text-red-600` |
| `inventory` | `inventory_2` | `bg-orange-100` | `text-orange-600` |
| `finance` | `payments` | `bg-green-100` | `text-green-600` |
| `general` | `store` | `bg-blue-100` | `text-blue-600` |

---

## Estados Visuales

### Notificación No Leída
- Fondo: `bg-blue-50` / `bg-primary/10`
- Borde izquierdo: `border-primary` (4px)
- Título: `font-bold`

### Notificación Leída
- Fondo: `bg-white` / `bg-surface-dark`
- Sin borde izquierdo
- Opacidad: 90%

### Estado Vacío
- Icono `notifications_off`
- Texto: "Estás al día"
- Subtexto: "No tienes nuevas notificaciones"

---

## Navegación

### Desde
| Origen | Acción |
|--------|--------|
| Dashboard | Click en ícono de campana |

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Página anterior | Botón ← | `router.back()` |

---

## Revisiones Incorporadas

| Fuente | Corrección | Estado |
|--------|------------|--------|
| `obs-ux-notifications.md` | Agregar campo `icon` a interface | ✅ Incorporado |
| `obs-ux-notifications.md` | Timestamps relativos | ✅ Incorporado |
| `obs-ux-notifications.md` | Iconografía por tipo | ✅ Incorporado |
| `obs-data-notifications.md` | `metadata.productId` → string (UUID) | ✅ Incorporado |
| `obs-data-notifications.md` | `metadata.amount` → number | ✅ Incorporado |
| `obs-data-notifications.md` | Agregar `metadata.saleId` | ✅ Incorporado |
| `obs-qa-notifications.md` | Validación de longitud title/message | ✅ Incorporado |
| `obs-qa-notifications.md` | Validación UUID en metadata | ✅ Incorporado |
| `obs-qa-notifications.md` | Flag anti-duplicado stock bajo | ✅ Incorporado |
| `obs-qa-notifications.md` | Rate limiting por tipo | ✅ Incorporado |
| `obs-qa-notifications.md` | Resiliencia localStorage | ✅ Incorporado |
| `obs-qa-notifications.md` | TTL para notificaciones antiguas | ✅ Incorporado |

