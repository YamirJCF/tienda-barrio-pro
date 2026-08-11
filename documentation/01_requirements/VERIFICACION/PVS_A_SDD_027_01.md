# PVS-A — Registro de Auditoría y Verificación: SDD_027_01

> **Documento auditado:** `SDD_027_01_REPORTES_CAJA.md`  
> **Ruta:** `documentation/01_requirements/SDD/SDD_027_01_REPORTES_CAJA.md`  
> **Fecha de ejecución:** 2026-08-08  
> **Estado:** 🔴 REQUIRE_MIGRATION (Fase B Completada)

---

## FASE A — Auditoría (Evidencia Cruda)

### Bloque 1 — Identificación

#### SDD_027_01.1 — Nombre y Ruta Exacta del SDD

- **Nombre:** SDD-027-01: Reportes y Auditoría de Caja Diaria
- **Ruta Absoluta:** `c:\Users\Windows 11\OneDrive\Desktop\prueba\documentation\01_requirements\SDD\SDD_027_01_REPORTES_CAJA.md`

#### SDD_027_01.2 — Lista Textual de Tablas Declaradas

Extraídas del cuerpo del documento (`SDD_027_01_REPORTES_CAJA.md`):

1. `cash_sessions` (Mencionada en Sección 0.3, 2.2, 4)
2. `cash_session_balances` (Mencionada en Sección 0.3, 2.1, 2.2, 4)
3. `cash_movements` (Mencionada en Sección 0.3, 4)
4. `sales` (Mencionada en Sección 2.2)
5. `audit_logs` (Mencionada en Sección 2.2)

#### SDD_027_01.3 — CHECKPOINT BLOQUE 1
>
> **Estado:** Completado.

---

### Bloque 2 — Verificación Mecánica (Tabla por Tabla)

#### Tabla 1: `cash_sessions`

##### SDD_027_01.4 — Evidencia Cruda `pg_proc` (`cash_sessions`)

- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%cash_sessions%';`
- **Resultado (JSON Crudo):**

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

##### SDD_027_01.5 — CHECKPOINT (`cash_sessions` - Funciones)
>
> **Estado:** Completado.

##### SDD_027_01.6 — Evidencia Cruda `pg_trigger` (`cash_sessions`)

- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_sessions'::regclass AND NOT tgisinternal;`
- **Resultado (JSON Crudo):**

  ```json
  [
    {"tgname":"trg_audit_cash_closed"},
    {"tgname":"trg_audit_cash_opened"},
    {"tgname":"trg_expire_passes_on_cash_close"}
  ]
  ```

##### SDD_027_01.7 — CHECKPOINT (`cash_sessions` - Triggers)
>
> **Estado:** Completado.

---

#### Tabla 2: `cash_session_balances`

##### SDD_027_01.4b — Evidencia Cruda `pg_proc` (`cash_session_balances`)

- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%cash_session_balances%';`
- **Resultado (JSON Crudo):** (Array vacío). No existen funciones almacenadas en pg_proc que referencien cash_session_balances en su código fuente actual.

  ```json
  []
  ```

##### SDD_027_01.5b — CHECKPOINT (`cash_session_balances` - Funciones)
>
> **Estado:** Completado.

##### SDD_027_01.6b — Evidencia Cruda `pg_trigger` (`cash_session_balances`)

- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_session_balances'::regclass AND NOT tgisinternal;`
- **Resultado (Error Crudo de PostgreSQL):**

  ```
  ERROR: 42P01: relation "cash_session_balances" does not exist
  LINE 1: SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_session_balances'::regclass...
  ```

- **Hallazgo Mecánico:** La tabla `cash_session_balances` **NO EXISTE** físicamente en la base de datos de producción/Supabase (`information_schema.tables`).

##### SDD_027_01.7b — CHECKPOINT (`cash_session_balances` - Triggers Completo)
>
> **Estado:** Completado.

---

#### Tabla 3: `cash_movements`

##### SDD_027_01.4c — Evidencia Cruda `pg_proc` (`cash_movements`)

- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%cash_movements%';`
- **Resultado (JSON Crudo):**

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

##### SDD_027_01.5c — CHECKPOINT (`cash_movements` - Funciones)
>
> **Estado:** Completado.

##### SDD_027_01.6c — Evidencia Cruda `pg_trigger` (`cash_movements`)

- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_movements'::regclass AND NOT tgisinternal;`
- **Resultado (JSON Crudo):**

  ```json
  []
  ```

##### SDD_027_01.7c — CHECKPOINT (`cash_movements` - Triggers Completo)
>
> **Estado:** Completado.

---

#### Tabla 4: `sales`

##### SDD_027_01.4d — Evidencia Cruda `pg_proc` (`sales`)

- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%sales%';`
- **Resultado (JSON Crudo):**

  ```json
  [
    {"proname":"rpc_get_comprehensive_financial_report"},
    {"proname":"procesar_venta"},
    {"proname":"rpc_anular_venta"},
    {"proname":"get_top_selling_products"},
    {"proname":"get_stagnant_products"},
    {"proname":"get_daily_summary"},
    {"proname":"get_smart_supply_report"},
    {"proname":"get_history_ventas"},
    {"proname":"get_top_products_by_units"},
    {"proname":"get_inventory_health"},
    {"proname":"rpc_procesar_venta_v2"},
    {"proname":"get_sale_detail"}
  ]
  ```

##### SDD_027_01.5d — CHECKPOINT (`sales` - Funciones)
>
> **Estado:** Completado.

##### SDD_027_01.6d — Evidencia Cruda `pg_trigger` (`sales`)

- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'sales'::regclass AND NOT tgisinternal;`
- **Resultado (JSON Crudo):**

  ```json
  [
    {"tgname":"trg_audit_sale_created"},
    {"tgname":"trg_audit_sale_voided"}
  ]
  ```

##### SDD_027_01.7d — CHECKPOINT (`sales` - Triggers Completo)
>
> **Estado:** Completado.

---

#### Tabla 5: `audit_logs`

##### SDD_027_01.4e — Evidencia Cruda `pg_proc` (`audit_logs`)

- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%audit_logs%';`
- **Resultado (JSON Crudo):**

  ```json
  [
    {"proname":"rpc_force_sale"},
    {"proname":"rpc_actualizar_precio_lote"},
    {"proname":"rpc_reconciliar_cierre_forzado"},
    {"proname":"rpc_check_and_force_close_shifts"}
  ]
  ```

##### SDD_027_01.5e — CHECKPOINT (`audit_logs` - Funciones)
>
> **Estado:** Completado.

##### SDD_027_01.6e — Evidencia Cruda `pg_trigger` (`audit_logs`)

- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'audit_logs'::regclass AND NOT tgisinternal;`
- **Resultado (JSON Crudo):**

  ```json
  []
  ```

##### SDD_027_01.7e — CHECKPOINT (`audit_logs` - Triggers Completo / Fin de Bloque 2)
>
> **Estado:** Completado.

---

### Bloque 3 — Contraste Sección 0 vs. Realidad

#### SDD_027_01.8 — Cita Textual Completa de la Sección 0 del SDD
> **Sección 0.1 Políticas Globales Activadas:**
> - `POL-FIN-01` (Financiero): Prohibido reportar fiados no cobrados o cuentas por pagar no pagadas como liquidez.
> - `POL-AUD-02` (Auditoría): Dicotomía del Reporte. El cajero solo ve su resumen operativo; el dueño ve el forense.
> - `POL-AUD-03` (Auditoría): Autenticidad de Descuadres. Cualquier diferencia (`expected` vs `actual`) queda sellada criptográficamente (Trigger).
> - `POL-SEG-01` (Seguridad): Arqueo Ciego. El backend tiene PROHIBIDO exponer `expected_balance` al frontend en `OPEN`.
>
> **Sección 0.2 Restricciones Transversales Inyectadas:**
> - `SDD_027 (Caja Multicanal)`: El reporte debe devolver un arreglo detallando `opening`, `expected`, `actual` y `difference` por cada canal (`payment_method_id`).
> - `SDD_010_016 (FIFO)`: El reporte de caja TIENE PROHIBIDO calcular márgenes o ganancias.
>
> **Sección 0.3 Auditoría de BD contra Realidad (Deuda Técnica Crítica):**
> - `get_history_caja`: "Reescribir el RPC para agrupar los datos desde la nueva tabla `cash_session_balances` por `payment_method_id`."
> - `trg_audit_cash_closed`: "El trigger de auditoría debe modificarse para observar los cierres en `cash_session_balances`."
> - `Arqueo Ciego Vulnerable`: "El RPC `cerrar_caja` calcula la diferencia internamente..."

#### SDD_027_01.9 — Cita Textual de Evidencias Obtenidas en Bloque 2 (por ID)
- **ID `.4` (`pg_proc` para `cash_sessions`):** `["rpc_get_comprehensive_financial_report", "abrir_caja", "cerrar_caja", "get_active_cash_session", "rpc_anular_venta", "get_history_caja", "rpc_procesar_venta_v2", "rpc_reconciliar_cierre_forzado", "rpc_check_and_force_close_shifts", "rpc_pay_supplier_invoice"]`
- **ID `.6` (`pg_trigger` para `cash_sessions`):** `["trg_audit_cash_closed", "trg_audit_cash_opened", "trg_expire_passes_on_cash_close"]`
- **ID `.4b` (`pg_proc` para `cash_session_balances`):** `[]`
- **ID `.6b` (`pg_trigger` para `cash_session_balances`):** `ERROR: 42P01: relation "cash_session_balances" does not exist`
- **ID `.4c` (`pg_proc` para `cash_movements`):** `["rpc_get_comprehensive_financial_report", "cerrar_caja", "rpc_anular_venta", "get_history_caja", "rpc_procesar_venta_v2", "rpc_check_and_force_close_shifts", "rpc_pay_supplier_invoice"]`

#### SDD_027_01.10 — Matriz Comparativa Campo por Campo (Sección 0 vs BD)

| Declaración en Sección 0 (`.8`) | Evidencia en BD (`.9`) | ¿Coincide la Realidad con la Declaración? | Análisis |
|---------------------------------|-------------------------|-------------------------------------------|----------|
| Mención de la función `get_history_caja` | `get_history_caja` existe en `.4` y `.4c` | **SÍ** | La función existe físicamente en la BD. |
| Mención del trigger `trg_audit_cash_closed` | `trg_audit_cash_closed` existe en `.6` | **SÍ** | El trigger existe sobre `cash_sessions`. |
| Mención del RPC `cerrar_caja` | `cerrar_caja` existe en `.4` y `.4c` | **SÍ** | La función existe en la BD. |
| Existencia de tabla `cash_session_balances` para migración | Error `42P01` en `.6b` y `[]` en `.4b` | **NO** (Discrepancia Crítica) | La Sección 0 afirma que los datos se deben agrupar desde "la nueva tabla `cash_session_balances`", pero esa tabla no existe en la base de datos física. |

**Conclusión del Bloque 3:** La Sección 0 diagnostica correctamente la existencia de las funciones `get_history_caja`, `cerrar_caja` y `trg_audit_cash_closed`. Sin embargo, presupone la existencia previa de la tabla `cash_session_balances` para su reescritura, la cual no está creada físicamente en la BD.

#### SDD_027_01.11 — CHECKPOINT BLOQUE 3
> **Estado:** Completado.

---

### Bloque 4 — Ciclo de Vida vs. Modelo de Datos

#### SDD_027_01.12 — Estados/Flujos Extraídos del SDD
- **Para `cash_sessions`:** El SDD declara explícitamente en la Sección 3.1: `status | ENUM | OPEN, CLOSED`. Además, el flujo 2.1 describe: "Marca sesión como 'CLOSED'".
- **Para `sales`:** El SDD asume la existencia del flag para anulación en la Sección 2.2: "Extrae ventas anuladas (`sales` donde `is_voided = true`)".

#### SDD_027_01.13 — Evidencia Cruda de Tipos de Dato
- **`cash_sessions` (`status`):** `data_type: text`
- **`sales` (`is_voided`):** `data_type: boolean`

#### SDD_027_01.14 — Matriz de Soporte Físico de Estados

| Entidad | Estado Mínimo (SDD) | Soporte Físico Actual (BD) | ¿Concuerda? |
|---------|----------------------|----------------------------|-------------|
| `cash_sessions` | `OPEN`, `CLOSED` (Declarado como ENUM) | Columna `status` (text) | **PARCIAL**. Existe la columna, pero como `text`, no como tipo `ENUM` nativo de Postgres. |
| `sales` | `is_voided = true` | Columna `is_voided` (boolean) | **SÍ**. Soporte físico exacto. |

#### SDD_027_01.15 — CHECKPOINT BLOQUE 4
> **Estado:** Completado.

---

### Bloque 5 — Seguridad

#### SDD_027_01.16 — Citas Textuales de Control de Acceso (Sección 4)
- **Bloqueo Post-Cierre:** "Ningún rol, incluyendo `postgres` o `admin`, puede modificar un registro en `cash_session_balances` si la sesión padre está en `CLOSED`. Esto debe garantizarse vía Row Level Security (RLS) estricta, utilizando obligatoriamente las funciones `assert_store_access` y `get_current_store_id` para garantizar el aislamiento multitenant absoluto."

#### SDD_027_01.17 — Evidencia Cruda `pg_policies`
- **Query:** `SELECT tablename, policyname, roles, cmd FROM pg_policies WHERE tablename IN ('cash_sessions', 'cash_session_balances', 'cash_movements');`
- **Resultado (JSON Crudo):**
  ```json
  [
    {"tablename":"cash_movements","policyname":"cash_movements_insert_store","roles":"{public}","cmd":"INSERT"},
    {"tablename":"cash_movements","policyname":"cash_movements_select_store","roles":"{public}","cmd":"SELECT"},
    {"tablename":"cash_sessions","policyname":"cash_sessions_insert_store","roles":"{public}","cmd":"INSERT"},
    {"tablename":"cash_sessions","policyname":"cash_sessions_select_store","roles":"{public}","cmd":"SELECT"},
    {"tablename":"cash_sessions","policyname":"cash_sessions_update_store","roles":"{public}","cmd":"UPDATE"}
  ]
  ```

#### SDD_027_01.18 — Matriz Comparativa (RLS)

| Regla de Negocio (SDD) | Política Físicamente Existente (BD) | ¿Concuerda? |
|-------------------------|--------------------------------------|-------------|
| RLS estricta para impedir modificaciones en `cash_session_balances` si la sesión padre está en `CLOSED` | Ninguna política encontrada para `cash_session_balances` | 🔴 **NO**. La tabla `cash_session_balances` ni siquiera existe, por lo que carece de políticas RLS. Además, en `cash_sessions`, hay política de `UPDATE` activa, pero el SDD declara que todo se debe bloquear tras `CLOSED`. No se ve política de bloqueo post-cierre documentada/aplicada en `pg_policies` (ej. una política con un check sobre `status != 'CLOSED'`). |
| Aislamiento multitenant vía `get_current_store_id` | `cash_sessions_*_store`, `cash_movements_*_store` | 🟡 **PARCIAL**. Existen políticas con el sufijo `_store` para aislamiento multitenant en las tablas base. |

#### SDD_027_01.19 — CHECKPOINT BLOQUE 5
> **Estado:** Completado.

---

### Bloque 6 — Canal de Pago

#### SDD_027_01.20 — ¿El SDD mueve o agrupa dinero?
- **Cita Textual (Sec 0.2):** "El reporte de caja TIENE PROHIBIDO calcular márgenes o ganancias. Su única responsabilidad es contar liquidez (dinero que entró y salió)."
- **Diagnóstico:** SÍ, reporta y agrupa dinero (liquidez).

#### SDD_027_01.21 — Verificación del Contrato de Canal
- **Declaración en el SDD (Sec 0.2):** "Debe devolver un arreglo detallando `opening`, `expected`, `actual` y `difference` **por cada canal (`payment_method_id`)**."
- **Evidencia Física vs. RVC:** El `RVC_registro_vivo_contratos.md` dictamina (tras el cierre de `SDD_007_02`) que la base de datos de producción usa **`payment_method` (text)** como identificador de canal, y no un `payment_method_id` (UUID). El SDD_027_01 está exigiendo un contrato (ID) que ya fue erradicado de la arquitectura de la base de datos en favor del campo de texto.

#### SDD_027_01.22 — CHECKPOINT BLOQUE 6 (FIN FASE A)
> **Estado:** Completado.

---

## FASE B — Análisis (Clasificación sin Corrección)

### SDD_027_01.23 — Clasificación de Hallazgos contra PEA-N (Corregida)

> **CORRECCIÓN DE PROTOCOLO (2026-08-08):** La clasificación original usó categorías inventadas ("H-1 Brecha Código/DB", "H-2 Divergencia de Contrato") en lugar de citar la definición literal del PEA-N. A continuación, la reclasificación usando exclusivamente la taxonomía real.

**Definiciones PEA-N citadas literalmente:**
- **H-1:** Dos filas del RVC se contradicen entre sí directamente.
- **H-2:** Vacío que involucra dinero real/permisos, sin resolución vía Jerarquía niveles 1-3.
- **H-3:** Un SDD nuevo obligaría a marcar 🟡 a 2+ SDDs ya 🟢.
- **H-4:** El FRD fuente mismo tiene contradicción interna.

**Inventario de hallazgos producidos en Fase A (N = 4):**

| ID | Hallazgo | ¿Dispara Halt? | Clasificación PEA-N (con cita literal) | Acción requerida |
|----|----------|----------------|----------------------------------------|------------------|
| **F-1** | La tabla `cash_session_balances` **NO EXISTE** en BD (error `42P01`). | **🔴 SÍ — H-2** | Constituye un *"vacío que involucra dinero real"* (almacena el dinero de cada canal) *"sin resolución vía Jerarquía niveles 1-3"*. | Migración SQL para crear la tabla. Halt bloquea Fase C. |
| **F-2** | Políticas RLS sobre `cash_session_balances` no existen. `cash_sessions` tiene `UPDATE` abierto. | **🔴 SÍ — H-2** | Constituye un *"vacío que involucra permisos"* (falta el candado post-cierre) *"sin resolución vía Jerarquía"*. | Migración SQL para RLS. Halt bloquea Fase C. |
| **F-3** | SDD declara `status` como `ENUM`, BD usa `text`. | **❌ NO** | Hallazgo normal. No es H-3 porque no obliga a reabrir 2+ SDDs (la lógica 'OPEN'/'CLOSED' sigue operando igual a nivel texto). Resoluble por Jerarquía (Nivel 1). | Pendiente de Fase C tras resolución del Halt. |
| **F-4** | SDD usa `payment_method_id`, BD usa `payment_method` (text). | **❌ NO** | Hallazgo normal. Resoluble por Jerarquía nivel 1 (el RVC ya documentó este estándar). No dispara Halt. | Pendiente de Fase C tras resolución del Halt. |

**Invariante de Reconciliación (Regla 9.1):**
N = 4 hallazgos. La sección de análisis referencia los 4: F-1, F-2, F-3, F-4. ✅

### SDD_027_01.24 — CHECKPOINT: VEREDICTO FORMAL

> [!CAUTION]
> #### 🔴 VEREDICTO: `DETENIDO POR HALT [H-2]`
>
> **Justificación (N=4 hallazgos referenciados explícitamente):**
> 1. **F-1 (`cash_session_balances` no existe):** Halt H-2 activo. Faltan las entidades que almacenan el balance de caja.
> 2. **F-2 (RLS ausente/incompleto):** Halt H-2 activo. Vulnerabilidad en el ciclo de vida por permisos faltantes.
> 3. **F-3 (`status` ENUM vs text):** No dispara Halt. No causa cascada sobre otros documentos (no es H-3).
> 4. **F-4 (`payment_method_id` vs `payment_method`):** No dispara Halt. Resoluble documentalmente vía Jerarquía (Nivel 1).
>
> **Consecuencia para la Fase C:** El protocolo para este SDD queda detenido. La Fase C no se ejecutará para ningún hallazgo (ni siquiera F-3 y F-4) hasta que se resuelva la deuda técnica estructural (H-2) con el Arquitecto de Datos.
>
> **Clasificación Final:** 🔴 `Detenido por Halt [H-2]`

---

## FASE C — No Ejecutada (Halt Activo)

> [!CAUTION]
> **Fase C bloqueada por §6 del protocolo (Manejo de Halt).**
>
> El hallazgo H-1 disparó un Halt de tipo H-1 (Brecha Código/DB). Según las reglas acordadas:
> 1. El protocolo para **este SDD** queda detenido por completo.
> 2. **No se ejecuta Fase C para NINGÚN hallazgo** de este SDD — incluyendo H-3 y H-4, que son corregibles pero se resolverán en conjunto tras la resolución del Halt.
> 3. No se inicia el siguiente SDD hasta que el Halt quede resuelto con supervisión humana.
>
> **Estado final:** 🔴 `Detenido por Halt [H-2: cash_session_balances no existe]`

