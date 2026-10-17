# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-008)

> **Componente Auditado:** `frontend/src/views/ReportsView.vue`, `frontend/src/components/SmartDailySummary.vue`, `frontend/src/components/reports/SmartSupplySection.vue`, `frontend/src/components/modals/BulkSupplierAssign.vue` (y stores `frontend/src/stores/reports.ts` y `frontend/src/stores/suppliers.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_008_REPORTES.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_008_REPORTES.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/ReportsView.vue` (registrada en `frontend/src/router/index.ts` bajo `/reports`)
- **Componentes de Visualización:**
  - `frontend/src/components/SmartDailySummary.vue` (Resumen diario y semáforo de desempeño)
  - `frontend/src/components/reports/SmartSupplySection.vue` (Sugerencias de compra e inventario blindado)
  - `frontend/src/components/modals/BulkSupplierAssign.vue` (Modal de asignación masiva de proveedor)
- **Stores:**
  - `frontend/src/stores/reports.ts`
  - `frontend/src/stores/suppliers.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.1 Resumen Diario Operativo: `get_daily_summary`
- **Parámetros de Entrada:**
  - `p_store_id` (`UUID`, obligatorio)
  - `p_date` (`DATE`, obligatorio)
- **Salida Exitosa (`JSONB`):**
  ```json
  {
    "traffic_light": {
      "status": "green",
      "message": "🚀 ¡Vas un 12% arriba de tu promedio!"
    },
    "hero_number": 450000,
    "money_breakdown": {
      "cash": 300000,
      "transfer": 100000,
      "credit": 50000
    },
    "alerts": [
      {
        "type": "stock_critical",
        "message": "⚠️ Bajo stock: Leche Entera 1L",
        "target_id": "uuid-producto",
        "stock": 3
      }
    ],
    "reminder": {
      "message": "Recuerda hacer el cierre de caja al final del turno."
    }
  }
  ```

### 5.2 Reporte de Abastecimiento Inteligente: `get_smart_supply_report`
- **Parámetros de Entrada:** `p_store_id` (`UUID`, obligatorio).
- **Salida Exitosa (`TABLE / SETOF RECORD`):**
  - `product_id` (`UUID`): Identificador del producto.
  - `product_name` (`TEXT`): Nombre comercial del producto.
  - `current_stock` (`NUMERIC`): Existencia física actual.
  - `velocity` (`NUMERIC`): Promedio de unidades vendidas por día en 30 días.
  - `doi` (`NUMERIC`): Días de autonomía estimados (`current_stock / velocity`).
  - `revenue_at_risk` (`NUMERIC`): Venta estimada en riesgo (entero COP).
  - `status` (`TEXT`): `'CRITICAL'`, `'WARNING'`, `'OK'`, `'LEARNING'` / `'UNKNOWN'`, `'REPRESSED'`.
  - `suggestion` (`TEXT`): Recomendación en lenguaje humano (`RN-008-01`).

### 5.3 Asignación Masiva de Proveedor: `rpc_asignar_proveedor_masivo`
- **Parámetros de Entrada:**
  - `p_store_id` (`UUID`, obligatorio)
  - `p_supplier_id` (`UUID`, obligatorio)
  - `p_product_ids` (`UUID[]`, obligatorio)
- **Salida Exitosa (`JSONB`):** `{ "success": true, "updated_count": 15 }`.
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componentes identificados y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `get_daily_summary`
- **Invocación RPC:**
  - Código real: En `reports.ts:75-76`, `supabase.rpc('get_daily_summary', params)` con `p_store_id` y `p_date`.
  - Resultado: **Presente y Conforme**.
- **Consumo de Campos (`traffic_light`, `hero_number`, `money_breakdown`, `alerts`):**
  - Código real: En `SmartDailySummary.vue`, se renderizan `hero_number`, `traffic_light.message`, `money_breakdown.cash`, `transfer`, `credit` sin cálculos de sumatoria en el cliente.
  - Resultado: **Presente y Conforme**.

### Operación: `get_smart_supply_report`
- **Invocación RPC:**
  - Código real: En `SmartSupplySection.vue:44-46`, `supabase.rpc('get_smart_supply_report', { p_store_id: storeId })`.
  - Resultado: **Presente y Conforme**.
- **Consumo de Campos (`status`, `suggestion`, `revenue_at_risk`):**
  - Código real: En `SmartSupplySection.vue:214-215` y `236-237`, el template ignora `item.suggestion` y usa strings fijos ("Se agotará antes de que llegue el proveedor").
  - Resultado: **Discrepancia**.

### Operación: `rpc_asignar_proveedor_masivo`
- **Invocación RPC:**
  - Código real: En `suppliers.ts:125-128`, `bulkAssignSupplier` ejecuta `.from('products').update({ supplier_id: supplierId }).in('id', productIds)` directo vía PostgREST, en lugar de llamar a `rpc_asignar_proveedor_masivo`.
  - Resultado: **Discrepancia Crítica**.

---

## Bloque 2b — Verificación de Límites Financieros y Lógica de Negocio

- **Moneda Entera sin Decimales (`SPEC-011`):**
  - En `SmartDailySummary.vue:96`, `formatCurrency(summary.hero_number).replace(',00', '')` formatea en pesos enteros.
- **Autoridad de Datos (Cálculos de Negocio):**
  - `hero_number`, `velocity` y `doi` vienen calculados desde PostgreSQL. El cliente solo calcula `totalRisk` como agregación visual sumando `item.revenue_at_risk`.
- **Lenguaje Humano (`RN-008-01`):**
  - El backend provee `traffic_light.message` y `suggestion`. Sin embargo, `SmartSupplySection.vue` no muestra la sugerencia dinámica del servidor sino textos hardcodeados.

---

## Bloque 3 — Verificación de Manejo de Errores

| Código de Error SDD | Estado en Código Actual | Tratamiento en UI | Conforme |
|---|---|---|---|
| `STORE_ACCESS_DENIED` | Capturado genéricamente | Muestra mensaje genérico "No pudimos cargar el resumen" | 🟡 Parcial |
| `UNAUTHORIZED_ROLE` | No capturado | Falla genérica en llamada | ❌ No |
| `SUPPLIER_NOT_FOUND` | No capturado | `alert(result.error)` en `BulkSupplierAssign.vue:87` | ❌ No |
| `EMPTY_PRODUCT_LIST` | Validado en store | `suppliers.ts:120`: retorna `{ success: false, error: 'No se seleccionaron productos' }` | ✅ Sí |

---

## Bloque 4 — Verificación de Estados de Carga e Interacción

- **Skeletons / Loading State:** `SmartDailySummary.vue:45-54` cuenta con skeleton pulsante y `SmartSupplySection.vue:111-114` implementa shimmer animado.
- **Bloqueo de Interacción:** `BulkSupplierAssign.vue` tiene `isLoading` y deshabilita acciones durante la asignación.

---

## Bloque 5 — Resumen de Discrepancias y Plan de Acción

### 5.1 Conteo Mecánico de Hallazgos (Regla 9.1: N = 4)
- **UX-1 (Severidad Alta):** Bypasseo de `rpc_asignar_proveedor_masivo`. En `frontend/src/stores/suppliers.ts:125-128`, `bulkAssignSupplier` ejecuta mutación directa con `supabase.from('products').update({ supplier_id, updated_at }).in('id', productIds)`, saltándose la validación `assert_store_access` en base de datos y la verificación administrativa en `admin_profiles` requerida por `SDD_008: 5.3`.
- **UX-2 (Severidad Media):** Sustitución de sugerencias del servidor por textos estáticos quemados. En `frontend/src/components/reports/SmartSupplySection.vue:214-215` y `236-237`, el template ignora `item.suggestion` (el mensaje conversacional generado en lenguaje humano por el backend según `RN-008-01`) y muestra textos estáticos ("Se agotará antes de que llegue el proveedor" e "Incluirlo en el próximo pedido al proveedor").
- **UX-3 (Severidad Media):** Omisión de renderizado para estados `LEARNING` y alerta azul `REPRESSED` (demanda reprimida por días saturados). En `SmartSupplySection.vue`, aunque calcula `isLearning` como condición agregada (`unknownItems.length === items.length`), si coexisten productos en `LEARNING` o en `REPRESSED` junto con críticos, no se renderizan en la lista de items ni se distingue visualmente el aprendizaje individual.
- **UX-4 (Severidad Baja):** Uso de `alert()` nativo en modal de asignación masiva. En `frontend/src/components/modals/BulkSupplierAssign.vue:87`, `alert(result.error || 'Error al asignar proveedor')` viola el estándar de UX de alertas y feedback visual con toasts no intrusivos.

---

### 5.2 Auto-Chequeo Anti-Sesgo (Regla 9.4)
- **9.1 Invariante de Reconciliación:** $N = 4$ hallazgos documentados en el Bloque 5.1 y citados exactamente.
- **9.2 No-Fusión de Dimensiones:** El correcto funcionamiento de `get_daily_summary` no atenúa la mutación directa en `suppliers.ts` ni el reemplazo de `item.suggestion`.
- **9.3 Cita de Fuentes:** Las discrepancias se sustentan en `suppliers.ts:125-128`, `SmartSupplySection.vue:214-215` y `BulkSupplierAssign.vue:87`.
- **9.4 Veredicto:** 🟡 **CON OBSERVACIONES (4 discrepancias detectadas)**.

---

## 📌 Instrucción para el Orquestador (Etapa 4)

1. En `frontend/src/stores/suppliers.ts`:
   - Modificar `bulkAssignSupplier` para invocar `supabase.rpc('rpc_asignar_proveedor_masivo', { p_store_id: storeId, p_supplier_id: supplierId, p_product_ids: productIds })`.
2. En `frontend/src/components/reports/SmartSupplySection.vue`:
   - Renderizar `item.suggestion` directamente en lugar de textos hardcodeados en las tarjetas de items críticos y de advertencia.
   - Añadir renderizado para items con estado `'REPRESSED'` (alerta azul de pérdida de venta) y `'LEARNING'` / `'UNKNOWN'` (badge gris de aprendizaje).
3. En `frontend/src/components/modals/BulkSupplierAssign.vue`:
   - Reemplazar `alert()` nativo por notificación toast amigable.
