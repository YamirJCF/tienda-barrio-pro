# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-017)

> **Componente Auditado:** `frontend/src/components/ForcedCloseAuditModal.vue` (y su integración en `frontend/src/views/CashControlView.vue:96-120`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_017_CICLO_CONTABLE_Y_SESIONES.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_017_CICLO_CONTABLE_Y_SESIONES.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Componente Modal:** `frontend/src/components/ForcedCloseAuditModal.vue`
- **Componente Invocador / Consumidor:** `frontend/src/views/CashControlView.vue` (métodos `fetchPendingForcedSessions` y `handleAuditConfirm`)

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. CONTRATO DE INTERFAZ (PAYLOADS JSON)

### 5.1 Ejecución Batch de Cierre Forzado de 24 Horas
- **Operación Backend:** `rpc_check_and_force_close_shifts`
- **Método / RPC:** Supabase RPC (Invocado por Cron o Servicio de Mantenimiento con rol `service_role`).

#### Payload de Entrada:
```json
{}
```

#### Payload de Respuesta (Éxito):
```json
{
  "success": true,
  "closed_shifts": 1
}
```

---

### 5.2 Reconciliación Administrativa de Cierre Forzado
- **Operación Backend:** `rpc_reconciliar_cierre_forzado`
- **Requisito de Seguridad:** Exclusivo personal con permiso `canOpenCloseCash = true` o rol `admin`. Ejecuta `assert_store_access(v_session.store_id)`.

#### Payload de Entrada:
```json
{
  "p_session_id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
  "p_employee_id": "8f7e6d5c-4b3a-2109-8765-4321fedcba98",
  "p_actual_balance": 1850000
}
```

#### Payload de Respuesta (Éxito - Arqueo Conciliado con Diferencia):
```json
{
  "success": true,
  "expected_balance": 1870000,
  "actual_balance": 1850000,
  "difference": 20000
}
```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_reconciliar_cierre_forzado`
- **Campo `p_session_id`:**
  - Código real: `CashControlView.vue:106` -> `p_session_id: sessionId`.
  - Resultado: **Presente**.
- **Campo `p_employee_id`:**
  - Código real: `CashControlView.vue:107` -> `p_employee_id: employeeId`.
  - Resultado: **Presente**.
- **Campo `p_actual_balance`:**
  - Código real: `CashControlView.vue:108` -> `p_actual_balance: actualBalance` (emitido desde `ForcedCloseAuditModal.vue:29`).
  - Resultado: **Presente**.

### B2.5 CHECKPOINT Bloque 2
Los 3 campos requeridos por `rpc_reconciliar_cierre_forzado` se envían correctamente hacia Supabase RPC.

---

## Bloque 2b — Verificación de Backend Authority (Obligatorio, sin excepción)

### B2.6 Búsqueda de Cálculos en Cliente
- En `frontend/src/components/ForcedCloseAuditModal.vue`:
  - **Líneas 59-68:** Cálculo reactivo en cliente de diferencias por método:
    ```typescript
    for (const [method, expected] of Object.entries(currentSession.value.balancesByMethod)) {
      const physical = parseFloat(physicalCounts.value[method]) || 0;
      diffs[method] = physical - expected;
    }
    ```
  - **Líneas 70-73:** Cálculo reactivo en cliente del descuadre global:
    ```typescript
    const difference = computed(() => {
      if (!currentSession.value) return 0;
      return totalPhysical.value - currentSession.value.expectedBalance;
    });
    ```
  - **Líneas 95-99:** Determinación heurística visual de *"Cuadra"*, *"Sobrante"* o *"Faltante"*.
  - **Línea 156:** Renderiza el saldo esperado en pantalla antes de que el usuario envíe su conteo real.

### B2.7 CHECKPOINT Bloque 2b
🔴 **HALLAZGO DE SEVERIDAD ALTA:** Violación de **Arqueo Ciego (`POL-SEG-01`)** en la reconciliación forzada. El modal exhibe el saldo teórico esperado que dejó el turno y pre-calcula los faltantes o sobrantes antes de ejecutar `rpc_reconciliar_cierre_forzado`.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados en SDD-017
1. `ShiftActive` (Turno abierto normal)
2. `ShiftExpired24H` (Turno abierto con > 24 horas, bloqueado)
3. `ForceClosedPendingAudit` (Turno cerrado por batch cron, `forced_close = true`, `actual_balance IS NULL`)
4. `ReconcilingAudit` (Invocación de `rpc_reconciliar_cierre_forzado` en vuelo)
5. `ShiftAudited` (Turno conciliado con `actual_balance` y `difference` certificados en BD)

### B3.9 Manejo Visual en `CashControlView.vue` y `ForcedCloseAuditModal.vue`
- `ForceClosedPendingAudit`:
  - En `CashControlView.vue:38`: `showAuditModal = computed(() => pendingForcedSessions.value.length > 0)`. Despliega el modal forzado e impide abrir una nueva caja (`CashControlView.vue:215-218`).
- `ReconcilingAudit`:
  - En `ForcedCloseAuditModal.vue`: Dispara `handleAuditConfirm` con feedback de éxito o error.
- **Regla anti-"$0 disfrazado":**
  - Si la llamada a `rpc_reconciliar_cierre_forzado` falla, `CashControlView.vue:118` captura el error con `showError(e.message)`. Sin embargo, `fetchPendingForcedSessions` (L91-93) atrapa fallos de consulta en `console.error` sin mostrar aviso al usuario, lo que podría ocultar sesiones pendientes si hay fallas temporales de red.

### B3.10 Cruce de Estados
| Estado SDD-017 | Reflejo en Componente | ¿Conforme? |
|---|---|:---:|
| `ShiftActive` | Manejado en vista principal | Sí |
| `ShiftExpired24H` | Banner de advertencia y botón de cierre | Sí |
| `ForceClosedPendingAudit` | Modal bloqueante obligatorio | Sí |
| `ReconcilingAudit` | Invocación asíncrona de reconciliación | Sí |
| `ShiftAudited` | Remueve la sesión de la cola pendiente | Sí |

### B3.11 CHECKPOINT Bloque 3
Estados cubiertos con advertencia de captura silenciosa en la lectura inicial.

---

## Bloque 4 — Verificación contra SPEC-011

### B4.12 Formateo de Moneda
- En `ForcedCloseAuditModal.vue:6, 37`: Utiliza `useCurrencyFormat()` (`formatCurrency`), compatible con el estándar nacional `$ #.##0 COP`.

### B4.13 CHECKPOINT Bloque 4
Conforme con `SPEC-011`.

---

## Bloque 5 — Verificación de Permisos / Rol

### B5.14 Restricciones de Rol en SDD-017
- La reconciliación de cierre forzado es potestad de Administradores o personal con permiso `canOpenCloseCash` (`RN-017-02`).

### B5.15 Verificación en Código
- En `CashControlView.vue:97`: Obtiene `employeeId = authStore.currentUser?.employeeId || authStore.currentUser?.id`.
- El backend en `rpc_reconciliar_cierre_forzado` valida la pertenencia a la tienda mediante `assert_store_access`.

### B5.16 CHECKPOINT Bloque 5
Conforme.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | **Violación de Arqueo Ciego en Reconciliación Forzada (`POL-SEG-01`):** `ForcedCloseAuditModal.vue` (L59-73, L95-99, L156) expone el saldo esperado del turno forzado y calcula en cliente diferencias/sobrantes/faltantes antes de invocar el RPC. | Bloque 2b (.6, .7) | 🔴 Alta |
| UX-2 | **Captura Silenciosa en Carga de Pendientes:** `CashControlView.vue:91-93` atrapa errores en `console.error` sin señal visual al usuario, pudiendo falsear que no hay cierres forzados pendientes ante desconexión. | Bloque 3 (.9, .11) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:** Frontend aporta `🔴` debido a la vulneración del Arqueo Ciego en el modal de auditoría forzada.  
  *Estado resultante para SDD-017:* `🟡 Backend Listo / Frontend Incompleto`.

---

## 📌 Instrucción para el Orquestador (/orchestrator)

Tareas atómicas para la Etapa 4 de remediación de código:
1. **Arqueo Ciego en `ForcedCloseAuditModal.vue`:** Ocultar los valores esperados de la sesión forzada y remover las variables calculadas de `differences` y `differenceStatus`. El usuario debe declarar exclusivamente lo que encontró físicamente en caja o comprobantes.
2. **Resultado Post-Reconciliación:** Mostrar el resultado del arqueo (saldo esperado, saldo real, diferencia) en una pantalla de confirmación posterior a la resolución exitosa de `rpc_reconciliar_cierre_forzado`.
3. **Manejo Robusto de Fallos en `fetchPendingForcedSessions`:** Activar bandera reactiva de error visual si falla la consulta inicial de turnos forzados.
