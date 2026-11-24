# 🔒 LOCKFILE: Funcionalidades Protegidas

**Versión:** 1.1  
**Fecha:** 2026-11-21  
**Autoridad:** Solo el USUARIO puede aprobar cambios a estas funcionalidades

---

## ⚠️ AVISO OBLIGATORIO

Antes de modificar **cualquier** función, archivo o componente listado en este documento, el agente **DEBE**:

1. **Detenerse** inmediatamente
2. **Notificar al usuario** con el mensaje exacto:
   > "⚠️ LOCKFILE: Estás proponiendo un cambio en una funcionalidad protegida: [NOMBRE]. ¿Apruebas este cambio?"
3. **Esperar aprobación explícita** del usuario
4. Documentar la aprobación en el commit con: `[LOCKFILE-APPROVED]`

---

## 🛡️ Funcionalidades Bloqueadas

### A. Core Financiero (CRÍTICO)

| ID | Funcionalidad | Archivo(s) | Razón |
|----|---------------|------------|-------|
| LF-001 | Procesamiento de Ventas | `procesar_venta()` en schema.sql | Integridad financiera |
| LF-002 | Cálculo de Totales | `salesStore.ts` → computed totals | Precisión decimal |
| LF-003 | Registro de Gastos | `expenses.ts`, `ShiftExpensesTab.vue`, `rpc_registrar_gasto_v2`, `rpc_obtener_gastos_turno` | Auditoría contable |
| LF-004 | Control de Caja RPCs | `validar_pin_admin`, `registrar_evento_caja` | Seguridad |

### B. Autenticación y Seguridad

| ID | Funcionalidad | Archivo(s) | Razón |
|----|---------------|------------|-------|
| LF-005 | Login de Empleados | `login_empleado_unificado()` | Seguridad IAM |
| LF-006 | Hash de PIN | `establecer_pin_admin()` (bcrypt) | Criptografía |
| LF-007 | Rate Limiting | Lógica de `pin_locked_until` | Anti brute-force |
| LF-008 | Permisos de Empleados | `EmployeePermissions` interface | Control de acceso |

### C. Integridad de Datos

| ID | Funcionalidad | Archivo(s) | Razón |
|----|---------------|------------|-------|
| LF-009 | Triggers de Inventario | `trigger_stock_*` en schema.sql | Consistencia |
| LF-010 | RLS Policies | Todas las policies en schema.sql | Seguridad multi-tenant |
| LF-011 | Serializers Decimal | `serializers.ts` | Precisión numérica |

### D. Cuenta Demo

| ID | Funcionalidad | Archivo(s) | Razón |
|----|---------------|------------|-------|
| LF-012 | DEMO_ACCOUNT constante | `auth.ts` → DEMO_ACCOUNT | Testing estable |

### E. Arquitectura UX y Guardarraíles

| ID | Funcionalidad | Archivo(s) | Razón |
|----|---------------|------------|-------|
| LF-013 | Mapa y Manifiesto UX | `documentation/03_ui_ux_design/UX_ARQUITECTURA_SISTEMA.md`, `ux-manifest.json`, `UX_ADR_LOG.md` | Fuente única de flujos, 8 contextos (`C1–C8`), señalización (`N1–N5`) y `baselineDebt` congelado |
| LF-014 | Shell, Router y Navegación Global | `frontend/src/router/index.ts`, `frontend/src/App.vue`, `frontend/src/components/BottomNav.vue`, altas/bajas en `frontend/src/views/**` | Evitar rutas huérfanas, overlays sin arbitraje o ruptura de Top Tasks *(requiere `UX-ADR-XXX` previo y `[UX-ARCH-APPROVED]`)* |
| LF-015 | Tests Estructurales de Arquitectura UX | `frontend/src/__tests__/architecture/ux-fitness.spec.ts` | Fitness functions anti-deriva (paridad router, cero vistas huérfanas, higiene `N1–N5`) |
| LF-016 | Hooks, Verificadores, CI y Contratos | `.githooks/**`, `scripts/verify-*.mjs`, `.github/workflows/architecture-guard.yml`, `.github/CODEOWNERS`, `.agent/AGENTS.md`, `.agent/LOCKFILE.md` | Blindaje mecánico anti-bypass local y remoto |

---

## 📋 Registro de Aprobaciones

| Fecha | LF-ID | Cambio Propuesto | Aprobado Por | Commit |
|-------|-------|------------------|--------------|--------|
| 2026-11-19 | LF-008, LF-010 | Fase 3 Ola 1: Esquema cerrado de 4 permisos en `EmployeePermissions` (eliminando `canViewReports`/`canViewInventory`) + políticas RLS/helpers centralizados (`is_store_admin`, `assert_store_admin`, `assert_employee_permission`) y continuidad `<24h` | Usuario (Sesión Fase 3 Ola 1) | `[LOCKFILE-APPROVED]` (rama `feat/fase3-ola1-cimientos-rbac-canales`) |
| 2026-11-21 | LF-013..LF-016 | WO-UX-GOV-000 (Ola 0): Blindaje UX en 5 anillos, actualización de `LOCKFILE.md` y Regla 12 en `AGENTS.md` | Usuario (Aprobación explícita Ola 0) | `[LOCKFILE-APPROVED] [UX-ARCH-APPROVED]` (rama `chore/ux-governance-ola0`) |
| 2026-11-24 | LF-003, LF-004, LF-013, LF-014 | WO-OLA2-C2-001 (UX-ADR-002): Consolidación de C2 en `/cash-control`, gastos OPEX exclusivos Admin (`assert_store_admin`) y cierre de C2-H1..C2-H4 | Usuario (Aprobación explícita WO-OLA2-C2-001) | `[UX-ARCH-APPROVED] [LOCKFILE-APPROVED]` (rama `feat/ola2-c2-caja-turnos-gastos`) |

---

## 🚨 Violaciones

Si un agente modifica una funcionalidad protegida SIN aprobación:

1. El cambio debe ser **revertido inmediatamente**
2. Se debe documentar en `01_REQUIREMENTS/discussions/lockfile-violations.md`
3. El agente debe explicar por qué no siguió el protocolo

---

## ✅ Funcionalidades NO Protegidas (Libre Modificación)

Aplica **únicamente a cambios internos dentro de vistas ya registradas en `ux-manifest.json`** (sin alterar rutas, `App.vue`, `BottomNav.vue`, `baselineDebt` ni crear vistas nuevas):

- Estilos CSS y animaciones dentro de vistas existentes
- Textos y labels de UI (sin introducir `alert()`, `confirm()`, `prompt()`, `vue-toastification` ni `material-icons`)
- Orden de elementos visuales internos que no afecten `App.vue`, `BottomNav.vue` ni las Top Tasks
- Subcomponentes internos nuevos dentro de un Contexto existente que no alteren los elementos protegidos (`LF-001` a `LF-016`)
- Documentación fuera de `LF-013` y `.agent/`
- Tests unitarios y de integración fuera de `LF-015`
