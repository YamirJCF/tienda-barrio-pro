# ⚙️ Plan de Implementación: Fase 2 - Inteligencia de Negocio

**Referencia:** `ANALYSIS_PHASE2_LOGIC.md`
**Rama Base:** `main` (Post-Fase 1)
**Rama de Trabajo:** `feat/financial-logic-phase2`

---

## 1. Estrategia de Control de Versiones (Git)

```bash
# 1. Asegurar estado limpio y actualizado
git checkout main
git pull origin main

# 2. Crear rama de feature
git checkout -b feat/financial-logic-phase2
```

---

## 2. Paso 1: Creación de RPCs (SQL)

**Objetivo:** Implementar las 3 funciones de base de datos que alimentarán el dashboard.

**Archivo de Migración:** `supabase/migrations/20260215170000_financial_rpcs.sql`

```sql
BEGIN;

-- 1. get_financial_summary
-- Calcula: Ventas, Costos, Ganancia Neta, Margen, Desglose
CREATE OR REPLACE FUNCTION get_financial_summary(
    p_store_id UUID,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
-- ... (Lógica definida en ANALYSIS_PHASE2_LOGIC.md) ...
$$;

-- 2. get_top_selling_products
-- Ranking de productos por unidades y ganancia
CREATE OR REPLACE FUNCTION get_top_selling_products(
    p_store_id UUID,
    p_limit INTEGER DEFAULT 10,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    units_sold NUMERIC,
    revenue NUMERIC,
    profit NUMERIC,
    stock_remaining NUMERIC,
    stock_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
-- ... (Lógica definida en ANALYSIS_PHASE2_LOGIC.md) ...
$$;

-- 3. get_stagnant_products
-- Identifica inventario muerto (sin ventas en X días)
CREATE OR REPLACE FUNCTION get_stagnant_products(
    p_store_id UUID,
    p_days_threshold INTEGER DEFAULT 30
)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    last_sale_date DATE,
    days_stagnant INTEGER,
    stock_value NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
-- ... (Lógica definida en ANALYSIS_PHASE2_LOGIC.md) ...
$$;

COMMIT;
```

---

## 3. Paso 2: Scripts de Verificación (QA Automatizado)

Crearemos un test automatizado para verificar matemáticamente la lógica financiera.

**Archivo de Test:** `frontend/src/test/integration/phase2_financial_logic.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { supabase } from '../../lib/supabase';

describe('Fase 2: Lógica Financiera', () => {
    
    // 1. Verificar Cálculo de Ganancia
    it('Debe calcular ganancia correcta (Ventas - Costos)', async () => {
        // Ejecutar RPC
        const { data, error } = await supabase.rpc('get_financial_summary', {
            p_store_id: '...store_id...',
            p_start_date: '2026-01-01',
            p_end_date: '2026-12-31'
        });

        expect(error).toBeNull();
        expect(data.net_profit).toBe(data.total_sales - data.total_cost);
    });

    // 2. Verificar Top Ventas
    it('Debe retornar lista ordenada de productos', async () => {
        const { data, error } = await supabase.rpc('get_top_selling_products', {
            p_store_id: '...store_id...',
            p_limit: 5
        });

        expect(error).toBeNull();
        expect(data.length).toBeLessThanOrEqual(5);
        // Verificar orden descendente
        expect(Number(data[0].units_sold)).toBeGreaterThanOrEqual(Number(data[1].units_sold));
    });
});
```

---

## 4. Orden de Ejecución para Antigravity

1.  **Generar SQL:** Crear archivo de migración con los 3 RPCs.
2.  **Aplicar Migración:** Ejecutar vía MCP Supabase.
3.  **Smoke Test Manual:** Ejecutar `SELECT * FROM get_financial_summary(...)` para validar JSON structure.
4.  **Confirmar:** Si SQL no falla y tests pasan -> Merge a main.
