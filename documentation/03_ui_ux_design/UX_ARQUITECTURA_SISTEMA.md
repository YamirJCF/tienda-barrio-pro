# Arquitectura del Sistema UX — Tienda Barrio Pro

> **Estado:** Vigente (`UX-ADR-004`)  
> **Última actualización:** 2026-11-25  
> **Fuente de verdad ejecutable:** [`ux-manifest.json`](./ux-manifest.json)  
> **Bitácora de decisiones:** [`UX_ADR_LOG.md`](./UX_ADR_LOG.md)  
> **Invariante de seguridad:** Regla 11 de [`.agent/AGENTS.md`](../../.agent/AGENTS.md) — El contexto `C8` (Acceso, Correo/Auth y `GatekeeperPending.vue`) permanece **blindado** y solo se registra a nivel cartográfico.

---

## 1. Propósito y Alcance

Este documento es el **marco maestro único de Arquitectura de Interacción y Gobernanza UX** para **Tienda Barrio Pro**. Su objetivo es erradicar la fragmentación por tickets/FRDs aislados, alinear la interfaz al modelo **"Mostrador de Precisión con Autoridad en el Servidor"** ([`PRODUCT.md`](../../PRODUCT.md)) y garantizar que ningún agente ni desarrollador introduzca rutas improvisadas, flujos redundantes o fallos silenciosos.

El marco rige el **100% de la aplicación**: las **27 rutas** declaradas en [`frontend/src/router/index.ts`](../../frontend/src/router/index.ts) (26 permanentes + 1 `DEV`-only), **1 subvista embebida** (`GatekeeperPending.vue` dentro de `LoginView.vue`), los **6 overlays globales** montados en [`frontend/src/App.vue`](../../frontend/src/App.vue) y cualquier módulo futuro (`C9+`).

---

## 2. Metodología Operativa en 5 Capas

### Capa 1 — 8 Contextos Delimitados de UX (`C1–C8`)

Toda pantalla, subvista y flujo pertenece a un único Contexto Delimitado con fronteras claras de dominio, permisos (`SDD-003-01`) y datos:

| ID | Contexto Delimitado | Propósito único | Superficies actuales (`frontend/src/views/`) |
|---|---|---|---|
| **C1** | **Mostrador (POS & Cobro)** | Cobro de alta velocidad en mostrador (**único contexto con cola offline**) | `POSView.vue` |
| **C2** | **Tesorería Diaria (Caja & Turnos)** | Ciclo de vida del turno: apertura, gastos OPEX (Admin), movimientos propios y cierre/reconciliación | `CashControlView.vue` (`/cash-control?tab=shift\|expenses\|movements`) |
| **C3** | **Catálogo e Inventario (Stock & FIFO)** | Definición de productos, capas de lotes FIFO, recepción masiva, conteo físico, salidas/mermas y Kardex | `InventoryView.vue`, `StockEntryView.vue`, `InventoryCountView.vue` |
| **C4** | **Cartera (Clientes & Fiado)** | Clientes, historial de deuda/fiado, abonos y política de cupo | `ClientListView.vue`, `ClientDetailView.vue` |
| **C5** | **Abastecimiento (Proveedores & CxP)** | Proveedores, facturas por pagar (`CxP`), abonos a proveedor y entregas | `SuppliersView.vue`, `PayablesView.vue` |
| **C6** | **Inteligencia y Auditoría (Solo Lectura)** | Rentabilidad, reportes financieros y trazabilidad histórica transversal | `ReportsHubView.vue`, `FinancialDashboardView.vue`, `HistoryView.vue` |
| **C7** | **Gobierno de Tienda** | Personal y permisos (`SDD-003-01`), sala diaria, notificaciones (`N4`), administración legal y hub de gobierno | `AdminHubView.vue`, `EmployeeManagerView.vue`, `NotificationCenterView.vue`, `DailyWaitingRoom.vue`, `PrivacyPolicyView.vue`, `PlatformLegalAdminView.vue` |
| **C8** | **Acceso y Ciclo de Cuenta (Blindado — Regla 11)** | Login, registro atómico de tienda, verificación de correo, recuperación de contraseña y espera de dispositivo | `LoginView.vue`, `GatekeeperPending.vue` *(embebida)*, `RegisterStoreView.vue`, `ForgotPasswordView.vue`, `CheckEmailView.vue`, `auth/WaitingRoomView.vue`, `auth/UpdatePasswordView.vue`, `auth/AuthCallbackView.vue` |

Además existen dos elementos estructurales transversales fuera de `C1–C8`:
- **`Shell`** (`Hub`): `DashboardView.vue` (`/`, alias `/dashboard`), punto de entrada operativo tras autenticarse.
- **`Dev`** (`devOnly`): `SystemAuditView.vue` (`/sys-audit`), inyectada únicamente cuando `import.meta.env.DEV` es verdadero.

> **Regla de crecimiento:** Ninguna capacidad futura abre una ruta suelta. Primero se evalúa si pertenece a `C1–C8` o si justifica crear el Contexto `C9+` mediante `UX-ADR-XXX` aprobado.

---

### Capa 2 — Grafo Global de Objetos (*OOUX / Matriz ORCA*)

La navegación y la estructura de vistas obedecen a **Sustantivos (Objetos de Negocio)** y sus relaciones `1:N`, no a tickets funcionales aislados:

1. **Un Objeto = Un Hogar Canónico:** Cada objeto principal (`Producto`, `Turno de Caja`, `Cliente`, `Proveedor`, `Factura CxP`, `Empleado`, `Venta`) tiene una sola vista o workspace maestro de verdad.
2. **Las relaciones `1:N` anidan, no crean rutas huérfanas:**
   - `Turno de Caja` contiene → Estado/Arqueo + Movimientos del Turno + Gastos del Turno.
   - `Proveedor` contiene → Ficha/Frecuencia + Facturas CxP + Entregas asociadas.
   - `Producto` contiene → Catálogo + Lotes FIFO (con acciones por lote) + Kardex.
   - `Cliente` contiene → Datos/Cupo + Deuda y Movimientos + Registrar Abono.
3. **Matriz Global de CTAs (`Verbo × Objeto × Rol × Online/Offline`):** Cuando dos contextos requieren ejecutar el mismo verbo (p. ej. crear cliente desde POS y desde Cartera, o consultar detalle de venta), reutilizan el mismo subflujo canónico en lugar de duplicar formularios.

---

### Capa 3 — Catálogo Cerrado de 6 Arquetipos (`A–F`) + `Hub`

Toda vista o modal operativo presente o futuro debe instanciar exactamente uno de los siguientes patrones (heredando su máquina de estados `Idle → Loading → Data/Empty → Submitting → Success/Error`):

| Código | Arquetipo | Cuándo se usa | Reglas obligatorias |
|---|---|---|---|
| **A** | **Superficie de Alta Velocidad** | Tareas repetidas decenas de veces al día bajo presión de fila | ≤ 3 toques para completar, teclado/pulgar prioritario, sin menús profundos, tolerancia offline si aplica (`POSView`) |
| **B** | **Workspace de Objeto (Lista → Ficha)** | Gestionar entidades y sus sub-entidades `1:N` | Lista buscable/filtrable → Ficha o drawer único con pestañas contextuales; evita saltar entre rutas paralelas |
| **C** | **Lienzo de Operación Masiva (Bulk)** | **Única razón válida** para ruta transaccional separada: operar `N` registros en un solo envío | Captura rápida en lote + resumen previo + confirmación única transaccional (`StockEntryView`) |
| **D** | **Hoja Transaccional con Read Model** | Cualquier acción que mueve dinero, deuda, cupo, stock o estado crítico | **Event Storming obligatorio:** (1) muestra verdad previa del servidor (*Read Model*), (2) impacto previsto (*Antes → Después*), (3) bloqueo de doble envío durante la mutación |
| **E** | **Centro de Inteligencia (Solo Lectura)** | Analítica, auditoría, reportes, historiales y bandejas de consulta | Cero mutaciones destructivas directas; filtros consistentes; drill-down contextual o disparo de **Arquetipo D** compensatorio |
| **F** | **Compuerta de Seguridad / Bloqueo** | Interceptores que impiden operar hasta cumplir una precondición de seguridad o integridad | Explica causa exacta, actor responsable y **una sola salida accionable** (`DailyWaitingRoom`, `PinUnlockModal`, `C8`) |
| **Hub** | **Lanzador Estructural (Shell)** | Menú de entrada operativo o administrativo (`DashboardView`, `AdminHubView`) | Enruta a Contextos y resume estado de alto nivel; **prohibido** mezclar formularios transaccionales de otros dominios |

---

### Capa 4 — Shell Global, Navegación y Matriz de Señalización (`N1–N5`)

#### 4.1 Leyes de Navegación del Shell
1. **`BottomNav` (`frontend/src/components/BottomNav.vue`):** Reservado estrictamente para los 4–5 destinos de mayor frecuencia (*Top Tasks*), gobernado por la matriz cerrada de permisos de `SDD-003-01` (`canManageInventory`, `canFiar`, `isAdmin`) y conservando un retorno claro hacia Inicio (`/`).
2. **1 Vista = 1 Ruta Canónica:** Se prohíben rutas duplicadas para un mismo workspace (ej. `/history` y `/admin/financial-dashboard` frente a `/reports`). En Ola 2 se consolidan o redirigen limpiamente.
3. **Heterarquía por enlaces contextuales:** Los contextos enlazan objetos relacionados preservando navegación de retorno real con fallback seguro.
4. **Permisos como Fuente Única de Verdad:** La visibilidad en navegación, las guardias de [`frontend/src/router/index.ts`](../../frontend/src/router/index.ts) y los controles internos obedecen de forma sincronizada a `SDD-003-01` y Backend Authority.

#### 4.2 Matriz Canónica de Señalización e Interrupción (`N1–N5`)

Una superficie cumple un único trabajo; ningún flujo puede degradar errores críticos a mensajes efímeros ni recurrir a diálogos nativos del navegador:

| Nivel | Superficie única permitida | Cuándo se usa | Regla de persistencia y prohibiciones |
|---|---|---|---|
| **N1 — Inline / Contextual** | Mensaje junto al campo, fila o bloque | Validaciones de formulario, cupo excedido, precio bajo costo, advertencia de lote FIFO | Persiste mientras exista la condición en pantalla. Nunca usa toast. |
| **N2 — Toast Efímero** | **1 solo motor unificado** (`frontend/src/components/ToastNotification.vue`) | Únicamente confirmación breve de éxito o información no crítica | Auto-cierre breve. **Prohibido** usar `vue-toastification` en código nuevo; prohibido para errores que requieran acción. |
| **N3 — Banner de Estado Persistente** | Franja fija en Shell o vista | Estado sostenido del sistema/vista: modo offline, cola pendiente de sync, caja cerrada, fallo de carga con Reintentar | Permanece visible hasta resolverse; si permite descarte, debe reflejar estado real. |
| **N4 — Bandeja Persistente (`/notifications`)** | `NotificationCenterView.vue` como Enrutador de Objetos | Eventos asíncronos o auditables por audiencia (`Admin` vs `Empleado`): stock bajo, cierres forzados, pases, alertas financieras | Toda notificación con `metadata` de entidad (`productId`, `clientId`, `sessionId`, etc.) debe enlazar al Hogar Canónico del objeto. |
| **N5 — Compuerta / Modal Bloqueante** | Árbitro de overlays en `frontend/src/App.vue` (Arquetipo `F`) | Bloqueos de seguridad, integridad, sesión o cumplimiento legal | **Jerarquía estricta de prioridad:** `1. Error fatal / integridad` → `2. Sesión / Legal` → `3. Solicitud de Pase / PIN` → `4. Alerta Crítica Operativa`. **Cero `alert()`, `confirm()` o `prompt()` nativos.** |

#### 4.3 Overlays Globales Registrados en `frontend/src/App.vue`
En orden exacto de montaje en `<template>` de [`frontend/src/App.vue`](../../frontend/src/App.vue):
1. `GlobalNetworkHandler`
2. `OfflineBanner`
3. `LegalComplianceGate`
4. `GlobalAccessRequestModal`
5. `PinUnlockModal`
6. `ToastNotification`

*(Nota técnica congelada en Ola 0: `CriticalAlertModal` permanece importado sin montar en `App.vue`; su destino definitivo se resuelve en Ola 2).*

---

### Capa 5 — Gobernanza en 5 Anillos, Triage y Gate UX-0

#### 5.1 Las 5 Top Tasks Protegidas
Ninguna tarea secundaria puede añadir clics, campos ni banners obstructivos a estas 5 tareas críticas de mostrador:
1. Cobrar venta en POS (`< 3` toques)
2. Abrir / cerrar caja y cuadrar turno
3. Registrar abono o fiado de cliente
4. Recibir compra de proveedor (entrada masiva)
5. Consultar o corregir un producto (precio, lote FIFO, merma)

#### 5.2 Triage de 3 Carriles
Todo requerimiento entra por uno de tres carriles antes de abrir rama:
- **Carril 1 — Integridad Contable / Dominio:** Descuadres de dinero, caja o inventario FIFO. Prioridad absoluta (`FRD → SDD → SQL → UI`).
- **Carril 2 — Consolidación UX:** Unificar superficies duplicadas, eliminar deuda de `baselineDebt` y alinear con `DESIGN.md`.
- **Carril 3 — Congelador (*Parking Lot*):** Ideas nuevas no críticas; permanecen congeladas hasta cerrar los carriles 1 y 2 del bloque activo.

#### 5.3 Gate UX-0 (4 Preguntas Obligatorias)
Antes de crear o alterar rutas, vistas, modales de flujo o señalización, es obligatorio responder en `UX_ADR_LOG.md`:
1. **Contexto y Objeto (ORCA):** ¿A qué Contexto (`C1–C8` o `C9+`) y Objeto pertenece, y por qué no vive en su hogar canónico existente?
2. **Verdad Contable (Read Model / Invariante):** ¿Qué *Read Model* del servidor debe ver el usuario antes de confirmar y qué invariante SQL/RPC garantiza integridad?
3. **Arquetipo, Señalización y Top Tasks:** ¿Qué Arquetipo (`A–F` / `Hub`) y niveles `N1–N5` instancia, y qué impacto tiene en toques sobre las 5 Top Tasks?
4. **Higiene de Crecimiento (Qué se consolida o elimina):** ¿Qué ruta duplicada, modal redundante, deuda de `baselineDebt` o botón huérfano se consolida o retira?

#### 5.4 Blindaje Técnico en 5 Anillos
1. **Anillo 1 — Manifiesto Ejecutable:** [`documentation/03_ui_ux_design/ux-manifest.json`](./ux-manifest.json) como única fuente legible por máquina para rutas, vistas embebidas, overlays en `App.vue`, motor de toast y `baselineDebt` congelado.
2. **Anillo 2 — Tests Estructurales (Vitest Fitness Functions):** [`frontend/src/__tests__/architecture/ux-fitness.spec.ts`](../../frontend/src/__tests__/architecture/ux-fitness.spec.ts) valida paridad 1:1 con `router/index.ts`, cero vistas huérfanas, cero diálogos nativos nuevos, cero `vue-toastification` nuevo, cero `material-icons` nuevos y paridad de overlays en `App.vue`.
3. **Anillo 3 — Hooks Versionados con Regla de 2 Commits Separados:** `.githooks/pre-commit` y `.githooks/commit-msg` ejecutan [`scripts/verify-impact-hook.mjs`](../../scripts/verify-impact-hook.mjs) y [`scripts/verify-ux-governance.mjs`](../../scripts/verify-ux-governance.mjs). Prohíbe mezclar cambios a gobernanza/guardarraíles con código de producto en el mismo commit; exige entrada nueva completa `UX-ADR-XXX` + `[UX-ARCH-APPROVED]` al tocar el mapa/manifiesto; exige `[LOCKFILE-APPROVED]` y prohíbe aumentar `baselineDebt` o debilitar `ux-fitness.spec.ts`.
4. **Anillo 4 — Muro Remoto en GitHub:** [`.github/workflows/architecture-guard.yml`](../../.github/workflows/architecture-guard.yml) ejecuta `ux-fitness.spec.ts`, `verify-ux-governance.mjs --ci --base origin/master`, suite completa y `npm run build` en PRs a `master`, respaldado por [`.github/CODEOWNERS`](../../.github/CODEOWNERS).
5. **Anillo 5 — Contratos de Agentes (`.agent/`):** **Regla 12** en [`.agent/AGENTS.md`](../../.agent/AGENTS.md), sección **E (`LF-013` a `LF-016`)** en [`.agent/LOCKFILE.md`](../../.agent/LOCKFILE.md) y sincronización en `ux`, `orchestrator`, `code-reviewer`, `verification-before-completion` y `commit`.

> **Trade-off documentado (Regla 7):** En un equipo de 1 maintainer humano + agentes IA, activar *"Require approvals ≥ 1"* en GitHub impediría al único dueño aprobar sus propios PRs. **Decisión:** Se exige prohibición de push directo a `master` + status check obligatorio `architecture-guard` sin bypass, sustituyendo la aprobación de un segundo humano por el flujo obligatorio de 2 commits separados (`UX-ADR` + `[UX-ARCH-APPROVED]`). **Condición de revisión:** Cuando se incorpore un segundo desarrollador al repositorio, activar *Require 1 approval from CODEOWNERS* en GitHub Branch Protection sin modificar los scripts locales ni de CI.

---

## 3. Inventario Canónico Verificado 1:1 (27 Rutas + 1 Subvista Embebida)

Inventario extraído línea por línea de [`frontend/src/router/index.ts`](../../frontend/src/router/index.ts) y [`frontend/src/views/`](../../frontend/src/views):

### 3.1 Las 27 Rutas de `frontend/src/router/index.ts`

| # | Path *(Aliases)* | Name | Vista (`frontend/src/views/...`) | Contexto | Arquetipo | Guard real en router | Estado actual |
|---|---|---|---|---|---|---|---|
| 1 | `/` *(alias `/dashboard`)* | `dashboard` | `DashboardView.vue` | `Shell` | `Hub` | `requiresAuth` | `canonica` |
| 2 | `/pos` | `pos` | `POSView.vue` | `C1` | `A` | `requiresAuth` | `canonica` |
| 3 | `/cash-control` | `cash-control` | `CashControlView.vue` | `C2` | `B/D` | `requiresAuth` *(pestañas/RPCs por rol: `Turno`, `Gastos` Admin-only, `Mis Movimientos`)* | `canonica` |
| 4 | `/inventory` | `inventory` | `InventoryView.vue` | `C3` | `B` | `canManageInventory` | `canonica` |
| 5 | `/stock-entry` | `stock-entry` | `StockEntryView.vue` | `C3` | `C` | `canManageInventory` | `canonica` |
| 6 | `/inventory-count` | `inventory-count` | `InventoryCountView.vue` | `C3` | `C` | `canManageInventory` | `canonica` |
| 7 | `/clients` | `clients` | `ClientListView.vue` | `C4` | `B` | `canFiar` | `canonica` |
| 8 | `/clients/:id` | `client-detail` | `ClientDetailView.vue` | `C4` | `B` | `canFiar` | `canonica` |
| 9 | `/suppliers` | `suppliers` | `SuppliersView.vue` | `C5` | `B` | `isAdmin` | `canonica` |
| 10 | `/payables` | `payables` | `PayablesView.vue` | `C5` | `B` | `isAdmin` | `consolidar` |
| 11 | `/reports` | `reports` | `ReportsHubView.vue` | `C6` | `E` | `isAdmin` | `canonica` |
| 12 | `/admin/financial-dashboard` | `financial-dashboard` | `FinancialDashboardView.vue` | `C6` | `E` | `isAdmin` | `duplicada` |
| 13 | `/history` | `history` | `HistoryView.vue` | `C6` | `E` | `isAdmin` | `duplicada` |
| 14 | `/admin` | `admin` | `AdminHubView.vue` | `C7` | `Hub` | `isAdmin` | `canonica` |
| 15 | `/employees` | `employees` | `EmployeeManagerView.vue` | `C7` | `B` | `isAdmin` | `canonica` |
| 16 | `/notifications` | `notifications` | `NotificationCenterView.vue` | `N4` | `E` | `requiresAuth` | `canonica` |
| 17 | `/daily-waiting-room` | `daily-waiting-room` | `DailyWaitingRoom.vue` | `C7` | `F` | `requiresAuth` | `canonica` |
| 18 | `/legal/privacy` *(alias `/legal/terms`)* | `privacy-policy` | `PrivacyPolicyView.vue` | `C7` | `E` | `public` | `canonica` |
| 19 | `/platform/legal` | `platform-legal` | `PlatformLegalAdminView.vue` | `C7` | `B` | `public` *(auditar en Ola 1)* | `canonica` |
| 20 | `/login` | `login` | `LoginView.vue` | `C8` | `F` | `guest` | `blindada` |
| 21 | `/register-store` | `register-store` | `RegisterStoreView.vue` | `C8` | `F` | `guest` | `blindada` |
| 22 | `/forgot-password` | `forgot-password` | `ForgotPasswordView.vue` | `C8` | `F` | `guest` | `blindada` |
| 23 | `/check-email` | `check-email` | `CheckEmailView.vue` | `C8` | `F` | `requiresAuth` | `blindada` |
| 24 | `/auth/waiting-verification` | `waiting-verification` | `auth/WaitingRoomView.vue` | `C8` | `F` | `guest` | `blindada` |
| 25 | `/update-password` | `update-password` | `auth/UpdatePasswordView.vue` | `C8` | `F` | `public` | `blindada` |
| 26 | `/:pathMatch(.*)*` | `auth-callback` | `auth/AuthCallbackView.vue` | `C8` | `F` | `public` | `blindada` |
| 27 | `/sys-audit` | `system-audit` | `SystemAuditView.vue` | `Dev` | `none` | `devOnly` | `dev_only` |

### 3.2 Subvistas Embebidas en `frontend/src/views/` (1 Registrada)

| # | Archivo | Vista / Ruta Padre | Contexto | Arquetipo | Estado | Motivo |
|---|---|---|---|---|---|---|
| 1 | `frontend/src/views/GatekeeperPending.vue` | `LoginView.vue` (`login`) | `C8` | `F` | `blindada` | Renderizada condicionalmente en `LoginView.vue` cuando `deviceApproved` es `pending`/`rejected`; protegida por Regla 11. |

---

## 4. Hoja de Ruta por Olas

| Ola | Alcance | Entregables | Regla |
|---|---|---|---|
| **Ola 0** *(actual)* | Gobernanza, fotografía real de 29+1 vistas, manifiesto y blindaje en 5 anillos | `UX_ARQUITECTURA_SISTEMA.md`, `UX_ADR_LOG.md`, `ux-manifest.json`, `ux-fitness.spec.ts`, hooks `.githooks/`, CI y reglas `.agent/` | Cero cambios a código productivo ni Auth/Regla 11 |
| **Ola 1** | Cartografía completa de los 8 Contextos (`CONTEXTOS/C1..C8`) | 8 fichas con Matrices ORCA, Breadboards actual vs. objetivo, Matriz `N1–N5` por flujo y Hotspots Contables | Cero código nuevo hasta ver todo el mapa completo |
| **Ola 2** | Consolidación en 3 bloques (`C3+C2`, `C5+C4+C1`, `C6+C7+Shell`) | Cerrar hotspots en `FRD/SDD/SQL`, consolidar rutas duplicadas, eliminar deuda de `baselineDebt` hasta dejarla en 0 | Un bloque por ciclo; ideas fuera de bloque van a Carril 3 |
| **Ola 3** | Crecimiento continuo (`C9+` o evoluciones) | Ciclo obligatorio `Triage → Event Storming → Gate UX-0 (Commit 1 ADR) → Implementación (Commit 2) → CI` | Prohibido saltarse el manifiesto o el verificador |
