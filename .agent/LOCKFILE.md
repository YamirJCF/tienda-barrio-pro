# 🔒 LOCKFILE: Funcionalidades Protegidas

**Versión:** 1.0  
**Fecha:** 2026-01-16  
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
| LF-003 | Registro de Gastos | `expenses.ts`, `ExpensesView.vue` | Auditoría contable |
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

---

## 📋 Registro de Aprobaciones

| Fecha | LF-ID | Cambio Propuesto | Aprobado Por | Commit |
|-------|-------|------------------|--------------|--------|
| 2026-11-19 | LF-008, LF-010 | Fase 3 Ola 1: Esquema cerrado de 4 permisos en `EmployeePermissions` (eliminando `canViewReports`/`canViewInventory`) + políticas RLS/helpers centralizados (`is_store_admin`, `assert_store_admin`, `assert_employee_permission`) y continuidad `<24h` | Usuario (Sesión Fase 3 Ola 1) | `[LOCKFILE-APPROVED]` (rama `feat/fase3-ola1-cimientos-rbac-canales`) |

---

## 🚨 Violaciones

Si un agente modifica una funcionalidad protegida SIN aprobación:

1. El cambio debe ser **revertido inmediatamente**
2. Se debe documentar en `01_REQUIREMENTS/discussions/lockfile-violations.md`
3. El agente debe explicar por qué no siguió el protocolo

---

## ✅ Funcionalidades NO Protegidas (Libre Modificación)

- Estilos CSS y animaciones
- Textos y labels de UI
- Orden de elementos visuales
- Nuevos componentes que no afecten los bloqueados
- Documentación
- Tests
