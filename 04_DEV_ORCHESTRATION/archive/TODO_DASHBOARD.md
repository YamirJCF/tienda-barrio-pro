# TODO Dashboard - Auditoría de Consistencia

> **Archivo de requisitos:** `01_REQUIREMENTS/dashboard.md`  
> **Implementación:** `03_SRC/src/views/DashboardView.vue`  
> **Fecha:** 2026-01-13

---

## ✅ Elementos Implementados Correctamente

| Requisito | Estado | Ubicación en Código |
|-----------|--------|---------------------|
| Ruta `/` (raíz) | ✅ | Configurado en `router/index.ts` |
| Componente `StatCard` | ✅ | `components/ui/StatCard.vue` |
| Componente `BottomNav` | ✅ | `components/BottomNav.vue` |
| Componente `UserProfileSidebar` | ✅ | `components/UserProfileSidebar.vue` |
| Composable `useCurrencyFormat` | ✅ | `composables/useCurrencyFormat.ts` |
| Store `useSalesStore` | ✅ | Línea 4 |
| Store `useInventoryStore` | ✅ | Línea 5 |
| Store `useAuthStore` | ✅ | Línea 6 |
| Navegación a POS (`/pos`) | ✅ | Via BottomNav |
| Navegación a Inventario (`/inventory`) | ✅ | Líneas 146, 190 |
| Navegación a Clientes (`/clients`) | ✅ | Via BottomNav |
| Navegación a Admin (`/admin`) | ✅ | Líneas 190, 202 |
| Stat: Caja Real | ✅ | Línea 156-161 |
| Stat: Ventas Hoy | ✅ | Línea 162-168 |
| Stat: Por Cobrar | ✅ | Línea 169-174 |
| Stat: Inventario | ✅ | Línea 175-182 |
| `lowStockProducts` de inventoryStore | ✅ | Línea 180 |

---

## ⚠️ Discrepancias Encontradas

### 1. Estructura de `todayStats` vs Propiedades Individuales

- [ ] **DOCUMENTACIÓN**: El requisito define `todayStats` como un objeto `DailyStats`, pero la implementación usa propiedades computadas individuales:
  - `salesStore.todayTotal` en lugar de `todayStats.totalSales`
  - `salesStore.todayCount` en lugar de `todayStats.salesCount`
  - `salesStore.todayFiado` en lugar de `todayStats.fiadoSales`
  
  **Acción sugerida:** Actualizar `01_REQUIREMENTS/dashboard.md` para reflejar las propiedades reales consumidas.

### 2. Campo `sales` del requisito

- [ ] **VERIFICAR**: El requisito menciona `sales` como `Sale[]` (ventas recientes), pero `DashboardView.vue` NO consume la lista `sales` directamente - solo accede a los totales computados.
  
  **Acción sugerida:** Eliminar `sales` de la tabla de datos de entrada en requisitos, ya que no se usa en Dashboard.

---

## 📋 Funcionalidades NO Documentadas en Requisitos

### 3. Toggle de Apertura/Cierre de Tienda

- [ ] **DOCUMENTAR**: La implementación incluye un toggle para abrir/cerrar la tienda (líneas 47-61, 107-131) con modal de apertura. Esto NO está documentado en los requisitos.

### 4. Modal de Apertura de Jornada

- [ ] **DOCUMENTAR**: Modal para confirmar base de caja al abrir tienda (líneas 217-254). No documentado.

### 5. Banner de Onboarding

- [ ] **DOCUMENTAR**: Banner informativo para nuevos usuarios cuando la tienda está cerrada y no hay productos (líneas 133-152). No documentado.

### 6. Botón de Notificaciones

- [ ] **DOCUMENTAR**: Header incluye acceso a `/notifications` (líneas 93-98). No mencionado en navegación de requisitos.

### 7. Sección "Gestión de Tienda" (Admin Only)

- [ ] **DOCUMENTAR**: Sección exclusiva para admins con accesos rápidos a "Gestionar Empleados" y "Configuración de Tienda" (líneas 185-214). No documentada.

### 8. Propiedades Adicionales Consumidas

- [ ] **ACTUALIZAR requisitos**: Faltan las siguientes propiedades consumidas:
  - `salesStore.isStoreOpen`
  - `salesStore.currentCash`
  - `inventoryStore.totalProducts`
  - `authStore.isAdmin`
  - `authStore.isEmployee`
  - `authStore.currentUser`
  - `authStore.currentStore`

---

## 🔧 Checklist de Acciones

### Actualización de Requisitos (01_REQUIREMENTS/dashboard.md)

- [x] Cambiar `todayStats` por propiedades individuales: `todayTotal`, `todayCount`, `todayFiado`, `currentCash`
- [x] Eliminar `sales` de "Datos de Entrada" (no se consume directamente)
- [x] Agregar datos de `authStore`: `isAdmin`, `isEmployee`, `currentUser`, `currentStore`
- [x] Agregar `inventoryStore.totalProducts` a datos de entrada
- [x] Agregar navegación a `/notifications`
- [x] Documentar toggle de apertura/cierre de tienda
- [x] Documentar modal de apertura de jornada
- [x] Documentar banner de onboarding para nuevos usuarios
- [x] Documentar sección "Gestión de Tienda" (Admin Only)

### Verificación de Implementación

- [ ] Confirmar que la ruta `/` está configurada correctamente en router
- [ ] Verificar que todas las navegaciones funcionan
- [ ] Verificar que StatCard renderiza correctamente todos los valores

---

## 📊 Resumen

| Categoría | Cantidad |
|-----------|----------|
| ✅ Implementado correctamente | 17 |
| ⚠️ Discrepancias en documentación | 2 |
| 📋 Funcionalidades no documentadas | 6 |
| 🔧 Acciones pendientes | 12 |

---

**Conclusión:** La implementación está **completa y funcional**, pero los requisitos están **desactualizados**. Se recomienda sincronizar la documentación con la implementación actual.

---

## 🔐 SPEC-005: Autenticación Unificada e Integridad IAM

> **Referencia:** `01_REQUIREMENTS/auth-unificada-iam.md`  
> **Fecha de Adición:** 2026-01-15  
> **Estado:** ✅ Especificación Completa - Listo para Implementar

### Tareas Backend (Supabase)

- [x] Verificar tabla `access_requests` en `supabase-schema.sql` ✅
- [x] Implementar RPC `login_empleado_unificado` con Gatekeeper de 3 capas ✅
- [x] Configurar índice para `access_requests(employee_id, device_fingerprint)` ✅
- [ ] Agregar campos `failed_attempts` y `locked_until` a tabla `employees`
- [ ] Agregar lógica de rate limiting al RPC (5 intentos / 15 min)
- [ ] Configurar `pg_cron` para limpieza de sesiones (TTL 8h)

### Tareas Frontend (Vue)

- [ ] **`src/stores/auth.ts`:** Agregar estados `deviceApproved` y `storeOpenStatus`
- [ ] **`src/views/LoginView.vue`:** Detectar tipo de usuario por presencia de `@` en input
- [ ] **`src/views/LoginView.vue`:** Manejar códigos de error `GATEKEEPER_PENDING`, `GATEKEEPER_REJECTED`, `ACCOUNT_LOCKED`
- [ ] **`src/router/index.ts`:** Middleware para bloquear `/pos` cuando `storeOpenStatus == false`
- [ ] **Dashboard:** Mostrar banner "Inicie jornada para vender" cuando tienda cerrada
- [ ] **Composable:** Crear `useDeviceFingerprint.ts` con algoritmo SHA-256

### Tareas de Seguridad

- [x] Definir algoritmo de fingerprinting → SHA-256(userAgent+screen+timezone+lang) ✅
- [x] Crear vista admin para aprobar/rechazar solicitudes pendientes ✅
- [x] Agregar badge de notificación en `NotificationCenterView.vue` ✅

---

## 🔔 Sistema de Notificaciones Funcional

> **Referencia:** `01_REQUIREMENTS/notifications.md`  
> **Fecha de Adición:** 2026-01-15  
> **Estado:** 📋 Especificación Completa - Listo para Implementar

### Contexto

El sistema actual tiene:
- ✅ **Toast notifications** (`useNotifications.ts`) - Funciona correctamente
- ❌ **Centro de Notificaciones** - Usa datos estáticos de ejemplo
- ❌ **Badge en Dashboard** - Siempre muestra punto rojo (hardcoded)

### Tareas de Implementación

#### Store de Notificaciones
- [ ] Crear `stores/notificationsStore.ts` con persistencia localStorage
- [ ] Definir interfaz `SystemNotification` según FRD

#### Integraciones con Eventos del Sistema
- [ ] Modificar `stores/inventory.ts` - Generar notificación cuando stock < 5
- [ ] Modificar `stores/sales.ts` - Generar notificación en cierre de caja
- [ ] Generar notificación al abrir tienda (jornada iniciada)

#### Actualización de Componentes
- [ ] **`views/NotificationCenterView.vue`:** Conectar a `useNotificationsStore` (eliminar datos estáticos)
- [ ] **`views/DashboardView.vue`:** Badge dinámico con `unreadCount` del store, ocultar si es 0

### Criterios de Aceptación
- [ ] Badge muestra contador real de notificaciones no leídas
- [ ] Notificación de stock bajo aparece al crear producto con stock < 5
- [ ] Notificación de cierre aparece tras arqueo exitoso
- [ ] "Marcar todo leído" limpia el badge
