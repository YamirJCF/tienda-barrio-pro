# Bitácora de Decisiones de Arquitectura UX (`UX-ADR-LOG`)

> **Regla del Protocolo de 2 Commits Separados:**  
> Todo cambio en la Zona de Gobernanza UX (`ux-manifest.json` o `UX_ARQUITECTURA_SISTEMA.md`) debe registrarse primero aquí como una nueva entrada `## UX-ADR-XXX: ...` con las **4 secciones obligatorias del Gate UX-0** y guardarse en un commit arquitectónico exclusivo con el marcador `[UX-ARCH-APPROVED]` en el mensaje del commit **antes** de implementar código en vistas, router o componentes globales.  
> Las rutas del contexto `C8` (`blindada`, incluyendo `GatekeeperPending.vue`) permanecen protegidas por la **Regla 11** de [`.agent/AGENTS.md`](../../.agent/AGENTS.md) y no se alteran sin autorización explícita del usuario.

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
