# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-017)

> **Componente Auditado:** `frontend/src/views/CashControlView.vue` (y `frontend/src/components/ForcedCloseAuditModal.vue`)  
> **SDD Fuente:** `documentation/01_requirements/SDD/SDD_017_CICLO_CONTABLE_Y_SESIONES.md`  
> **Fecha:** 2026-10-24  
> **Carácter:** Cartografía consultiva no bloqueante bajo metodología oficial PAC-UXD.

---

## Bloque 1 — Identificación

### B1.1 — Declaración de Componente Auditado
- **Vista Principal de Control de Turno:** [`frontend/src/views/CashControlView.vue`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/views/CashControlView.vue)
- **Modal de Reconciliación Forzada:** [`frontend/src/components/ForcedCloseAuditModal.vue`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/components/ForcedCloseAuditModal.vue)
- **Store de Caja:** [`frontend/src/stores/cashRegister.ts`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/stores/cashRegister.ts)

### B1.2 — Cita Literal de la Sección 5 (Contrato de Interfaz) de SDD-017

```json
{
  "rpc_reconciliar_cierre_forzado": {
    "p_session_id": "UUID (Obligatorio)",
    "p_employee_id": "UUID (Obligatorio)",
    "p_actual_balance": "NUMERIC >= 0 (Obligatorio)"
  },
  "abrir_caja": {
    "p_store_id": "UUID (Obligatorio)",
    "p_employee_id": "UUID (Obligatorio)",
    "p_opening_balance": "NUMERIC >= 0 (Obligatorio)"
  },
  "cerrar_caja": {
    "p_session_id": "UUID (Obligatorio)",
    "p_employee_id": "UUID (Obligatorio)",
    "p_actual_balance": "NUMERIC >= 0 (Obligatorio)"
  }
}
```

### B1.3 — CHECKPOINT BLOQUE 1
✅ Bloque 1 completado. Vista de control, modal y contratos canónicos de Sección 5 identificados y citados literalmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

Inspección en `CashControlView.vue` (líneas 84-88) y `cashRegister.ts`:

```typescript
const { data, error } = await supabase.rpc('rpc_reconciliar_cierre_forzado', {
    p_session_id:     sessionId,
    p_employee_id:    employeeId,
    p_actual_balance: actualBalance,
});
```

### B2.4 / B2.5 — Checkpoint por Operación y Campo

| Operación / Campo | Estado en Código Frontend | Cita Textual de Línea / Observación |
|---|---|---|
| `rpc_reconciliar_cierre_forzado.p_session_id` | ✅ Presente | `CashControlView.vue` L85: `p_session_id: sessionId` |
| `rpc_reconciliar_cierre_forzado.p_employee_id` | ✅ Presente | `CashControlView.vue` L86: `p_employee_id: employeeId` |
| `rpc_reconciliar_cierre_forzado.p_actual_balance` | ✅ Presente | `CashControlView.vue` L87: `p_actual_balance: actualBalance` |
| `abrir_caja.p_store_id` | ✅ Presente | `cashRegister.ts`: `p_store_id: storeId` |
| `abrir_caja.p_employee_id` | ✅ Presente | `cashRegister.ts`: `p_employee_id: employeeId` |
| `abrir_caja.p_opening_balance` | ✅ Presente | `cashRegister.ts`: `p_opening_balance: openingBalance.toNumber()` |
| `cerrar_caja.p_session_id` | ✅ Presente | `cashRegister.ts`: `p_session_id: currentSession.value.id` |
| `cerrar_caja.p_employee_id` | ✅ Presente | `cashRegister.ts`: `p_employee_id: employeeId` |
| `cerrar_caja.p_actual_balance` | ✅ Presente | `cashRegister.ts`: `p_actual_balance: actualBalance.toNumber()` |

---

## Bloque 2b — Verificación de Backend Authority (Arqueo Ciego)

- **B2.6 — Búsqueda explícita de cálculos de saldos esperados o diferencias en cliente:**
  - Inspección en `CashControlView.vue` (líneas 48-49):
    > *"Arqueo Ciego (POL-SEG-01): el saldo esperado NO viaja al cliente. Solo se piden id y fecha de apertura; el servidor calcula la diferencia al reconciliar."*
  - Inspección en `cerrar_caja`: El cliente solo envía `p_actual_balance`. El cálculo de `expected_balance` y `difference = actual - expected` se realiza con bloqueo pesimista en PostgreSQL.
- **B2.7 — CHECKPOINT:** ✅ Backend Authority e Inviolabilidad del Arqueo Ciego cumplidas al 100%.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 — Estados del Ciclo de Vida de SDD-017
1. `Cerrada`
2. `Abierta`
3. `OperandoDia`
4. `OperandoNoche`
5. `CaducadaForzada`
6. `BloqueoMonetario`

### B3.9 — Mapeo Visual en Componentes
- **`Cerrada`:** `CashControlView.vue` (líneas 280-320): Renderiza pantalla de "Apertura de Turno" con input para base en efectivo.
- **`Abierta` / `OperandoDia`:** `CashControlView.vue` (líneas 330-380): Renderiza formulario de "Cierre de Turno" (Arqueo Ciego).
- **`OperandoNoche`:** `CashControlView.vue` / `POSView.vue`: No impone corte a las 00:00:00 si `opened_at < NOW() - INTERVAL '24h'`.
- **`CaducadaForzada` / `BloqueoMonetario`:**
  - `CashControlView.vue` (líneas 37-41 y 207-210): `pendingForcedSessions` detecta turnos caducados sin reconciliar y dispara el modal bloqueante `ForcedCloseAuditModal.vue`.
  - Bloquea explícitamente la apertura de nuevo turno: *"Debes reconciliar los turnos cerrados forzosamente antes de abrir una nueva caja"* (L209).

### B3.10 / B3.11 — CHECKPOINT
✅ Todos los estados del ciclo contable tienen representación diferenciada y defensiva. Se cumple la regla anti-"$0 disfrazado".

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12:**
  - `CashControlView.vue` y `ForcedCloseAuditModal.vue` emplean `useCurrencyFormat()` y `FormInputCurrency.vue`.
  - Se formatean los montos contados en moneda colombiana entera ($COP, sin decimales flotantes), garantizando concordancia con `SPEC-011`.
- **B4.13 — CHECKPOINT:** ✅ Conforme a `SPEC-011`.

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 / B5.15:**
  - Validación de permiso `canOpenCloseCash` implementada en cliente y verificada en servidor.
  - El error `INSUFFICIENT_PERMISSIONS` de PostgreSQL es traducido en `CashControlView.vue` (línea 111): *"No tienes permiso para reconciliar cierres de caja. Consulta con el administrador."*
- **B5.16 — CHECKPOINT:** ✅ Conforme.

---

## 📋 Resumen de Hallazgos (PAC-UXD SDD-017)

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-017-01 | En `CashControlView.vue` (línea 50), la consulta a `cash_sessions` para listar turnos forzados pendientes se ejecuta mediante un `SELECT` directo vía cliente Supabase en lugar de un RPC encapsulado. | Bloque 1 (B1.1) | 🟡 Media |
| UX-017-02 | En `CashControlView.vue` (líneas 64-68), el array `channels` se hardcodea a `['efectivo']` debido a que la tabla multicanal `cash_session_balances` está diferida para la Ola 4 en el RVC. | Bloque 2 (B2.4) | 🔵 Baja (Trazabilidad RVC) |
| UX-017-03 | El mensaje de error `AUDIT_ACTOR_UNRESOLVABLE` (línea 112) orienta correctamente al usuario hacia la intervención del administrador cuando el colaborador carece de usuario en `auth.users`. | Bloque 3 (B3.9) | 🟢 Positiva (Fidelidad UX) |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🟢 Conforme con Observaciones Menores`
- **Impacto en Estado Compuesto:** Cero hallazgos de severidad alta. La interfaz respeta escrupulosamente el arqueo ciego, el bloqueo de apertura por forzados pendientes y el formateo monetario `SPEC-011`.

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. En Fase 3, encapsular la consulta de `fetchPendingForcedSessions` en un RPC ligero `rpc_get_pending_forced_shifts(p_store_id)` para aislar la vista de consultas directas de tabla.
2. Mantener la restricción de que ningún saldo esperado sea transmitido al modal antes de ejecutar la confirmación del conteo real.
