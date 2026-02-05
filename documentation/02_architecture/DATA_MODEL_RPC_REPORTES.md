## Modelo de Datos - Módulo de Reportes (Dashboard Conversacional)

### Explicación Lógica
Para cumplir con el principio de "Single Source of Truth" y evitar cálculos en el cliente, centralizamos la lógica del resumen diario en una función RPC (`get_daily_summary`).

Esta función:
1.  **Agrega Ventas**: Suma el total del día solicitado, excluyendo ventas anuladas.
2.  **Clasifica Métodos de Pago**: Normaliza `nequi` y `daviplata` como `transfer` para simplificar la UI.
3.  **Analiza Tendencias**: Compara el desempeño actual contra el promedio móvil de los últimos 7 días para generar el "semáforo" y el mensaje motivacional.
4.  **Detecta Alertas**: Identifica inventario crítico en tiempo real.
5.  **Formatea Salida**: Entrega un JSON listo para ser consumido por la UI sin transformación adicional.

### Bloque de Código SQL

```sql
/**
 * get_daily_summary
 * Retorna el resumen financiero y operativo para el dashboard principal.
 *
 * @param p_store_id UUID - ID de la tienda
 * @param p_date DATE - Fecha del reporte (default: hoy)
 */
CREATE OR REPLACE FUNCTION get_daily_summary(
    p_store_id UUID,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Se ejecuta con permisos de definidor para acceder a datos agregados
AS $$
DECLARE
    v_total_sales NUMERIC DEFAULT 0;
    v_avg_sales_7d NUMERIC DEFAULT 0;
    v_breakdown JSONB;
    v_alerts JSONB;
    v_traffic_status TEXT;
    v_traffic_message TEXT;
    v_start_date TIMESTAMPTZ;
    v_end_date TIMESTAMPTZ;
BEGIN
    -- Definir rango de tiempo para el día consultado (asumiendo UTC por ahora, idealmente adaptar a timezone de tienda)
    v_start_date := p_date::TIMESTAMPTZ;
    v_end_date := v_start_date + INTERVAL '1 day';

    -- 1. Hero Number (Ventas Totales del Día)
    SELECT COALESCE(SUM(total), 0)
    INTO v_total_sales
    FROM sales
    WHERE store_id = p_store_id
      AND created_at >= v_start_date
      AND created_at < v_end_date
      AND is_voided = FALSE;

    -- 2. Money Breakdown (Desglose por método de pago)
    -- Mapeo: efectivo->cash, nequi/daviplata->transfer, fiado->credit
    SELECT jsonb_object_agg(method_group, amount)
    INTO v_breakdown
    FROM (
        SELECT
            CASE
                WHEN payment_method IN ('nequi', 'daviplata') THEN 'transfer'
                WHEN payment_method = 'fiado' THEN 'credit'
                ELSE 'cash'
            END as method_group,
            SUM(total) as amount
        FROM sales
        WHERE store_id = p_store_id
          AND created_at >= v_start_date
          AND created_at < v_end_date
          AND is_voided = FALSE
        GROUP BY 1
    ) sub;

    -- Garantizar estructura aunque sea cero
    v_breakdown := jsonb_build_object(
        'cash', COALESCE((v_breakdown->>'cash')::NUMERIC, 0),
        'transfer', COALESCE((v_breakdown->>'transfer')::NUMERIC, 0),
        'credit', COALESCE((v_breakdown->>'credit')::NUMERIC, 0)
    );

    -- 3. Traffic Light (Comparativo vs Promedio 7 días anteriores)
    SELECT COALESCE(AVG(daily_total), 0)
    INTO v_avg_sales_7d
    FROM (
        SELECT DATE(created_at) as day, SUM(total) as daily_total
        FROM sales
        WHERE store_id = p_store_id
          AND created_at >= (v_start_date - INTERVAL '7 days')
          AND created_at < v_start_date
          AND is_voided = FALSE
        GROUP BY 1
    ) past_sales;

    -- Lógica del Semáforo
    IF v_avg_sales_7d = 0 THEN
        v_traffic_status := 'gray';
        v_traffic_message := 'Recopilando datos históricos...';
    ELSIF v_total_sales >= (v_avg_sales_7d * 1.05) THEN
        v_traffic_status := 'green';
        v_traffic_message := '🚀 ¡Vas un ' || ROUND(((v_total_sales - v_avg_sales_7d) / v_avg_sales_7d * 100), 0) || '% arriba de tu promedio!';
    ELSIF v_total_sales <= (v_avg_sales_7d * 0.95) THEN
        v_traffic_status := 'red';
        v_traffic_message := '🔻 Estás un ' || ROUND(((v_avg_sales_7d - v_total_sales) / v_avg_sales_7d * 100), 0) || '% abajo de tu promedio.';
    ELSE
        v_traffic_status := 'green'; -- Yellow a veces se percibe negativo, usamos green para "estable"
        v_traffic_message := '👍 Ventas estables respecto a tu semana.';
    END IF;

    -- 4. Alertas (Prioridad: Stock Crítico)
    -- Top 5 productos con stock bajo o agotado
    SELECT jsonb_agg(jsonb_build_object(
        'type', 'stock_critical',
        'message', CASE WHEN current_stock <= 0 THEN '❌ Agotado: ' || name ELSE '⚠️ Bajo stock: ' || name END,
        'target_id', id,
        'stock', current_stock
    ))
    INTO v_alerts
    FROM products
    WHERE store_id = p_store_id
      AND current_stock <= min_stock
    LIMIT 5;

    IF v_alerts IS NULL THEN v_alerts := '[]'::JSONB; END IF;

    -- 5. Retornar Payload
    RETURN jsonb_build_object(
        'traffic_light', jsonb_build_object(
            'status', v_traffic_status,
            'message', v_traffic_message
        ),
        'hero_number', v_total_sales,
        'money_breakdown', v_breakdown,
        'alerts', v_alerts,
        -- Placeholder para recordatorios futuros
        'reminder', jsonb_build_object('message', CASE WHEN v_total_sales = 0 THEN '¡Abre caja para empezar a vender!' ELSE 'Recuerda hacer el cierre de caja al final del turno.' END)
    );
END;
$$;
```

### Diccionario de Datos de Salida

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `traffic_light` | JSON | Objeto con estado y mensaje motivacional |
| `traffic_light.status` | Text | `green` (bueno/estable), `red` (bajo rendimiento), `gray` (sin datos) |
| `traffic_light.message` | Text | Mensaje humano explicativo del estado |
| `hero_number` | Number | Monto total vendido en el día (integer/numeric) |
| `money_breakdown` | JSON | Desglose por tipo de pago simplificado |
| `money_breakdown.cash` | Number | Total en efectivo |
| `money_breakdown.transfer` | Number | Total Nequi + Daviplata |
| `money_breakdown.credit` | Number | Total Fiado |
| `alerts` | Array | Lista de alertas prioritarias (stock bajo, deudas altas, etc.) |
| `reminder` | JSON | Mensaje recordatorio contextual (cierre de caja, etc.) |

### Instrucción para el Orquestador

1.  **Ejecución:** Aplicar este script SQL en el editor de Supabase.
2.  **Integración:** Actualizar el store de frontend para usar `rpc('get_daily_summary', { p_store_id: ..., p_date: ... })` en lugar de consultar `sales` directamente.
3.  **Limpieza:** Eliminar la lógica de `reduce` y `computed` en `ReportsContent.vue` una vez conectado este endpoint.
