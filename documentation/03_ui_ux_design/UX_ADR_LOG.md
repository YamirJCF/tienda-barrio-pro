# Bitácora de Decisiones de Arquitectura UX (`UX-ADR-LOG`)

> **Regla del Protocolo de 2 Commits Separados (Local y CI):**  
> Todo cambio en la Zona de Gobernanza UX (`ux-manifest.json`, `UX_ARQUITECTURA_SISTEMA.md` o `UX_ADR_LOG.md`) debe registrarse primero aquí como una nueva entrada `## UX-ADR-XXX: ...` con las **4 secciones obligatorias del Gate UX-0** y guardarse en un commit arquitectónico exclusivo con el marcador `[UX-ARCH-APPROVED]` en el mensaje del commit **antes** de implementar código en vistas, router o componentes globales.  
> **Regla operativa en CI (`architecture-guard`):** En cambios estructurales futuros, **Commit 1 (`arch(ux)`)** y **Commit 2 (`feat/refactor`)** deben viajar como **2 commits separados dentro del mismo PR** hacia `master`, de modo que `ux-fitness.spec.ts` valide la paridad 1:1 en verde al evaluar el `HEAD` del PR en GitHub Actions mientras `verify-ux-governance.mjs --ci` verifica la separación por commit.  
> Los encabezados históricos `## UX-ADR-XXX` son inmutables (prohibido borrarlos) y las rutas del contexto `C8` (`blindada`, incluyendo `GatekeeperPending.vue`) permanecen protegidas por la **Regla 11** de [`.agent/AGENTS.md`](../../.agent/AGENTS.md) sin alterarse salvo autorización explícita del usuario.

---

## Plantilla Obligatoria (`UX-ADR-XXX`)

```markdown
## UX-ADR-XXX: [Título breve de la decisión]
- **Fecha:** YYYY-MM-DD
- **Estado:** Propuesto | Aprobado | Supersedido
- **Contexto(s) / Rutas afectadas:** [C1..C8, paths exactos]

### 1. Contexto y Objeto (ORCA)
[A qué Contexto (C1–C8 o C9+) y Objeto pertenece, y por qué no vive en su hogar canónico existente.]

### 2. Verdad Contable (Read Model / Invariante)
[Qué Read Model del servidor ve el usuario antes de confirmar y qué invariante SQL/RPC respalda la operación.]

### 3. Arquetipo, Señalización y Top Tasks
[Qué Arquetipo (A–F o Hub) y niveles de señalización (N1–N5) instancia, y su impacto en toques sobre las 5 Top Tasks.]

### 4. Higiene de Crecimiento (Qué se consolida o elimina)
[Qué ruta duplicada, modal redundante, deuda de baselineDebt o botón huérfano se consolida o retira.]
```

---

## UX-ADR-000: Adopción de Gobernanza UX en 5 Capas y Blindaje en 5 Anillos
- **Fecha:** 2026-11-21
- **Estado:** Aprobado (`[UX-ARCH-APPROVED]` `[LOCKFILE-APPROVED]`)
- **Alcance inicial verificado:** 29 rutas de `frontend/src/router/index.ts` (28 permanentes + `/sys-audit` `DEV`-only) + 1 subvista embebida (`frontend/src/views/GatekeeperPending.vue` dentro de `LoginView.vue`) + 6 overlays globales en `frontend/src/App.vue` + deuda base congelada (`baselineDebt`).

### 1. Contexto y Objeto (ORCA)
Se establece la cartografía fundacional completa de **Tienda Barrio Pro** dividida en **8 Contextos Delimitados (`C1–C8`)**, más el lanzador `Shell` (`DashboardView.vue`) y `Dev` (`SystemAuditView.vue`). Toda entidad operativa (`Producto`, `Turno de Caja`, `Cliente`, `Proveedor`, `Factura CxP`, `Empleado`, `Venta`) queda anclada a un Hogar Canónico en [`ux-manifest.json`](./ux-manifest.json), evitando que nuevos FRDs sigan generando rutas o modales huérfanos. Las rutas de `C8` (y `GatekeeperPending.vue`) quedan registradas únicamente a nivel cartográfico bajo blindaje estricto de la **Regla 11**.

### 2. Verdad Contable (Read Model / Invariante)
Se formaliza el vínculo entre *Backend Authority* (`SPEC_001`) y UX mediante el **Event Storming de Integridad** (obligatorio en todo Arquetipo `D` y en cualquier flujo que toque dinero, fiado, CxP o stock FIFO): antes de confirmar una mutación, la UI debe presentar el *Read Model* real del servidor (capas FIFO, saldo de factura, estado de turno, límite de crédito) e impedir cálculos locales o mutaciones destructivas de historia contable.

### 3. Arquetipo, Señalización y Top Tasks
Se adopta el catálogo cerrado de **6 Arquetipos (`A–F`) + `Hub`**, la protección de las **5 Top Tasks** de mostrador contra fricción adicional, y la **Matriz de Señalización `N1–N5`** con jerarquía única de arbitraje en `App.vue` para los 6 overlays globales (`GlobalNetworkHandler`, `OfflineBanner`, `LegalComplianceGate`, `GlobalAccessRequestModal`, `PinUnlockModal`, `ToastNotification`).

### 4. Higiene de Crecimiento (Qué se consolida o elimina)
En **Ola 0** no se modifica código productivo Vue/SQL/Auth; en su lugar se **congela la deuda preexistente** en `baselineDebt` dentro de `ux-manifest.json` (3 archivos con `alert`/`confirm`, 8 archivos con `vue-toastification` y 2 archivos con `material-icons`), se marcan las rutas candidatas a consolidación o retiro (`/my-shift-movements`, `/expenses`, `/stock-outputs`, `/payables`, `/admin/financial-dashboard`, `/history`) para **Ola 1 y Ola 2**, y se instala el blindaje mecánico (`ux-fitness.spec.ts` + `.githooks/` + `verify-ux-governance.mjs` + GitHub Actions) para bloquear al 100% cualquier violación nueva desde el día 1.

---

## UX-ADR-001: Endurecimiento de Guardarraíles UX de Ola 0
- **Fecha:** 2026-11-21
- **Estado:** Aprobado (`[UX-ARCH-APPROVED]` `[LOCKFILE-APPROVED]`)
- **Alcance:** `documentation/03_ui_ux_design/ux-manifest.json`, `documentation/03_ui_ux_design/UX_ADR_LOG.md`, `frontend/src/__tests__/architecture/ux-fitness.spec.ts`, `scripts/verify-ux-governance.mjs` (cero cambios en código productivo ni en `C8`/Regla 11).

### 1. Contexto y Objeto (ORCA)
Se incorpora el arreglo explícito `bottomNavRoutes` (`["/pos", "/inventory", "/reports", "/clients", "/admin"]`) en `ux-manifest.json` para anclar la barra de navegación global (`Shell` / `BottomNav.vue`) al contrato ejecutable, se incluye `UX_ADR_LOG.md` dentro de la zona protegida de Gobernanza UX y se valida en `ux-fitness.spec.ts` la correspondencia real entre los permisos declarados en el manifiesto y los bloqueos en `router.beforeEach`.

### 2. Verdad Contable (Read Model / Invariante)
Se refuerza la verificación AST de las guardias de permiso (`isAdmin`, `canManageInventory`, `canFiar`, `canOpenCloseCash`) sobre `router.beforeEach` de `frontend/src/router/index.ts` alineadas a `SDD-003-01` y se protege la integridad histórica de `UX_ADR_LOG.md` impidiendo la eliminación de decisiones previas, sin tocar lógica contable, SQL ni rutas blindadas (`C8` / Regla 11).

### 3. Arquetipo, Señalización y Top Tasks
Se protegen los 5 accesos directos de `BottomNav.vue` (Top Tasks de mostrador) exigiendo paridad 1:1 contra `bottomNavRoutes` y rutas canónicas registradas; además se acota el chequeo de overlays globales `N5` en `App.vue` exclusivamente a hijos directos del contenedor raíz importados desde `./components/` para evitar falsos positivos con íconos Lucide o `BaseButton` dentro de `errorDetected`.

### 4. Higiene de Crecimiento (Qué se consolida o elimina)
Se cierran 4 vectores de bypass detectados tras el despliegue inicial de Ola 0: reutilizar un `adrVersion` obsoleto en `ux-manifest.json`, dejar secciones vacías en nuevos `UX-ADR-XXX`, reducir silenciosamente bloques `it(` en `ux-fitness.spec.ts` y eliminar encabezados `## UX-ADR-XXX` históricos en `UX_ADR_LOG.md`, manteniendo congelado el `baselineDebt` sin agregar deuda nueva.

---

## UX-ADR-002: Consolidación de Contexto C2 en Workspace /cash-control y Gastos OPEX Exclusivos Admin
- **Fecha:** 2026-11-24
- **Estado:** Aprobado (`[UX-ARCH-APPROVED]` `[LOCKFILE-APPROVED]`)
- **Contexto(s) / Rutas afectadas:** `C2` (`/cash-control`; retiro de `/expenses` y `/my-shift-movements`)

### 1. Contexto y Objeto (ORCA)
Unifica el objeto `Turno de Caja` y sus relaciones `1:N` (`Gasto OPEX`, `Movimiento Propio del Turno`) en un solo Hogar Canónico `/cash-control` (`?tab=shift|expenses|movements`). Define acceso `requiresAuth` en router con pestañas segregadas por rol: `Turno` (`Admin` o `canOpenCloseCash`), `Gastos` (estrictamente `Admin`), `Mis Movimientos` (todos los autenticados).

### 2. Verdad Contable (Read Model / Invariante)
Blindaje en servidor con `assert_store_admin` en `rpc_registrar_gasto_v2` y nuevo RPC de lectura `rpc_obtener_gastos_turno` que devuelve la lista OPEX limpia (`movement_type = 'gasto'`) y `total_opex_expenses` calculado por PostgreSQL (cero `.reduce()` en cliente). Corrección del mapeo de `source === 'refund'` en `cashRegister.ts`, conectividad online obligatoria (`checkConnectivity: true`) y error inicial `N3` fail-closed.

### 3. Arquetipo, Señalización y Top Tasks
Mantiene Arquetipo `B/D` (Workspace + Hoja Transaccional `BaseModal` para gasto OPEX + Arquetipo `E` en tab `Mis Movimientos` + Compuerta `F` prioritaria en `+24h`/forzados). Validaciones de campo pasan a `N1` inline; éxito a `N2` (`ToastNotification.vue`); errores de sincronización/propiedad/intentos a `N3` persistente; cero fricción adicional a la Top Task #2 (abrir/cerrar caja).

### 4. Higiene de Crecimiento (Qué se consolida o elimina)
Se retiran 2 rutas y 2 vistas redundantes: `/expenses` (`ExpensesView.vue`, `LF-003`) y `/my-shift-movements` (`MyShiftMovementsView.vue`). Se eliminan violaciones de `DESIGN.md` en `C2` (emoji `⚠️`, `bg-gray-50`, `border-2`, modal custom, spinner genérico) sin aumentar `baselineDebt`.

---

## UX-ADR-003: Consolidación de Ficha de Producto C3, Entrada Masiva Atómica y Retiro de vue-toastification
- **Fecha:** 2026-11-24
- **Estado:** Aprobado (`[UX-ARCH-APPROVED]` `[LOCKFILE-APPROVED]`)
- **Contexto(s) / Rutas afectadas:** `C3` (`/inventory`, `/stock-entry`; retiro de modales huérfanos `BatchHistoryModal.vue` y `KardexModal.vue`)

### 1. Contexto y Objeto (ORCA)
Unifica el objeto `Producto` en `/inventory` mediante Ficha con 3 pestañas (`Datos | Lotes | Historial`) para edición de catálogo, gestión de lotes FIFO, bajas/mermas `$0` contextuales y Kardex; alinea todo el Contexto C3 al permiso único `canManageInventory` (o `Admin`), manteniendo `/stock-outputs` intacto hasta Parte 2 (`PR 2.1B-2`).

### 2. Verdad Contable (Read Model / Invariante)
Agrega `inventory_batches.expiration_date DATE`, amplía `rpc_registrar_salida_logistica(..., p_batch_id UUID DEFAULT NULL)` con selección explícita de lote o FIFO + permiso único `canManageInventory` + protección anti-doble-consumo en `bridge_movement_to_batch` (`LF-009`), y eleva `rpc_registrar_entrada_masiva` a operación atómica todo-o-nada con totales calculados exclusivamente en PostgreSQL (`total_entry_cost`, cero `qty * cost` o `.reduce()` en cliente).

### 3. Arquetipo, Señalización y Top Tasks
Mantiene Arquetipo `B` en `/inventory` con Ficha unificada + Hoja Transaccional `D` (`BaseModal`) para Merma/Salida por lote y Arquetipo `C` en `/stock-entry` con paleta dual `DESIGN.md` y `font-mono tabular-nums`; validaciones inline `N1`, confirmaciones unificadas `N2` vía `useNotifications()` (`ToastNotification.vue`), `BaseListSkeleton` en Kardex y cero fricción sobre Top Tasks.

### 4. Higiene de Crecimiento (Qué se consolida o elimina)
Se eliminan 2 modales redundantes (`BatchHistoryModal.vue` y `KardexModal.vue`), el bloque duplicado de lotes al final de `ProductFormModal.vue`, los 3 mini-botones en tarjetas de `InventoryView.vue` y 3 archivos de `baselineDebt.legacyToastImportsAllowed` (bajando de 8 a 5: retiro de `ProductFormModal.vue`, `KardexModal.vue` e `InventoryView.vue`).

---

## UX-ADR-004: Creación de Ruta Canónica /inventory-count con Compuerta de Caja Cerrada y Retiro de /stock-outputs
- **Fecha:** 2026-11-25
- **Estado:** Aprobado (`[UX-ARCH-APPROVED]` `[LOCKFILE-APPROVED]`)
- **Contexto(s) / Rutas afectadas:** `C3` (alta de `/inventory-count` con `InventoryCountView.vue`; retiro de `/stock-outputs` y `StockOutputsView.vue`)

### 1. Contexto y Objeto (ORCA)
Establece `/inventory-count` (`InventoryCountView.vue`, Arquetipo `C`) como superficie masiva dedicada al conteo físico de estantería dentro de `C3` bajo guardia `canManageInventory`, y retira `/stock-outputs` (`StockOutputsView.vue`) dado que las mermas y salidas puntuales ya viven en la Ficha de Producto (`/inventory`).

### 2. Verdad Contable (Read Model / Invariante)
Introduce `rpc_obtener_lotes_activos_tienda` (1 sola consulta sin N+1 + verificación en servidor de caja cerrada) y `rpc_aplicar_inventariado_fisico` atómico todo-o-nada que exige caja cerrada (`CASH_REGISTER_MUST_BE_CLOSED`), calcula `delta = contado - current_stock` en PostgreSQL con bloqueo `FOR UPDATE` ordenado por UUID, impacta `$0` en caja/CxP y emite 1 sola notificación resumen al Admin.

### 3. Arquetipo, Señalización y Top Tasks
Instancia Arquetipo `C` precedido por Compuerta `F` (`N5`: bloquea si la caja está abierta o si existen operaciones pendientes en `syncQueue`), guía rápida colapsable de 3 pasos, botón `✓ Igual` de 1 toque, `BatchShelfSelector` solo cuando hay 2+ lotes activos, borrador local y errores `N3` fail-closed; cero toques añadidos a las 5 Top Tasks.

### 4. Higiene de Crecimiento (Qué se consolida o elimina)
Elimina la ruta `/stock-outputs` y `StockOutputsView.vue` (que tenía `bg-gray-900` fijo y carecía de lotes FIFO), retira el acceso de mermas para empleados sin `canManageInventory` en `DashboardView.vue` y mantiene `baselineDebt` sin incremento.

---

## UX-ADR-005 — Consolidación de Proveedores y Cuentas por Pagar en /suppliers
- **Fecha:** 2026-11-25
- **Estado:** Aprobado
- **Contexto(s) / Rutas afectadas:** `C5` (`/suppliers?tab=suppliers|payables`, alias `/payables`; retiro de ruta paralela `/payables` -> `PayablesView.vue`)
- **Aprobación:** `[UX-ARCH-APPROVED] [LOCKFILE-APPROVED]` (`WO-OLA2-C5-001`)

### 1. Contexto y Objeto (ORCA)
Unifica los objetos canónicos `Proveedor` y `Factura CxP` (`1:N`) dentro del hogar único `/suppliers` mediante pestañas `?tab=suppliers|payables` y deep-links `?supplier=<uuid>&invoice=<uuid>`, eliminando la fragmentación histórica entre `/suppliers` y `/payables` y manteniendo `/payables` únicamente como alias compatible redirigido a `/suppliers?tab=payables`.

### 2. Verdad Contable (Read Model / Invariante)
Los KPIs globales `summary` (`total_debt`, `total_overdue`, `pending_count`, `overdue_count`) y `pending_balance` por factura se calculan exclusivamente en PostgreSQL dentro de `rpc_obtener_cuentas_por_pagar` sobre toda la tienda (sin truncamiento por `p_limit`, `p_offset` ni filtro de estado), y la deuda agregada por proveedor proviene de `rpc_obtener_proveedores_con_cxp`. El alta de facturas en `rpc_crear_factura_proveedor` prioriza la FK relacional `p_supplier_id` validada por tienda, con `assert_store_access` y `assert_store_admin` obligatorios. `PayInvoiceModal` sincroniza liquidez real de caja al abrirse y nunca calcula restas en cliente.

### 3. Arquetipo, Señalización y Top Tasks
Instancia el Arquetipo `B/D` (Workspace de Objeto `Proveedores | Cuentas por Pagar` + Hoja Transaccional `PayInvoiceModal` sobre `BaseModal` con Read Model de liquidez por canal `C2`). Aplica señalización `N1` inline para validaciones y sobregiro de canal, `N2` unificado mediante `useNotifications()` / `ToastNotification.vue`, `N3` persistente fail-closed con Reintentar ante error o caja cerrada/`+24h` (sin `border-l-4` ni emojis), y `N5` en `BaseModal` para confirmación destructiva de eliminación; cero toques añadidos a las 5 Top Tasks.

### 4. Higiene de Crecimiento (Qué se consolida o elimina)
Elimina la ruta paralela `/payables` y el archivo `PayablesView.vue` (bajando de 27 a 26 rutas totales: 25 permanentes + 1 `DEV`-only) y reduce `baselineDebt` en `ux-manifest.json`: `nativeDialogsAllowed` pasa de `3 → 2` (se retira `SuppliersView.vue`) y `legacyToastImportsAllowed` pasa de `5 → 4` (se retira `PayInvoiceModal.vue`).

---

## UX-ADR-006 — Consolidación de Deuda Global de Cartera, Política de Cupo e Hidratación en C4
- **Fecha:** 2026-11-25
- **Estado:** Aprobado
- **Contexto(s) / Rutas afectadas:** `C4` (`/clients`, `/clients/:id`) y `C7` (`/admin` — retiro de formulario transaccional de cupo)
- **Aprobación:** `[UX-ARCH-APPROVED] [LOCKFILE-APPROVED]` (`WO-OLA2-C4-001`)

### 1. Contexto y Objeto (ORCA)
Consolida la jerarquía `Política de Cupo Global -> Cliente (1:N) Movimiento de Cartera` dentro del Contexto `C4` (`/clients` y `/clients/:id`). Reubica la configuración de `globalCreditLimit` desde `AdminHubView.vue` (`C7`) hacia `/clients` (modal exclusivo `isAdmin`), dejando a `AdminHubView` como lanzador puro (`Hub`).

### 2. Verdad Contable (Read Model / Invariante)
`rpc_admin_get_clients` calcula `total_portfolio_debt` y `debtors_count` en PostgreSQL sobre el 100% de los clientes activos (`is_deleted = false`) sin truncarse por paginación, búsqueda ni filtro, manteniendo acceso tanto a `Admin` como a empleados con `canFiar`. `ClientDetailView.vue` hidrata `client` y `creditAvailable` directamente desde `rpc_obtener_estado_cuenta_cliente`; el modal de abono sincroniza caja fail-closed (`throwOnError: true`) y `clientsStore.registerPayment` exige conexión online obligatoria sin escritura local optimista offline.

### 3. Arquetipo, Señalización y Top Tasks
Formaliza el Arquetipo `B/D` en `/clients/:id` (`ClientDetailView.vue`), migra validaciones de sobre-abono y errores de RPC o cupo global a alertas `N1` inline sin `showWarning` ni doble toast, añade banners `N3` fail-closed con **Reintentar** ante fallos de red o carga, y alinea Hero y tarjetas a tokens duales `DESIGN.md` + `font-mono tabular-nums`; cero toques extra añadidos a Top Task #3.

### 4. Higiene de Crecimiento (Qué se consolida o elimina)
Retira el formulario transaccional de cupo global incrustado en `AdminHubView.vue`, elimina `.reduce()` parcial sobre `pagedClients` en `ClientListView.vue`, retira `bg-slate-800` fijo, patrón radial inline, gradientes (`bg-gradient-to-r`) y `border-l-[6px]`, y mantiene `baselineDebt` intacto sin incremento.

---

## UX-ADR-007 — Consolidación de Cobro Comercial, Retiro Personal ($0), Resiliencia de Catálogo y Reembolso FIFO en C1
- **Fecha:** 2026-11-25
- **Estado:** Aprobado
- **Contexto(s) / Rutas afectadas:** `C1` (`/pos` — `POSView.vue`, `CheckoutModal.vue`, `PersonalWithdrawalModal.vue`, `RefundModal.vue`)
- **Aprobación:** `[UX-ARCH-APPROVED] [LOCKFILE-APPROVED]` (`WO-OLA2-C1-001`)

### 1. Contexto y Objeto (ORCA)
Consolida en `C1` la jerarquía `Venta/Ticket 1:N Línea -> Cobro Comercial | Retiro Personal ($0) | Reembolso FIFO` dentro del hogar único `/pos` (única ruta Arquetipo `A` sin `BottomNav` para preservar el teclado táctil de mostrador). Extrae `consumo_personal` (`Retiro Personal $0`) hacia el subcomponente interno `PersonalWithdrawalModal.vue` (`BaseModal` Arquetipo `D`), separándolo de los medios comerciales de `CheckoutModal.vue` sin crear rutas nuevas.

### 2. Verdad Contable (Read Model / Invariante)
En `CheckoutModal.vue`, la ecuación de cupo en Fiado evalúa `isCreditLimitExceeded` contra `amountToCredit = remainingBalance > 0 ? remainingBalance : total` (`currentDebt + amountToCredit > creditLimit`) con bloqueo duro en `canComplete`, Read Model explícito (`Cupo total | Deuda actual | Monto a fiar | Nuevo saldo previsto`) y rechazo estricto offline (`OFFLINE_NOT_ALLOWED`) en `saleRepository.processSale` para `fiado` y `consumo_personal` (manteniendo `syncQueue` exclusivo para ventas comerciales offline permitidas según `PRODUCT.md`). `cartStore` mantiene `item.subtotal` calculado en el store evitando aritmética ad-hoc en `<template>`. En PostgreSQL, `rpc_buscar_ventas_para_reembolso` (`assert_store_access` + `canManageRefunds`) expone las capas originales `fifo_batches` desde `sale_item_batches` + `inventory_batches` para mostrar el Read Model de reingreso vendible o asiento de merma antes de confirmar en `RefundModal.vue`.

### 3. Arquetipo, Señalización y Top Tasks
Mantiene Arquetipo `A` en `/pos` conservando `< 3` toques en Top Task #1 (`Cobrar venta en POS`) y modales transaccionales Arquetipo `D` (`CheckoutModal`, `PersonalWithdrawalModal`, `RefundModal`). Aplica alertas `N1` inline en `CheckoutModal`, `PersonalWithdrawalModal` y `RefundModal` eliminando `showWarning`/`showError` efímeros para errores accionables; barra `N2` `Undo` temporal (6s) con **Deshacer** tras vaciar ticket (`Clear Ticket`); y banner `N3` persistente con **Reintentar** ante fallos de carga de inventario (`pos-inventory-error-banner`) o búsqueda de reembolsos (`refund-search-error`) sin disfrazar errores de red como estados vacíos.

### 4. Higiene de Crecimiento (Qué se consolida o elimina)
Extrae `consumo_personal` fuera de `activeMethods` en `CheckoutModal.vue` hacia `PersonalWithdrawalModal.vue`, elimina el bug `:disabled="!canComplete && !isFiado"`, retira el falso bloqueo `"Sin Inventario"` ante errores de red o carga inicial en `POSView.vue`, suprime la multiplicación en plantilla de filas de ticket y mantiene `baselineDebt` en `ux-manifest.json` intacto con cero incremento.
