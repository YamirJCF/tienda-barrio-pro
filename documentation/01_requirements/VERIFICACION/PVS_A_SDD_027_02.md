# PVS-A — Registro de Auditoría y Verificación: SDD_027_02

> **Documento auditado:** `SDD_027_02_LIMITE_24_HORAS.md`
> **Ruta:** `documentation/01_requirements/SDD/SDD_027_02_LIMITE_24_HORAS.md`
> **Fecha de ejecución:** 2026-08-08
> **Estado:** FASE A — En curso (Bloque 2)

---

## FASE A — Auditoría (Evidencia Cruda)

### Bloque 1 — Identificación

#### SDD_027_02.1 — Nombre y Ruta Exacta del SDD
- **Nombre:** SDD-027-02: Límite de 24 Horas y Caducidad de Caja
- **Ruta Absoluta:** `c:\Users\Windows 11\OneDrive\Desktop\prueba\documentation\01_requirements\SDD\SDD_027_02_LIMITE_24_HORAS.md`

#### SDD_027_02.2 — Lista Textual de Tablas Declaradas
Extraídas del cuerpo del documento (`SDD_027_02_LIMITE_24_HORAS.md`):

1. `cash_sessions` (Mencionada en Sección 2.1, 2.2)
2. `cash_session_balances` (Mencionada en Sección 0.2, 0.3, 2.2)
3. `audit_logs` (Mencionada en Sección 2.2)

#### SDD_027_02.3 — CHECKPOINT BLOQUE 1
> **Estado:** Completado.

---

### Bloque 2 — Verificación Mecánica (Tabla por Tabla)

#### Tabla 1: `cash_session_balances`

##### SDD_027_02.4 — Evidencia Cruda `pg_proc` (`cash_session_balances`)
- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%cash_session_balances%';`
- **Resultado (JSON Crudo):**
  ```json
  []
  ```
- **Hallazgo:** No existen funciones almacenadas en `pg_proc` que referencien `cash_session_balances`.

##### SDD_027_02.5 — CHECKPOINT (`cash_session_balances` - Funciones)
> **Estado:** Completado.

##### SDD_027_02.6 — Evidencia Cruda `pg_trigger` (`cash_session_balances`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_session_balances'::regclass AND NOT tgisinternal;`
- **Resultado (Error Crudo de PostgreSQL):**
  ```
  ERROR: 42P01: relation "cash_session_balances" does not exist
  LINE 1: SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_session_balances'::regclass AND NOT tgisinternal;
  ```
- **Hallazgo Mecánico:** La tabla `cash_session_balances` **NO EXISTE** físicamente en la base de datos de producción (`information_schema.tables`).

##### SDD_027_02.7 — CHECKPOINT (`cash_session_balances` - Triggers Completo)
> **Estado:** Completado.

---

#### Tabla 2: `cash_sessions`

##### SDD_027_02.4b — Evidencia Cruda `pg_proc` (`cash_sessions`)
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

##### SDD_027_02.5b — CHECKPOINT (`cash_sessions` - Funciones)
> **Estado:** Completado.

##### SDD_027_02.6b — Evidencia Cruda `pg_trigger` (`cash_sessions`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_sessions'::regclass AND NOT tgisinternal;`
- **Resultado (JSON Crudo):**
  ```json
  [
    {"tgname":"trg_audit_cash_closed"},
    {"tgname":"trg_audit_cash_opened"},
    {"tgname":"trg_expire_passes_on_cash_close"}
  ]
  ```

##### SDD_027_02.7b — CHECKPOINT (`cash_sessions` - Triggers Completo)
> **Estado:** Completado.

---

#### Tabla 3: `audit_logs`

##### SDD_027_02.4c — Evidencia Cruda `pg_proc` (`audit_logs`)
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

##### SDD_027_02.5c — CHECKPOINT (`audit_logs` - Funciones)
> **Estado:** Completado.

##### SDD_027_02.6c — Evidencia Cruda `pg_trigger` (`audit_logs`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'audit_logs'::regclass AND NOT tgisinternal;`
- **Resultado (JSON Crudo):**
  ```json
  []
  ```

##### SDD_027_02.7c — CHECKPOINT (`audit_logs` - Triggers Completo / Fin Bloque 2)
> **Estado:** Esperando confirmación para avanzar al

### Bloque 3 — Contraste Sección 0 vs. Realidad

#### SDD_027_02.8 — Cita Textual de Sección 0
*(Extracto de la Sección 0.3 de `SDD_027_02_LIMITE_24_HORAS.md`)*:
> La auditoría revela que la base de datos actual posee una protección muy débil y mal implementada contra la regla de las 24 horas.
> | Hallazgo / Función | Brecha Descubierta | Solución Obligatoria (DSD/SQL) |
> |--------------------|--------------------|--------------------------------|
> | 🔴 `rpc_procesar_venta_v2` | Selecciona la sesión activa (`status='open'`) sin validar si `opened_at` excedió las 24 horas. Permite inyectar ventas a un turno caducado. | Modificar la validación en todo RPC financiero para abortar (`RAISE EXCEPTION 'SHIFT_EXPIRED'`) si `now() - opened_at > 24h`. |
> | 🔴 `rpc_check_and_force_close_shifts` | Calcula saldos globales (violando Fase 0 multicanal) y asigna `actual_balance = NULL` y `difference = NULL`. | Reescribir el cron job para que, por cada `payment_method_id` en `cash_session_balances`, asigne `actual = expected` y `difference = 0`. |

#### SDD_027_02.9 — Cita Textual de Resultados de Bloque 2
- **[Paso .4b] `cash_sessions` (pg_proc):**
  > `[{"proname":"rpc_procesar_venta_v2"}, {"proname":"rpc_check_and_force_close_shifts"}, ...]`
- **[Paso .6] `cash_session_balances` (pg_trigger):**
  > `ERROR: 42P01: relation "cash_session_balances" does not exist`

#### SDD_027_02.10 — Tabla Comparativa (Realidad vs Sección 0)

| Elemento en Sec 0 | Estado en BD (Evidencia Cruda) | Contradicción Detectada |
|-------------------|--------------------------------|-------------------------|
| Función `rpc_procesar_venta_v2` | **Existe** (evidencia en `.4b`) | 🟢 Ninguna. |
| Función `rpc_check_and_force_close_shifts` | **Existe** (evidencia en `.4b`) | 🟢 Ninguna. |
| Tabla `cash_session_balances` para iteración en la solución obligatoria | **NO Existe la tabla** (evidencia en `.6`) | 🔴 **Crítica.** El SDD exige explícitamente reescribir un cron job para iterar sobre los métodos de pago en la tabla `cash_session_balances`, la cual no existe físicamente en producción. |

#### SDD_027_02.11 — CHECKPOINT (Fin Bloque 3)
> **Estado:** Completado.

---

### Bloque 4 — Ciclo de Vida vs. Modelo de Datos

#### SDD_027_02.12 — Estados y Flujos (Diagramas)
- El Diagrama 2.1 (Rechazo Inmediato) declara:
  - Condición de expiración: `(NOW() - opened_at) > 24 hours`
  - Estado de sesión buscada: `status = 'OPEN'` (u `OPEN` literal).
- El Diagrama 2.2 (Cierre Forzoso Multicanal) declara:
  - Iteración sobre: `cash_session_balances`
  - Actualizaciones exigidas en `cash_session_balances`: `actual_balance = expected_balance`, `difference = 0`
  - Actualizaciones exigidas en `cash_sessions`: `status = 'CLOSED'`, `forced_close = true`

#### SDD_027_02.13 — Evidencia Cruda `column_name`, `data_type`
- **Query (`cash_sessions`):** `SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'cash_sessions';`
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

#### SDD_027_02.14 — Tabla Comparativa (Soporte Físico de Estados)

| Elemento de Flujo | Existe Físicamente | Observación |
|-------------------|--------------------|-------------|
| `cash_sessions.opened_at` | **Sí** (`timestamptz`) | 🟢 Soporta la validación de caducidad transaccional. |
| `cash_sessions.status` | **Sí** (`text`) | 🟢 Soporta la distinción OPEN/CLOSED. |
| `cash_sessions.forced_close` | **Sí** (`boolean`) | 🟢 Soporta la bandera de alerta para auditoría. |
| Iteración sobre `cash_session_balances` | **NO** | 🔴 Imposible ejecutar el diagrama 2.2; la tabla no existe. |
| `actual_balance`, `expected_balance`, `difference` | **Sí**, pero en `cash_sessions` | 🟡 Estos campos están en `cash_sessions` a nivel global (unicanal), lo que contradice el mandato de "repartirlos por canal" de la Fase 0. |

#### SDD_027_02.15 — CHECKPOINT BLOQUE 4
> **Estado:** Completado.

---

### Bloque 5 — Seguridad

#### SDD_027_02.16 — Control de Acceso (Sección 4)
- **Cita:** *"Inmutabilidad del Cierre Forzoso: Al igual que un cierre normal, un turno cerrado forzosamente no puede ser reabierto. El flujo operativo debe continuar abriendo un nuevo turno."* (Sección 4).

#### SDD_027_02.17 — Evidencia Cruda `pg_policies`
- **Query:** `SELECT policyname FROM pg_policies WHERE tablename = 'cash_sessions';`
- **Resultado:**
  ```json
  [
    {"policyname":"cash_sessions_select_store"},
    {"policyname":"cash_sessions_insert_store"},
    {"policyname":"cash_sessions_update_store"}
  ]
  ```

#### SDD_027_02.18 — Tabla Comparativa (Políticas vs Exigencias)

| Mención en SDD Sec 4 | Política Exacta en BD | Observación |
|----------------------|-----------------------|-------------|
| Inmutabilidad del turno cerrado | **No visible en RLS** | 🟡 Las políticas actuales solo protegen el aislamiento por tienda (`_store`), no bloquean la edición de turnos cerrados a nivel de RLS. La protección asume que solo se usan los RPCs para modificar, lo cual es débil frente a updates directos. |

#### SDD_027_02.19 — CHECKPOINT BLOQUE 5
> **Estado:** Completado.

---

### Bloque 6 — Canal de Pago

#### SDD_027_02.20 — ¿El SDD mueve dinero?
- **Cita Textual:** *"Si posteriormente el conteo físico del dinero es menor, la pérdida es asumida administrativamente..."* y la instrucción obligatoria *"por cada `payment_method_id` en `cash_session_balances`, asigne `actual = expected`"*.
- **Veredicto:** **SÍ**. El SDD gestiona el cierre y consolidación de saldos de liquidez.

#### SDD_027_02.21 — Verificación del Contrato de Canal
- **Requisito del Contrato (Fase 0):** El SDD_027_02 asimila la restricción del SDD_027 padre, exigiendo explícitamente iterar sobre los canales.
- **Resultado Físico:** Como se documentó en los pasos `.6` y `.14`, la tabla `cash_session_balances` no existe, y los saldos siguen atrapados de forma unicanal en `cash_sessions`.
- **Hallazgo:** 🔴 **Incumplimiento Crítico**. El SDD documenta un modelo de canales de pago y obliga a iterarlo, pero el esquema físico no lo soporta.

#### SDD_027_02.22 — CHECKPOINT BLOQUE 6 (Fin de Fase A)
> **Estado:** Completado.

---

## Fase B: Análisis (Clasificación sin Corrección)

### SDD_027_02.23 — Clasificación contra PEA-N

#### Hallazgo F-1: Ausencia estructural de `cash_session_balances`
- **Descripción:** El SDD exige en su Sección 0.3 iterar sobre la tabla `cash_session_balances` para procesar el cierre multicanal de caja y gestionar la liquidez. La evidencia física (Paso .6) demostró que esta tabla no existe, y los saldos siguen atrapados de forma unicanal en `cash_sessions` (Paso .14).
- **Nivel de Jerarquía:** Requiere intervención directa del Arquitecto de Datos (DSD/Migración) para modelar el esquema físico. Es un impedimento estructural que no se resuelve ajustando texto ni en el Frontend (Niveles 1-3).
- **Clasificación PEA-N:** 🔴 **Halt H-2**.
- **Cita Literal PEA-N:** *"Vacío que involucra dinero real/permisos, sin resolución vía Jerarquía niveles 1-3."*

#### Hallazgo F-2: RLS sin inmutabilidad de cierre
- **Descripción:** El SDD exige en la Sección 4 que un turno cerrado sea inmutable. Las políticas RLS actuales (Paso .18) no prohíben operaciones de `UPDATE` sobre sesiones con `status = 'CLOSED'`.
- **Nivel de Jerarquía:** Al igual que F-1, requiere la creación de políticas SQL físicas (Nivel 4).
- **Clasificación PEA-N:** 🔴 **Halt H-2**.
- **Cita Literal PEA-N:** *"Vacío que involucra dinero real/permisos, sin resolución vía Jerarquía niveles 1-3."*

### SDD_027_02.24 — CHECKPOINT (Veredicto de Fase B)
> **Veredicto:** 🔴 **REQUIRE_MIGRATION (HALT H-2 DETECTADO)**.
> Al confirmarse la presencia de un Halt H-2 legítimo, el protocolo obliga a activar la bifurcación §4.1 hacia el §6 (Manejo de Halt). La Fase C queda estrictamente prohibida.

---

## Rama §6: Manejo de Halt

> 🛑 **PROTOCOLO DETENIDO POR HALT**
> Se ha ejecutado el protocolo de emergencia según la regla de bifurcación §4.1.
> 1. El protocolo PVS-A para `SDD_027_02` se **DETIENE** aquí.
> 2. La Fase C (Corrección) queda estrictamente bloqueada para todos los hallazgos de este documento.
> 3. El estado del documento se ha reportado como `🔴 Detenido por Halt` en el documento maestro.
> 
> *El sistema queda a la espera de que el Arquitecto de Datos resuelva la deuda estructural (Ausencia de `cash_session_balances` e Inmutabilidad de RLS).*
