# 🛡️ PVS-A: Auditoría y Verificación de Fase 0
> **Documento Analizado:** SDD_025_POLITICA_DEUDAS_PROVEEDORES.md
> **Fecha de Ejecución:** 2026-08-08
> **Auditor Autónomo:** Antigravity (QA Auditor)

---

## FASE A — Recolección de Evidencia Cruda (Modo Solo Lectura)

### Bloque 1 — Identificación

#### SDD_025.1 — Metadatos del Documento
- **Nombre:** `SDD_025_POLITICA_DEUDAS_PROVEEDORES.md`
- **Ruta:** `documentation/01_requirements/SDD/SDD_025_POLITICA_DEUDAS_PROVEEDORES.md`

#### SDD_025.2 — Tablas Declaradas (Extracción Textual)
Las tablas mencionadas explícitamente en los flujos y diagramas del SDD son:
- `supplier_invoices`
- `cash_session_balances`
- `cash_movements`

#### SDD_025.3 — CHECKPOINT BLOQUE 1
> **Estado:** Completado.

---

### Bloque 2 — Verificación Mecánica (Tabla por Tabla)

#### SDD_025.4a — Funciones Asociadas (`supplier_invoices`)
- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%supplier_invoices%';`
- **Resultado:**
  ```json
  [
    {"proname":"rpc_soft_delete_product"},
    {"proname":"bridge_movement_to_batch"},
    {"proname":"rpc_pay_supplier_invoice"}
  ]
  ```

#### SDD_025.5a — CHECKPOINT (`supplier_invoices` - Funciones)
> **Estado:** Completado.

#### SDD_025.6a — Triggers Asociados (`supplier_invoices`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'supplier_invoices'::regclass;`
- **Resultado:**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_a_77447"},
    {"tgname":"RI_ConstraintTrigger_a_77448"},
    {"tgname":"RI_ConstraintTrigger_c_77439"},
    {"tgname":"RI_ConstraintTrigger_c_77440"},
    {"tgname":"RI_ConstraintTrigger_c_77444"},
    {"tgname":"RI_ConstraintTrigger_c_77445"}
  ]
  ```

#### SDD_025.7a — CHECKPOINT (`supplier_invoices` - Triggers)
> **Estado:** Completado.

#### SDD_025.4b — Funciones Asociadas (`cash_session_balances`)
- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%cash_session_balances%';`
- **Resultado:** `[]` (Ninguna función hace referencia a esta tabla).
- *Nota Crítica:* La tabla `cash_session_balances` **NO EXISTE FÍSICAMENTE** en la base de datos (`information_schema.tables` retorna `[]`). Esto confirma la ausencia del esquema multicanal.

#### SDD_025.5b — CHECKPOINT (`cash_session_balances` - Funciones)
> **Estado:** Completado.

#### SDD_025.6b — Triggers Asociados (`cash_session_balances`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_session_balances'::regclass;`
- **Resultado:** Error DB `42P01: relation "cash_session_balances" does not exist`.
- *Nota:* Imposible consultar triggers al no existir la tabla en la base de datos.

#### SDD_025.7b — CHECKPOINT (`cash_session_balances` - Triggers)
> **Estado:** Completado.

#### SDD_025.4c — Funciones Asociadas (`cash_movements`)
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
- *Nota:* La función `rpc_pay_supplier_invoice` sí aparece referenciada en `cash_movements`.

#### SDD_025.5c — CHECKPOINT (`cash_movements` - Funciones)
> **Estado:** Completado.

#### SDD_025.6c — Triggers Asociados (`cash_movements`)
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

#### SDD_025.7c — CHECKPOINT (`cash_movements` - Triggers / Fin de Bloque 2)
> **Estado:** Completado.

---

### Bloque 3 — Contraste Sección 0 vs. Realidad

#### SDD_025.8 — Cita Textual de la Sección 0
> "La auditoría revela que el módulo de pago a proveedores es un 'caballo de Troya' para generar saldos negativos (sobregiros) en la caja.
> | Hallazgo / Función | Brecha Descubierta | Solución Obligatoria (DSD/SQL) |
> |--------------------|--------------------|--------------------------------|
> | 🔴 `rpc_pay_supplier_invoice` | Inserta un egreso en `cash_movements` asumiendo caja única. **No exige canal ni valida fondos**. Esto permite pagarle al proveedor un millón de pesos en efectivo, incluso si la gaveta de efectivo está vacía. | 1. Modificar la firma para recibir `p_payment_method`. <br/> 2. Buscar `cash_session_balances` para ese canal. <br/> 3. Hacer `IF expected_balance < p_amount THEN RAISE EXCEPTION 'SOBREGIRO'`. |
> | 🔴 Validación de 24 Horas | El RPC no verifica si la sesión `OPEN` ha excedido las 24 horas antes de extraer el dinero. | Añadir la validación `now() - opened_at > 24h` y abortar con `SHIFT_EXPIRED`. |"

#### SDD_025.9 — Cita Textual de Resultados de BD (`.4`/`.6`)
- **.4a (`supplier_invoices`):** Existe `rpc_pay_supplier_invoice`.
- **.4b (`cash_session_balances`):** `cash_session_balances` **NO EXISTE** en la BD (retorna error/vacío).
- **.4c (`cash_movements`):** Existe `rpc_pay_supplier_invoice` en las referencias de `cash_movements`.

#### SDD_025.10 — Tabla de Contraste

| Elemento Declarado en Sec 0 | Estado Real (BD) | Coincidencia |
|-----------------------------|------------------|--------------|
| `rpc_pay_supplier_invoice` inserta egreso en `cash_movements` asumiendo caja única | `rpc_pay_supplier_invoice` está presente en `cash_movements` (.4c) | ✅ COINCIDE |
| No valida fondos en `cash_session_balances` | `cash_session_balances` no existe en la BD (.4b) | ✅ COINCIDE (La tabla multicanal donde pretende validar ni siquiera existe) |

#### SDD_025.11 — CHECKPOINT BLOQUE 3
> **Estado:** Completado.

---

### Bloque 4 — Ciclo de Vida vs. Modelo de Datos

#### SDD_025.12 — Extraer Lista Textual de Estados (SDD)
- Diagrama 2.1 (Pago a Proveedor):
  - `cash_session_balances (expected_balance = expected_balance - 500,000)` para un `canal` específico.
  - `supplier_invoices (amount_paid = amount_paid + 500,000)`
  - `cash_movements (tipo = 'pago_proveedor', amount = 500,000, payment_method = 'efectivo')`

#### SDD_025.13 — Esquema Físico (Evidencia BD)
- **Query:** `SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_name IN ('supplier_invoices', 'cash_movements');`
- **Resultados:**
  - `supplier_invoices`: `id`, `store_id`, `supplier_id`, `invoice_number`, `total_amount`, `amount_paid`, `due_date`, `created_at`.
  - `cash_movements`: `id`, `session_id`, `sale_id`, `amount`, `movement_type`, `description`, `created_at`.
  - `cash_session_balances`: **NO EXISTE LA TABLA**.

#### SDD_025.14 — Tabla Comparativa (Soporte Físico de Estados)

| Requisito en SDD | Columna/Tabla Requerida | Estado Real (BD) | Coincidencia |
|------------------|-------------------------|------------------|--------------|
| `amount_paid = amount_paid + X` | `amount_paid` en `supplier_invoices` | Existe (`numeric`) | ✅ COINCIDE |
| `tipo = 'pago_proveedor'` | `movement_type` en `cash_movements` | Existe (`text`) | ✅ COINCIDE |
| **`payment_method = 'efectivo'`** | Columna de canal en `cash_movements` | **NO EXISTE NINGUNA COLUMNA RELACIONADA** | 🔴 CONTRADICCIÓN CRÍTICA (Inviabilidad de guardar el canal por el cual egresó el dinero) |
| **`SELECT expected_balance WHERE canal = 'Efectivo'`** | Tabla `cash_session_balances` | **NO EXISTE LA TABLA** | 🔴 CONTRADICCIÓN CRÍTICA (Bloqueante Estructural: Inviabilidad de prevenir sobregiro por canal) |

#### SDD_025.15 — CHECKPOINT BLOQUE 4
> **Estado:** Completado.

---

### Bloque 5 — Seguridad

#### SDD_025.16 — Citas Textuales de Control de Acceso
- **Sec 4 (Blindaje contra Abuso):** "Solo los perfiles de tipo Administrador (validación `admin_profiles`) están autorizados a invocar este RPC y extraer dinero de la caja..."
- **Sec 4 (Race Condition de Saldo):** "El bloqueo de fila (`FOR UPDATE`) sobre `cash_session_balances` es obligatorio."

#### SDD_025.17 — Evidencia Cruda (`pg_policies`)
- **Query:** `SELECT tablename, policyname, cmd FROM pg_policies WHERE tablename IN ('supplier_invoices', 'cash_movements', 'admin_profiles');`
- **Resultado:**
  ```json
  [
    {"tablename":"admin_profiles","policyname":"admin_profiles_select_own","cmd":"SELECT"},
    {"tablename":"admin_profiles","policyname":"admin_profiles_update_self","cmd":"UPDATE"},
    {"tablename":"cash_movements","policyname":"cash_movements_insert_store","cmd":"INSERT"},
    {"tablename":"cash_movements","policyname":"cash_movements_select_store","cmd":"SELECT"},
    {"tablename":"supplier_invoices","policyname":"Admins can manage invoices","cmd":"ALL"},
    {"tablename":"supplier_invoices","policyname":"Users can view invoices from their store","cmd":"SELECT"}
  ]
  ```

#### SDD_025.18 — Tabla Comparativa (Mención vs. RLS/Mecanismo Exacto)

| Mención en SDD | Política/Mecanismo Detectado en BD | Coincidencia |
|----------------|------------------------------------|--------------|
| Validación de Administrador (`admin_profiles`) | RLS `Admins can manage invoices` y tabla `admin_profiles` existen | ✅ COINCIDE |
| Bloqueo `FOR UPDATE` sobre `cash_session_balances` | Tabla `cash_session_balances` **NO EXISTE** | 🔴 CONTRADICCIÓN CRÍTICA (Mecanismo de concurrencia inoperativo por inexistencia física del objeto) |

#### SDD_025.19 — CHECKPOINT BLOQUE 5
> **Estado:** Completado.

---

### Bloque 6 — Canal de Pago (Multicanalidad)

#### SDD_025.20 — Movimiento de Dinero (Cita Textual)
- **Sec 1 (El Desembolso):** "El dinero abandona la caja por un canal específico. La deuda disminuye."
- **Sec 3.1 (Firma RPC):** Requiere `p_payment_method` (String). "Canal (Efectivo, Nequi, etc) del cual extraer los fondos."

#### SDD_025.21 — Evidencia BD (Soporte Físico)
- Como se demostró en el Bloque 4 (`.13`), la tabla `cash_movements` **carece por completo** de una columna para almacenar el canal de pago (`payment_method` o `payment_method_id`).
- Además, la tabla `cash_session_balances` **no existe en la BD** (`.4b`), lo que imposibilita la validación de fondos por canal previa al desembolso.

#### SDD_025.22 — CHECKPOINT BLOQUE 6 (FIN FASE A)
> **Estado:** Completado.

---

## FASE B — Análisis y Clasificación

### SDD_025.23 — Clasificación de Hallazgos (vs. PEA-N)

| ID Halt | Hallazgo | Bloque Origen | Clasificación |
|---------|----------|---------------|---------------|
| **H-1** | `cash_movements` carece de columna `payment_method`. La firma del RPC propuesto (`p_payment_method`) y la inserción del egreso no pueden cumplirse físicamente. | Bloque 4 (`.14`) | 🔴 **HALT ESTRUCTURAL** — El schema de la tabla no soporta el contrato de multicanalidad. Requiere migración de BD. |
| **H-2** | El control anti-sobregiro (`SELECT expected_balance WHERE canal = X`) requiere la tabla `cash_session_balances`, la cual NO EXISTE. | Bloque 4 (`.14`) | 🔴 **HALT ARQUITECTÓNICO** — Hereda el bloqueante crítico de `SDD_004`/`SDD_027`. No se puede validar si hay dinero antes de extraerlo. |
| **H-3** | El mecanismo de seguridad de concurrencia (`FOR UPDATE` sobre `cash_session_balances`) es inoperativo por inexistencia física del objeto. | Bloque 5 (`.18`) | 🔴 **HALT DE SEGURIDAD** — Mecanismo de blindaje contra race conditions que protege la caja es ficticio. |

> **N Total de Hallazgos:** 3 (H-1, H-2, H-3).
> **Reconciliación §9.1:** Los 3 hallazgos están explícitamente nombrados en este bloque. ✅

### SDD_025.24 — CHECKPOINT FASE B / Bifurcación §6

> **Veredicto Final:** 🔴 **SDD_025 DETENIDO POR HALT**
>
> Se activa la **Bifurcación §6** (rama de Halt). Motivación: Los 3 hallazgos (H-1, H-2, H-3) son estructurales y bloqueantes. Al igual que el `SDD_024`, este SDD asume que la base de datos ya soporta "Caja Multicanal" y "Saldos por Canal", lo cual no es cierto (Deuda Técnica de `SDD_004` y `SDD_027`).
>
> **Fase C: BLOQUEADA.** No se aplicarán correcciones hasta que la arquitectura de caja subyacente sea resuelta.
