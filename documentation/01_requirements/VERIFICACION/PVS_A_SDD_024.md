# 🛡️ PVS-A: Auditoría y Verificación de Fase 0
> **Documento Analizado:** SDD_024_POLITICA_FIADOS.md
> **Fecha de Ejecución:** 2026-08-08
> **Auditor Autónomo:** Antigravity (QA Auditor)

---

## FASE A — Recolección de Evidencia Cruda (Modo Solo Lectura)

### Bloque 1 — Identificación
#### SDD_024.1 — Metadatos del Documento
- **Nombre:** `SDD_024_POLITICA_FIADOS.md`
- **Ruta:** `documentation/01_requirements/SDD/SDD_024_POLITICA_FIADOS.md`

#### SDD_024.2 — Tablas Declaradas (Extracción Textual)
Las tablas mencionadas explícitamente en los flujos y diagramas del SDD son:
- `clients`
- `client_ledger`
- `cash_movements`

#### SDD_024.3 — CHECKPOINT BLOQUE 1
> **Estado:** Completado.

---

### Bloque 2 — Verificación Mecánica (Tabla por Tabla)

#### SDD_024.4a — Funciones Asociadas (`clients`)
- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%clients%';`
- **Resultado:**
  ```json
  [
    {"proname":"rpc_get_comprehensive_financial_report"},
    {"proname":"handle_new_user_atomic"},
    {"proname":"rpc_anular_venta"},
    {"proname":"get_history_ventas"},
    {"proname":"get_client_ledger_summary"},
    {"proname":"rpc_procesar_venta_v2"},
    {"proname":"get_sale_detail"},
    {"proname":"registrar_abono"},
    {"proname":"get_history_creditos"}
  ]
  ```

#### SDD_024.5a — CHECKPOINT (`clients` - Funciones)
> **Estado:** Completado.

#### SDD_024.6a — Triggers Asociados (`clients`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'clients'::regclass;`
- **Resultado:**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_a_40339"},
    {"tgname":"RI_ConstraintTrigger_a_40340"},
    {"tgname":"RI_ConstraintTrigger_c_33538"},
    {"tgname":"RI_ConstraintTrigger_c_33539"},
    {"tgname":"trg_clients_updated"}
  ]
  ```

#### SDD_024.7a — CHECKPOINT (`clients` - Triggers)
> **Estado:** Completado.

#### SDD_024.4b — Funciones Asociadas (`client_ledger`)
- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%client_ledger%';`
- **Resultado:**
  ```json
  [
    {"proname":"rpc_anular_venta"},
    {"proname":"rpc_procesar_venta_v2"},
    {"proname":"registrar_abono"},
    {"proname":"get_history_creditos"}
  ]
  ```

#### SDD_024.5b — CHECKPOINT (`client_ledger` - Funciones)
> **Estado:** Completado.

#### SDD_024.6b — Triggers Asociados (`client_ledger`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'client_ledger'::regclass;`
- **Resultado:**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_c_40341"},
    {"tgname":"RI_ConstraintTrigger_c_40342"},
    {"tgname":"RI_ConstraintTrigger_c_40346"},
    {"tgname":"RI_ConstraintTrigger_c_40347"},
    {"tgname":"RI_ConstraintTrigger_c_40351"},
    {"tgname":"RI_ConstraintTrigger_c_40352"}
  ]
  ```

#### SDD_024.7b — CHECKPOINT (`client_ledger` - Triggers)
> **Estado:** Completado.

#### SDD_024.4c — Funciones Asociadas (`cash_movements`)
- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%cash_movements%';`
- **Resultado:**
  ```json
  [
    {"proname":"rpc_get_comprehensive_financial_report"},
    {"proname":"cerrar_caja"},
    {"proname":"rpc_anular_venta"},
    {"proname":"get_history_caja"},
    {"proname":"rpc_procesar_venta_v2"},
    {"proname":"rpc_check_and_force_close_shifts"},
    {"proname":"rpc_pay_supplier_invoice"}
  ]
  ```
- *Nota Crítica:* La función `registrar_abono` **NO APARECE** en este listado. Esto corrobora la evidencia mencionada en el SDD (Sec 0.3): el abono se cobra pero el dinero desaparece porque la función nunca lo inyecta a la caja.

#### SDD_024.5c — CHECKPOINT (`cash_movements` - Funciones)
> **Estado:** Completado.

#### SDD_024.6c — Triggers Asociados (`cash_movements`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_movements'::regclass;`
- **Resultado:**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_c_33614"},
    {"tgname":"RI_ConstraintTrigger_c_33615"},
    {"tgname":"RI_ConstraintTrigger_c_33619"},
    {"tgname":"RI_ConstraintTrigger_c_33620"}
  ]
  ```

#### SDD_024.7c — CHECKPOINT (`cash_movements` - Triggers / Fin de Bloque 2)
> **Estado:** Completado.

---

### Bloque 3 — Contraste Sección 0 vs. Realidad

#### SDD_024.8 — Cita Textual de la Sección 0
> "La auditoría revela que la base de datos actual posee una fuga masiva de capital (dinero 'fantasma' que nunca ingresa a la tienda).
> | Hallazgo / Función | Brecha Descubierta | Solución Obligatoria (DSD/SQL) |
> |--------------------|--------------------|--------------------------------|
> | 🔴 `registrar_abono` | Rebaja la deuda del cliente y registra el ledger, **PERO NO inyecta el dinero en la caja diaria**. El abono desaparece contablemente del turno actual. | El RPC debe reescribirse para: 1. Requerir `p_payment_method`. 2. Buscar la sesión abierta. 3. Insertar el ingreso en `cash_movements`. |
> | 🔴 Falta de Canal | El RPC de abonos asume que el pago es 'mágico'. | Modificar la firma del RPC para recibir obligatoriamente el canal financiero. |"

#### SDD_024.9 — Cita Textual de Resultados de BD (`.4`/`.6`)
- **.4a (`clients`):** Existe `registrar_abono`.
- **.4b (`client_ledger`):** Existe `registrar_abono`.
- **.4c (`cash_movements`):** **NO EXISTE** `registrar_abono`.

#### SDD_024.10 — Tabla de Contraste

| Elemento Declarado en Sec 0 | Estado Real (BD) | Coincidencia |
|-----------------------------|------------------|--------------|
| `registrar_abono` rebaja deuda y registra ledger | Interactúa con `clients` (.4a) y `client_ledger` (.4b) | ✅ COINCIDE |
| `registrar_abono` **NO** inyecta el dinero en la caja diaria (`cash_movements`) | `registrar_abono` NO aparece en la lista de dependencias de `cash_movements` (.4c) | ✅ COINCIDE PERFECTAMENTE (La Deuda Técnica es real y comprobable físicamente) |

#### SDD_024.11 — CHECKPOINT BLOQUE 3
> **Estado:** Completado.

---

### Bloque 4 — Ciclo de Vida vs. Modelo de Datos

#### SDD_024.12 — Extraer Lista Textual de Estados (SDD)
- Diagrama 2.1 (Abono): `client_ledger (tipo = abono, amount = -50,000)`
- Diagrama 2.1 (Abono): `cash_movements (tipo = 'ingreso', amount = 50,000, payment_method = 'efectivo')`
- *Requisito estructural:* `cash_movements` requiere almacenar el canal de pago (`payment_method`).

#### SDD_024.13 — Esquema Físico (Evidencia BD)
- **Query:** `SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_name IN ('client_ledger', 'cash_movements');`
- **Resultado Crítico para `cash_movements`:**
  - `movement_type` (text)
  - `amount` (numeric)
  - `session_id` (uuid)
  - **NO EXISTE** `payment_method_id` o `payment_method` en `cash_movements`.

#### SDD_024.14 — Tabla Comparativa (Soporte Físico de Estados)

| Requisito en SDD | Columna/Tabla Requerida | Estado Real (BD) | Coincidencia |
|------------------|-------------------------|------------------|--------------|
| "tipo = 'ingreso'" | `movement_type` en `cash_movements` | Existe como `text` | ✅ COINCIDE |
| "tipo = 'abono'" | `transaction_type` en `client_ledger` | Existe como `text` | ✅ COINCIDE |
| **"payment_method = 'efectivo'"** | `payment_method` en `cash_movements` | **NO EXISTE NINGUNA COLUMNA RELACIONADA** | 🔴 CONTRADICCIÓN CRÍTICA (Bloqueante Estructural: incluso si se corrige el RPC, la tabla destino no soporta el guardado del canal financiero) |

#### SDD_024.15 — CHECKPOINT BLOQUE 4
> **Estado:** Completado.

---

### Bloque 5 — Seguridad

#### SDD_024.16 — Citas Textuales de Control de Acceso
- **Sec 4 (Integridad Transaccional):** "Si la caja está caducada (Límite 24H) o cerrada, el RPC registrar_abono intentará insertar el movimiento en la caja, pero será rechazado por los triggers defensivos de la caja."
- **Sec 4 (Abonos Excesivos):** "El RPC incluye validación defensiva estricta: p_amount no puede ser matemáticamente superior a v_client.balance."

#### SDD_024.17 — Evidencia Cruda (`pg_policies`)
- **Query:** `SELECT tablename, policyname, cmd FROM pg_policies WHERE tablename IN ('clients', 'client_ledger', 'cash_movements');`
- **Resultado:**
  ```json
  [
    {"tablename":"cash_movements","policyname":"cash_movements_insert_store","cmd":"INSERT"},
    {"tablename":"cash_movements","policyname":"cash_movements_select_store","cmd":"SELECT"},
    {"tablename":"client_ledger","policyname":"ledger_read_store","cmd":"SELECT"},
    {"tablename":"clients","policyname":"clients_insert_store","cmd":"INSERT"},
    {"tablename":"clients","policyname":"clients_select_store","cmd":"SELECT"},
    {"tablename":"clients","policyname":"clients_update_store","cmd":"UPDATE"}
  ]
  ```

#### SDD_024.18 — Tabla Comparativa (Mención vs. RLS/Trigger Exacto)

| Mención en SDD | Política/Trigger Detectado en BD | Coincidencia |
|----------------|----------------------------------|--------------|
| Rechazado por triggers defensivos de caja | NO HAY TRIGGERS de negocio en `cash_movements` (.6c) | 🔴 CONTRADICCIÓN CRÍTICA (Falso sentido de seguridad: los triggers defensivos de caja no existen en la BD, un abono a caja cerrada entraría sin problema si se corrigiera el RPC) |
| Validación `p_amount` <= `v_client.balance` | Evaluado dentro de `registrar_abono` (RPC existe) | ✅ COINCIDE (Asumiendo validación interna del RPC) |
| Aislamiento de Tenant (Implícito por POL-AUTH) | Existen políticas `_store` para las 3 tablas | ✅ COINCIDE |

#### SDD_024.19 — CHECKPOINT BLOQUE 5
> **Estado:** Completado.

---

### Bloque 6 — Canal de Pago (Multicanalidad)

#### SDD_024.20 — Movimiento de Dinero (Cita Textual)
- **Sec 2.1:** "Este diagrama modela la corrección a la deuda técnica encontrada. Muestra cómo un abono inyecta liquidez en el ecosistema Multicanal."
- **Sec 3.1 (Firma RPC):** Requiere `p_payment_method` (String). "Canal (Efectivo, Nequi, etc). Si no hay turno abierto para este canal, el RPC debe fallar."

#### SDD_024.21 — Evidencia BD (Soporte Físico)
- Como se demostró en el Bloque 4 (`.13`), la tabla `cash_movements` **carece por completo** de una columna para almacenar el canal de pago (`payment_method` o `payment_method_id`).
- Adicionalmente, el SDD ignora que en el ecosistema Multicanal actual (verificado en SDD_004 y SDD_027), los turnos de caja se abren por TIENDA (`store_id`), no por CANAL. La afirmación "Si no hay turno abierto para este canal, el RPC debe fallar" asume un modelo de `cash_sessions` por canal que no existe físicamente en la BD.

#### SDD_024.22 — CHECKPOINT BLOQUE 6 (FIN FASE A)
> **Estado:** Completado.

---

## FASE B — Análisis y Clasificación

### SDD_024.23 — Clasificación de Hallazgos (vs. PEA-N)

| ID Halt | Hallazgo | Bloque Origen | Clasificación |
|---------|----------|---------------|---------------|
| **H-1** | `cash_movements` carece de columna `payment_method` o `payment_method_id`. La firma del RPC propuesto en Sec 3.1 no puede cumplirse físicamente. | Bloque 4 (`.13`, `.14`) | 🔴 **HALT ESTRUCTURAL** — El schema de la tabla no soporta el contrato. Requiere migración de BD antes de cualquier cambio en el RPC. |
| **H-2** | `registrar_abono` asume sesiones de caja por CANAL (`payment_method`), pero `cash_sessions` opera por TIENDA (`store_id`). El modelo Multicanal subyacente no existe en BD. | Bloque 6 (`.21`) | 🔴 **HALT ARQUITECTÓNICO** — Hereda la contradicción estructural bloqueante del `SDD_004`. No resoluble en este documento de forma aislada. |
| **H-3** | La Sec 4 declara que la caja rechaza abonos en turnos cerrados via "triggers defensivos". Dichos triggers NO EXISTEN en `cash_movements`. El mecanismo de seguridad es una promesa no implementada. | Bloque 5 (`.17`, `.18`) | 🔴 **HALT DE SEGURIDAD** — Falso sentido de seguridad documentado. Si se implementara el flujo parcialmente, habría agujero de integridad. |

> **N Total de Hallazgos:** 3 (H-1, H-2, H-3).
> **Reconciliación §9.1:** Los 3 hallazgos están explícitamente nombrados en este bloque. ✅

### SDD_024.24 — CHECKPOINT FASE B / Bifurcación §6

> **Veredicto Final:** 🔴 **SDD_024 DETENIDO POR HALT**
>
> Se activa la **Bifurcación §6** (rama de Halt). Motivación: Los 3 hallazgos (H-1, H-2, H-3) son de naturaleza arquitectónica y estructural, no correctable a nivel de este SDD de forma aislada. La resolución requiere:
> 1. Resolver el Halt H-1 del `SDD_004` (añadir soporte de multicanalidad a `cash_movements` y `cash_sessions`).
> 2. Solo después de resolver `SDD_004`, re-abrir la auditoría de `SDD_024` con el esquema corregido como punto de partida.
>
> **Fase C: BLOQUEADA.** No se aplicarán correcciones hasta resolución arquitectónica global.
