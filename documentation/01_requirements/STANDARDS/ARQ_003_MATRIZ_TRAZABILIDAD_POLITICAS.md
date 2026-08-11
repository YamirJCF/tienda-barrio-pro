# 📐 Estándar ARQ-003: Matriz de Trazabilidad Política → Regla

**Versión:** 1.0  
**Fecha:** 2026-07-31  
**Autor:** Arquitecto de Producto  
**Estado:** ✅ Activo  
**Documento Padre:** `ARQ_002_POLITICAS_GLOBALES_NEGOCIO.md`

---

## Problema que Resuelve

Sin una matriz centralizada, es imposible responder rápidamente: "¿Qué FRDs se ven afectados si cambio la Política X?" o "¿Bajo qué Política está protegida la Regla Y del FRD Z?". Este documento elimina esa ambigüedad ofreciendo un mapeo bidireccional completo.

---

## Principio Fundamental

> **"Toda regla operativa (FRD) DEBE ser trazable a una Política estratégica (ARQ-002). Una regla sin política es una regla huérfana y debe ser cuestionada."**

---

## Matriz Política → FRDs

| Código | Política | FRDs que Gobierna | Módulos Afectados |
|--------|----------|-------------------|-------------------|
| POL-FIN-01 | Solidez de Caja (Liquidez Real) | FRD-027, FRD-027-01, FRD-026, FRD-004, FRD-028 | Caja, Reportes, Gastos, Multicanal, Almacenamiento Seguro |
| POL-FIN-02 | Segregación de Canales Monetarios | FRD-027, FRD-026, FRD-004, FRD-019 | Caja, Gastos, Multicanal, Proveedores |
| POL-FIN-03 | Aislamiento de Promesas de Pago | FRD-024, FRD-027, FRD-019 | Fiados, Proveedores, Caja |
| POL-FIN-04 | Transformación de Promesa a Liquidez | FRD-024, FRD-006-02, FRD-019 | Fiados, Proveedores, Reembolsos |
| POL-FIN-05 | Distribución por Tipo de Transacción en POS | FRD-007-01, FRD-006-02 | POS, Reembolsos |
| POL-LOG-01 | Independencia Logística-Financiera | FRD-027, FRD-006-01, FRD-006-01-01, FRD-012-01, FRD-019 | Caja, Inventario, Entradas, Sincronización, Proveedores |
| POL-LOG-02 | Verdad Física (Anti-Negativos) | FRD-006-01, FRD-007-01, FRD-012-01 | Inventario, POS, Sincronización |
| POL-LOG-03 | Embudo Único de Egresos (POS) | FRD-006-01-02, FRD-007-01 | Salidas, POS |
| POL-LOG-04 | Inmediatez Logística | FRD-024, FRD-006-01, FRD-012-01, FRD-019 | Fiados, Proveedores, Inventario, Sincronización |
| POL-SEG-01 | Arqueo Ciego | FRD-027-01 | Reportes |
| POL-SEG-02 | Caducidad del Turno Operativo | FRD-027-02, FRD-001, FRD-012-01, FRD-004 | Límite 24h, Seguridad, Pase Diario, Sincronización, Caja |
| POL-SEG-03 | Control de Acceso por Roles | FRD-006-02, FRD-007-01, FRD-001, FRD-003, FRD-012-01, FRD-028, FRD-019 | Reembolsos, POS, Seguridad, Pase Diario, Empleados, Sincronización, Almacenamiento, Proveedores |
| POL-AUD-01 | Inmutabilidad Histórica | FRD-027-01, FRD-006-01, FRD-012-01, FRD-028, FRD-019 | Reportes, Inventario, Sincronización, Almacenamiento, Proveedores |
| POL-AUD-02 | Trazabilidad Universal | FRD-027-01, FRD-006-01-01, FRD-006-01-02, FRD-007-01, FRD-006-02, FRD-007-02, FRD-006-03 | Todos |
| POL-AUD-03 | Detección de Anomalías | FRD-027-01, FRD-027-02 | Reportes, Caja |

---

## Matriz Inversa: FRD → Políticas

| FRD | Políticas que lo Gobiernan |
|-----|---------------------------|
| FRD-001 (Seguridad Diaria) | POL-SEG-02, POL-SEG-03 |
| FRD-003 (Gestión Empleados) | POL-SEG-03 |
| FRD-004 (Control de Caja) | POL-FIN-01, POL-FIN-02, POL-SEG-02 |
| FRD-006-01 (Núcleo Inventario) | POL-LOG-01, POL-LOG-02, POL-LOG-04, POL-AUD-01 |
| FRD-006-01-01 (Entradas) | POL-LOG-01, POL-AUD-02 |
| FRD-006-01-02 (Salidas) | POL-LOG-03, POL-AUD-02 |
| FRD-006-02 (Reembolsos) | POL-FIN-04, POL-FIN-05, POL-SEG-03, POL-AUD-02 |
| FRD-006-03 (Código Producto) | POL-LOG-01, POL-AUD-01, POL-AUD-02 |
| FRD-007-01 (Núcleo POS) | POL-FIN-05, POL-LOG-02, POL-LOG-03, POL-SEG-03, POL-AUD-02 |
| FRD-007-02 (Ticket Venta) | POL-AUD-01, POL-AUD-02 |
| FRD-007 (Ventas) | POL-FIN-05, POL-LOG-03 |
| FRD-012 (Sincronización Offline) | POL-LOG-01, POL-LOG-02, POL-LOG-04, POL-SEG-02, POL-AUD-01 |
| FRD-012-01 (Límites Sistema Offline) | POL-LOG-01, POL-LOG-02, POL-LOG-04, POL-SEG-02, POL-SEG-03, POL-AUD-01 |
| FRD-019 (Cuentas por Pagar) | POL-FIN-02, POL-FIN-03, POL-FIN-04, POL-LOG-01, POL-LOG-04, POL-SEG-03, POL-AUD-01 |
| FRD-024 (Fiados Clientes) | POL-FIN-03, POL-FIN-04, POL-LOG-04 |
| FRD-026 (Gastos) | POL-FIN-01, POL-FIN-02 |
| FRD-027 (Núcleo Caja) | POL-FIN-01, POL-FIN-02, POL-FIN-03, POL-LOG-01 |
| FRD-028 (Almacenamiento Local Seguro) | POL-FIN-01, POL-SEG-03, POL-AUD-01 |
| FRD-027-01 (Reportes) | POL-FIN-01, POL-SEG-01, POL-AUD-01, POL-AUD-02, POL-AUD-03 |
| FRD-027-02 (Límite 24h) | POL-SEG-02, POL-AUD-03 |

---

## Protocolo de Actualización

| Evento | Acción Obligatoria |
|--------|-------------------|
| Se crea un nuevo FRD | Agregar fila(s) en ambas matrices indicando qué Política(s) lo gobiernan. |
| Se crea una nueva Política en ARQ-002 | Agregar fila en la Matriz Política → FRDs con los documentos afectados. |
| Se elimina o fusiona un FRD | Eliminar sus referencias de ambas matrices y verificar que ninguna Política quede sin FRDs. |

---

## Historial de Cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1.0 | 2026-07-31 | Arquitecto de Producto | Creación inicial. Extraída desde la Sección II de ARQ-002. Agregada Matriz Inversa (FRD → Políticas). |

---

**Firmado:** Arquitecto de Producto  
**Fecha:** 2026-07-31
