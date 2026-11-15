# 📐 Estándar ARQ-003: Matriz de Trazabilidad Política → Regla

**Versión:** 1.4  
**Fecha:** 2026-11-15  
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
| POL-FIN-01 | Solidez de Caja (Liquidez Real) | FRD-027, FRD-027-01, FRD-026, FRD-004, FRD-028, FRD-007, FRD-009, FRD-012-01, FRD-017, FRD-003-01 | Caja, Reportes, Gastos, Multicanal, Almacenamiento Seguro, Offline, Ciclo Contable, Permisos Empleados |
| POL-FIN-02 | Segregación de Canales Monetarios | FRD-027, FRD-026, FRD-004, FRD-019, FRD-007, FRD-009, FRD-003-01 | Caja, Gastos, Multicanal, Proveedores, Permisos Empleados |
| POL-FIN-03 | Aislamiento de Promesas de Pago | FRD-024, FRD-027, FRD-019, FRD-007, FRD-003-01 | Fiados, Proveedores, Caja, Permisos Empleados |
| POL-FIN-04 | Transformación de Promesa a Liquidez | FRD-024, FRD-006-02, FRD-019, FRD-009, FRD-003-01 | Fiados, Proveedores, Reembolsos, Permisos Empleados |
| POL-FIN-05 | Distribución por Tipo de Transacción en POS | FRD-007-01, FRD-006-02, FRD-003-01 | POS, Reembolsos, Permisos Empleados |
| POL-LOG-01 | Independencia Logística-Financiera | FRD-027, FRD-006-01, FRD-006-01-01, FRD-012-01, FRD-019, FRD-007, FRD-013, FRD-017, FRD-003-01 | Caja, Inventario, Entradas, Sincronización, Proveedores, Sesiones, Ciclo Contable, Permisos Empleados |
| POL-LOG-02 | Verdad Física (Anti-Negativos) | FRD-006-01, FRD-007-01, FRD-012-01 | Inventario, POS, Sincronización |
| POL-LOG-03 | Embudo Único de Egresos (POS) | FRD-006-01-02, FRD-007-01, FRD-003-01 | Salidas, POS, Permisos Empleados |
| POL-LOG-04 | Inmediatez Logística | FRD-024, FRD-006-01, FRD-012-01, FRD-019, FRD-009, FRD-003-01 | Fiados, Proveedores, Inventario, Sincronización, Permisos Empleados |
| POL-SEG-01 | Arqueo Ciego | FRD-027-01, FRD-003-01 | Reportes, Caja, Permisos Empleados |
| POL-SEG-02 | Caducidad del Turno Operativo | FRD-027-02, FRD-001, FRD-012-01, FRD-004, FRD-013, FRD-017, FRD-003-01 | Límite 24h, Seguridad, Pase Diario, Sincronización, Caja, Sesiones, Ciclo Contable, Permisos Empleados |
| POL-SEG-03 | Control de Acceso por Roles | FRD-006-02, FRD-007-01, FRD-001, FRD-003, FRD-003-01, FRD-012-01, FRD-028, FRD-019, FRD-013, FRD-017, FRD-029, FRD-030 | Reembolsos, POS, Seguridad, Pase Diario, Empleados, Permisos Empleados, Sincronización, Almacenamiento, Proveedores, Sesiones, Ciclo Contable, Consentimiento Legal, Clientes |
| POL-AUD-01 | Inmutabilidad Histórica | FRD-027-01, FRD-006-01, FRD-012-01, FRD-028, FRD-019, FRD-007, FRD-013, FRD-017, FRD-029, FRD-030, FRD-003-01 | Reportes, Inventario, Sincronización, Almacenamiento, Proveedores, Sesiones, Ciclo Contable, Consentimiento Legal, Clientes, Permisos Empleados |
| POL-AUD-02 | Trazabilidad Universal | FRD-027-01, FRD-006-01-01, FRD-006-01-02, FRD-007-01, FRD-006-02, FRD-007-02, FRD-006-03, FRD-012-01, FRD-013, FRD-017, FRD-029, FRD-030, FRD-003-01 | Todos |
| POL-AUD-03 | Detección de Anomalías | FRD-027-01, FRD-027-02, FRD-017, FRD-013 | Reportes, Caja, Ciclo Contable, Sesiones |
| POL-PRIV-01 | Trazabilidad de Consentimiento y Alta de Datos Personales | FRD-029, FRD-030, FRD-003-01 | Registro Admin, Clientes (Fiados), Consentimiento Legal, Permisos Empleados |
| POL-PRIV-02 | Eliminación Protegida y Resguardo Contable Interno | FRD-030, FRD-003-01 | Clientes (Fiados), Archivo Contable, Permisos Empleados |

---

## Matriz Inversa: FRD → Políticas

| FRD | Políticas que lo Gobiernan |
|-----|---------------------------|
| FRD-001 (Seguridad Diaria) | POL-SEG-02, POL-SEG-03 |
| FRD-003 (Gestión Empleados) | POL-SEG-03 |
| FRD-003-01 (Matriz de Permisos de Empleados) | POL-FIN-01, POL-FIN-02, POL-FIN-03, POL-FIN-04, POL-FIN-05, POL-LOG-01, POL-LOG-03, POL-LOG-04, POL-SEG-01, POL-SEG-02, POL-SEG-03, POL-AUD-01, POL-AUD-02, POL-PRIV-01, POL-PRIV-02 |
| FRD-004 (Control de Caja) | POL-FIN-01, POL-FIN-02, POL-SEG-02 |
| FRD-006-01 (Núcleo Inventario) | POL-LOG-01, POL-LOG-02, POL-LOG-04, POL-AUD-01 |
| FRD-006-01-01 (Entradas) | POL-LOG-01, POL-AUD-02 |
| FRD-006-01-02 (Salidas) | POL-LOG-03, POL-AUD-02 |
| FRD-006-02 (Reembolsos) | POL-FIN-04, POL-FIN-05, POL-SEG-03, POL-AUD-02 |
| FRD-006-03 (Código Producto) | POL-LOG-01, POL-AUD-01, POL-AUD-02 |
| FRD-007-01 (Núcleo POS) | POL-FIN-05, POL-LOG-02, POL-LOG-03, POL-SEG-03, POL-AUD-02 |
| FRD-007-02 (Ticket Venta) | POL-AUD-01, POL-AUD-02 |
| FRD-007 (Ventas) | POL-FIN-05, POL-LOG-03, POL-FIN-01, POL-FIN-02, POL-FIN-03, POL-LOG-01, POL-AUD-01, POL-AUD-02 |
| FRD-009 (Clientes) | POL-FIN-01, POL-FIN-02, POL-FIN-04, POL-LOG-04 |
| FRD-012 (Sincronización Offline) | POL-LOG-01, POL-LOG-02, POL-LOG-04, POL-SEG-02, POL-AUD-01 |
| FRD-012-01 (Límites Sistema Offline) | POL-LOG-01, POL-LOG-02, POL-LOG-04, POL-SEG-02, POL-SEG-03, POL-AUD-01, POL-AUD-02, POL-FIN-01 |
| FRD-013 (Gestión Sesiones) | POL-SEG-02, POL-SEG-03, POL-LOG-01, POL-AUD-01, POL-AUD-02, POL-AUD-03 |
| FRD-017 (Ciclo Contable y Sesiones) | POL-FIN-01, POL-SEG-02, POL-SEG-03, POL-LOG-01, POL-AUD-01, POL-AUD-02, POL-AUD-03 |
| FRD-019 (Cuentas por Pagar) | POL-FIN-02, POL-FIN-03, POL-FIN-04, POL-LOG-01, POL-LOG-04, POL-SEG-03, POL-AUD-01 |
| FRD-024 (Fiados Clientes) | POL-FIN-03, POL-FIN-04, POL-LOG-04 |
| FRD-026 (Gastos) | POL-FIN-01, POL-FIN-02 |
| FRD-027 (Núcleo Caja) | POL-FIN-01, POL-FIN-02, POL-FIN-03, POL-LOG-01 |
| FRD-028 (Almacenamiento Local Seguro) | POL-FIN-01, POL-SEG-03, POL-AUD-01 |
| FRD-027-01 (Reportes) | POL-FIN-01, POL-SEG-01, POL-AUD-01, POL-AUD-02, POL-AUD-03 |
| FRD-027-02 (Límite 24h) | POL-SEG-02, POL-AUD-03 |
| FRD-029 (Consentimiento Legal Versionado) | POL-PRIV-01, POL-AUD-01, POL-AUD-02, POL-SEG-03 |
| FRD-030 (Derechos del Titular y Eliminación Contable Protegida) | POL-PRIV-02, POL-PRIV-01, POL-AUD-01, POL-AUD-02, POL-SEG-03 |

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
| 1.1 | 2026-10-24 | Arquitecto de Producto | Sincronización de FRD-012-01, FRD-013 y FRD-017 en ambas matrices tras formalización integral de la triada offline, sesiones y contabilidad. |
| 1.2 | 2026-11-08 | Arquitecto de Producto | Incorporación de POL-PRIV-01 y sincronización de FRD-029 (Consentimiento Legal Versionado) en ambas matrices. |
| 1.3 | 2026-11-10 | Arquitecto de Producto | Incorporación de POL-PRIV-02 y sincronización de FRD-030 (Derechos del Titular y Eliminación Contable Protegida) en ambas matrices. |
| 1.4 | 2026-11-15 | Arquitecto de Producto | Sincronización bidireccional de FRD-003-01 (Matriz de Permisos de Empleados) alineada a POL-LOG-03, POL-SEG-01 y POL-SEG-03. |

---

**Firmado:** Arquitecto de Producto  
**Fecha:** 2026-10-24