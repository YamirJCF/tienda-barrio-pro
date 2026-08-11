# PVS-A — Registro de Auditoría y Verificación: SDD_004

> **Documento auditado:** `SDD_004_CONTROL_DE_CAJA.md`  
> **Ruta:** `documentation/01_requirements/SDD/SDD_004_CONTROL_DE_CAJA.md`  
> **Fecha de ejecución:** 2026-08-08  
> **Estado:** ⏳ EN PROGRESO

---

## FASE A — Auditoría (Evidencia Cruda)

### Bloque 1 — Identificación

#### SDD_004.1 — Nombre y Ruta Exacta del SDD

- **Nombre:** SDD-004: Control Operativo de Caja (Sesiones Multicanal)
- **Ruta Absoluta:** `c:\Users\Windows 11\OneDrive\Desktop\prueba\documentation\01_requirements\SDD\SDD_004_CONTROL_DE_CAJA.md`

#### SDD_004.2 — Lista Textual de Tablas Declaradas

Extraídas del cuerpo del documento (`SDD_004_CONTROL_DE_CAJA.md`):

1. `cash_sessions` (Mencionada en Sec 2.1, 2.2)
2. `cash_session_balances` (Mencionada en Sec 0.3, 2.1, 2.2)
3. `cash_movements` (Mencionada en Sec 1)
4. `daily_passes` (Mencionada en Sec 0.3, 2.2)

#### SDD_004.3 — CHECKPOINT BLOQUE 1
>
> **Estado:** Completado.

---

### Bloque 2 — Verificación Mecánica (Tabla por Tabla)

#### Tabla 1: `cash_sessions`

##### SDD_004.4a — `pg_proc` (`cash_sessions`)

- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%cash_sessions%';`
- **Resultado Crudo:**

  ```json
  [
    {"proname":"rpc_get_comprehensive_financial_report"},
    {"proname":"abrir_caja"},
    {"proname":"cerrar_caja"},
    {"proname":"get_active_cash_session"},
    {"proname":"rpc_anular_venta"},
    {"proname":"get_history_caja"},
    {"proname":"rpc_procesar_venta_v2"},
    {"proname":"rpc_reconciliar_cierre_forzado"},
    {"proname":"rpc_check_and_force_close_shifts"},
    {"proname":"rpc_pay_supplier_invoice"}
  ]
  ```

##### SDD_004.5a — CHECKPOINT (`cash_sessions` - Funciones)
>
> **Estado:** Completado.

##### SDD_004.6a — `pg_trigger` (`cash_sessions`)

- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_sessions'::regclass;`
- **Resultado Crudo:**

  ```json
  [
    {"tgname":"RI_ConstraintTrigger_a_33612"},
    {"tgname":"RI_ConstraintTrigger_a_33613"},
    {"tgname":"RI_ConstraintTrigger_a_77030"},
    {"tgname":"RI_ConstraintTrigger_a_77031"},
    {"tgname":"RI_ConstraintTrigger_c_33583"},
    {"tgname":"RI_ConstraintTrigger_c_33584"},
    {"tgname":"RI_ConstraintTrigger_c_33588"},
    {"tgname":"RI_ConstraintTrigger_c_33589"},
    {"tgname":"RI_ConstraintTrigger_c_33593"},
    {"tgname":"RI_ConstraintTrigger_c_33594"},
    {"tgname":"trg_audit_cash_closed"},
    {"tgname":"trg_audit_cash_opened"},
    {"tgname":"trg_expire_passes_on_cash_close"}
  ]
  ```

##### SDD_004.7a — CHECKPOINT (`cash_sessions` - Triggers)
>
> **Estado:** Completado.

#### Tabla 2: `cash_session_balances`

##### SDD_004.4b — `pg_proc` (`cash_session_balances`)

- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%cash_session_balances%';`
- **Resultado Crudo:** Ninguna función en la base de datos referencia a la entidad cash_session_balances)

  ```json
  []
  ```

##### SDD_004.5b — CHECKPOINT (`cash_session_balances` - Funciones)
> **Estado:** Completado.

##### SDD_004.6b — `pg_trigger` (`cash_session_balances`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_session_balances'::regclass;`
- **Resultado Crudo:**
  ```text
  ERROR: 42P01: relation "cash_session_balances" does not exist
  ```

##### SDD_004.7b — CHECKPOINT (`cash_session_balances` - Triggers)
> **Estado:** Completado.

#### Tabla 3: `cash_movements`

##### SDD_004.4c — `pg_proc` (`cash_movements`)
- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%cash_movements%';`
- **Resultado Crudo:**
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

##### SDD_004.5c — CHECKPOINT (`cash_movements` - Funciones)
> **Estado:** Completado.

##### SDD_004.6c — `pg_trigger` (`cash_movements`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_movements'::regclass;`
- **Resultado Crudo:**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_c_33614"},
    {"tgname":"RI_ConstraintTrigger_c_33615"},
    {"tgname":"RI_ConstraintTrigger_c_33619"},
    {"tgname":"RI_ConstraintTrigger_c_33620"}
  ]
  ```

##### SDD_004.7c — CHECKPOINT (`cash_movements` - Triggers)
> **Estado:** Completado.

#### Tabla 4: `daily_passes`

##### SDD_004.4d — `pg_proc` (`daily_passes`)
- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%daily_passes%';`
- **Resultado Crudo:**
  ```json
  [
    {"proname":"request_employee_access"},
    {"proname":"get_current_store_id"},
    {"proname":"get_employee_id_from_session"},
    {"proname":"aprobar_pase_diario"},
    {"proname":"solicitar_pase_diario"},
    {"proname":"expire_daily_passes"},
    {"proname":"check_my_pass_status"},
    {"proname":"check_daily_pass_status"}
  ]
  ```

##### SDD_004.5d — CHECKPOINT (`daily_passes` - Funciones)
> **Estado:** Completado.

##### SDD_004.6d — `pg_trigger` (`daily_passes`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'daily_passes'::regclass;`
- **Resultado Crudo:**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_c_34770"},
    {"tgname":"RI_ConstraintTrigger_c_34771"},
    {"tgname":"RI_ConstraintTrigger_c_34775"},
    {"tgname":"RI_ConstraintTrigger_c_34776"},
    {"tgname":"RI_ConstraintTrigger_c_69588"},
    {"tgname":"RI_ConstraintTrigger_c_69589"},
    {"tgname":"RI_ConstraintTrigger_c_69593"},
    {"tgname":"RI_ConstraintTrigger_c_69594"},
    {"tgname":"update_daily_passes_updated_at"}
  ]
  ```

##### SDD_004.7d — CHECKPOINT (`daily_passes` - Triggers / Fin de Bloque 2)
> **Estado:** Completado.

---

### Bloque 3 — Contraste Sección 0 vs. Realidad

#### SDD_004.8 — Cita Textual de la Sección 0
> "La auditoría revela que las funciones actuales que operan la caja están completamente rotas respecto a los contratos de Fase 0.
> | Hallazgo / Función | Brecha Descubierta | Solución Obligatoria (DSD/SQL) |
> |--------------------|--------------------|--------------------------------|
> | 🔴 `abrir_caja` (RPC) | Recibe `p_opening_balance` e inserta en la tabla padre depreciada. | Reescribir a `abrir_caja_multicanal` que reciba un Array de canales y pueble `cash_session_balances`. |
> | 🔴 `cerrar_caja` (RPC) | Calcula un saldo monolítico e inserta en la tabla padre. | Reescribir a `cerrar_caja_multicanal` que asigne el saldo esperado independientemente por cada canal, respetando Arqueo Ciego. |
> | 🔴 Expiración de Pases | El FRD exige: 'Al cerrar la caja, todos los pases diarios expiran'. El RPC actual no hace nada con la tabla `daily_passes`. | Inyectar en el RPC de cierre un `UPDATE daily_passes SET expires_at = NOW() WHERE store_id = p_store_id`. |"

#### SDD_004.9 — Cita Textual de Resultados de BD (`.4`/`.6`)
- **.4a (`cash_sessions` func):** Existen `abrir_caja` y `cerrar_caja`. NO existen `abrir_caja_multicanal` ni `cerrar_caja_multicanal`.
- **.6a (`cash_sessions` triggers):** Existe un trigger llamado `trg_expire_passes_on_cash_close`.
- **.4b/.6b (`cash_session_balances`):** `ERROR: 42P01: relation "cash_session_balances" does not exist`.

#### SDD_004.10 — Tabla de Contraste

| Elemento Declarado en Sec 0 | Estado Real (BD) | Coincidencia |
|-----------------------------|------------------|--------------|
| `abrir_caja` y `cerrar_caja` existen (están rotas/obsoletas) | Existen en `pg_proc` (.4a) | ✅ COINCIDE |
| La solución requiere poblar `cash_session_balances` | La tabla `cash_session_balances` NO EXISTE (.4b, .6b) | 🔴 CONTRADICCIÓN (Imposible implementar solución sobre tabla inexistente) |
| Solución: reescribir a `abrir_caja_multicanal` y `cerrar_caja_multicanal` | Aún no existen en `pg_proc` (.4a) | ✅ COINCIDE (Es trabajo pendiente) |
| El RPC actual no expira pases, sugiere inyectar un UPDATE | Existe un trigger `trg_expire_passes_on_cash_close` (.6a) | 🔴 CONTRADICCIÓN (La lógica ya existe vía trigger, inyectar el UPDATE en el RPC chocaría arquitectónicamente) |

#### SDD_004.11 — CHECKPOINT BLOQUE 3
> **Estado:** Completado.

---

### Bloque 4 — Ciclo de Vida vs. Modelo de Datos

#### SDD_004.12 — Extraer Lista Textual de Estados (SDD)
- Diagrama 2.1 (Apertura): `status: 'OPEN'`
- Diagrama 2.2 (Cierre): `status = 'CLOSED'`
- *Estados identificados en el SDD:* `OPEN`, `CLOSED`.

#### SDD_004.13 — Esquema Físico (Evidencia BD)
- **Query:** `SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'cash_sessions';`
- **Resultado:**
  ```json
  [
    {"column_name":"forced_close","data_type":"boolean"},
    {"column_name":"store_id","data_type":"uuid"},
    {"column_name":"opened_by","data_type":"uuid"},
    {"column_name":"closed_by","data_type":"uuid"},
    {"column_name":"opening_balance","data_type":"numeric"},
    {"column_name":"expected_balance","data_type":"numeric"},
    {"column_name":"actual_balance","data_type":"numeric"},
    {"column_name":"difference","data_type":"numeric"},
    {"column_name":"id","data_type":"uuid"},
    {"column_name":"opened_at","data_type":"timestamp with time zone"},
    {"column_name":"closed_at","data_type":"timestamp with time zone"},
    {"column_name":"status","data_type":"text"}
  ]
  ```
- *Nota crítica:* La columna `status` existe como `text`. Sin embargo, las columnas físicas (`opening_balance`, `expected_balance`, etc.) siguen ancladas a la tabla `cash_sessions` de manera monolítica, confirmando la deuda técnica: el diseño exige que estos campos se trasladen a `cash_session_balances` (que no existe) para soportar múltiples canales.

#### SDD_004.14 — Tabla Comparativa (Soporte Físico de Estados)

| Estado en SDD | Columna/Tabla Requerida | Estado Real (BD) | Coincidencia |
|---------------|-------------------------|------------------|--------------|
| `OPEN` / `CLOSED` | `status` en `cash_sessions` | Existe como `text` | ✅ COINCIDE |
| N/A | Tipado estricto (enum o check) | Es `text` libre | 🟡 PARCIAL (Permite valores inválidos como 'ABIERTA') |

#### SDD_004.15 — CHECKPOINT BLOQUE 4
> **Estado:** Completado.

---

### Bloque 5 — Seguridad

#### SDD_004.16 — Citas Textuales de Control de Acceso
- *Nota:* El documento `SDD_004_CONTROL_DE_CAJA.md` **NO CONTIENE** una Sección 4 explícita. Finaliza en la Sección 3.
- Las únicas menciones a seguridad/acceso están en:
  - **Sec 0.1 (POL-AUD-01):** "Inmutabilidad de los cierres. Tras cerrar, ni el admin puede reabrir o modificar la sesión."
  - **Sec 0.1 (POL-AUTH-01):** "Todo control de acceso se basa en el Session Token y las políticas RLS."
  - **Sec 2.1:** "API->>API: Valida RLS y permisos del usuario logueado"

#### SDD_004.17 — Evidencia Cruda (`pg_policies`)
- **Query:** `SELECT tablename, policyname, cmd FROM pg_policies WHERE tablename IN ('cash_sessions', 'cash_session_balances', 'cash_movements', 'daily_passes');`
- **Resultado:**
  ```json
  [
    {"tablename":"cash_movements","policyname":"cash_movements_insert_store","cmd":"INSERT"},
    {"tablename":"cash_movements","policyname":"cash_movements_select_store","cmd":"SELECT"},
    {"tablename":"cash_sessions","policyname":"cash_sessions_insert_store","cmd":"INSERT"},
    {"tablename":"cash_sessions","policyname":"cash_sessions_select_store","cmd":"SELECT"},
    {"tablename":"cash_sessions","policyname":"cash_sessions_update_store","cmd":"UPDATE"},
    {"tablename":"daily_passes","policyname":"daily_passes_insert_own","cmd":"INSERT"},
    {"tablename":"daily_passes","policyname":"daily_passes_select_store","cmd":"SELECT"},
    {"tablename":"daily_passes","policyname":"daily_passes_update_store","cmd":"UPDATE"}
  ]
  ```

#### SDD_004.18 — Tabla Comparativa (Mención vs. RLS Exacta)

| Mención en SDD | Política RLS Detectada en BD | Coincidencia |
|----------------|------------------------------|--------------|
| "Inmutabilidad de los cierres. Tras cerrar, ni el admin puede reabrir o modificar la sesión" | NO EXISTE POLÍTICA DE INMUTABILIDAD (Hay una `cash_sessions_update_store` permisiva) | 🔴 CONTRADICCIÓN CRÍTICA (Brecha de Seguridad ya observada en PVS de SDD_027) |
| "Valida RLS y permisos" para Inserción/Apertura | Existen `cash_sessions_insert_store` y similares | ✅ COINCIDE (Existen barreras iniciales de tenant isolation) |

#### SDD_004.19 — CHECKPOINT BLOQUE 5
> **Estado:** Completado.

---

### Bloque 6 — Canal de Pago

#### SDD_004.20 — ¿Mueve Dinero? (Cita Textual)
- **Sí.** Es el documento central de liquidez.
- *Cita de Sec 2.1:* `UI->>API: Declara [{canal_id, monto_inicial}, ...]`
- *Cita de Sec 2.2:* `UI->>API: Declara [{canal_id, monto_real_contado}, ...]`

#### SDD_004.21 — Verificación del Contrato
- **Resultado:** 🔴 **CONTRADICCIÓN CRÍTICA (Halt).** Aunque el SDD declara usar arreglos con `canal_id` (diseño multicanal), el esquema físico actual (paso `.13`) solo admite un balance único (`opening_balance`, `expected_balance`, `actual_balance`) directamente en la tabla `cash_sessions`. No hay soporte estructural para `canal_id` porque `cash_session_balances` no existe. El contrato de la aplicación (Fase 0) exige el canal, pero la BD lo bloquea físicamente al carecer de la tabla que lo soporta.

#### SDD_004.22 — CHECKPOINT BLOQUE 6 (Fin de Fase A)
> **Estado:** Completado.

---

## FASE B — Análisis (Clasificación sin Corrección)

### SDD_004.23 — Clasificación de Hallazgos contra PEA-N

| ID | Hallazgo (paso de referencia) | Clasificación PEA-N | Tipo |
|----|-------------------------------|---------------------|------|
| F-1 | La tabla `cash_session_balances` no existe en la BD (`.4b`, `.6b`) | **H-1** — Tabla declarada en el SDD como destino de datos no existe físicamente | 🔴 HALT |
| F-2 | El contrato multicanal (`canal_id` por operación) es imposible de cumplir sin `cash_session_balances` (`.21`) | **H-2** — El esquema físico actual (`cash_sessions` monolítica) es incompatible estructuralmente con el contrato declarado | 🔴 HALT |
| F-3 | No existe política de inmutabilidad RLS para sesiones `CLOSED` (`.18`). La política `cash_sessions_update_store` es permisiva, violando POL-AUD-01 | **H-3** — Política de seguridad declarada como obligatoria por el SDD no existe en la BD | 🔴 HALT |
| F-4 | El SDD ordena "inyectar UPDATE `daily_passes` en el RPC de cierre" pero ya existe el trigger `trg_expire_passes_on_cash_close` que ejecuta exactamente esa lógica (`.6a`, Sec 0.3) | **H-4** — Contradicción arquitectónica: el SDD prescribe una acción que ya existe implementada por otro mecanismo (trigger vs. RPC). Implementar ambos produciría ejecución doble | 🔴 HALT |
| F-5 | La columna `status` en `cash_sessions` es `text` libre sin constraint o enum (`.13`, `.14`) | **W-1** — Advertencia: falta de tipado estricto no bloquea funcionalidad pero introduce riesgo de datos inválidos | 🟡 WARNING |

**Conteo de hallazgos (Invariante §9.1):** N = 5 hallazgos totales. 4 de tipo HALT (F-1, F-2, F-3, F-4), 1 de tipo WARNING (F-5).

#### SDD_004.24 — CHECKPOINT (Veredicto — Fin de Fase B)

**Veredicto: 🔴 HALT MÚLTIPLE — Se activa la bifurcación §6**

El documento `SDD_004_CONTROL_DE_CAJA.md` presenta **cuatro (4) hallazgos de tipo Halt** que bloquean la implementación en su totalidad. En particular:

- Los Halts **H-1** (F-1) y **H-2** (F-2) son **dependencias del mismo bloqueante estructural** ya detectado en los PVS de `SDD_027_01` y `SDD_027_02`: la ausencia de la tabla `cash_session_balances`. Este SDD no puede ejecutarse hasta que la deuda técnica de Fase 0 sea resuelta.
- El Halt **H-3** (F-3) confirma de forma independiente la brecha de seguridad (inmutabilidad de cierre sin RLS) ya catalogada en `SDD_027_02`.
- El Halt **H-4** (F-4) es nuevo y exclusivo a este SDD: el propio documento prescribe duplicar lógica ya existente en un trigger, lo que requiere una decisión de arquitectura (¿se elimina el trigger o se corrige el texto del SDD?) antes de proceder.

> **Estado:** Completado. Se procede a ejecutar la rama §6.

---

### SDD_004.25 — EJECUCIÓN DE BIFURCACIÓN §6 (MANEJO DE HALT)
- **Protocolo Detenido:** Se bloquea la Fase C (Corrección) para este documento de forma indefinida.
- **Registro en Maestro:** Se ha actualizado `AUDITORIA_EJECUCION_PLAN_SDD.md`, marcando a `SDD_004_CAJA` como `🔴 Detenido por Halt` con el detalle de los bloqueantes estructurales (H-1, H-2, H-3, H-4).
- **Impacto Sistémico:** La resolución de este Halt excede el alcance del PVS de un solo documento. Requiere una intervención de Arquitectura de Datos para consolidar el diseño de la sesión de caja, las políticas RLS y la unificación de los triggers/RPCs (particularmente la expiración de pases).
- **Estado Final:** 🔴 **BLOQUEADO.** A la espera de resolución de arquitectura.
