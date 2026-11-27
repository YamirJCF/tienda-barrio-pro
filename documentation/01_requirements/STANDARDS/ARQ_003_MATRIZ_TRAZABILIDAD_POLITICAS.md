# 📐 Estándar ARQ-003: Matriz de Trazabilidad Política → Regla

**Versión:** 1.6  
**Fecha:** 2026-11-26  
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
| POL-FIN-01 | Solidez de Caja (Liquidez Real y Caja Dedicada POS) | FRD-027, FRD-027-01, FRD-026, FRD-022, FRD-004, FRD-028, FRD-007, FRD-009, FRD-012-01, FRD-017, FRD-018, FRD-019, FRD-003-01 | Caja Dedicada POS, Reportes, Gastos, Multicanal, Proveedores (Pagos Externos), Almacenamiento Seguro, Offline, Ciclo Contable, P&L, Permisos Empleados |
| POL-FIN-02 | Segregación de Canales Monetarios (Efectivo, Nequi, Llave BRE) | FRD-027, FRD-026, FRD-022, FRD-004, FRD-019, FRD-006-02, FRD-007, FRD-009, FRD-024, FRD-003-01 | Caja, Gastos, Multicanal, Proveedores, Reembolsos, Fiados, Permisos Empleados |
| POL-FIN-03 | Aislamiento de Promesas de Pago | FRD-024, FRD-027, FRD-019, FRD-007, FRD-003-01 | Fiados, Proveedores, Caja, Permisos Empleados |
| POL-FIN-04 | Transformación de Promesa a Liquidez | FRD-024, FRD-006-02, FRD-019, FRD-009, FRD-003-01 | Fiados, Proveedores, Reembolsos, Permisos Empleados |
| POL-FIN-05 | Distribución por Tipo de Transacción en POS (Contado, Fiado, Consumo Personal) | FRD-007-01, FRD-006-01-02, FRD-006-02, FRD-018, FRD-003-01 | POS, Consumo Personal, Reembolsos, P&L, Permisos Empleados |
| POL-LOG-01 | Independencia Logística-Financiera | FRD-027, FRD-006, FRD-006-01, FRD-006-01-01, FRD-006-01-02, FRD-012-01, FRD-018, FRD-019, FRD-007, FRD-013, FRD-017, FRD-003-01 | Caja, Inventario, Entradas, Salidas/Mermas, Sincronización, P&L, Proveedores, Sesiones, Ciclo Contable, Permisos Empleados |
| POL-LOG-02 | Verdad Física (Anti-Negativos y Etiqueta `"merma"` en Reembolsos) | FRD-006, FRD-006-01, FRD-006-02, FRD-007-01, FRD-012-01, FRD-003-01 | Inventario, Reembolsos, POS, Sincronización, Permisos Empleados |
| POL-LOG-03 | Salidas Logísticas, Consumos y Ajustes con Firma Individual | FRD-006, FRD-006-01-01, FRD-006-01-02, FRD-007-01, FRD-018, FRD-019, FRD-003-01 | Inventario, Salidas/Mermas, Consumos (Negocio/Personal), Ajustes Físicos, POS, P&L, Permisos Empleados |
| POL-LOG-04 | Inmediatez Logística | FRD-024, FRD-006-01, FRD-006-02, FRD-012-01, FRD-019, FRD-009, FRD-003-01 | Fiados, Proveedores, Inventario, Reembolsos, Sincronización, Permisos Empleados |
| POL-SEG-01 | Arqueo Físico de Efectivo, Cierre Diferenciado por Rol y Margen de Monedas (`P_MARGEN_DESCUADRE_EFECTIVO`) | FRD-004, FRD-017, FRD-027-01, FRD-003-01 | Caja, Ciclo Contable, Reportes de Caja, Permisos Empleados |
| POL-SEG-02 | Caducidad del Turno (24h) y Continuidad Nocturna | FRD-027-02, FRD-001, FRD-012-01, FRD-004, FRD-013, FRD-017, FRD-003-01 | Límite 24h, Seguridad, Pase Diario, Sincronización, Caja, Sesiones, Ciclo Contable, Permisos Empleados |
| POL-SEG-03 | Control de Acceso (4 Permisos, 1 Dispositivo/Cuenta y Propiedad del Turno) | FRD-001, FRD-002, FRD-003, FRD-003-01, FRD-004, FRD-005, FRD-006, FRD-006-02, FRD-007-01, FRD-008, FRD-009, FRD-012-01, FRD-013, FRD-017, FRD-018, FRD-019, FRD-022, FRD-024, FRD-026, FRD-027-01, FRD-027-02, FRD-028, FRD-029, FRD-030 | Todos los módulos |
| POL-AUD-01 | Inmutabilidad Histórica y Fotografía de Firma | FRD-003, FRD-004, FRD-005, FRD-006, FRD-006-01, FRD-006-01-02, FRD-006-02, FRD-007, FRD-012-01, FRD-013, FRD-017, FRD-019, FRD-027-01, FRD-028, FRD-029, FRD-030, FRD-003-01 | Auditoría, Empleados, Caja, Reportes, Inventario, Reembolsos, Sincronización, Proveedores, Clientes, Permisos Empleados |
| POL-AUD-02 | Trazabilidad Universal y Firma Individual Seccionada | FRD-003-01, FRD-004, FRD-005, FRD-006, FRD-006-01-01, FRD-006-01-02, FRD-006-02, FRD-006-03, FRD-007-01, FRD-007-02, FRD-008, FRD-012-01, FRD-013, FRD-017, FRD-018, FRD-022, FRD-026, FRD-027-01, FRD-029, FRD-030 | Todos |
| POL-AUD-03 | Detección de Anomalías y Alertas al Administrador | FRD-003-01, FRD-004, FRD-005, FRD-006, FRD-006-02, FRD-013, FRD-017, FRD-027-01, FRD-027-02 | Permisos Empleados, Caja, Auditoría, Inventario, Reembolsos, Ciclo Contable, Reportes |
| POL-PRIV-01 | Trazabilidad de Consentimiento y Alta de Clientes (Exclusiva Admin) | FRD-029, FRD-030, FRD-009, FRD-003-01 | Registro Admin, Clientes (Fiados), Consentimiento Legal, Permisos Empleados |
| POL-PRIV-02 | Eliminación Protegida y Resguardo Contable Interno | FRD-030, FRD-009, FRD-003-01 | Clientes (Fiados), Archivo Contable, Permisos Empleados |
| POL-PROD-01 | Barrera Lógica, Voluntariedad y Lenguaje Único del Tendero (`ARQ-005`) | FRD-003-01, FRD-004, FRD-006, FRD-006-01-01, FRD-007-01, FRD-026, FRD-027-01 | Transversal (Caja, Gastos, Inventario/Entradas, POS, Permisos Empleados) |

---

## Matriz Inversa: FRD → Políticas

| FRD | Políticas que lo Gobiernan |
|-----|---------------------------|
| FRD-001 (Seguridad Diaria) | POL-SEG-02, POL-SEG-03 |
| FRD-002 (Autorización Estricta) | POL-SEG-03 |
| FRD-003 (Gestión Empleados) | POL-SEG-03, POL-AUD-01 |
| FRD-003-01 (Matriz de Permisos de Empleados) | POL-FIN-01, POL-FIN-02, POL-FIN-03, POL-FIN-04, POL-FIN-05, POL-LOG-01, POL-LOG-02, POL-LOG-03, POL-LOG-04, POL-SEG-01, POL-SEG-02, POL-SEG-03, POL-AUD-01, POL-AUD-02, POL-AUD-03, POL-PRIV-01, POL-PRIV-02, POL-PROD-01 |
| FRD-004 (Control de Caja) | POL-FIN-01, POL-FIN-02, POL-SEG-01, POL-SEG-02, POL-SEG-03, POL-AUD-01, POL-AUD-02, POL-AUD-03, POL-PROD-01 |
| FRD-005 (Auditoría y Trazabilidad) | POL-SEG-03, POL-AUD-01, POL-AUD-02, POL-AUD-03 |
| FRD-006 (Inventario) | POL-LOG-01, POL-LOG-02, POL-LOG-03, POL-SEG-03, POL-AUD-01, POL-AUD-02, POL-AUD-03, POL-PROD-01 |
| FRD-006-01 (Núcleo Inventario) | POL-LOG-01, POL-LOG-02, POL-LOG-04, POL-AUD-01 |
| FRD-006-01-01 (Entradas) | POL-LOG-01, POL-LOG-03, POL-AUD-02, POL-PROD-01 |
| FRD-006-01-02 (Salidas, Consumos y Ajustes) | POL-FIN-05, POL-LOG-01, POL-LOG-03, POL-AUD-01, POL-AUD-02 |
| FRD-006-02 (Reembolsos) | POL-FIN-02, POL-FIN-04, POL-FIN-05, POL-LOG-02, POL-LOG-04, POL-SEG-03, POL-AUD-01, POL-AUD-02, POL-AUD-03 |
| FRD-006-03 (Código Producto) | POL-LOG-01, POL-AUD-01, POL-AUD-02 |
| FRD-007-01 (Núcleo POS) | POL-FIN-05, POL-LOG-02, POL-LOG-03, POL-SEG-03, POL-AUD-02, POL-PROD-01 |
| FRD-007-02 (Ticket Venta) | POL-AUD-01, POL-AUD-02 |
| FRD-007 (Ventas) | POL-FIN-05, POL-FIN-01, POL-FIN-02, POL-FIN-03, POL-LOG-01, POL-AUD-01, POL-AUD-02 |
| FRD-008 (Resumen Diario y Abastecimiento) | POL-SEG-03, POL-AUD-02 |
| FRD-009 (Clientes) | POL-FIN-01, POL-FIN-02, POL-FIN-04, POL-LOG-04, POL-SEG-03, POL-PRIV-01, POL-PRIV-02 |
| FRD-012 (Sincronización Offline) | POL-LOG-01, POL-LOG-02, POL-LOG-04, POL-SEG-02, POL-AUD-01 |
| FRD-012-01 (Límites Sistema Offline) | POL-LOG-01, POL-LOG-02, POL-LOG-04, POL-SEG-02, POL-SEG-03, POL-AUD-01, POL-AUD-02, POL-FIN-01 |
| FRD-013 (Gestión Sesiones) | POL-SEG-02, POL-SEG-03, POL-LOG-01, POL-AUD-01, POL-AUD-02, POL-AUD-03 |
| FRD-017 (Ciclo Contable y Sesiones) | POL-FIN-01, POL-SEG-01, POL-SEG-02, POL-SEG-03, POL-LOG-01, POL-AUD-01, POL-AUD-02, POL-AUD-03 |
| FRD-018 (Control Operacional y Financiero) | POL-FIN-01, POL-FIN-05, POL-LOG-01, POL-LOG-03, POL-SEG-03, POL-AUD-02 |
| FRD-019 (Cuentas por Pagar) | POL-FIN-01, POL-FIN-02, POL-FIN-03, POL-FIN-04, POL-LOG-01, POL-LOG-03, POL-LOG-04, POL-SEG-03, POL-AUD-01 |
| FRD-022 (Gastos Multicanal) | POL-FIN-01, POL-FIN-02, POL-SEG-03, POL-AUD-02 |
| FRD-024 (Fiados Clientes) | POL-FIN-02, POL-FIN-03, POL-FIN-04, POL-LOG-04, POL-SEG-03 |
| FRD-026 (Gastos Inmediatos) | POL-FIN-01, POL-FIN-02, POL-SEG-03, POL-AUD-02, POL-PROD-01 |
| FRD-027 (Núcleo Caja) | POL-FIN-01, POL-FIN-02, POL-FIN-03, POL-LOG-01 |
| FRD-028 (Almacenamiento Local Seguro) | POL-FIN-01, POL-SEG-03, POL-AUD-01 |
| FRD-027-01 (Reportes de Caja) | POL-FIN-01, POL-SEG-01, POL-SEG-03, POL-AUD-01, POL-AUD-02, POL-AUD-03, POL-PROD-01 |
| FRD-027-02 (Límite 24h) | POL-SEG-02, POL-SEG-03, POL-AUD-03 |
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
| 1.5 | 2026-11-18 | Arquitecto de Producto | Sincronización general con ARQ-002 v1.4 y FRD-003-01 consolidado (4 permisos delegables, Cierre Asistido, salidas logísticas `$0`, consumo negocio vs. personal, etiqueta `"merma"` en reembolsos y reportes/proveedores/clientes CRUD exclusivos del Admin). |
| 1.6 | 2026-11-26 | Arquitecto de Producto | Sincronización con `ARQ-002` v1.5 y `ARQ-005` v1.0: actualización de `POL-SEG-01` (arqueo físico de efectivo + `P_MARGEN_DESCUADRE_EFECTIVO`) e incorporación de `POL-PROD-01` en ambas matrices. |

---

**Firmado:** Arquitecto de Producto  
**Fecha:** 2026-11-26
