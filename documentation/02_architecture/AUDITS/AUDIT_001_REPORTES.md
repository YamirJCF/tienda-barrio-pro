# Auditoría de Implementación vs FRD-008 (Reportes)

**Fecha:** 2026-02-04
**Versión Auditada:** Frontend (`ReportsContent.vue`), Backend (Migraciones actuales)
**Auditor:** @[/architect]

## 1. Resumen Ejecutivo
El módulo de reportes actual presenta una **desviación crítica** con respecto a los principios de arquitectura del sistema. Actualmente, el frontend está asumiendo responsabilidades de cálculo financiero (totales, ganancias, crecimiento) que pertenecen estrictamente al Backend.

Además, la experiencia de usuario (UX) implementada es más genérica ("Dashboard Administrativo") que la solicitada en el FRD ("Resumen Conversacional para Tenderos").

---

## 2. Hallazgos Críticos (Violaciones de Arquitectura)

| Gravedad | Hallazgo | Estándar Violado |
|----------|----------|-------------------|
| 🔴 **CRÍTICA** | **Cálculos en Frontend:** `ReportsContent.vue` descarga ventas y suma totales (`reduce`) en el navegador. | *Principio 1: Arquitecto de Datos define la verdad.* |
| 🔴 **CRÍTICA** | **Lógica de Negocio Fantasma:** El margen de ganancia se calcula asumiendo un costo fijo del 70% (`totalSales * 0.7`). No es real. | *Principio 1: El dato es sagrado.* |
| 🟠 **ALTA** | **Falta de RPC:** No existe una función `get_daily_summary` en Supabase. El cliente hace query de todas las ventas para filtrar. | *Principio 3: Flujo Unidireccional.* |

---

## 3. Discrepancias de Funcionalidad (UX)

| Zona FRD | Requisito | Implementación Actual | Veredicto |
|----------|-----------|-----------------------|-----------|
| **A. Encabezado** | Fecha + Semáforo (vs Promedio 7 días) | Selector de Periodo (Hoy/Semana/Mes) + Crecimiento vs Periodo Anterior | ❌ Divergente |
| **B. Héroe** | Monto Entero (Sin decimales) | Muestra monto formateado (Ok), pero calculado localmente. | ⚠️ Parcial |
| **C. Dinero** | Desglose (Efectivo, Nequi, Fiado) interactivo | Cards informativos no interactivos. | ⚠️ Visual Ok, Funcionalidad ❌ |
| **D. Alertas** | Lista priorizada (Stock Crítico > Fiado) | Tabs de productos (Top / Bajo Stock / Estancados). | ❌ Modelo mental diferente |
| **E. Recordatorio** | "Mañana recuerda: [Acción]" | No existe. | ❌ Ausente |

---

## 4. Recomendaciones Técnicas

### 4.1 Backend (Prioridad Inmediata)
Implementar función RPC `get_daily_summary(store_id, date)` que retorne el JSON exacto para la UI:

```json
{
  "traffic_light": { "status": "green", "message": "Estás vendiendo +15% que tu promedio" },
  "hero_number": 150000,
  "money_breakdown": { "cash": 100000, "transfer": 50000, "credit": 0 },
  "alerts": [
    { "type": "stock_critical", "message": "Azúcar se agotó", "target_id": 123 }
  ],
  "reminder": { "message": "Mañana recuerda: Pedir Leche" }
}
```

### 4.2 Frontend
1. **Eliminar lógica de cálculo:** Borrar todos los `computed` que suman valores en `ReportsContent.vue`.
2. **Consumo Pasivo:** El componente solo debe renderizar el JSON que llega del store.
3. **Refactor UX:** Transformar el tablero de "Dashboard con Tabs" al diseño de "Feed Conversacional" (Semáforo -> Héroe -> Lista de Tareas).
