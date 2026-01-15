# Centro de Notificaciones (NotificationCenterView)

## Descripción
Vista centralizada para mostrar y gestionar las notificaciones del sistema. Incluye alertas de seguridad, inventario, finanzas y generales, con soporte para notificaciones accionables.

## Ruta
`/notifications`

---

## Tipos de Notificación

| Tipo | Icono | Color Fondo | Color Texto | Ejemplo |
|------|-------|-------------|-------------|---------|
| `security` | `lock_person` | Rojo | Rojo | Solicitud de acceso desde dispositivo |
| `inventory` | `inventory_2` | Naranja | Naranja | Stock bajo en producto |
| `finance` | `payments` | Verde | Verde | Pago recibido |
| `general` | `notifications_active` | Gris | Gris | Cierre de caja exitoso |

---

## Estructura de Notificación

```typescript
interface Notification {
    id: string;
    type: 'security' | 'inventory' | 'finance' | 'general';
    title: string;
    message: string;
    time: string;           // "Hace 5 min", "Ayer"
    isRead: boolean;
    actionable?: boolean;   // Tiene botones de acción
}
```

---

## Flujo de Usuario

### Ver Notificaciones
1. Usuario accede desde Dashboard (ícono de campana)
2. Ve lista de notificaciones ordenadas por fecha
3. Notificaciones no leídas tienen fondo azul y borde izquierdo
4. Notificaciones leídas tienen fondo blanco/gris

### Marcar como Leídas
1. Click en **"Marcar todo leído"** (visible solo si hay no leídas)
2. Sistema marca todas las notificaciones como `isRead: true`

### Notificaciones Accionables
1. Usuario ve notificación de seguridad con botones
2. Click **"Aprobar"** → Aprueba acción y elimina notificación
3. Click **"Rechazar"** → Rechaza acción y elimina notificación

---

## Estado Local

| Estado | Tipo | Descripción |
|--------|------|-------------|
| `notifications` | `Notification[]` | Lista de notificaciones (datos de ejemplo) |

> [!NOTE]
> Actualmente las notificaciones son **datos de ejemplo estáticos**. No hay integración con stores del sistema.

---

## Propiedades Computadas

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `hasUnreadNotifications` | `boolean` | ¿Hay al menos una no leída? |
| `isEmpty` | `boolean` | ¿Lista vacía? |

---

## Métodos

| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `goBack()` | - | Navega a página anterior |
| `markAllAsRead()` | - | Marca todas como leídas |
| `handleApprove()` | `notificationId: string` | Aprueba y elimina notificación |
| `handleReject()` | `notificationId: string` | Rechaza y elimina notificación |
| `removeNotification()` | `id: string` | Elimina notificación de la lista |
| `getIconConfig()` | `type: string` | Retorna icono y colores según tipo |

---

## Estados Visuales

### Notificación No Leída
- Fondo: `bg-blue-50` / `bg-primary/10`
- Borde izquierdo: `border-primary` (4px)
- Título: `font-bold`
- Indicador de punto azul (excepto accionables)

### Notificación Leída
- Fondo: `bg-white` / `bg-surface-dark`
- Sin borde izquierdo
- Título: `font-semibold`
- Opacidad: 90%

### Notificación Accionable
- Muestra botones "Aprobar" y "Rechazar"
- Solo visible si no está leída
- Botones ocupan ancho completo en 2 columnas

---

## Estado Vacío

Si no hay notificaciones:
- Icono `notifications_off` (grande, opaco)
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

## Componentes UI

- Header sticky con botón de retroceso
- Botón "Marcar todo leído" (condicional)
- Lista de tarjetas de notificación
- Indicadores visuales de estado (leído/no leído)
- Botones de acción para notificaciones accionables

---

## Limitaciones Actuales

> [!WARNING]
> Esta vista actualmente usa **datos estáticos de ejemplo**. 
> Para producción, requiere:
> - Store de notificaciones (`useNotificationsStore`)
> - Integración con `inventoryStore` para alertas de stock bajo
> - Integración con `salesStore` para alertas financieras
> - WebSocket/Push notifications para tiempo real
