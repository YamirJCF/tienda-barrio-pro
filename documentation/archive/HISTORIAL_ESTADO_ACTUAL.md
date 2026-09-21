# Estado Actual: Módulo de Historiales

> **Fecha de Actualización:** 15 de Febrero, 2026

---

## 1. Tipos de Historial Existentes

El sistema gestiona 6 tipos de historiales distintos, centralizados visualmente pero desacoplados a nivel de datos:

| Tipo | Icono | Fuente de Datos | Descripción |
|------|-------|-----------------|-------------|
| **Ventas** | 🛒 | `sales` | Tickets emitidos, anulaciones, y método de pago (Efectivo/Nequi/Fiado). |
| **Caja** | 🏛️ | `cash_sessions` | Aperturas y cierres de turno, incluyendo balance inicial/final y diferencias (sobrantes/faltantes). |
| **Compras** | 📦 | `inventory_movements` | Entradas de mercancía (`movement_type = 'entrada'`) asociadas a proveedores. |
| **Auditoría** | 🛡️ | `audit_logs` | Eventos de seguridad: Login, Cambio de PIN, Accesos denegados. |
| **Gastos** | 💸 | `expenses` | Salidas de dinero registradas manualmente en caja menor. |
| **Precios** | 🏷️ | `price_change_logs` | Bitácora de cambios de precio (Anterior vs Nuevo). |

---

## 2. Modelo de Datos

No existe una tabla única de "historial". La estrategia es **Historial Distribuido**: cada módulo principal tiene su propia tabla transaccional.

*   **Ventas**: Tabla `sales`. Campos clave: `ticket_number`, `total`, `payment_method`, `is_voided`.
*   **Caja**: Tabla `cash_sessions`. Campos clave: `opening_balance`, `closing_balance`, `difference`.
*   **Inventario**: Tabla `inventory_movements`. Es el **Kardex** del sistema.
*   **Auditoría**: Tabla dedicada `audit_logs` con campo `metadata` (JSONB) para flexibilidad.

**Estrategia de Borrado**:
*   `sales`: **Soft Delete** lógico vía campo `is_voided` (no se borran, se marcan).
*   `audit_logs`: **Append Only** (Solo inserción, nunca borrado ni modificación).
*   `products`: Sin borrado físico documentado en historial, pero soporte de `deleted_at` en arquitectura.

---

## 3. RPCs de Consulta

El frontend consume funciones RPC específicas para cada pestaña.
*(Nota: Definiciones inferidas del consumo en frontend `useHistory.ts`)*

### `get_history_ventas`
*   **Parámetros**:
    *   `p_store_id`: UUID
    *   `p_start_date`: TEXT (YYYY-MM-DD)
    *   `p_end_date`: TEXT (YYYY-MM-DD)
    *   `p_employee_id`: UUID (Opcional, para filtrar por cajero)
*   **Retorno**: Array de objetos con `ticket_number`, `items_count`, `total`, `is_voided`, `client_name`.

### `get_history_caja`
*   **Parámetros**: `p_store_id`, `p_start_date`, `p_end_date`
*   **Retorno**: Sesiones con estado (`open`/`closed`), balances calculados y nombre de responsables de apertura/cierre.

### `get_history_compras`
*   **Parámetros**: `p_store_id`, `p_start_date`, `p_end_date`
*   **Retorno**: Movimientos de inventario enriquecidos con nombre del proveedor y referencia de factura.

---

## 4. Funcionalidad Actual en UI (`HistoryView.vue`)

*   **Navegación**: Pestañas superiores para cambiar de contexto (Ventas, Caja, etc.).
*   **Filtros de Tiempo**: 4 Presets rígidos ("Hoy", "Ayer", "Semana", "Mes").
*   **Filtro de Empleado**: Disponible solo en la pestaña de **Ventas**.
*   **Visualización**:
    *   Lista vertical de tarjetas (`HistoryItemCard`).
    *   Iconografía distintiva por tipo de evento.
    *   Indicadores de estado (ej: Fondo rojo para ventas anuladas).
*   **Carga**: Estrategia *Lazy Load* (carga al cambiar de pestaña).

---

## 5. Limitaciones y Dolor del Usuario

1.  **Búsqueda Inexistente**: No hay barra de búsqueda. No se puede buscar un ticket por número ni un producto específico en el historial.
2.  **Filtros Rígidos**: Imposible consultar un rango específico (ej: "Ventas de Diciembre 2024").
3.  **Sin Detalle Expandido**: Al hacer click en una venta, **no pasa nada**. No se puede ver qué productos se vendieron en ese ticket.
4.  **Scroll Infinito Ausente**: Carga una lista fija (limitada por backend o rendimiento). Si hay mil ventas en un mes, la UI podría sufrir.
5.  **Falta de Totales**: El resumen superior muestra un total simple, pero no desglosa (ej: en Caja muestra balance final, pero no cuánto fue efectivo vs transferencia).

---

## 6. Código Relevante

### Composable: `composables/useHistory.ts`
Centraliza la lógica de llamada a las 6 APIs distintas y normaliza los datos en una interfaz común `HistoryItem`.

```typescript
// Ejemplo de normalización en frontend
items.value = rows.map(sale => ({
    type: 'sales',
    title: `Venta #${sale.ticket_number}`,
    amount: sale.total,
    colorClass: sale.is_voided ? 'bg-red-100' : 'bg-green-100',
    // ...
}));
```

### Repositorio Auditoría: `auditRepository.ts`
A diferencia de Ventas/Caja que usan RPCs, Auditoría y Precios consultan directamente las tablas `audit_logs` y `price_change_logs` usando el cliente Supabase.

```typescript
// Consulta directa sin RPC
supabase.from('audit_logs').select('...').eq('store_id', storeId)
```
