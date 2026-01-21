# Órdenes de Trabajo - Fase 2: Lógica de Negocio y Operativa

> **Fase**: 2 (Implementación de Procesos Core)  
> **Fecha**: 2026-01-21  
> **Estado**: ✅ Completada (Aprobada por QA)

---

## Resumen Ejecutivo

Esta fase implementa los flujos de trabajo críticos del negocio: Gestión de Inventario, Punto de Venta (POS), Control de Caja y Reportes. Se construye sobre la capa de datos offline-first de la Fase 1.

---

## Diagrama de Dependencias

```mermaid
flowchart LR
    WO201[WO-001: Inventario Avanzado] --> WO204[WO-004: Dashboard]
    WO202[WO-002: Sistema POS] --> WO203[WO-003: Control Caja]
    WO201 --> WO202
    WO203 --> WO204
    WO204 --> WO205[WO-005: QA Fase 2]
```

---

## WO-PHASE2-001: Gestión de Inventario Avanzda

| Campo | Valor |
|-------|-------|
| **Agente** | Full Stack |
| **Prioridad** | 🔴 Crítica |
| **Estimación** | 6-8 horas |
| **Dependencias** | `inventory.md`, `stock-entry.md` |

### Tareas

- [x] **T1.1**: Implementar `StockEntryView.vue`
  - Formulario de entrada/salida/ajuste
  - Selección de motivo (Compra, Pérdida, Ajuste)
  - Cálculo de nuevo costo promedio (si aplica, o FIFO simplificado)

- [x] **T1.2**: Lógica de Movimientos en `productRepository`
  - Método `registerMovement(type, quantity, reason)`
  - Validación de stock negativo (según política configurada)
  - Actualización atómica de `stock` en tabla `products`

- [x] **T1.3**: Gestión de Lotes y Vencimiento (Básico)
  - Campo `expiration_date` en entrada
  - Alerta visual en `InventoryView` para próximos a vencer

- [x] **T1.4**: Kardex (Historial de Movimientos)
  - Vista `ProductHistoryModal.vue`
  - Consulta a tabla `stock_movements` (crearla si no existe en schema)

### Criterios de Aceptación

- [x] Se pueden registrar entradas y salidas
- [x] El stock se actualiza correctamente
- [x] Se genera historial de movimientos (Kardex)

---

## WO-PHASE2-002: Sistema POS y Checkout

| Campo | Valor |
|-------|-------|
| **Agente** | UX/Frontend |
| **Prioridad** | 🔴 Crítica |
| **Estimación** | 8-10 horas |
| **Dependencias** | WO-201 (Stock), `pos.md`, `rounding-policy.md` |

### Tareas

- [x] **T2.1**: Refactorizar `CartStore` para usar `SaleRepository`
  - Validar stock disponible al agregar
  - Integrar lógica de impuestos (si aplica)

- [x] **T2.2**: Implementar Política de Redondeo
  - Redondeo a 50 pesos (Colombia) a favor del cliente/tienda según ley
  - Visualización de "Ajuste por redondeo" en ticket

- [x] **T2.3**: Checkout Modal UX
  - Selección de método de pago (Efectivo, Transferencia, Crédito)
  - Cálculo de cambio (devuelta)
  - Generación de ID de venta (UUID) previo a envío

- [x] **T2.4**: Integración con "Venta Rápida" (Teclado)
  - Atajos de teclado para cobrar (F12, Enter)

### Criterios de Aceptación

- [x] Flujo completo: Agregar -> Pagar -> Confirmar -> Reducir Stock
- [x] Redondeo correcto en totales
- [x] Soporte para métodos de pago mixtos (opcional fase 2, deseable)

---

## WO-PHASE2-003: Control de Caja (Cash Control)

| Campo | Valor |
|-------|-------|
| **Agente** | Backend/Logic |
| **Prioridad** | 🟠 Alta |
| **Estimación** | 6-8 horas |
| **Dependencias** | WO-202 (Ventas generan ingresos), `cash-control.md` |

### Tareas

- [x] **T3.1**: Schema de Caja
  - Tabla `cash_registers` (sesiones)
  - Tabla `cash_movements` (ingresos/egresos manuales y automáticos) or `transactions`

- [x] **T3.2**: Flujo de Apertura de Caja
  - Modal `OpenRegister.vue`: Conteo de base inicial
  - Asignación de cajero responsable

- [x] **T3.3**: Flujo de Cierre de Caja (Arqueo)
  - Modal `CloseRegister.vue`: Conteo final de efectivo
  - Cálculo de discrepancia (Sobrante/Faltante)
  - Bloqueo de POS si caja cerrada

- [x] **T3.4**: Gestión de Gastos Menores
  - Vista `ExpensesView.vue`: Registrar salida de efectivo (ej. pago proveedores menor)
  - Impacto en saldo de caja actual

### Criterios de Aceptación

- [x] No se puede vender sin abrir caja
- [x] El cierre genera reporte de discrepancias
- [x] Los gastos descuentan del efectivo teórico

---

## WO-PHASE2-004: Dashboard y Reportes

| Campo | Valor |
|-------|-------|
| **Agente** | Frontend |
| **Prioridad** | 🟡 Media |
| **Estimación** | 4-6 horas |
| **Dependencias** | Todas las anteriores, `dashboard.md` |

### Tareas

- [x] **T4.1**: Widgets Dashboard Principal
  - "Ventas del Día" (Total $)
  - "Transacciones" (Cantidad #)
  - "Productos Bajo Stock" (Alerta)

- [x] **T4.2**: Reporte de Ventas Básico
  - Vista `SalesReport.vue`
  - Filtros por fecha, cajero, método de pago

- [x] **T4.3**: Reporte de Inventario
  - Valoración del inventario (Costo vs Precio Venta)

### Criterios de Aceptación

- [x] Dashboard carga rápido (optimistic metrics)
- [x] Datos coinciden con POS y Caja

---

## WO-PHASE2-005: QA Integral Fase 2

| Campo | Valor |
|-------|-------|
| **Agente** | QA |
| **Prioridad** | 🔴 Crítica |
| **Estimación** | 4-6 horas |
| **Dependencias** | Todos los WO Completos |

### Tareas

- [x] **T5.1**: Pruebas E2E de Flujo de Venta
- [x] **T5.2**: Validación de Cálculos Contables (Caja)
- [x] **T5.3**: Pruebas de Estrés de Inventario
- [x] **T5.4**: Auditoría de Permisos (Cajero vs Admin en reportes)

### Criterios de Aceptación

- [x] Sin errores de cálculo financiero
- [x] Flujos bloqueantes (Caja cerrada) funcionan 100%
