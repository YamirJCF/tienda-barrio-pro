# Estado Actual: Módulo de Reportes

> **Fecha de Actualización:** 15 de Febrero, 2026

---

## 1. Reportes Existentes

El sistema cuenta actualmente con tres niveles de reportes:

1.  **Resumen Financiero Diario (Daily Summary)**:
    *   **Enfoque**: "Pulso" del negocio en tiempo real.
    *   **Ubicación**: `AdminHub` -> Pestaña "Reportes".
    *   **Contenido**: Ventas totales, desglose por método de pago, comparación con promedio semanal (semáforo).

2.  **Sugerencias de Abastecimiento (Smart Supply)**:
    *   **Enfoque**: Predictivo / Inteligencia de Inventario.
    *   **Ubicación**: Debajo del Resumen Diario en `AdminHub`.
    *   **Contenido**: Productos críticos con riesgo de agotarse y sugerencias de compra. Muestra "Días de Racha" si el inventario está sano.

3.  **Historiales y Auditoría Auditables**:
    *   **Enfoque**: Trazabilidad detallada fila por fila.
    *   **Ubicación**: `HistoryView`.
    *   **Tipos**:
        *   **Ventas**: Listado de tickets con detalle de pago y anulaciones.
        *   **Caja**: Sesiones de apertura/cierre, sobrantes y faltantes.
        *   **Compras**: Entradas de inventario con proveedor y referencia.
        *   **Auditoría**: Log de seguridad (Login, cambio de PIN).
        *   **Gastos**: Egresos de caja menor.
        *   **Precios**: Historial de cambios de precio.

---

## 2. Estructura del Reporte Diario (`get_daily_summary`)

Este reporte se genera 100% en backend mediante una RPC para garantizar velocidad y consistencia.

### Campos de Retorno (Payload)

```json
{
  "traffic_light": {
    "status": "green", 
    "message": "🚀 ¡Vas un 15% arriba de tu promedio!"
  },
  "hero_number": 1500000,
  "money_breakdown": {
    "cash": 800000,
    "credit": 200000,
    "transfer": 500000
  },
  "alerts": [
    {
      "type": "stock_critical",
      "stock": 0,
      "message": "❌ Agotado: Leche Deslactosada",
      "target_id": "uuid-producto"
    }
  ],
  "reminder": {
    "message": "Recuerda hacer el cierre de caja al final del turno."
  }
}
```

### Lógica de Cálculo
*   **Hero Number**: Suma de columna `total` en tabla `sales` filtrado por fecha y `is_voided = FALSE`.
*   **Semáforo**: Se compara el total actual contra el **promedio de ventas de los últimos 7 días**.
    *   `> 105%` del promedio: 🟢 Verde (Mensaje de éxito).
    *   `< 95%` del promedio: 🔴 Rojo (Alerta de bajada).
    *   Rango medio: 🟢 Verde (Mensaje de estabilidad).

---

## 3. Actores y Permisos

El acceso a reportes está segregado mediante `authStore` y RLS.

*   **Administrador (Dueño)**: Acceso total a todos los reportes, costos y configuración.
*   **Empleado con Permiso `canViewReports`**:
    *   Puede ver el `AdminHub` y la pestaña de "Reportes".
    *   Ve el Resumen Diario y Smart Supply.
*   **Empleado sin Permiso**:
    *   No tiene acceso al botón de "Administración".
    *   Bloqueado a nivel de navegación (redirect).

---

## 4. Limitaciones Actuales

A pesar de tener datos robustos, la capa de presentación tiene carencias:

*   ❌ **Sin Exportación**: No existe botón para descargar Excel/PDF en Historiales ni Reportes.
*   ❌ **Rangos Rígidos**: Los filtros de fecha son presets (Hoy, Ayer, Semana, Mes). No hay selector de rango personalizado ("Del 5 al 10 de Enero").
*   ❌ **Ausencia de Gráficos**: Todo es numérico o textual. No hay gráficas de tendencia o torta.
*   ❌ **Unidireccionalidad de Supply**: El reporte de "Smart Supply" es de solo lectura. No permite convertir una sugerencia en una Orden de Compra automáticamente.

---

## 5. Código Relevante

### Frontend Store (`stores/reports.ts`)
Maneja la llamada a la RPC y tipado de la respuesta.
```typescript
const fetchDailySummary = async (date?: string) => {
    // ...
    const { data } = await supabase.rpc('get_daily_summary', { p_store_id: ... });
    summary.value = data as DailySummary;
};
```

### Backend RPC (`migrations/20260204120000_get_daily_summary.sql`)
Centraliza la lógica financiera.
```sql
CREATE FUNCTION get_daily_summary(...) RETURNS JSONB AS $$
BEGIN
    -- Calcula ventas, promedio 7 días y alertas de stock en una sola transacción
    -- Retorna JSON listo para consumir
END;
$$;
```
