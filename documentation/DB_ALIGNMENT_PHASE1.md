# 🛡️ Informe Técnico de Base de Datos: Validación Fase 1

**Para:** Arquitecto de Producto (@[/architect])
**De:** Arquitecto de Datos (@[/data])
**Fecha:** 15 de Febrero, 2026
**Asunto:** Validación de Impacto y Alineación de Esquema - Fase 1 (Costos)

---

## 1. Resumen de Análisis

He revisado la estructura actual de la base de datos y los procedimientos almacenados críticos (`rpc_procesar_venta_v2`, `get_daily_summary`, `get_smart_supply_report`) contra los requisitos de la Fase 1 del FRD.

**Conclusión:** ✅ **ALINEACIÓN CORRECTA Y SEGURA**

La implementación propuesta en el FRD es **no disruptiva** y compatible con la arquitectura actual, siempre que se respeten estrictamente los valores por defecto (`DEFAULT 0`).

---

## 2. Validación de Impacto (Breaking Changes Analysis)

### 2.1. Tablas (`products`, `sale_items`, `inventory_movements`)
La adición de columnas es segura debido a las siguientes condiciones:
*   **Inserciones Explícitas:** El código actual en `financial_core.sql` (líneas 250, 254) utiliza `INSERT INTO table (col1, col2...) VALUES ...`. Al agregar nuevas columnas con valor por defecto, estas sentencias SQL existentes **NO fallarán**.
*   **Lecturas Robustas:** Las RPCs de lectura (`get_smart_supply_report`) seleccionan columnas específicas, no `SELECT *`. La adición de campos no afectará los payloads de retorno actuales hasta que se modifiquen explícitamente.

**⚠️ Punto Crítico de Control:**
Es imperativo que todas las columnas numéricas nuevas (`cost`, `unit_cost`, `total_cost`) se definan como:
`DECIMAL(10,2) NOT NULL DEFAULT 0`
Si se omite el `DEFAULT 0`, **se romperá el flujo de venta actual** inmediatamente tras la migración.

### 2.2. RPCs Criticas
*   **`rpc_procesar_venta_v2`:** Debe ser actualizada en la Fase 1 para *poblar* las nuevas columnas, pero su versión actual seguirá funcionando sin errores en una base de datos migrada (rellenará con `0` temporalmente).

---

## 3. Modelo de Datos Recomendado (Definición Técnica)

A continuación, la traducción técnica exacta para ejecutar la Fase 1 sin errores.

### 3.1. Script de Migración Seguro (DDL)

```sql
BEGIN;

-- 1. Tabla PRODUCTS
-- Agregamos rastreo de costo promedio y última compra
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS cost DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_purchase_price DECIMAL(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_purchase_date TIMESTAMPTZ;

-- Indices para reportes rápidos de margen
CREATE INDEX IF NOT EXISTS idx_products_cost ON public.products(cost);

-- 2. Tabla SALE_ITEMS
-- Snapshot del costo al momento de la venta (Glory Data)
ALTER TABLE public.sale_items 
ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0;

-- 3. Tabla INVENTORY_MOVEMENTS
-- Valoración de entradas y salidas
ALTER TABLE public.inventory_movements 
ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(12,2), -- Puede ser NULL en ajustes de cantidad sin valor
ADD COLUMN IF NOT EXISTS total_cost DECIMAL(12,2);

COMMIT;
```

---

## 4. Observaciones y Recomendaciones

1.  **Migración de Datos Históricos (Data Backfill):**
    El FRD sugiere actualizar costos históricos. Recomiendo hacerlo en un bloque transaccional separado y en horas de baja carga, ya que actualizar `sale_items` masivamente puede bloquear la tabla de ventas momentáneamente.

2.  **Lógica WAC (Costo Promedio):**
    El cálculo del Costo Promedio Ponderado no debe dejarse al frontend. Debe implementarse en:
    a) Un **Trigger** `BEFORE INSERT` en `inventory_movements` (Más robusto, garantiza consistencia siempre).
    b) Dentro de la RPC de compra/entrada (Más controlable, pero omite inserciones manuales).
    *Recomendación:* Implementar función `recalculate_product_cost(product_id)` y llamarla tras cada movimiento de entrada.

3.  **Seguridad (RLS):**
    Las nuevas columnas `cost` son sensibles. Aunque el usuario Admin las ve, si en el futuro se exponen endpoints públicos, debemos asegurar que estas columnas estén protegidas o filtradas, aunque por ahora las políticas RLS de `select` son por fila (store_id) y no por columna.

---

## 5. Instrucciones para Ejecución

1.  **Ejecutar DDL:** Aplicar el script del punto 3.1.
2.  **Actualizar RPC Ventas:** Modificar `rpc_procesar_venta_v2` para leer el costo actual y escribirlo en `sale_items`.
3.  **Data Backfill:** Ejecutar script de estimación (Opción B del FRD).

**Estado:** Aprobado para proceder.
