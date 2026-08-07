### Bloque 1 — Identificación

- **SDD_007_01.1**: 
  - Cita literal del encabezado: `# SDD-007-01: Núcleo del Punto de Venta (POS) Desacoplado`
  - Ruta exacta: `C:\Users\Windows 11\OneDrive\Desktop\prueba\documentation\01_requirements\SDD\SDD_007_01_NUCLEO_POS.md`

- **SDD_007_01.2**: Tablas declaradas explícitamente en el diseño lógico (Sección 7) del documento:
  - `"El RPC descuenta directamente la cantidad de los lotes (inventory_batches) e inserta en sale_item_batches."` (Sección 7)
  - `"Se registra el identificador global de la venta (sales)."` (Sección 7)
  - `"Aquí el backend asienta el Precio Real de Venta y Costo Promedio consumido, congelándolos (sale_items)."` (Sección 7)
  - `"Se asienta la salida física (inventory_movements)."` (Sección 7)
  - `"Si la operación requiere un canal, se inserta el registro de ingreso/egreso en cash_movements."` (Sección 7)

**Ejecución de Regla 2 (AGENTS.md) - Verificación de Esquema Real (Supabase public schema):**
```sql
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name IN ('inventory_batches', 'sale_item_batches', 'sales', 'sale_items', 'inventory_movements', 'cash_movements')
AND table_schema = 'public';
```
*Resultado Crudo:*
```json
[{"table_name":"cash_movements","column_name":"id","data_type":"uuid"},{"table_name":"cash_movements","column_name":"session_id","data_type":"uuid"},{"table_name":"cash_movements","column_name":"movement_type","data_type":"text"},{"table_name":"cash_movements","column_name":"amount","data_type":"numeric"},{"table_name":"cash_movements","column_name":"description","data_type":"text"},{"table_name":"cash_movements","column_name":"sale_id","data_type":"uuid"},{"table_name":"cash_movements","column_name":"created_at","data_type":"timestamp with time zone"},{"table_name":"inventory_batches","column_name":"id","data_type":"uuid"},{"table_name":"inventory_batches","column_name":"product_id","data_type":"uuid"},{"table_name":"inventory_batches","column_name":"quantity_initial","data_type":"numeric"},{"table_name":"inventory_batches","column_name":"quantity_remaining","data_type":"numeric"},{"table_name":"inventory_batches","column_name":"cost_unit","data_type":"numeric"},{"table_name":"inventory_batches","column_name":"is_active","data_type":"boolean"},{"table_name":"inventory_batches","column_name":"created_at","data_type":"timestamp with time zone"},{"table_name":"inventory_batches","column_name":"created_by","data_type":"uuid"},{"table_name":"inventory_batches","column_name":"sale_price","data_type":"numeric"},{"table_name":"inventory_batches","column_name":"source_movement_id","data_type":"uuid"},{"table_name":"inventory_movements","column_name":"id","data_type":"uuid"},{"table_name":"inventory_movements","column_name":"product_id","data_type":"uuid"},{"table_name":"inventory_movements","column_name":"movement_type","data_type":"text"},{"table_name":"inventory_movements","column_name":"quantity","data_type":"numeric"},{"table_name":"inventory_movements","column_name":"reason","data_type":"text"},{"table_name":"inventory_movements","column_name":"created_by","data_type":"uuid"},{"table_name":"inventory_movements","column_name":"created_at","data_type":"timestamp with time zone"},{"table_name":"inventory_movements","column_name":"supplier_id","data_type":"uuid"},{"table_name":"inventory_movements","column_name":"invoice_reference","data_type":"text"},{"table_name":"inventory_movements","column_name":"payment_type","data_type":"text"},{"table_name":"inventory_movements","column_name":"reference_invoice_id","data_type":"uuid"},{"table_name":"inventory_movements","column_name":"unit_cost","data_type":"numeric"},{"table_name":"sale_item_batches","column_name":"id","data_type":"uuid"},{"table_name":"sale_item_batches","column_name":"sale_item_id","data_type":"uuid"},{"table_name":"sale_item_batches","column_name":"batch_id","data_type":"uuid"},{"table_name":"sale_item_batches","column_name":"quantity_consumed","data_type":"numeric"},{"table_name":"sale_item_batches","column_name":"unit_cost","data_type":"numeric"},{"table_name":"sale_item_batches","column_name":"unit_price","data_type":"numeric"},{"table_name":"sale_item_batches","column_name":"created_at","data_type":"timestamp with time zone"},{"table_name":"sale_items","column_name":"id","data_type":"uuid"},{"table_name":"sale_items","column_name":"sale_id","data_type":"uuid"},{"table_name":"sale_items","column_name":"product_id","data_type":"uuid"},{"table_name":"sale_items","column_name":"quantity","data_type":"numeric"},{"table_name":"sale_items","column_name":"unit_price","data_type":"numeric"},{"table_name":"sale_items","column_name":"subtotal","data_type":"numeric"},{"table_name":"sale_items","column_name":"created_at","data_type":"timestamp with time zone"},{"table_name":"sale_items","column_name":"unit_cost","data_type":"numeric"},{"table_name":"sales","column_name":"id","data_type":"uuid"},{"table_name":"sales","column_name":"store_id","data_type":"uuid"},{"table_name":"sales","column_name":"ticket_number","data_type":"integer"},{"table_name":"sales","column_name":"employee_id","data_type":"uuid"},{"table_name":"sales","column_name":"client_id","data_type":"uuid"},{"table_name":"sales","column_name":"total","data_type":"numeric"},{"table_name":"sales","column_name":"rounding_difference","data_type":"numeric"},{"table_name":"sales","column_name":"payment_method","data_type":"text"},{"table_name":"sales","column_name":"amount_received","data_type":"numeric"},{"table_name":"sales","column_name":"change_given","data_type":"numeric"},{"table_name":"sales","column_name":"sync_status","data_type":"text"},{"table_name":"sales","column_name":"local_id","data_type":"text"},{"table_name":"sales","column_name":"is_voided","data_type":"boolean"},{"table_name":"sales","column_name":"voided_by","data_type":"uuid"},{"table_name":"sales","column_name":"void_reason","data_type":"text"},{"table_name":"sales","column_name":"created_at","data_type":"timestamp with time zone"}]
```

- **SDD_007_01.3**: **CHECKPOINT.**
  - Tablas únicas verificadas en esquema real: `inventory_batches`, `sale_item_batches`, `sales`, `sale_items`, `inventory_movements`, `cash_movements`.

> **Auto-Chequeo (Regla 9.4):**
> 1. (9.1) Conteo: N=0 hallazgos (fase de recolección).
> 2. (9.2) No-Fusión: N/A.
> 3. (9.3) Fuente vs Evidencia: Cumplido. Toda tabla listada fue comprobada ejecutando una consulta a la base de datos real (Supabase, proyecto `ihtjocmhzuliwwvdzfnz`) mediante `execute_sql` (cumpliendo Regla 2). Ningún nombre se asumió basándose únicamente en las declaraciones del SDD. No se leyó la Sección 0 para evitar tomar auditorías previas como verdad.

### Bloque 2 — Verificación Mecánica (Tabla 1: `inventory_batches`)

- **SDD_007_01.4**: Funciones que referencian `inventory_batches` en el esquema real:
```sql
SELECT proname FROM pg_proc WHERE prosrc ILIKE '%inventory_batches%';
```
*Resultado Crudo:*
```json
[{"proname":"rpc_get_comprehensive_financial_report"},{"proname":"sync_product_stock_from_batches"},{"proname":"consume_stock_fifo"},{"proname":"rpc_actualizar_precio_lote"},{"proname":"rpc_actualizar_precio_lote"},{"proname":"rpc_registrar_entrada"},{"proname":"bridge_movement_to_batch"}]
```

- **SDD_007_01.5**: **CHECKPOINT.** (Tabla 1: `inventory_batches` - Funciones)

- **SDD_007_01.6**: Triggers asociados a `inventory_batches` en el esquema real:
```sql
SELECT tgname FROM pg_trigger WHERE tgrelid = 'inventory_batches'::regclass;
```
*Resultado Crudo:*
```json
[{"tgname":"RI_ConstraintTrigger_a_77245"},{"tgname":"RI_ConstraintTrigger_a_77246"},{"tgname":"RI_ConstraintTrigger_a_77475"},{"tgname":"RI_ConstraintTrigger_a_77476"},{"tgname":"RI_ConstraintTrigger_c_77130"},{"tgname":"RI_ConstraintTrigger_c_77131"},{"tgname":"RI_ConstraintTrigger_c_77135"},{"tgname":"RI_ConstraintTrigger_c_77136"},{"tgname":"RI_ConstraintTrigger_c_77454"},{"tgname":"RI_ConstraintTrigger_c_77455"},{"tgname":"trg_sync_batches"}]
```

- **SDD_007_01.7**: **CHECKPOINT.** (Tabla 1: `inventory_batches` - Triggers)

### Bloque 2 — Verificación Mecánica (Tabla 2: `sale_item_batches`)

- **SDD_007_01.4**: Funciones que referencian `sale_item_batches` en el esquema real:
```sql
SELECT proname FROM pg_proc WHERE prosrc ILIKE '%sale_item_batches%';
```
*Resultado Crudo:*
```json
[{"proname":"rpc_get_comprehensive_financial_report"},{"proname":"rpc_procesar_venta_v2"}]
```

- **SDD_007_01.5**: **CHECKPOINT.** (Tabla 2: `sale_item_batches` - Funciones)

- **SDD_007_01.6**: Triggers asociados a `sale_item_batches` en el esquema real:
```sql
SELECT tgname FROM pg_trigger WHERE tgrelid = 'sale_item_batches'::regclass;
```
*Resultado Crudo:*
```json
[{"tgname":"RI_ConstraintTrigger_c_77242"},{"tgname":"RI_ConstraintTrigger_c_77243"},{"tgname":"RI_ConstraintTrigger_c_77247"},{"tgname":"RI_ConstraintTrigger_c_77248"}]
```

- **SDD_007_01.7**: **CHECKPOINT.** (Tabla 2: `sale_item_batches` - Triggers)

### Bloque 2 — Verificación Mecánica (Tabla 3: `sales`)

- **SDD_007_01.4**: Funciones que referencian `sales` en el esquema real:
```sql
SELECT proname FROM pg_proc WHERE prosrc ILIKE '%sales%';
```
*Resultado Crudo:*
```json
[{"proname":"rpc_get_comprehensive_financial_report"},{"proname":"procesar_venta"},{"proname":"rpc_anular_venta"},{"proname":"get_top_selling_products"},{"proname":"get_stagnant_products"},{"proname":"get_daily_summary"},{"proname":"get_smart_supply_report"},{"proname":"get_history_ventas"},{"proname":"get_top_products_by_units"},{"proname":"get_inventory_health"},{"proname":"rpc_procesar_venta_v2"},{"proname":"get_sale_detail"}]
```

- **SDD_007_01.5**: **CHECKPOINT.** (Tabla 3: `sales` - Funciones)

- **SDD_007_01.6**: Triggers asociados a `sales` en el esquema real:
```sql
SELECT tgname FROM pg_trigger WHERE tgrelid = 'sales'::regclass;
```
*Resultado Crudo:*
```json
[{"tgname":"RI_ConstraintTrigger_a_33455"},{"tgname":"RI_ConstraintTrigger_a_33456"},{"tgname":"RI_ConstraintTrigger_a_33617"},{"tgname":"RI_ConstraintTrigger_a_33618"},{"tgname":"RI_ConstraintTrigger_a_76972"},{"tgname":"RI_ConstraintTrigger_a_76973"},{"tgname":"RI_ConstraintTrigger_c_33430"},{"tgname":"RI_ConstraintTrigger_c_33431"},{"tgname":"RI_ConstraintTrigger_c_33435"},{"tgname":"RI_ConstraintTrigger_c_33436"},{"tgname":"RI_ConstraintTrigger_c_33440"},{"tgname":"RI_ConstraintTrigger_c_33441"},{"tgname":"trg_audit_sale_created"},{"tgname":"trg_audit_sale_voided"}]
```

- **SDD_007_01.7**: **CHECKPOINT.** (Tabla 3: `sales` - Triggers)

### Bloque 2 — Verificación Mecánica (Tabla 4: `sale_items`)

- **SDD_007_01.4**: Funciones que referencian `sale_items` en el esquema real:
```sql
SELECT proname FROM pg_proc WHERE prosrc ILIKE '%sale_items%';
```
*Resultado Crudo:*
```json
[{"proname":"rpc_get_comprehensive_financial_report"},{"proname":"procesar_venta"},{"proname":"rpc_anular_venta"},{"proname":"get_top_selling_products"},{"proname":"get_stagnant_products"},{"proname":"get_smart_supply_report"},{"proname":"get_history_ventas"},{"proname":"get_top_products_by_units"},{"proname":"get_inventory_health"},{"proname":"rpc_procesar_venta_v2"},{"proname":"get_sale_detail"}]
```

- **SDD_007_01.5**: **CHECKPOINT.** (Tabla 4: `sale_items` - Funciones)

- **SDD_007_01.6**: Triggers asociados a `sale_items` en el esquema real:
```sql
SELECT tgname FROM pg_trigger WHERE tgrelid = 'sale_items'::regclass;
```
*Resultado Crudo:*
```json
[{"tgname":"RI_ConstraintTrigger_a_77240"},{"tgname":"RI_ConstraintTrigger_a_77241"},{"tgname":"RI_ConstraintTrigger_c_33457"},{"tgname":"RI_ConstraintTrigger_c_33458"},{"tgname":"RI_ConstraintTrigger_c_33462"},{"tgname":"RI_ConstraintTrigger_c_33463"}]
```

- **SDD_007_01.7**: **CHECKPOINT.** (Tabla 4: `sale_items` - Triggers)

### Bloque 2 — Verificación Mecánica (Tabla 5: `inventory_movements`)

- **SDD_007_01.4**: Funciones que referencian `inventory_movements` en el esquema real:
```sql
SELECT proname FROM pg_proc WHERE prosrc ILIKE '%inventory_movements%';
```
*Resultado Crudo:*
```json
[{"proname":"procesar_venta"},{"proname":"rpc_anular_venta"},{"proname":"get_history_compras"},{"proname":"get_top_products_by_units"},{"proname":"rpc_procesar_venta_v2"},{"proname":"rpc_force_sale"},{"proname":"rpc_registrar_entrada"},{"proname":"rpc_registrar_entrada"},{"proname":"rpc_registrar_movimiento_inventario"},{"proname":"rpc_soft_delete_product"},{"proname":"bridge_movement_to_batch"}]
```

- **SDD_007_01.5**: **CHECKPOINT.** (Tabla 5: `inventory_movements` - Funciones)
