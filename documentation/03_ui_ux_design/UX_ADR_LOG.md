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
