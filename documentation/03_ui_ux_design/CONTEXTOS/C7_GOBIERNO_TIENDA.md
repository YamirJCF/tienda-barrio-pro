# Contexto C7 — Gobierno de Tienda y Shell Global

> **Estado:** Cartografía Ola 1 (`Lote 1C` — solo documentación)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-001`)  
> **Restricción de conectividad:** **Online obligatorio** para todas las acciones de gobierno, permisos, pases diarios y notificaciones ([`PRODUCT.md`](../../../PRODUCT.md#L38)).

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Abarcar el **Shell Global** de navegación y señalización transversal (`DashboardView.vue`, `BottomNav.vue`, `App.vue`) junto con la administración operativa de la tienda: empleados y permisos (`SDD-003-01`), sala diaria de autorización, bandeja de notificaciones `N4` y gestión legal (`SDD-029`).

### 1.2 Rutas Actuales vs. Objetivo Canónico

| Ruta | Vista / Componente | Estado en `ux-manifest.json` | Arquetipo | Destino Objetivo (Ola 2) |
|---|---|---|---|---|
| `/` *(alias `/dashboard`)* | [`DashboardView.vue`](../../../frontend/src/views/DashboardView.vue) (`Shell`) | `canonica` | `Hub` | **Se mantiene canónica:** Hub operativo con toggle de caja condicionado a `canOpenCloseCash`. |
| `/admin` | [`AdminHubView.vue`](../../../frontend/src/views/AdminHubView.vue) | `canonica` | `Hub` | **Se mantiene canónica como Hub puro:** retira `globalCreditLimit` hacia `C4` (`/clients`) y reubica Proveedores fuera de Inventario. |
| `/employees` | [`EmployeeManagerView.vue`](../../../frontend/src/views/EmployeeManagerView.vue) | `canonica` | `B` | **Se mantiene canónica:** Lista + Ficha/Modal de empleado con permisos `SDD-003-01` (máx. 5 activos). |
| `/notifications` | [`NotificationCenterView.vue`](../../../frontend/src/views/NotificationCenterView.vue) (`N4`) | `canonica` | `E` | **Se mantiene canónica como Enrutador OOUX:** al pulsar notificación navega al Hogar Canónico vía `metadata`. |
| `/daily-waiting-room` | [`DailyWaitingRoom.vue`](../../../frontend/src/views/DailyWaitingRoom.vue) | `canonica` | `F` | **Se mantiene canónica:** Compuerta diaria de pase con suscripción encapsulada en Store/Repo (sin `supabase` directo en vista). |
| `/legal/privacy` *(alias `/legal/terms`)* | [`PrivacyPolicyView.vue`](../../../frontend/src/views/PrivacyPolicyView.vue) | `canonica` | `E` | **Se mantiene canónica (`public`).** |
| `/platform/legal` | [`PlatformLegalAdminView.vue`](../../../frontend/src/views/PlatformLegalAdminView.vue) | `canonica` | `B` | **Se mantiene canónica (`public` intencional):** Ver nota de seguridad abajo. |

> **Nota verificada sobre `/platform/legal`:** Su `requiresAuth: false` en [`router/index.ts`](../../../frontend/src/router/index.ts#L53-L57) es **intencional y correcto**, porque [`PlatformLegalAdminView.vue`](../../../frontend/src/views/PlatformLegalAdminView.vue#L1-L30) autentica directamente al **Dueño de Plataforma SaaS** en el servidor vía `legalRepository`, de forma independiente a la sesión operativa de tienda.

### 1.3 Matriz de Permisos (`SDD-003-01`)

| Capacidad / Acción | `Admin` | Empleado | Público | Evidencia en Código |
|---|---|---|---|---|
| Hub operativo `/` y `/notifications` | ✅ | ✅ *(audiencia filtrada)* | ❌ | `requiresAuth` en `router/index.ts` |
| Abrir `/admin` y gestionar `/employees` | ✅ | ❌ | ❌ | [`router/index.ts`](../../../frontend/src/router/index.ts#L337-L349) (`!authStore.isAdmin`) |
| Sala de espera diaria `/daily-waiting-room` | N/A | ✅ *(pase pendiente)* | ❌ | `requiresAuth` + redirección en `router.beforeEach` |
| Consulta legal `/legal/privacy` y consola `/platform/legal` | ✅ | ✅ | ✅ *(admin plataforma con auth propia)* | `requiresAuth: false` |

---

## §2. Matriz ORCA (Objetos, Relaciones, CTAs y Shell)

### 2.1 Objetos Canónicos

```text
Shell Global [App.vue + BottomNav.vue + DashboardView.vue]
  ├── Árbitro N5 [App.vue]: Cola única de overlays globales (6 montados)
  └── Enrutador N4 [/notifications]: metadata -> deep-links hacia C1..C7

Gobierno de Tienda:
  ├── Empleado (1) [máx. 5 activos] ── Permisos SDD-003-01 (4 booleanos) + PIN
  ├── Pase Diario / Dispositivo (1) ── Estado (pending | approved | rejected | expired)
  └── Versión Legal SaaS [SDD-029]  ── Aceptación por tienda / publicación plataforma
```

### 2.2 Matriz Global de CTAs (`Verbo × Objeto`)

| Verbo + Objeto | Rol autorizado | Red | Hogar Actual | Hogar Canónico Objetivo |
|---|---|---|---|---|
| **Navegar Top Tasks (`BottomNav`)** | Según `SDD-003-01` | N/A | `BottomNav.vue` sin enlace a `/` | `BottomNav.vue` con acceso preservado a `/` y Top Tasks sincronizadas |
| **Alternar estado Caja desde `DashboardView`** | `Admin`, `canOpenCloseCash` | Online | Toggle visible para todos (rebota en router si no tiene permiso) | Toggle visible/accionable solo para `canOpenCloseCash`; empleado sin permiso ve solo estado informativo |
| **Gestionar `Empleado` y Permisos** | `Admin` | Online | `/employees` (`EmployeeManagerView.vue`, sin error de carga) | `/employees` con Banner `N3` + Reintentar y aviso `N1` de límite `5/5` |
| **Enrutar `Notificación N4`** | `Admin` / Empleado | Online | `/notifications` solo marca leída (sin navegar) | `/notifications` marca leída **y** navega al objeto vía `metadata` |
| **Gestionar `Árbitro N5` y `Toasts N2`** | Sistema / `Admin` | Local + Online | 6 overlays sin cola en `App.vue`, `CriticalAlertModal` sin montar, 2 motores toast | 1 motor toast (`ToastNotification.vue` con Lucide), 1 árbitro `N5` con prioridad fija, cero `alert()`/`material-icons` |

---

## §3. Breadboards (Shell Actual vs. Shell Objetivo)

### 3.1 Breadboard Actual (Shell y Señalización Fragmentada)

```text
[App.vue (Shell Raíz)]
  ├── errorDetected -> pantalla roja fatal
  ├── alert() nativo en handleSyncAuthRequired (L65)
  ├── CriticalAlertModal importado + useCriticalAlerts() (L10-33) -> JAMÁS renderizado en <template> (L139-198)
  ├── 6 overlays montados sin árbitro de prioridad:
  │     GlobalNetworkHandler | OfflineBanner (Cerrar inoperante, material-icons, 📡)
  │     LegalComplianceGate | GlobalAccessRequestModal | PinUnlockModal
  │     ToastNotification (getIcon() pasa strings Material a <component :is>, L23-50)
  └── ConflictResolver.vue -> usa 4 alert() y 9 material-icons (deuda baselineDebt)

[DashboardView.vue] ── botón Caja (L116-120, L191-210) ──> /cash-control (rebote silencioso si !canOpenCloseCash)
[AdminHubView.vue] ── mezcla globalCreditLimit [C4] (L348-395) + Proveedores bajo "📦 Inventario" (L399-405)
[NotificationCenterView.vue] ── click notificación (L74-78) ──> markAsRead() (callejón sin salida, ignora metadata)
```

### 3.2 Breadboard Objetivo (Shell Coherente + Árbitro Único `N5` + Enrutador `N4`)

```text
[App.vue — Árbitro Único de Prioridad N5]
  └── Jerarquía estricta: 1. Error fatal/integridad -> 2. Sesión/Legal -> 3. Pase/PIN -> 4. CriticalAlertModal
        ├── ToastNotification.vue (ÚNICO motor N2 con íconos Lucide reales)
        ├── OfflineBanner.vue (cierre funcional + Lucide, sin material-icons ni emojis)
        └── Cero alert() nativos (reemplazados por N2/N5 según severidad)

[BottomNav.vue] ── Top Tasks según SDD-003-01 + retorno claro a Inicio (/)
[AdminHubView.vue (Hub Puro)] ── Enlaza a C3 (/inventory), C5 (/suppliers), C6 (/reports), C7 (/employees)
[NotificationCenterView.vue (Enrutador N4)]
  └── Tap en notificación ──> markAsRead() + router.push(resolveDeepLink(notification.metadata))
                                ├── productId ──> /inventory?product=<id>&tab=batches
                                ├── clientId  ──> /clients/<id>
                                └── sessionId ──> /cash-control o /reports?tab=history (Admin)
```

---

## §4. Matriz de Señalización (`N1–N5`) y Plan Transversal de Saneamiento

| Nivel | Situación Actual (`baselineDebt` / Bugs) | Objetivo Canónico en Ola 2 |
|---|---|---|
| **N1 — Inline** | Límite `5/5` empleados solo por toast (`EmployeeManagerView.vue` L100) | Banner/aviso inline en botón `+ Nuevo Empleado` cuando alcanza `5/5`. |
| **N2 — Toast Efímero** | `ToastNotification.vue` roto (`<component :is>` recibe string) + **8** archivos usando `vue-toastification` (`baselineDebt`) | Unificar 100% en `ToastNotification.vue` con mapa explícito de íconos Lucide; vaciar `legacyToastImportsAllowed` hasta `0` *(salvo los archivos `C8` diferidos bajo Regla 11 si siguen sin autorización)*. |
| **N3 — Banner Persistente** | `OfflineBanner.vue` ignora `dismissed` (`v-if="!isOnline"`) y usa `material-icons` + `📡`; `EmployeeManagerView` sin error de carga | Corregir `v-if="!isOnline && !dismissed"`, migrar a Lucide, y añadir Banner `N3` con Reintentar en `/employees`. |
| **N4 — Bandeja `/notifications`** | `NotificationCenterView.vue` marca leída sin navegar y usa `border-l-4` | Conectar deep-links por `metadata` (`productId`, `clientId`, `saleId`, `sessionId`) y retirar `border-l-4`. |
| **N5 — Compuerta Bloqueante** | `CriticalAlertModal` muerto sin montar en `App.vue`; `alert()` en `App.vue` (L65) y `ConflictResolver.vue` (L164-261); sin arbitraje de cola | Definir árbitro único de prioridad en `App.vue`, decidir montaje/uso de `CriticalAlertModal`, erradicar `alert()` y `material-icons` de `ConflictResolver` (reduciendo `baselineDebt`). |

---

## §5. Hotspots Contables y de Dominio Verificados para Ola 2 (`FRD/SDD/SQL` antes de UI)

| ID | Severidad | Evidencia Verificada en Código | Brecha Sistémica / UX | Acción Requerida en Ola 2 |
|---|---|---|---|---|
| **C7-H1** | 🔴 **CRÍTICO** | [`ToastNotification.vue`](../../../frontend/src/components/ToastNotification.vue#L23-L50); [`App.vue`](../../../frontend/src/App.vue#L10-L33) (L65, L139-198); [`OfflineBanner.vue`](../../../frontend/src/components/common/OfflineBanner.vue#L10-L44); [`ConflictResolver.vue`](../../../frontend/src/components/common/ConflictResolver.vue#L9-L92) (L164, 188, 257, 261) | 1) Bug en `ToastNotification.vue` (`useNotifications` pasa strings Material Icons a `<component :is>`) + motor duplicado `vue-toastification` (8 archivos en `baselineDebt`).<br>2) `CriticalAlertModal` importado/inicializado pero **nunca montado** en `<template>` de `App.vue` (fallo silencioso).<br>3) `OfflineBanner.vue` con botón cerrar inoperante (`dismissed` sin usar en `v-if`), `material-icons` y emoji `📡`.<br>4) `alert()` nativo en `App.vue` (L65) y `ConflictResolver.vue` (4 llamadas + 9 `material-icons`).<br>5) 6 overlays montados en `App.vue` sin árbitro de prioridad. | Saneamiento integral del Shell de Comunicación (N2, N3, N5), montaje/resolución de `CriticalAlertModal` y reducción de `baselineDebt` (con `UX-ADR` cuando toque `App.vue`). |
| **C7-H2** | 🟠 **ALTO** | [`DashboardView.vue`](../../../frontend/src/views/DashboardView.vue#L116-L120) (L191-210); [`BottomNav.vue`](../../../frontend/src/components/BottomNav.vue#L49-L101); [`AdminHubView.vue`](../../../frontend/src/views/AdminHubView.vue#L177-L184) (L348-405) | 1) Toggle `ABIERTO/CERRADO` en `DashboardView.vue` envía a `/cash-control` a empleados sin `canOpenCloseCash` provocando rebote silencioso en router.<br>2) `BottomNav.vue` no ofrece acceso directo a `Inicio (/)`.<br>3) `AdminHubView.vue` mezcla `globalCreditLimit` de `C4` (L348-395), formatea moneda con `.replace(...)` regex (L177-184), ubica Proveedores bajo `📦 Inventario` (L399-405) y usa emojis. | Alinear permisos del toggle en `DashboardView`, restaurar camino a `/` en Shell (con `UX-ADR` en `BottomNav.vue`), mover `globalCreditLimit` a `C4` y limpiar `AdminHubView`. |
| **C7-H3** | 🟠 **ALTO** | [`NotificationCenterView.vue`](../../../frontend/src/views/NotificationCenterView.vue#L74-L78) y L198-199 | `handleNotificationClick` solo marca leída la notificación e ignora `metadata` (`productId`, `clientId`, `saleId`, `sessionId`), dejando `/notifications` como callejón sin salida; además usa `border-l-4` prohibido en `DESIGN.md`. | Implementar enrutamiento OOUX desde `metadata` hacia `C1..C7` y retirar `border-l-4`. |
| **C7-H4** | 🟡 **MEDIO** | [`EmployeeManagerView.vue`](../../../frontend/src/views/EmployeeManagerView.vue#L32-L37) y L100; [`DailyWaitingRoom.vue`](../../../frontend/src/views/DailyWaitingRoom.vue#L18-L69) | 1) `EmployeeManagerView.vue` no expone estado visual de error/Reintentar si falla `initialize` (Regla 3) y comunica el límite `5/5` solo con toast efímero.<br>2) `DailyWaitingRoom.vue` importa `supabase` directamente en la vista (viola One Way Data Flow). | Agregar Banner `N3` + Reintentar y aviso inline `5/5` en `/employees`; encapsular canal Realtime de `daily_passes` en Repository/Store. |
