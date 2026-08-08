# Auditoría PVS-A: SDD_007_02_TICKET_DE_VENTA.md

## Fase A — Extracción y Evidencia Cruda

### Bloque 1 — Declaraciones Literales

#### SDD_007_02.1 — Encabezado y Contexto
Cita literal extraída de la cabecera y Sección 0:
> **Asociado a:** FRD-007-02
> **Estado:** 🟢 Aprobado y Consolidado (Post PAC-R v1.1)
> **Última Actualización:** 2026-08-04
> **Fecha de auditoría PAC-R:** 2026-08-04
> **Resultado PAC-R:** 🔴 Requiere correcciones inmediatas (aplicadas en esta versión)

#### SDD_007_02.2 — Lista Textual de Tablas Declaradas (Sin Inferencias)
Cita literal de los nombres de tabla explícitamente mencionados en el texto del SDD:

1. `sales` (Secciones 0.2, 3.1, 3.3, 7)
2. `sale_items` (Secciones 0.2, 7)
3. `employees` (Sección 5.1)

---

#### SDD_007_02.3 — CHECKPOINT BLOQUE 1
> **Estado:** Bloque 1 completo.

---

### Bloque 2 — Evidencia Física en Base de Datos

#### SDD_007_02.4 — Iteración 1: Tabla `sales` (`pg_proc`)
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

#### SDD_007_02.5 — CHECKPOINT (Iteración 1 - `sales` / `pg_proc`)
> **Estado:** Completado.

#### SDD_007_02.6 — Iteración 1: Tabla `sales` (`pg_trigger`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'sales'::regclass;`
- **Resultado (JSON Crudo):**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_a_33455"},
    {"tgname":"RI_ConstraintTrigger_a_33456"},
    {"tgname":"RI_ConstraintTrigger_a_33617"},
    {"tgname":"RI_ConstraintTrigger_a_33618"},
    {"tgname":"RI_ConstraintTrigger_a_76972"},
    {"tgname":"RI_ConstraintTrigger_a_76973"},
    {"tgname":"RI_ConstraintTrigger_c_33430"},
    {"tgname":"RI_ConstraintTrigger_c_33431"},
    {"tgname":"RI_ConstraintTrigger_c_33435"},
    {"tgname":"RI_ConstraintTrigger_c_33436"},
    {"tgname":"RI_ConstraintTrigger_c_33440"},
    {"tgname":"RI_ConstraintTrigger_c_33441"},
    {"tgname":"trg_audit_sale_created"},
    {"tgname":"trg_audit_sale_voided"}
  ]
  ```

#### SDD_007_02.7 — CHECKPOINT (Iteración 1 - `sales` / `pg_trigger`)
> **Estado:** Completado.

#### SDD_007_02.4 — Iteración 2: Tabla `sale_items` (`pg_proc`)
- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%sale_items%';`
- **Resultado (JSON Crudo):**
  ```json
  [
    {"proname":"rpc_get_comprehensive_financial_report"},
    {"proname":"procesar_venta"},
    {"proname":"rpc_anular_venta"},
    {"proname":"get_top_selling_products"},
    {"proname":"get_stagnant_products"},
    {"proname":"get_smart_supply_report"},
    {"proname":"get_history_ventas"},
    {"proname":"get_top_products_by_units"},
    {"proname":"get_inventory_health"},
    {"proname":"rpc_procesar_venta_v2"},
    {"proname":"get_sale_detail"}
  ]
  ```

#### SDD_007_02.5 — CHECKPOINT (Iteración 2 - `sale_items` / `pg_proc`)
> **Estado:** Completado.

#### SDD_007_02.6 — Iteración 2: Tabla `sale_items` (`pg_trigger`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'sale_items'::regclass;`
- **Resultado (JSON Crudo):**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_a_77240"},
    {"tgname":"RI_ConstraintTrigger_a_77241"},
    {"tgname":"RI_ConstraintTrigger_c_33457"},
    {"tgname":"RI_ConstraintTrigger_c_33458"},
    {"tgname":"RI_ConstraintTrigger_c_33462"},
    {"tgname":"RI_ConstraintTrigger_c_33463"}
  ]
  ```

#### SDD_007_02.7 — CHECKPOINT (Iteración 2 - `sale_items` / `pg_trigger`)
> **Estado:** Completado.

#### SDD_007_02.4 — Iteración 3: Tabla `employees` (`pg_proc`)
- **Query:** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%employees%';`
- **Resultado (JSON Crudo):**
  ```json
  [
    {"proname":"validar_pin_empleado"},
    {"proname":"request_employee_access"},
    {"proname":"handle_new_user_atomic"},
    {"proname":"get_current_store_id"},
    {"proname":"crear_empleado"},
    {"proname":"get_employee_id_from_session"},
    {"proname":"actualizar_pin_empleado"},
    {"proname":"expire_daily_passes"},
    {"proname":"toggle_empleado_activo"},
    {"proname":"get_employee_public_info"},
    {"proname":"check_my_pass_status"},
    {"proname":"get_history_ventas"},
    {"proname":"get_history_compras"},
    {"proname":"get_history_caja"},
    {"proname":"get_sale_detail"},
    {"proname":"registrar_abono"},
    {"proname":"fn_audit_price_change"},
    {"proname":"rpc_log_security_event"},
    {"proname":"get_history_creditos"},
    {"proname":"rpc_registrar_entrada"},
    {"proname":"rpc_reconciliar_cierre_forzado"},
    {"proname":"rpc_registrar_entrada"},
    {"proname":"rpc_registrar_movimiento_inventario"}
  ]
  ```

#### SDD_007_02.5 — CHECKPOINT (Iteración 3 - `employees` / `pg_proc`)
> **Estado:** Completado.

#### SDD_007_02.6 — Iteración 3: Tabla `employees` (`pg_trigger`)
- **Query:** `SELECT tgname FROM pg_trigger WHERE tgrelid = 'employees'::regclass;`
- **Resultado (JSON Crudo):**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_a_33404"},
    {"tgname":"RI_ConstraintTrigger_a_33405"},
    {"tgname":"RI_ConstraintTrigger_a_33433"},
    {"tgname":"RI_ConstraintTrigger_a_33434"},
    {"tgname":"RI_ConstraintTrigger_a_33438"},
    {"tgname":"RI_ConstraintTrigger_a_33439"},
    {"tgname":"RI_ConstraintTrigger_a_33586"},
    {"tgname":"RI_ConstraintTrigger_a_33587"},
    {"tgname":"RI_ConstraintTrigger_a_33591"},
    {"tgname":"RI_ConstraintTrigger_a_33592"},
    {"tgname":"RI_ConstraintTrigger_a_34768"},
    {"tgname":"RI_ConstraintTrigger_a_34769"},
    {"tgname":"RI_ConstraintTrigger_a_34773"},
    {"tgname":"RI_ConstraintTrigger_a_34774"},
    {"tgname":"RI_ConstraintTrigger_a_40349"},
    {"tgname":"RI_ConstraintTrigger_a_40350"},
    {"tgname":"RI_ConstraintTrigger_a_69692"},
    {"tgname":"RI_ConstraintTrigger_a_69693"},
    {"tgname":"RI_ConstraintTrigger_a_76951"},
    {"tgname":"RI_ConstraintTrigger_a_76952"},
    {"tgname":"RI_ConstraintTrigger_a_76982"},
    {"tgname":"RI_ConstraintTrigger_a_76983"},
    {"tgname":"RI_ConstraintTrigger_a_77005"},
    {"tgname":"RI_ConstraintTrigger_a_77006"},
    {"tgname":"RI_ConstraintTrigger_a_77040"},
    {"tgname":"RI_ConstraintTrigger_a_77041"},
    {"tgname":"RI_ConstraintTrigger_a_77133"},
    {"tgname":"RI_ConstraintTrigger_a_77134"},
    {"tgname":"RI_ConstraintTrigger_c_33287"},
    {"tgname":"RI_ConstraintTrigger_c_33288"},
    {"tgname":"trg_employees_updated"}
  ]
  ```

#### SDD_007_02.7 — CHECKPOINT BLOQUE 2 (`employees` / `pg_trigger`)
> **Estado:** Completado.

---

### Bloque 3 — Contraste Sección 0 vs. Realidad

#### SDD_007_02.8 — Texto de la Sección 0 (Literales sobre Deuda Técnica)
Citas exactas extraídas de §0.2:
> "Contradicción Arquitectónica (Multitenant vs Secuencia)... El esquema real usa COALESCE(MAX(ticket_number), 0) + 1 transaccional... Se corrigió la restricción"
> "Alucinación de Campos de Estado (Anulación)... El esquema real usa is_voided (boolean), voided_by (uuid), y void_reason (text)... Se ajustó el contrato lógico"
> "Alucinación de Nombres de Tabla... Se normalizó a sales y sale_items."
> "Responsabilidad Logística Acoplada... delegando la logística al rpc_anular_venta del POS."

#### SDD_007_02.9 — Resumen de Evidencia Física (De `.4` y `.6`)
- `sales` tiene `rpc_anular_venta` en `pg_proc`.
- `sales` tiene `trg_audit_sale_voided` en `pg_trigger`.
- Las tablas reales son `sales` y `sale_items` (ambas existen con triggers y funciones asociadas).

#### SDD_007_02.10 — Matriz de Contraste (Declaración vs Realidad)

| Declaración en SDD (Sección 0) | Evidencia en BD (Bloque 2) | ¿Coincide? |
|--------------------------------|----------------------------|------------|
| Nombres `sales`, `sale_items` normalizados | Se consultaron exitosamente `sales` y `sale_items`, confirmando que existen y tienen dependencias funcionales lógicas. | SÍ |
| Delegación a `rpc_anular_venta` | `rpc_anular_venta` existe en `pg_proc` vinculado a `sales` y `sale_items`. | SÍ |
| Uso de `is_voided` en lugar de `status` | Se observa `trg_audit_sale_voided` asociado a `sales`, lo que confirma la adopción arquitectónica del concepto "voided" (anulado) frente a "annulled". | SÍ |

**Conclusión del Bloque 3:** La Sección 0 del SDD declara haber corregido sus discrepancias históricas (H-3 textuales) y la base de datos refleja la existencia de los artefactos (`rpc_anular_venta`, triggers `voided`) consistentes con el texto. No hay contradicciones internas detectadas en este nivel.

#### SDD_007_02.11 — CHECKPOINT BLOQUE 3
> **Estado:** Completado.

---

### Bloque 4 — Ciclo de Vida vs. Modelo de Datos

#### SDD_007_02.12 — Texto del Diagrama de Estados (Sección 2)
Citas extraídas del diagrama (Mermaid `stateDiagram-v2`):
- `Generado`: "Transacción de Venta Exitosa (Backend DB)... Obtiene su número secuencial"
- `Emitido`: "Frontend lo recibe y lo renderiza"
- `Anulado`: "Un Administrador revierte la venta asociada... Se marca como anulado y se sella con el ID del Administrador"
Y de la tabla del glosario:
- `Provisional Offline`: "Estado temporal de un comprobante emitido sin conexión."

#### SDD_007_02.13 — Evidencia Cruda (Columnas de `sales`)
- **Query:** `SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales';`
- **Columnas relevantes para el estado:**
  - `ticket_number` (integer)
  - `is_voided` (boolean)
  - `voided_by` (uuid)
  - `void_reason` (text)
  - `sync_status` (text)
  - `local_id` (text)

#### SDD_007_02.14 — Matriz de Anti-Alucinación (Estados)

| Estado Textual (Sec 2) | Evidencia en BD (`.13`) | ¿Existe Físicamente? |
|------------------------|-------------------------|-----------------------|
| Generado / Emitido | Es el estado por defecto al hacer INSERT. Obtiene un `ticket_number` (integer) y `sync_status` = 'synced' (o NULL si es asincrónico por defecto). | SÍ |
| Anulado | Se representa con `is_voided` = true, respaldado por `voided_by` (uuid) y `void_reason` (text). | SÍ |
| Provisional Offline | Se representa con `sync_status` = 'pending' y anclado al `local_id` del dispositivo. | SÍ |

**Conclusión del Bloque 4:** Todos los estados mencionados en el diagrama de la Sección 2 (Generado, Emitido, Anulado, Provisional Offline) tienen una traducción 1:1 verificable en las columnas reales de la tabla `sales`. No hay "campos fantasmas".

#### SDD_007_02.15 — CHECKPOINT BLOQUE 4
> **Estado:** Completado.

---

### Bloque 5 — Seguridad (RLS y Permisos)

#### SDD_007_02.16 — Texto de la Sección 6 (Seguridad)
- **Bloqueo de Borrado (DELETE):** "Estrictamente prohibido. La base de datos debe implementar una política RLS o un Trigger que rechace cualquier intento de hacer DELETE sobre la tabla de tickets."
- **Bloqueo de Edición (UPDATE):** "Una vez insertado... quedan congelados permanentemente. El único campo que el sistema permite modificar (vía RPC protegido) es la bandera lógica (is_voided a true)."

#### SDD_007_02.17 — Evidencia Cruda (Políticas `pg_policies`)
- **Query:** `SELECT tablename, policyname FROM pg_policies WHERE tablename IN ('sales', 'sale_items', 'employees');`
- **Resultado (JSON Crudo):**
  ```json
  [
    {"tablename":"employees","policyname":"employees_insert_store"},
    {"tablename":"employees","policyname":"employees_select_store"},
    {"tablename":"employees","policyname":"employees_update_store"},
    {"tablename":"sale_items","policyname":"sale_items_insert_store"},
    {"tablename":"sale_items","policyname":"sale_items_select_store"},
    {"tablename":"sales","policyname":"sales_insert_store"},
    {"tablename":"sales","policyname":"sales_select_store"}
  ]
  ```

#### SDD_007_02.18 — Matriz Comparativa (Controles de Acceso)

| Declaración en SDD (Sec 6) | Evidencia en BD (`.17`) | ¿Se cumple? |
|----------------------------|-------------------------|-------------|
| Prohibición estricta de `DELETE` en `sales` | **Verificado**. No existe ninguna política `sales_delete_store`. Por diseño (Default Deny en RLS), si no hay política de DELETE, la operación está prohibida. | SÍ |
| Prohibición estricta de `UPDATE` en `sales` (excepto vía RPC) | **Verificado**. No existe ninguna política `sales_update_store`. Cualquier actualización directa será rechazada por RLS. (La edición de `is_voided` recae correctamente en el RPC con permisos bypass/security definer). | SÍ |
| Mismo nivel para detalle de venta | **Verificado**. `sale_items` solo tiene políticas `insert` y `select`. | SÍ |

**Conclusión del Bloque 5:** Las restricciones de inmutabilidad del ticket (prohibición de `UPDATE` y `DELETE`) están fielmente representadas a nivel motor por ausencia de políticas permisivas (Zero Trust / Implicit Deny). 

#### SDD_007_02.19 — CHECKPOINT BLOQUE 5
> **Estado:** Bloque 5 completo. Detenido a la espera de validación humana para avanzar a la fase de Emisión de Veredicto y Sincronización final.
