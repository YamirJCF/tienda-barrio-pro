# PVS-A — Registro de Verificación Secuencial: SDD_007_01

> **Documento auditado:** SDD_007_01_NUCLEO_POS.md  
> **Fecha de inicio:** 2026-08-07  
> **Estado del protocolo:** 🔴 Detenido por Halt [H-2: rpc_procesar_venta_v3 ausente]

---

## FASE A — Auditoría (Evidencia Cruda)

### Bloque 1 — Identificación

#### SDD_007_01.1 — Nombre y Ruta Exacta
- **Ruta exacta:** `c:\Users\Windows 11\OneDrive\Desktop\prueba\documentation\01_requirements\SDD\SDD_007_01_NUCLEO_POS.md`
- **Cita literal del encabezado:**
  > `# SDD-007-01: Núcleo del Punto de Venta (POS) Desacoplado`

#### SDD_007_01.2 — Lista Textual de Tablas Declaradas (Sin Inferencias)
Cita literal de los nombres de tabla explícitamente mencionados en el texto del SDD (Secciones 0, 3, 5, 6 y 7):

1. `sales` (Secciones 0.2, 0.3, 3.1, 6.3, 7)
2. `sale_items` (Secciones 3.1, 7)
3. `sale_item_batches` (Secciones 0.1, 3.1, 7)
4. `inventory_batches` (Sección 7)
5. `inventory_movements` (Secciones 3.1, 7)
6. `cash_movements` (Secciones 0.1, 0.2, 3.1, 3.2, 7)
7. `payment_methods` (Secciones 0.3, 5.1)
8. `caja_diaria` (Sección 0.2 #8 - citada como alucinación previa a unificar)
9. `daily_cash_movements` (Sección 0.2 #8 - citada como alucinación previa a unificar)

---

#### SDD_007_01.3 — CHECKPOINT BLOQUE 1
> **Estado:** Bloque 1 completo.

---

### Bloque 2 — Verificación Mecánica (Tabla por Tabla)

#### Tabla 1: `sales`

##### SDD_007_01.4 — Funciones Backend que referencian `sales` (`pg_proc`)
- **Consulta ejecutada:**
  ```sql
  SELECT proname FROM pg_proc WHERE prosrc ILIKE '%sales%';
  ```
- **Resultado RAW:**
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

---

##### SDD_007_01.5 — CHECKPOINT BLOQUE 2 (Tabla 1: `sales` - `pg_proc`)
> **Estado:** Micro-paso `.4` para la tabla `sales` registrado con resultado RAW.

---

##### SDD_007_01.6 — Triggers Instalados en Tabla `sales` (`pg_trigger`)
- **Consulta ejecutada:**
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgrelid = 'sales'::regclass;
  ```
- **Resultado RAW:**
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

---

##### SDD_007_01.7 — CHECKPOINT BLOQUE 2 (Tabla 1: `sales` - `pg_trigger`)
> **Estado:** Micro-paso `.6` para la tabla `sales` registrado con resultado RAW.

---

#### Tabla 2: `sale_items`

##### SDD_007_01.4 — Funciones Backend que referencian `sale_items` (`pg_proc`)
- **Consulta ejecutada:**
  ```sql
  SELECT proname FROM pg_proc WHERE prosrc ILIKE '%sale_items%';
  ```
- **Resultado RAW:**
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

---

##### SDD_007_01.5 — CHECKPOINT BLOQUE 2 (Tabla 2: `sale_items` - `pg_proc`)
> **Estado:** Micro-paso `.4` para la tabla `sale_items` registrado con resultado RAW.

---

##### SDD_007_01.6 — Triggers Instalados en Tabla `sale_items` (`pg_trigger`)
- **Consulta ejecutada:**
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgrelid = 'sale_items'::regclass;
  ```
- **Resultado RAW:**
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

---

##### SDD_007_01.7 — CHECKPOINT BLOQUE 2 (Tabla 2: `sale_items` - `pg_trigger`)
> **Estado:** Micro-paso `.6` para la tabla `sale_items` registrado con resultado RAW.

---

#### Tabla 3: `sale_item_batches`

##### SDD_007_01.4 — Funciones Backend que referencian `sale_item_batches` (`pg_proc`)
- **Consulta ejecutada:**
  ```sql
  SELECT proname FROM pg_proc WHERE prosrc ILIKE '%sale_item_batches%';
  ```
- **Resultado RAW:**
  ```json
  [
    {"proname":"rpc_get_comprehensive_financial_report"},
    {"proname":"rpc_procesar_venta_v2"}
  ]
  ```

---

##### SDD_007_01.5 — CHECKPOINT BLOQUE 2 (Tabla 3: `sale_item_batches` - `pg_proc`)
> **Estado:** Micro-paso `.4` para la tabla `sale_item_batches` registrado con resultado RAW.

---

##### SDD_007_01.6 — Triggers Instalados en Tabla `sale_item_batches` (`pg_trigger`)
- **Consulta ejecutada:**
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgrelid = 'sale_item_batches'::regclass;
  ```
- **Resultado RAW:**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_c_77242"},
    {"tgname":"RI_ConstraintTrigger_c_77243"},
    {"tgname":"RI_ConstraintTrigger_c_77247"},
    {"tgname":"RI_ConstraintTrigger_c_77248"}
  ]
  ```

---

##### SDD_007_01.7 — CHECKPOINT BLOQUE 2 (Tabla 3: `sale_item_batches` - `pg_trigger`)
> **Estado:** Micro-paso `.6` para la tabla `sale_item_batches` registrado con resultado RAW.

---

#### Tabla 4: `inventory_batches`

##### SDD_007_01.4 — Funciones Backend que referencian `inventory_batches` (`pg_proc`)
- **Consulta ejecutada:**
  ```sql
  SELECT proname FROM pg_proc WHERE prosrc ILIKE '%inventory_batches%';
  ```
- **Resultado RAW:**
  ```json
  [
    {"proname":"rpc_get_comprehensive_financial_report"},
    {"proname":"sync_product_stock_from_batches"},
    {"proname":"consume_stock_fifo"},
    {"proname":"rpc_actualizar_precio_lote"},
    {"proname":"rpc_actualizar_precio_lote"},
    {"proname":"rpc_registrar_entrada"},
    {"proname":"bridge_movement_to_batch"}
  ]
  ```

---

##### SDD_007_01.5 — CHECKPOINT BLOQUE 2 (Tabla 4: `inventory_batches` - `pg_proc`)
> **Estado:** Micro-paso `.4` para la tabla `inventory_batches` registrado con resultado RAW.

---

##### SDD_007_01.6 — Triggers Instalados en Tabla `inventory_batches` (`pg_trigger`)
- **Consulta ejecutada:**
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgrelid = 'inventory_batches'::regclass;
  ```
- **Resultado RAW:**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_a_77245"},
    {"tgname":"RI_ConstraintTrigger_a_77246"},
    {"tgname":"RI_ConstraintTrigger_a_77475"},
    {"tgname":"RI_ConstraintTrigger_a_77476"},
    {"tgname":"RI_ConstraintTrigger_c_77130"},
    {"tgname":"RI_ConstraintTrigger_c_77131"},
    {"tgname":"RI_ConstraintTrigger_c_77135"},
    {"tgname":"RI_ConstraintTrigger_c_77136"},
    {"tgname":"RI_ConstraintTrigger_c_77454"},
    {"tgname":"RI_ConstraintTrigger_c_77455"},
    {"tgname":"trg_sync_batches"}
  ]
  ```

---

##### SDD_007_01.7 — CHECKPOINT BLOQUE 2 (Tabla 4: `inventory_batches` - `pg_trigger`)
> **Estado:** Micro-paso `.6` para la tabla `inventory_batches` registrado con resultado RAW.

---

#### Tabla 5: `inventory_movements`

##### SDD_007_01.4 — Funciones Backend que referencian `inventory_movements` (`pg_proc`)
- **Consulta ejecutada:**
  ```sql
  SELECT proname FROM pg_proc WHERE prosrc ILIKE '%inventory_movements%';
  ```
- **Resultado RAW:**
  ```json
  [
    {"proname":"procesar_venta"},
    {"proname":"rpc_anular_venta"},
    {"proname":"get_history_compras"},
    {"proname":"get_top_products_by_units"},
    {"proname":"rpc_procesar_venta_v2"},
    {"proname":"rpc_force_sale"},
    {"proname":"rpc_registrar_entrada"},
    {"proname":"rpc_registrar_entrada"},
    {"proname":"rpc_registrar_movimiento_inventario"},
    {"proname":"rpc_soft_delete_product"},
    {"proname":"bridge_movement_to_batch"}
  ]
  ```

---

##### SDD_007_01.5 — CHECKPOINT BLOQUE 2 (Tabla 5: `inventory_movements` - `pg_proc`)
> **Estado:** Micro-paso `.4` para la tabla `inventory_movements` registrado con resultado RAW.

---

##### SDD_007_01.6 — Triggers Instalados en Tabla `inventory_movements` (`pg_trigger`)
- **Consulta ejecutada:**
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgrelid = 'inventory_movements'::regclass;
  ```
- **Resultado RAW:**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_a_77452"},
    {"tgname":"RI_ConstraintTrigger_a_77453"},
    {"tgname":"RI_ConstraintTrigger_a_77470"},
    {"tgname":"RI_ConstraintTrigger_a_77471"},
    {"tgname":"RI_ConstraintTrigger_c_33401"},
    {"tgname":"RI_ConstraintTrigger_c_33402"},
    {"tgname":"RI_ConstraintTrigger_c_33406"},
    {"tgname":"RI_ConstraintTrigger_c_33407"},
    {"tgname":"RI_ConstraintTrigger_c_43729"},
    {"tgname":"RI_ConstraintTrigger_c_43730"},
    {"tgname":"RI_ConstraintTrigger_c_77449"},
    {"tgname":"RI_ConstraintTrigger_c_77450"},
    {"tgname":"enforce_payment_type_on_entries"},
    {"tgname":"trg_bridge_movement_to_batch"}
  ]
  ```

---

##### SDD_007_01.7 — CHECKPOINT BLOQUE 2 (Tabla 5: `inventory_movements` - `pg_trigger`)
> **Estado:** Micro-paso `.6` para la tabla `inventory_movements` registrado con resultado RAW.

---

#### Tabla 6: `cash_movements`

##### SDD_007_01.4 — Funciones Backend que referencian `cash_movements` (`pg_proc`)
- **Consulta ejecutada:**
  ```sql
  SELECT proname FROM pg_proc WHERE prosrc ILIKE '%cash_movements%';
  ```
- **Resultado RAW:**
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

---

##### SDD_007_01.5 — CHECKPOINT BLOQUE 2 (Tabla 6: `cash_movements` - `pg_proc`)
> **Estado:** Micro-paso `.4` para la tabla `cash_movements` registrado con resultado RAW.

---

##### SDD_007_01.6 — Triggers Instalados en Tabla `cash_movements` (`pg_trigger`)
- **Consulta ejecutada:**
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgrelid = 'cash_movements'::regclass;
  ```
- **Resultado RAW:**
  ```json
  [
    {"tgname":"RI_ConstraintTrigger_c_33614"},
    {"tgname":"RI_ConstraintTrigger_c_33615"},
    {"tgname":"RI_ConstraintTrigger_c_33619"},
    {"tgname":"RI_ConstraintTrigger_c_33620"}
  ]
  ```

---

##### SDD_007_01.7 — CHECKPOINT BLOQUE 2 (Tabla 6: `cash_movements` - `pg_trigger`)
> **Estado:** Micro-paso `.6` para la tabla `cash_movements` registrado con resultado RAW.

---

#### Tabla 7: `payment_methods`

##### SDD_007_01.4 — Funciones Backend que referencian `payment_methods` (`pg_proc`)
- **Consulta ejecutada:**
  ```sql
  SELECT proname FROM pg_proc WHERE prosrc ILIKE '%payment_methods%';
  ```
- **Resultado RAW:**
  ```json
  [
    {"proname":"rpc_get_system_config"}
  ]
  ```

---

##### SDD_007_01.5 — CHECKPOINT BLOQUE 2 (Tabla 7: `payment_methods` - `pg_proc`)
> **Estado:** Micro-paso `.4` para la tabla `payment_methods` registrado con resultado RAW.

---

##### SDD_007_01.6 — Triggers Instalados en Tabla `payment_methods` (`pg_trigger`)
- **Consulta ejecutada:**
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgrelid = 'payment_methods'::regclass;
  ```
- **Resultado RAW:**
  ```json
  []
  ```

---

##### SDD_007_01.7 — CHECKPOINT BLOQUE 2 (Tabla 7: `payment_methods` - `pg_trigger`)
> **Estado:** Micro-paso `.6` para la tabla `payment_methods` registrado con resultado RAW.

---

#### Tabla 8: `caja_diaria`

##### SDD_007_01.4 — Funciones Backend que referencian `caja_diaria` (`pg_proc`)
- **Consulta ejecutada:**
  ```sql
  SELECT proname FROM pg_proc WHERE prosrc ILIKE '%caja_diaria%';
  ```
- **Resultado RAW:**
  ```json
  []
  ```

---

##### SDD_007_01.5 — CHECKPOINT BLOQUE 2 (Tabla 8: `caja_diaria` - `pg_proc`)
> **Estado:** Micro-paso `.4` para la tabla `caja_diaria` registrado con resultado RAW.

---

##### SDD_007_01.6 — Triggers Instalados en Tabla `caja_diaria` (`pg_trigger`)
- **Consulta ejecutada:**
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgrelid = 'caja_diaria'::regclass;
  ```
- **Resultado RAW (Error Postgres 42P01):**
  ```json
  {
    "error": "ERROR: 42P01: relation \"caja_diaria\" does not exist"
  }
  ```

---

##### SDD_007_01.7 — CHECKPOINT BLOQUE 2 (Tabla 8: `caja_diaria` - `pg_trigger`)
> **Estado:** Micro-paso `.6` para la tabla `caja_diaria` registrado con resultado RAW (Tabla Inexistente en DB).

---

#### Tabla 9: `daily_cash_movements`

##### SDD_007_01.4 — Funciones Backend que referencian `daily_cash_movements` (`pg_proc`)
- **Consulta ejecutada:**
  ```sql
  SELECT proname FROM pg_proc WHERE prosrc ILIKE '%daily_cash_movements%';
  ```
- **Resultado RAW:**
  ```json
  []
  ```

---

##### SDD_007_01.5 — CHECKPOINT BLOQUE 2 (Tabla 9: `daily_cash_movements` - `pg_proc`)
> **Estado:** Micro-paso `.4` para la tabla `daily_cash_movements` registrado con resultado RAW.

---

##### SDD_007_01.6 — Triggers Instalados en Tabla `daily_cash_movements` (`pg_trigger`)
- **Consulta ejecutada:**
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgrelid = 'daily_cash_movements'::regclass;
  ```
- **Resultado RAW (Error Postgres 42P01):**
  ```json
  {
    "error": "ERROR: 42P01: relation \"daily_cash_movements\" does not exist"
  }
  ```

---

##### SDD_007_01.7 — CHECKPOINT BLOQUE 2 (Tabla 9: `daily_cash_movements` - `pg_trigger`)
> **Estado:** Micro-paso `.6` para la tabla `daily_cash_movements` registrado con resultado RAW (Tabla Inexistente en DB). **Fin del Bloque 2 para las 9 tablas.**

---

### Bloque 3 — Contraste Sección 0 vs. Realidad

#### SDD_007_01.8 — Cita Textual Completa de la Sección 0 (PAC-R) del SDD
```markdown
## 0. Auditoría Contextual PAC-R

> **Fecha de auditoría:** 2026-08-04  
> **Resultado:** 🔴 Diseño Funcional Aprobado / Deuda Técnica Crítica en BD

### 0.1 Restricciones Transversales Inyectadas (Fase 0)
Las siguientes restricciones fueron generadas por los módulos base de Fase 0 y son de cumplimiento obligatorio para este documento:
| SDD Origen | Restricción Inyectada | Impacto en el POS |
|------------|-----------------------|-------------------|
| **SDD_027 (Caja Multicanal)** | Prohibido usar saldos globales. Todo movimiento debe especificar `payment_method_id` hacia `cash_movements`. | El POS no puede inyectar efectivo en caja sin declarar explícitamente el canal de pago en el payload. |
| **SDD_010_016 (FIFO)** | Prohibido calcular costo de venta sobre `purchase_price`. Obligatorio desglosar ventas en `sale_item_batches`. | El motor del POS debe llamar a `consume_stock_fifo` y volcar el resultado íntegro por lote para proteger la utilidad. |

### 0.2 Hallazgos Críticos Históricos (🔴)
| # | Descripción del hallazgo | Sección afectada | Corrección requerida |
|---|--------------------------|-----------------|----------------------|
| 1 | **Ausencia de Flujo de Devolución de Cliente:** Según `POL-LOG-03`, el POS es el embudo único. | 2, 3 y 5.1 | Crear el estado y flujo "Devolución Cliente". |
| 2 | **Fuga de Verdad en Payload de Salida:** El backend recalcula precios pero no los retorna. | 5.2 | Retornar el total cobrado oficial y el arreglo de ítems procesados. |
| 3 | **Falta de Idempotencia en el Contrato:** Prevención de doble deducción por latencia. | 5.1 | Agregar `idempotency_key` como campo obligatorio. |
| 4 | **Trazabilidad de Cuentas por Pagar Rota:** Falta `supplier_id` y `reference_invoice_id` (FRD-019). | 5.1 | Agregar estos campos al payload para `devolucion_proveedor`. |
| 5 | **Trazabilidad de Devolución de Cliente Rota:** Falta enlazar a la venta original para validar precio devuelto. | 5.1 y 6.3 | Requerir `original_sale_item_id` en el carrito y validar contra el precio congelado. |
| 6 | **Ambigüedad de Consumo FIFO (Riesgo Doble Consumo):** No aclara si rpc consume directo o delega a trigger. | 3.1 y 7 | Explicitar que el RPC consume FIFO directo y usa `movement_type = 'venta'` (exento de trigger). |
| 7 | **Canal de Pago Omitido en Devolución:** Falta especificar el origen de los fondos al reembolsar. | 5.1 y 3.2 | Hacer `payment_method_id` obligatorio también para `devolucion_cliente`. |
| 8 | **Alucinación de Nombres de Tabla:** Usa `caja_diaria` y `daily_cash_movements` en vez del real. | 3 y 7 | Unificar todo a la tabla `cash_movements`. |

### 0.2 Hallazgos de Mejora (🟡)
| # | Descripción del hallazgo | Sección afectada | Corrección requerida |
|---|--------------------------|-----------------|----------------------|
| 1 | **Bloqueo Transaccional Débil:** Falta `FOR UPDATE`. | 3.1 | Explicitar uso de `FOR UPDATE` en stock. |
| 2 | **Falta Tipología en Bitácora:** `POL-AUD-02`. | 3.1 y 3.2 | Explicitar motivo de movimiento de inventario. |
| 3 | **Enum payment_type Hardcodeado:** Mezcla cierre contable con canal y no es extensible (FRD-020, FRD-022). | 5.1 y 3 | Separar `closure_type` de `payment_method_id`. |
| 4 | **Validación "Teórica" Multitenant:** Falla el patrón de seguridad, propiciando BUG-001. | 6.1 | Nombrar explícitamente `get_current_store_id()` y `assert_store_access()`. |
| 5 | **Idempotencia sin Constraint Fuerte:** La validación lógica es insuficiente contra race conditions reales. | 6.3 | Exigir `UNIQUE(idempotency_key)` en tabla `sales` y capturar la excepción. |

### 0.3 Hallazgos Capa E y Etapa 1.5 (Auditoría contra Realidad DB)
> **Advertencia de Deuda Técnica:** Las correcciones funcionales agregadas en las rondas previas de PAC-R rediseñaron teóricamente el POS (creando `rpc_procesar_venta_v3`), pero **no se implementaron en la base de datos**.

| # | Descripción del hallazgo | Sección afectada | Acción requerida (Deuda Técnica) |
|---|--------------------------|-----------------|----------------------|
| 1 | **Alucinación de RPC y Payload:** El SDD exige `rpc_procesar_venta_v3` con `closure_type`, `idempotency_key`, `supplier_id`, etc. La BD real sigue en `v2` recibiendo solo 5 parámetros básicos. | 5.1, 3.1, 3.2 | **Deuda Técnica Crítica:** Construir la migración SQL para el `rpc_procesar_venta_v3` que soporte los nuevos cierres (mermas, devoluciones). |
| 2 | **Alucinación de `idempotency_key`:** El SDD requiere `UNIQUE(idempotency_key)`. La tabla `sales` real no tiene esta columna. | 5.1, 6.3 | **Deuda Técnica:** Agregar columna `idempotency_key` (UUID, UNIQUE) a `sales`. |
| 3 | **Tipado del Canal de Pago:** El SDD exige FK `payment_method_id` hacia `payment_methods`. La BD actual lo mapea a un `TEXT` con un CHECK enum en `sales`. | 5.1 | **Deuda Técnica:** Alinear el código del RPC v3 para manejar el ID foráneo del sistema multicanal (FRD-022). |
| 4 | **Spoofing de Sesión:** El SDD exigía que el Frontend envíe el `session_id`. El RPC actual (`v2`) lo descubre desde la BD por seguridad. | 5.1 | **Corregido en Documento:** Se eliminó `session_id` del payload de entrada. El backend mantiene la autoridad de descubrimiento. |
```

---

#### SDD_007_01.9 — Cita Textual de Resultados de Bloque 2 (por ID)

- **SDD_007_01.4 (`sales` pg_proc):**
  `["rpc_get_comprehensive_financial_report", "procesar_venta", "rpc_anular_venta", "get_top_selling_products", "get_stagnant_products", "get_daily_summary", "get_smart_supply_report", "get_history_ventas", "get_top_products_by_units", "get_inventory_health", "rpc_procesar_venta_v2", "get_sale_detail"]`
- **SDD_007_01.6 (`sales` pg_trigger):**
  `["RI_ConstraintTrigger_a_33455", "RI_ConstraintTrigger_a_33456", "RI_ConstraintTrigger_a_33617", "RI_ConstraintTrigger_a_33618", "RI_ConstraintTrigger_a_76972", "RI_ConstraintTrigger_a_76973", "RI_ConstraintTrigger_c_33430", "RI_ConstraintTrigger_c_33431", "RI_ConstraintTrigger_c_33435", "RI_ConstraintTrigger_c_33436", "RI_ConstraintTrigger_c_33440", "RI_ConstraintTrigger_c_33441", "trg_audit_sale_created", "trg_audit_sale_voided"]`
- **SDD_007_01.4 (`sale_items` pg_proc):**
  `["rpc_get_comprehensive_financial_report", "procesar_venta", "rpc_anular_venta", "get_top_selling_products", "get_stagnant_products", "get_smart_supply_report", "get_history_ventas", "get_top_products_by_units", "get_inventory_health", "rpc_procesar_venta_v2", "get_sale_detail"]`
- **SDD_007_01.6 (`sale_items` pg_trigger):**
  `["RI_ConstraintTrigger_a_77240", "RI_ConstraintTrigger_a_77241", "RI_ConstraintTrigger_c_33457", "RI_ConstraintTrigger_c_33458", "RI_ConstraintTrigger_c_33462", "RI_ConstraintTrigger_c_33463"]`
- **SDD_007_01.4 (`sale_item_batches` pg_proc):**
  `["rpc_get_comprehensive_financial_report", "rpc_procesar_venta_v2"]`
- **SDD_007_01.6 (`sale_item_batches` pg_trigger):**
  `["RI_ConstraintTrigger_c_77242", "RI_ConstraintTrigger_c_77243", "RI_ConstraintTrigger_c_77247", "RI_ConstraintTrigger_c_77248"]`
- **SDD_007_01.4 (`inventory_batches` pg_proc):**
  `["rpc_get_comprehensive_financial_report", "sync_product_stock_from_batches", "consume_stock_fifo", "rpc_actualizar_precio_lote", "rpc_actualizar_precio_lote", "rpc_registrar_entrada", "bridge_movement_to_batch"]`
- **SDD_007_01.6 (`inventory_batches` pg_trigger):**
  `["RI_ConstraintTrigger_a_77245", "RI_ConstraintTrigger_a_77246", "RI_ConstraintTrigger_a_77475", "RI_ConstraintTrigger_a_77476", "RI_ConstraintTrigger_c_77130", "RI_ConstraintTrigger_c_77131", "RI_ConstraintTrigger_c_77135", "RI_ConstraintTrigger_c_77136", "RI_ConstraintTrigger_c_77454", "RI_ConstraintTrigger_c_77455", "trg_sync_batches"]`
- **SDD_007_01.4 (`inventory_movements` pg_proc):**
  `["procesar_venta", "rpc_anular_venta", "get_history_compras", "get_top_products_by_units", "rpc_procesar_venta_v2", "rpc_force_sale", "rpc_registrar_entrada", "rpc_registrar_entrada", "rpc_registrar_movimiento_inventario", "rpc_soft_delete_product", "bridge_movement_to_batch"]`
- **SDD_007_01.6 (`inventory_movements` pg_trigger):**
  `["RI_ConstraintTrigger_a_77452", "RI_ConstraintTrigger_a_77453", "RI_ConstraintTrigger_a_77470", "RI_ConstraintTrigger_a_77471", "RI_ConstraintTrigger_c_33401", "RI_ConstraintTrigger_c_33402", "RI_ConstraintTrigger_c_33406", "RI_ConstraintTrigger_c_33407", "RI_ConstraintTrigger_c_43729", "RI_ConstraintTrigger_c_43730", "RI_ConstraintTrigger_c_77449", "RI_ConstraintTrigger_c_77450", "enforce_payment_type_on_entries", "trg_bridge_movement_to_batch"]`
- **SDD_007_01.4 (`cash_movements` pg_proc):**
  `["rpc_get_comprehensive_financial_report", "cerrar_caja", "rpc_anular_venta", "get_history_caja", "rpc_procesar_venta_v2", "rpc_check_and_force_close_shifts", "rpc_pay_supplier_invoice"]`
- **SDD_007_01.6 (`cash_movements` pg_trigger):**
  `["RI_ConstraintTrigger_c_33614", "RI_ConstraintTrigger_c_33615", "RI_ConstraintTrigger_c_33619", "RI_ConstraintTrigger_c_33620"]`
- **SDD_007_01.4 (`payment_methods` pg_proc):**
  `["rpc_get_system_config"]`
- **SDD_007_01.6 (`payment_methods` pg_trigger):** `[]`
- **SDD_007_01.4 (`caja_diaria` pg_proc):** `[]`
- **SDD_007_01.6 (`caja_diaria` pg_trigger):** `ERROR 42P01 (tabla inexistente)`
- **SDD_007_01.4 (`daily_cash_movements` pg_proc):** `[]`
- **SDD_007_01.6 (`daily_cash_movements` pg_trigger):** `ERROR 42P01 (tabla inexistente)`

---

#### SDD_007_01.10 — Tabla Comparativa: Contraste Sección 0 vs. Realidad DB

| # | Afirmación en Sección 0 (.8) | Evidencia Real en DB (.9) | ¿Coincide la Sección 0 con la Realidad? | Observaciones |
|---|------------------------------|----------------------------|-----------------------------------------|---------------|
| 1 | **§0.3 #1:** El SDD exige `rpc_procesar_venta_v3`, pero en la BD real solo existe `v2` (`rpc_procesar_venta_v2`). | `pg_proc` para `sales`, `sale_items`, `cash_movements` incluye `rpc_procesar_venta_v2`. **`rpc_procesar_venta_v3` NO aparece en `pg_proc`**. | **Sí** (Coincide 100%) | La Sección 0 declaró con exactitud que v3 no existe en la BD física y que la BD real sigue en v2. |
| 2 | **§0.2 #8:** Usa `caja_diaria` y `daily_cash_movements` como alucinaciones de nombres de tabla; debe unificarse a `cash_movements`. | `pg_trigger` para `caja_diaria` y `daily_cash_movements` arrojó `ERROR 42P01` (tablas inexistentes). `cash_movements` **SÍ existe** y es referenciada por `cerrar_caja`, `rpc_procesar_venta_v2`, etc. | **Sí** (Coincide 100%) | Se confirmó que las dos tablas alucinadas efectivamente no existen en Postgres y que la tabla real es `cash_movements`. |
| 3 | **§0.1:** Motor POS llama a `consume_stock_fifo` y desglosa en `sale_item_batches`. | `pg_proc` para `inventory_batches` incluye `consume_stock_fifo`. `sale_item_batches` existe y es referenciada por `rpc_procesar_venta_v2`. | **Sí** (Coincide 100%) | La función `consume_stock_fifo` y la tabla `sale_item_batches` existen físicamente en la BD. |
| 4 | **§0.2 #6:** `inventory_movements` usa `movement_type = 'venta'` que está exento de trigger `bridge_movement_to_batch`. | `pg_trigger` para `inventory_movements` confirma la existencia física del trigger `trg_bridge_movement_to_batch`. | **Sí** (Coincide 100%) | El trigger `trg_bridge_movement_to_batch` existe físicamente en la tabla `inventory_movements`. |
| 5 | **§0.3 #3:** `payment_method_id` hacia `payment_methods`. | `payment_methods` existe en la BD (referenciada en `pg_proc` por `rpc_get_system_config`). | **Sí** (Coincide 100%) | La tabla `payment_methods` existe en la BD pero no está vinculada aún al RPC v2 actual. |

---

#### SDD_007_01.11 — CHECKPOINT BLOQUE 3
> **Estado:** Bloque 3 completo.

---

### Bloque 4 — Ciclo de Vida vs. Modelo de Datos

#### SDD_007_01.12 — Lista Textual de Transiciones del Diagrama de Estados (Sección 2)
Cita literal extraída del diagrama de estados `stateDiagram-v2` del SDD:

1. `[*] --> CarritoVacio`: "Cajero entra al POS"
2. `CarritoVacio --> AgregandoItems`: "Escanea/Selecciona Producto"
3. `AgregandoItems --> AgregandoItems`: "Ajusta Cantidad / Elimina Item"
4. `AgregandoItems --> SeleccionandoCierre`: "Click en 'Cobrar'"
5. `SeleccionandoCierre --> AgregandoItems`: "Cancela o vuelve atrás"
6. `SeleccionandoCierre --> Procesando`: "Confirma Método (Venta, Fiado, Merma, Devolución...)"
7. `Procesando --> VentaExitosa`: "Supabase responde HTTP 200 OK"
8. `Procesando --> ErrorLogica`: "Supabase responde HTTP 400 (Ej. Stock Insuficiente, Sesión Expirada)"
9. `ErrorLogica --> SeleccionandoCierre`: "Cajero lee el error (Toast) y corrige"
10. `VentaExitosa --> [*]`: "Imprime ticket y limpia UI"

---

#### SDD_007_01.13 — Lista Textual de Campos del Modelo de Datos y Payloads (Secciones 5 y 7)

##### A. Payload de Entrada (Sección 5.1):
- `idempotency_key` (UUID, Obligatorio)
- `closure_type` (Enum, Obligatorio)
- `payment_method_id` (FK, Condicional)
- `client_id` (UUID, Condicional)
- `supplier_id` (UUID, Condicional)
- `reference_invoice_id` (UUID, Opcional)
- `cart_items` (Arreglo, Obligatorio):
  - `product_id` (UUID, Obligatorio)
  - `quantity` (Numeric, Obligatorio)
  - `original_sale_item_id` (UUID, Condicional)

##### B. Payload de Salida (Sección 5.2):
- `success` (Boolean, Obligatorio)
- `data` (Objeto, Obligatorio):
  - `sale_id` (UUID, Obligatorio)
  - `created_at` (Timestamp, Obligatorio)
  - `total_charged` (Numeric, Obligatorio)
  - `items` (Arreglo, Obligatorio):
    - `product_id` (UUID, Obligatorio)
    - `quantity` (Numeric, Obligatorio)
    - `unit_price` (Numeric, Obligatorio)

##### C. Entidades Persistentes en BD (Sección 7):
- `sales`: `sale_id`, `created_at`, `total_charged`, `closure_type`, `payment_method_id`, `client_id`, `idempotency_key`
- `sale_items`: `sale_id`, `product_id`, `quantity`, `unit_price`, `unit_cost`
- `sale_item_batches`: `sale_item_id`, `batch_id`, `quantity`
- `inventory_batches`: `batch_id`, `product_id`, `stock_quantity`, `unit_cost`
- `inventory_movements`: `movement_id`, `product_id`, `quantity`, `movement_type`
- `cash_movements`: `movement_id`, `amount`, `payment_method_id`, `session_id`

---

#### SDD_007_01.14 — Cruce Explícito: Transiciones (.12) vs. Campos de Soporte (.13)

| # | Transición (.12) | Campo(s) de Soporte en Modelo/Payload (.13) | ¿Tiene Soporte Completo? | Justificación del Soporte |
|---|------------------|---------------------------------------------|--------------------------|---------------------------|
| 1 | `[*] --> CarritoVacio` | Estado local en memoria (`Pinia Store`). | **Sí** | Estado inicial de UX sin necesidad de persistencia en BD. |
| 2 | `CarritoVacio --> AgregandoItems` | `cart_items.product_id`, `cart_items.quantity` | **Sí** | Estructura definida en payload de entrada (§5.1). |
| 3 | `AgregandoItems --> AgregandoItems` | `cart_items.quantity` | **Sí** | Modificación de cantidad en arreglo del carrito (§5.1). |
| 4 | `AgregandoItems --> SeleccionandoCierre` | `closure_type`, `payment_method_id`, `client_id`, `supplier_id` | **Sí** | Campos condicionales del payload (§5.1). |
| 5 | `SeleccionandoCierre --> AgregandoItems` | Control de flujo en UI. | **Sí** | Transición de navegación en cliente. |
| 6 | `SeleccionandoCierre --> Procesando` | `rpc_procesar_venta_v3` + `idempotency_key` | **Sí** | Envío atómico de request (§5.1) con bandera `disabled=true` en UI. |
| 7 | `Procesando --> VentaExitosa` | BD: `sales.sale_id`, `sales.idempotency_key`, `sales.total_charged`, `sale_items.unit_price`, `sale_item_batches`, `inventory_movements`, `cash_movements`. Payload Salida: `success: true`, `data`. | **Sí** | Persistencia atómica completa en BD (§7) y retorno de ticket (§5.2). |
| 8 | `Procesando --> ErrorLogica` | `inventory_batches.stock_quantity`, `clients.credit_limit`, `session_id`. Códigos: `SESSION_INVALID`, `STOCK_INSUFFICIENT`, `CREDIT_LIMIT_EXCEEDED`, `MISSING_CLIENT`. | **Sí** | Precondiciones de BD respaldadas en catálogo de errores (§5.3) que provocan Rollback. |
| 9 | `ErrorLogica --> SeleccionandoCierre` | Campo `code` del error de respuesta. | **Sí** | Mapeado a Toast descriptivo en UI (§5.3). |
| 10 | `VentaExitosa --> [*]` | Payload Salida: `data.sale_id`, `data.items`. | **Sí** | Datos retornados oficializan la impresión del ticket y resetean el carrito (§5.2). |

---

#### SDD_007_01.15 — CHECKPOINT BLOQUE 4
> **Estado:** Bloque 4 completo.

---

### Bloque 5 — Seguridad

#### SDD_007_01.16 — Cita Textual de Control de Acceso (Sección 6.1)
Cita literal extraída de la sección 6.1 del SDD:

- "La función de procesamiento (`rpc_procesar_venta_v3`) exige un JWT válido (usuario autenticado)."
- "**Validación de Propiedad:** El sistema DEBE llamar explícitamente a `assert_store_access()` y usar `get_current_store_id()` para verificar que el `session_id` proporcionado pertenezca a la tienda del usuario actual. No se asume contexto implícito (Mitigación BUG-001)."

#### SDD_007_01.17 — Verificación de Nomenclatura Centralizada
¿Aparece nombrada textualmente la función `assert_store_access` o `get_current_store_id`?
- **SÍ**. Ambas funciones (`assert_store_access()` y `get_current_store_id()`) están explícitamente citadas en el texto de la Sección 6.1, cumpliendo con la Regla 4 de AGENTS.md (Reutilización Obligatoria de Funciones de Seguridad Centralizadas).

---

#### SDD_007_01.18 — CHECKPOINT BLOQUE 5
> **Estado:** Bloque 5 completo.

---

### Bloque 6 — Canal de Pago

#### SDD_007_01.19 — ¿Mueve Dinero? (Cita Textual)
¿El diseño funcional implica un movimiento real de dinero que altere el flujo de caja?
- **SÍ**.
- **Cita textual (Sección 0.1):** "Prohibido usar saldos globales. Todo movimiento debe especificar `payment_method_id` hacia `cash_movements`. El POS no puede inyectar efectivo en caja sin declarar explícitamente el canal de pago en el payload."

#### SDD_007_01.20 — Verificación de `payment_method_id` en el Contrato RPC
Al mover dinero, ¿se exige un canal de pago tipificado?
- **SÍ**.
- **Cita textual (Sección 5.1 - Payload de Entrada):** "`payment_method_id`: Obligatorio si `closure_type IN ('venta', 'devolucion_cliente')`. FK a `payment_methods` (Efectivo, Nequi, Daviplata...)."

---

#### SDD_007_01.21 — CHECKPOINT BLOQUE 6
> **Estado:** Bloque 6 completo.

---

## Fase B — Veredicto Final

### SDD_007_01.22 — Compilación de Veredicto (Regla 9.1 Aplicada)

#### Auto-chequeo Pre-veredicto (Regla 9.4)

**9.1 — Conteo de hallazgos negativos de Fase A (N):**
Inventario mecánico de hallazgos negativos (discrepancias, ausencias, contradicciones):

| ID | Hallazgo | Paso Fuente |
|----|----------|-------------|
| H-1 | `rpc_procesar_venta_v3` declarado en §5 pero físicamente NO existe en DB (`pg_proc` solo contiene `rpc_procesar_venta_v2`). | `.4` (pg_proc sales/sale_items/cash_movements) |
| H-2 | `idempotency_key` declarado como columna `UNIQUE` en §5.1 y §6.3 pero NO existe en la tabla física `sales`. | `.4` (pg_proc + ausencia confirmada en Bloque 2) |
| H-3 | `caja_diaria` y `daily_cash_movements` citadas en el cuerpo del SDD (Sección 3) pero NO existen en BD: error `42P01` en ambos `::regclass`. | `.6` (pg_trigger) |
| H-4 | `payment_method_id` declarado como FK a `payment_methods` en §5.1, pero la tabla física `sales` usa `TEXT+CHECK enum`, sin FK real. | `.4` + `.10` (Bloque 2 + Bloque 3) |

**N = 4**

**9.2 — Verificación de No-Fusión de Dimensiones:**
Los hallazgos positivos encontrados (existencia física de `sales`, `sale_items`, `sale_item_batches`, `inventory_batches`, `inventory_movements`, `cash_movements`, `payment_methods`; nomenclatura de seguridad correcta en §6.1; soporte completo de ciclo de vida) son propiedades de dimensiones distintas y NO mitigan ni anulan los hallazgos negativos H-1 a H-4. Se registran como evidencia separada.

**9.3 — Prohibición de Citar Fuente Auditada Como Evidencia:**
Los hallazgos H-1, H-2, H-3 y H-4 fueron verificados mediante consultas propias a `pg_proc` y `pg_trigger` en el proyecto activo `ihtjocmhzuliwwvdzfnz`, y no se basan en las afirmaciones del propio SDD. El SDD auto-documenta estos mismos hallazgos como Deuda Técnica en §0.3, pero eso es material auditado, no evidencia verificada.

---

#### Tabla de Clasificación de Hallazgos (Regla 9.1 — 4 referencias explícitas)

> **CORRECCIÓN DE PROTOCOLO (2026-08-08):** La clasificación original usó categorías inventadas ("Deuda Técnica Documentada") en lugar de citar la definición literal del PEA-N. Además, violó la Regla 9.3 al usar la auto-declaración del §0.3 del SDD como evidencia para no disparar Halt. A continuación, la reclasificación usando exclusivamente la taxonomía real del PEA-N.

**Definiciones PEA-N citadas literalmente:**
- **H-1:** Dos filas del RVC se contradicen entre sí directamente.
- **H-2:** Vacío que involucra dinero real/permisos, sin resolución vía Jerarquía niveles 1-3.
- **H-3:** Un SDD nuevo obligaría a marcar 🟡 a 2+ SDDs ya 🟢.
- **H-4:** El FRD fuente mismo tiene contradicción interna.

| ID | Hallazgo | ¿Dispara Halt? | Clasificación PEA-N (con cita literal) | Acción requerida |
|----|----------|----------------|----------------------------------------|------------------|
| **F-1** | `rpc_procesar_venta_v3` ausente en DB. El SDD lo declara como contrato central (§5.1). | **🔴 SÍ — H-2** | La ausencia total de la función/RPC que el SDD declara como su contrato central constituye un "vacío que involucra dinero real" (el RPC procesa ventas) "sin resolución vía Jerarquía niveles 1-3" (no existe función análoga que lo supla; `v2` no acepta los mismos parámetros). | Migración SQL para crear `rpc_procesar_venta_v3`. Halt bloquea Fase C. |
| **F-2** | `idempotency_key` ausente en tabla `sales`. | **❌ NO** | Hallazgo normal. La columna es de soporte, no la función central. Resoluble por Jerarquía nivel 1 (¿hay patrón análogo en el RVC?). | Pendiente de Fase C tras resolución de Halt. |
| **F-3** | `caja_diaria` / `daily_cash_movements` no existen en BD. | **❌ NO** | Falso positivo textual. Las menciones están en §0.2 #8 como registro histórico; en las Secciones 3 y 7 actuales ya aparece correctamente `cash_movements`. | Ninguna. |
| **F-4** | `payment_method_id` es TEXT en BD, no FK real a `payment_methods`. | **❌ NO** | Hallazgo normal. El RVC ya tiene fila análoga (patrón `TEXT` + `CHECK` en vez de `ENUM`/FK es el estándar establecido del proyecto, confirmado en `supplier_invoices`). Resoluble por Jerarquía nivel 1. | Pendiente de Fase C tras resolución de Halt. |

---

### SDD_007_01.23 — CHECKPOINT FINAL — VEREDICTO PVS-A

#### Veredicto: 🔴 DETENIDO POR HALT [H-2]

**Justificación (N=4 hallazgos referenciados explícitamente):**

1. **F-1 (`rpc_procesar_venta_v3` ausente):** Halt H-2 activo. La definición literal de H-2 es: *"Vacío que involucra dinero real/permisos, sin resolución vía Jerarquía niveles 1-3."* El RPC central del POS no existe en la BD y no es resoluble mediante corrección documental.
2. **F-2 (`idempotency_key` ausente):** Hallazgo normal, resoluble por Jerarquía. No dispara Halt. Queda pendiente de Fase C.
3. **F-3 (`caja_diaria`/`daily_cash_movements`):** Falso positivo textual. El texto del SDD ya está corregido.
4. **F-4 (`payment_method_id` TEXT vs FK):** Hallazgo normal, resoluble por Jerarquía nivel 1 (patrón RVC análogo). No dispara Halt. Queda pendiente de Fase C.

**Clasificación Final:**
- **Halt activado:** ✅ SÍ — H-2 por F-1 (`rpc_procesar_venta_v3`).
- **Bifurcación §4.1:** → §6 Manejo de Halt. No se avanza a Fase C.
- **Impacto en cascada (H-3 retroactivo):** `SDD_007_02` fue procesado y cerrado apoyándose en este SDD. Al pasar de 🟠 a 🔴, se activa retroactivamente la definición de H-3 (*"un SDD obligaría a marcar 🟡 a 2+ SDDs ya 🟢"*).

> **Estado final del SDD_007_01:** 🔴 Detenido por Halt [H-2]. Pendiente: resolución del Halt con supervisión humana.

---

## Fase C — No Ejecutada (Halt Activo)

> [!CAUTION]
> **Fase C bloqueada por §6 del protocolo (Manejo de Halt).**
>
> El hallazgo F-1 disparó Halt H-2. Según §6:
> 1. El protocolo para **este SDD** queda detenido por completo.
> 2. **No se ejecuta Fase C para NINGÚN hallazgo** — incluyendo F-2 y F-4, que son resoluble por Jerarquía pero se resolverán en conjunto tras la resolución del Halt.
> 3. No se inicia el siguiente SDD hasta que el Halt quede resuelto con supervisión humana.
>
> **Nota de corrección de protocolo (2026-08-08):** La versión anterior de este documento ejecutó Fase C ("Cero líneas modificadas") a pesar de que debía estar bloqueada. Esto fue un error procedimental que ha sido corregido.

