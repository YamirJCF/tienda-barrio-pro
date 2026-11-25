# Contexto C7 — Gobierno de Tienda y Shell Global

> **Estado:** Consolidado Ola 2 (`UX-ADR-009` — 2026-11-25)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-009`)  
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
  ├── Árbitro N5 [App.vue]: activeN5Overlay (7 overlays con CriticalAlertModal)
  └── Enrutador N4 [/notifications]: metadata -> deep-links hacia C1..C7

Gobierno de Tienda:
  ├── Empleado (1) [máx. 5 operativos activos] ── Permisos SDD-003-01 (4 booleanos) + PIN
  ├── Pase Diario / Dispositivo (1) ── Estado (pending | approved | rejected | expired)
  └── Versión Legal SaaS [SDD-029]  ── Aceptación por tienda / publicación plataforma
```

### 2.2 Matriz Global de CTAs (`Verbo × Objeto`)

| Verbo + Objeto | Rol autorizado | Red | Estado Anterior | Estado Consolidado (`UX-ADR-009`) |
|---|---|---|---|---|
| **Navegar Top Tasks (`BottomNav`)** | Según `SDD-003-01` | N/A | `BottomNav.vue` sin enlace a `/` | `BottomNav.vue` con botón **Inicio (`/`)** + Top Tasks sincronizadas (`grid-cols-1..6`) |
| **Alternar estado Caja desde `DashboardView`** | `Admin`, `canOpenCloseCash` | Online | Enlace a `/admin?tab=gestion` | Enlace a `/admin`, logout explícito `/login` y control de Caja alineado |
| **Gestionar `Empleado` y Permisos** | `Admin` | Online | `/employees` sin error de carga | `/employees` con `BaseListSkeleton`, Banner `N3` + Reintentar y aviso `N1` `5/5` |
| **Enrutar `Notificación N4`** | `Admin` / Empleado | Online | `/notifications` solo marca leída | `/notifications` marca leída **y** enruta vía `metadata` y permisos |
| **Gestionar `Árbitro N5` y `Toasts N2`** | Sistema / `Admin` | Local + Online | 6 overlays sin árbitro, `CriticalAlertModal` desconectado, `alert()` y `vue-toastification` fuera de `C8` | 1 motor toast Lucide (`ToastNotification.vue`), árbitro `activeN5Overlay` con 7 overlays, cero `alert()`/`material-icons` fuera de `C8` |

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
| **C7-H1** | 🔴 **CRÍTICO** | [`ToastNotification.vue`](../../../frontend/src/components/ToastNotification.vue); [`App.vue`](../../../frontend/src/App.vue); [`OfflineBanner.vue`](../../../frontend/src/components/common/OfflineBanner.vue); [`ConflictResolver.vue`](../../../frontend/src/components/common/ConflictResolver.vue) | 1) `ToastNotification.vue` pasaba strings a `<component :is>` y `useSessionGuard.ts` importaba `vue-toastification`.<br>2) `CriticalAlertModal` sin montar y sin árbitro `N5`.<br>3) `OfflineBanner.vue` ignoraba `dismissed` y usaba `material-icons`/emoji.<br>4) `alert()` y `material-icons` en `App.vue` y `ConflictResolver.vue` (con `ForceSaleModal` fuera de `<template>`). | ✅ **Cerrado (`UX-ADR-009`):** Lucide mapeado en `ToastNotification`, `useSessionGuard` unificado, árbitro `activeN5Overlay` en `App.vue` montando los 7 overlays, `ForceSaleModal` en `<template>` con errores `N1` y `baselineDebt = 0` fuera de `C8`. |
| **C7-H2** | 🟠 **ALTO** | [`DashboardView.vue`](../../../frontend/src/views/DashboardView.vue); [`BottomNav.vue`](../../../frontend/src/components/BottomNav.vue); [`AdminHubView.vue`](../../../frontend/src/views/AdminHubView.vue) | Faltaba retorno a `/` en `BottomNav`, `DashboardView` apuntaba a `/admin?tab=gestion`, y `AdminHubView` formateaba moneda manualmente y agrupaba Proveedores bajo Inventario con emojis. | ✅ **Cerrado (`UX-ADR-009`):** `Inicio` (`/`) primero en `BottomNav`, `/admin` + logout `/login` en `DashboardView`, `formatWithSign` + Lucide y secciones separadas (`Abastecimiento`, `Inventario`, `Reportes`) en `AdminHubView`. |
| **C7-H3** | 🟠 **ALTO** | [`NotificationCenterView.vue`](../../../frontend/src/views/NotificationCenterView.vue); [`notificationsStore.ts`](../../../frontend/src/stores/notificationsStore.ts) | `handleNotificationClick` solo marcaba leída sin enrutar por `metadata` y usaba `border-l-4`. | ✅ **Cerrado (`UX-ADR-009`):** `resolveNotificationTarget(n)` con validación de permisos (`C3`, `C4`, `C5`, `C6`, `/cash-control`), `metadata` normalizado y sin `border-l-4`. |
| **C7-H4** | 🟡 **MEDIO** | [`EmployeeManagerView.vue`](../../../frontend/src/views/EmployeeManagerView.vue); [`employees.ts`](../../../frontend/src/stores/employees.ts); [`DailyWaitingRoom.vue`](../../../frontend/src/views/DailyWaitingRoom.vue); [`devices.ts`](../../../frontend/src/stores/devices.ts) | `/employees` sin `N3`/skeleton ni aviso `N1` `5/5`, conteo con `activeEmployees` en vez de operativos, y `DailyWaitingRoom.vue` importaba `supabase` directamente. | ✅ **Cerrado (`UX-ADR-009`):** Skeleton + Banner `N3` + aviso `N1` `5/5` + `@username`, conteo `activeOperationalEmployees`, y suscripción Realtime encapsulada en `useDevicesStore`. |
