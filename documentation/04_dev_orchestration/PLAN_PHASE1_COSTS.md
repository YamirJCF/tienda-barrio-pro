# ⚙️ Plan de Implementación: Fase 1 - Fundación de Costos

**Referencia:** `GAP_ANALYSIS_FRD_vs_CODE.md` | `DB_ALIGNMENT_PHASE1.md`
**Rama Base:** `main`
**Rama de Trabajo:** `feat/financial-core-phase1`

---

## 1. Estrategia de Control de Versiones (Git)

```bash
# 1. Asegurar estado limpio
git checkout main
git pull origin main

# 2. Crear rama de feature
git checkout -b feat/financial-core-phase1
```

---

## 2. Paso 1: Migración de Base de Datos (DDL)

**Objetivo:** Agregar columnas de costos sin romper la compatibilidad actual.

**Archivo de Migración:** `supabase/migrations/20260215160000_add_cost_columns.sql`

```sql
-- Detalle técnico en DB_ALIGNMENT_PHASE1.md
BEGIN;

ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS cost DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_purchase_price DECIMAL(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_purchase_date TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_products_cost ON public.products(cost);

ALTER TABLE public.sale_items 
ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0;

ALTER TABLE public.inventory_movements 
ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(12,2),
ADD COLUMN IF NOT EXISTS total_cost DECIMAL(12,2);

COMMIT;
```

---

## 3. Paso 2: Scripts de Verificación (QA Automatizado)

Para garantizar que la migración fue exitosa y **NO generó regresiones**, crearemos un test de integración en el frontend.

**Archivo de Test:** `frontend/src/test/integration/phase1_db_check.test.ts`

```typescript
import { describe, it, expect, beforeAll } from 'vitest';
import { supabase } from '../../lib/supabase'; // Asegurar ruta correcta a cliente real o mockeado para test e2e

describe('Fase 1: Verificación de Esquema de Costos', () => {
    
    // 1. Verificar que las columnas existen
    it('Debe permitir seleccionar la columna "cost" en inserts', async () => {
        const { data, error } = await supabase
            .from('products')
            .select('cost')
            .limit(1);
            
        // Si la columna no existe, Supabase devuelve error: "Could not find the 'cost' column..."
        expect(error).toBeNull();
    });

    // 2. Verificar Valor por Defecto (Crucial para NO romper flujo actual)
    it('Debe insertar producto con cost=0 por defecto si no se especifica', async () => {
        const mockProduct = {
            name: 'Test Product Phase 1',
            price: 1000,
            store_id: '...uuid-valido...', // Necesitarás un ID real o mockeado del entorno de test
            // NO enviamos 'cost'
        };

        const { data, error } = await supabase
            .from('products')
            .insert(mockProduct)
            .select()
            .single();

        expect(error).toBeNull();
        expect(data.cost).toBe(0); // El default funcionó
        
        // Limpieza
        if(data) await supabase.from('products').delete().eq('id', data.id);
    });

    // 3. Test de Regresión: RPC Venta
    it('RPC de venta debe funcionar sin enviar costos (Backward Compatibility)', async () => {
        // Ejecutar rpc_procesar_venta_v2 con payload viejo
        // Esperar éxito, no error de SQL "column unit_cost cannot be null"
        // Este test requiere un entorno con datos seed
    });
});
```

---

## 4. Paso 3: Migración de Datos (Estimación Inicial)

Una vez verificada la estructura, poblaremos los costos para que el dashboard no nazca muerto.

**Script SQL:** `scripts/backfill_estimated_costs.sql`

```sql
-- Asumimos margen del 30% para datos históricos
UPDATE public.products
SET cost = price * 0.70
WHERE cost = 0;

-- Propagamos a ventas históricas (para que reportes pasados funcionen)
UPDATE public.sale_items si
SET unit_cost = (SELECT cost FROM products WHERE id = si.product_id)
WHERE unit_cost = 0;
```

---

## 5. Orden de Ejecución para Antigravity

1.  **Crear Migración:** Generar archivo `.sql` en `supabase/migrations`.
2.  **Aplicar Migración:** Ejecutar comando backend (local o remoto).
3.  **Ejecutar Test:** Correr `npm test phase1` (o equivalente) para validar.
4.  **Confirmar:** Si Tests pasan ✅ -> Merge a main.
