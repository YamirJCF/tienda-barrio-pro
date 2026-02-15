# 🧠 Análisis Lógico: Fase 2 - Inteligencia de Negocio

**Referencia:** `FRD_Reportes_Historiales_v1.0.md`
**Estado Fase 1:** Completada (`cost_price` en products, `unit_cost` en sale_items).

---

## 1. Definición de RPCs (Backend)

### 1.1. `get_financial_summary`
**Objetivo:** Calcular la "Ganancia Neta" real del negocio.

**Fórmulas:**
*   **Ventas Totales (Revenue):** `SUM(total)` de tabla `sales` (excluyendo anuladas).
*   **Costo de Mercancía (COGS):** `SUM(quantity * unit_cost)` de tabla `sale_items`.
    *   *Nota:* Usamos `sale_items.unit_cost` (histórico), NO `products.cost_price` (actual), para respetar la realidad del momento de la venta.
*   **Ganancia Bruta:** `Revenue - COGS`.
*   **Margen:** `(Ganancia / Revenue) * 100`.

**Consideraciones Técnicas:**
*   Las ventas anuladas (`is_voided = TRUE`) deben excluirse tanto de ventas como de costos.
*   El desglose de dinero (`money_breakdown`) debe coincidir exactamente con el total de ventas.
*   Se incluirá el saldo de fiado pendiente (`client_ledger`) como métrica de liquidez.

### 1.2. `get_top_selling_products`
**Objetivo:** Ranking de rendimiento por producto.

**Lógica de Query:**
```sql
SELECT 
    p.name,
    SUM(si.quantity) as units,
    SUM(si.subtotal) as revenue,
    SUM(si.subtotal - (si.quantity * si.unit_cost)) as profit
FROM sale_items si
JOIN sales s ON si.sale_id = s.id
JOIN products p ON si.product_id = p.id
WHERE s.created_at BETWEEN start AND end
  AND s.is_voided = FALSE
GROUP BY p.id
ORDER BY units DESC (opcional: BY profit DESC)
LIMIT 10
```

### 1.3. `get_stagnant_products`
**Objetivo:** Detectar capital inmovilizado (Stock muerto).

**Lógica:**
*   Productos con `current_stock > 0`.
*   Que NO tengan ventas en los últimos `N` días.
*   O que nunca hayan tenido ventas.
*   Valorización: `current_stock * cost_price`.

---

## 2. Estrategia de Tests (Verificación)

Para validar estas nuevas lógicas sin UI, crearemos un script de prueba SQL (`check_financial_logic.sql`) que:
1.  Cree una venta de prueba controlada (1 item, precio conocido, costo conocido).
2.  Ejecute `get_financial_summary`.
3.  Verifique que `Revenue - Cost == Profit` esperado.

---

## 3. Plan de Implementación (Fase 2)

1.  **Crear Migración SQL:** Archivo único `20260215170000_financial_rpcs.sql` conteniendo las 3 funciones.
2.  **Validar:** Ejecutar queries de prueba en el editor SQL.
3.  **Actualizar Store Frontend:** `useReportsStore` para consumir `get_financial_summary`.

**Estado:** Listo para proceder a la creación de los RPCs.
