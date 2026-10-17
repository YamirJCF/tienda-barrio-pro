# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-018)

> **Componente Auditado:** `frontend/src/views/FinancialDashboardView.vue`, `frontend/src/views/DashboardView.vue` (y stores `frontend/src/stores/financial.ts` y `frontend/src/stores/sales.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_018_CONTROL_OPERACIONAL.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_018_CONTROL_OPERACIONAL.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Rutas Principales:**
  - `frontend/src/views/FinancialDashboardView.vue` (`/admin/financial-dashboard`)
  - `frontend/src/views/DashboardView.vue` (`/`)
- **Widgets y Subcomponentes:**
  - `frontend/src/components/reports/InventoryHealthWidget.vue`
  - `frontend/src/components/reports/ClientLedgerWidget.vue`
- **Stores:**
  - `frontend/src/stores/financial.ts`
  - `frontend/src/stores/sales.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contratos de Interfaz (JSON Schemas)

### 5.1 Endpoint de Reporte Consolidado: `rpc_get_comprehensive_financial_report`
- **Tipo de Operación:** Postgres RPC / Lectura Analítica (READ-ONLY)
- **Nivel de Seguridad:** `SECURITY DEFINER`
- **Rol Requerido:** Administrador / Dueño (`admin_profiles`)

#### 5.1.1 Parámetros de Entrada:
```json
{
  "p_store_id": "UUID (Obligatorio)",
  "p_start_date": "DATE (YYYY-MM-DD)",
  "p_end_date": "DATE (YYYY-MM-DD)",
  "p_employee_id": "UUID | null (Opcional, filtra solo Pilar 4)"
}
```

#### 5.1.2 Salida Exitosa (Estructura de 4 Pilares):
```json
{
  "period": { "start": "DATE", "end": "DATE" },
  "pilar_1_pnl": {
    "revenue": 1500000,
    "cogs": 900000,
    "gross_profit": 600000,
    "gross_margin_percentage": 40.0,
    "operational_expenses": 150000,
    "net_profit": 450000,
    "opex_breakdown": { "servicios": 0, "arriendo": 0, "nomina": 0, "transporte": 0, "mantenimiento": 0, "merma": 0, "otros": 150000 }
  },
  "pilar_2_tesoreria_capital": {
    "payment_breakdown": { "cash": 800000, "transfer": 500000, "credit": 200000 },
    "accounts_receivable": { "total_balance": 450000, "aging_buckets": {}, "default_risk_index": 5.2 },
    "accounts_payable": { "total_pending": 300000, "calendar": {} }
  },
  "pilar_3_inventario_activos": {
    "inventory_valuation_fifo": 4200000,
    "dio": 14,
    "dio_status": "optimo",
    "stagnant_capital": { "total_dead_stock": 120000 }
  },
  "pilar_4_eficiencia_empleados": {
    "cashier_productivity": [],
    "average_ticket": 12500,
    "upt": 2.4,
    "cash_discrepancies": 0,
    "void_rate": 0.5
  },
  "semaforo_rendimiento": {
    "status": "green",
    "message": "🚀 ¡Vas un 12% arriba de tu promedio!"
  }
}
```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componentes identificados y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_get_comprehensive_financial_report`
- **Invocación RPC:**
  - Código real: En `financial.ts:159-163`, invoca `supabase.rpc('rpc_get_comprehensive_financial_report', { p_store_id, p_start_date, p_end_date })`.
  - Resultado: **Presente pero Parcial**. No envía el parámetro `p_employee_id`.
- **Estructura del Payload:**
  - Código real: En `financial.ts:8-20`, la interfaz `FinancialReportPayload` espera un payload plano legacy (`revenue`, `cogs`, `gross_profit`, `gross_margin`, `operational_expenses`, `net_profit`, `inventory_value`, `payment_breakdown`, `fiado_pendiente`, `traffic_light`), y fuerza llamadas adicionales paralelas a `get_inventory_health`, `get_client_ledger_summary` y `get_stagnant_products`.
  - Resultado: **Discrepancia**.

---

## Bloque 2b — Verificación de Límites Financieros y Lógica de Negocio

- **Prohibición de Cálculo Financiero en Cliente (`POL-DATA-01` y Regla Global 2.1):**
  - En `FinancialDashboardView.vue`, los valores de P&L provienen del RPC.
  - **Violación en `DashboardView.vue` y `salesStore.ts`:** En `DashboardView.vue:80-82`, las tarjetas principales de la pantalla de inicio consumen `salesStore.currentCash`, `salesStore.todayTotal` y `salesStore.todayFiado`. En `salesStore.ts:55-95`, estos valores se calculan sumando con `Decimal.js` en memoria los arreglos de ventas locales (`todaySales.value.reduce(...)`).
- **Moneda Entera sin Decimales (`SPEC-011`):**
  - En `FinancialDashboardView.vue:185, 193, 199, 207, 234`, utiliza `formatCurrency(...)` respetando el formato entero sin decimales.
- **Segregación OPEX vs Pagos a Proveedores:**
  - Garantizada a nivel de backend en el RPC.

---

## Bloque 3 — Verificación de Manejo de Errores

| Código de Error SDD | Estado en Código Actual | Tratamiento en UI | Conforme |
|---|---|---|---|
| `UNAUTHORIZED_ROLE` (403) | No capturado específicamente | Mensaje genérico en `store.error`: "Error al cargar los datos financieros..." | ❌ No |
| `STORE_ACCESS_DENIED` | Capturado genéricamente | Banner de error con botón "Reintentar" | 🟡 Parcial |
| `INVALID_DATE_RANGE` | No validado en cliente | Falla en llamada si el usuario invierte fechas | ❌ No |
| `RANGE_EXCEEDS_MAX_LIMIT` | No validado en cliente | Manejado como error genérico | ❌ No |

---

## Bloque 4 — Verificación de Estados de Carga e Interacción

- **Skeletons / Loading State:** `FinancialDashboardView.vue:123-132` implementa skeletons completos para todas las tarjetas durante `isLoadingTimeSeries`.
- **Bloqueo de Interacción:** Las pestañas de período cambian reactivamente y disparan loading protegiendo contra doble petición.

---

## Bloque 5 — Resumen de Discrepancias y Plan de Acción

### 5.1 Conteo Mecánico de Hallazgos (Regla 9.1: N = 4)
- **UX-1 (Severidad Alta):** Cálculo de agregaciones financieras en el cliente en `DashboardView.vue`. Las tarjetas principales del home (`formattedTodayTotal`, `formattedTodayFiado`, `formattedCash`) consumen getters de `salesStore.ts:55-95` (`todayTotal`, `todayFiado`, `currentCash`) que reducen en memoria el array local `todaySales.value` usando `Decimal.js`, violando la regla de Backend Authority (`POL-DATA-01` y Regla Global 2.1). Deben alimentarse de `get_daily_summary`.
- **UX-2 (Severidad Alta):** Fragmentación de llamadas y desalineación con el contrato de 4 Pilares de `SDD_018`. En `financial.ts:142-146`, el cliente ejecuta llamadas dispersas (`fetchInventoryHealth`, `fetchClientLedgerSummary`, `fetchStagnantProducts`) mediante `Promise.allSettled` porque `FinancialReportPayload` (`financial.ts:8-20`) está atado al payload plano legacy, en lugar de consumir el contrato canónico modular estructurado en los 4 Pilares (`pilar_1_pnl`, `pilar_2_tesoreria_capital`, `pilar_3_inventario_activos`, `pilar_4_eficiencia_empleados`).
- **UX-3 (Severidad Media):** Ausencia de selector de empleado (`p_employee_id`) en `FinancialDashboardView.vue`. El componente carece de interfaz para filtrar el Pilar 4 por colaborador individual (`CA-018-07` y `H17`), enviando siempre `p_employee_id = null` implícito.
- **UX-4 (Severidad Media):** Manejo de error genérico ante excepción `UNAUTHORIZED_ROLE`. Si un cajero intenta acceder a `/admin/financial-dashboard`, la respuesta del backend (`RAISE EXCEPTION 'UNAUTHORIZED_ROLE'`) se captura genéricamente en `financial.ts:206` como un fallo de red ("Error al cargar los datos financieros del periodo"), sin advertir que es una vista de acceso restringido para el Administrador (`POL-SEC-01`).

---

### 5.2 Auto-Chequeo Anti-Sesgo (Regla 9.4)
- **9.1 Invariante de Reconciliación:** $N = 4$ hallazgos documentados en el Bloque 5.1 y citados exactamente.
- **9.2 No-Fusión de Dimensiones:** La excelente presentación visual de Skeletons y gráficos no disculpa los cálculos en cliente de `salesStore.ts` ni la fragmentación de llamadas.
- **9.3 Cita de Fuentes:** Las discrepancias se sustentan en `DashboardView.vue:80-82`, `salesStore.ts:55-95`, `financial.ts:8-20, 142-146` y `FinancialDashboardView.vue`.
- **9.4 Veredicto:** 🟡 **CON OBSERVACIONES (4 discrepancias detectadas)**.

---

## 📌 Instrucción para el Orquestador (Etapa 4)

1. En `frontend/src/views/DashboardView.vue`:
   - Conectar las tarjetas de resumen diario (`formattedTodayTotal`, `formattedTodayFiado`, `formattedCash`) con `useReportsStore().summary` (`get_daily_summary`), eliminando la reducción manual de arreglos en `salesStore.ts`.
2. En `frontend/src/stores/financial.ts`:
   - Actualizar las interfaces tipadas a la estructura canónica de 4 Pilares de `SDD_018`.
   - Reemplazar las 4 llamadas separadas de `Promise.allSettled` por el consumo unificado de `rpc_get_comprehensive_financial_report(p_store_id, p_start_date, p_end_date, p_employee_id)`.
3. En `frontend/src/views/FinancialDashboardView.vue`:
   - Añadir selector opcional de empleado para auditar métricas del Pilar 4.
   - Manejar explícitamente el error 403 `UNAUTHORIZED_ROLE` mostrando advertencia de acceso reservado para dueños.
