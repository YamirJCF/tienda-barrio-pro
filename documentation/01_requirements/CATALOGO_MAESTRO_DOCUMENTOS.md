# 📋 Catálogo Maestro de Documentos — Tienda Barrio Pro

> **Versión:** 1.0  
> **Fecha:** 2026-08-07  
> **Propósito:** Mapa oficial y único de todos los documentos del proyecto. Sirve como hoja de ruta de implementación y registro de trazabilidad documental.  
> **Norma:** Todo documento nuevo debe registrarse aquí antes de ser aprobado.

---

## Leyenda de Estados

| Ícono | Tipo | Significado |
|-------|------|-------------|
| 🔴 | FRD/SDD | Borrador / Sin cobertura SDD |
| 🟡 | SDD | Validado localmente (PAC ejecutado) |
| 🟠 | SDD | Aprobado con Deuda Técnica documentada |
| 🟢 | Cualquiera | Aprobado y alineado con BD |
| ⚠️ | Cualquiera | Requiere saneamiento (viola el estándar) |
| 🚫 | FRD | Deprecated — conservado para trazabilidad |

---

## Módulo 001 — Seguridad Diaria (Zero Trust)

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-001 | [FRD_001_SEGURIDAD_DIARIA.md](FRD/FRD_001_SEGURIDAD_DIARIA.md) | FRD | 🟢 | ✅ SDD_001 | Documento canónico |
| FRD-001-1 | [FRD_001_1_PASE_DIARIO_STABLE.md](FRD/FRD_001_1_PASE_DIARIO_STABLE.md) | FRD | 🟢 | ✅ SDD_001 | Versión estabilizada. Separado por diseño (trazabilidad). |
| SDD-001 | [SDD_001_SEGURIDAD_DIARIA.md](SDD/SDD_001_SEGURIDAD_DIARIA.md) | SDD | 🟡 Validado | — | **Pendiente Fase 2C:** Agregar Casos C/D, campo retry_count |

---

## Módulo 002 — Registro y Autorización

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-002 | [FRD_002_REGISTRO_ADMIN.md](FRD/FRD_002_REGISTRO_ADMIN.md) | FRD | 🟢 | ✅ SDD_002 | — |
| FRD-002-A | [FRD_002_AUTORIZACION_ESTRICTA.md](FRD/FRD_002_AUTORIZACION_ESTRICTA.md) | FRD | 🟢 | 🔴 SIN SDD | **Pendiente Fase 3-P1** |
| FRD-002-1 | [FRD_002_1_CAMBIO_CONTRASENA.md](FRD/FRD_002_1_CAMBIO_CONTRASENA.md) | FRD | 🟢 | ✅ SDD_002_1 | — |
| SDD-002 | [SDD_002_REGISTRO_ADMIN.md](SDD/SDD_002_REGISTRO_ADMIN.md) | SDD | 🟡 Validado | — | — |
| SDD-002-1 | [SDD_002_1_CAMBIO_CONTRASENA.md](SDD/SDD_002_1_CAMBIO_CONTRASENA.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 003 — Independencia Logística-Contable

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-003 | [FRD_003_GESTION_EMPLEADOS.md](FRD/FRD_003_GESTION_EMPLEADOS.md) | FRD | 🟢 | ✅ SDD_003 | — |
| FRD-003-ILC | [FRD_003_INDEPENDENCIA_LOGISTICA_CONTABLE.md](FRD/FRD_003_INDEPENDENCIA_LOGISTICA_CONTABLE.md) | FRD | 🟢 | 🔴 SIN SDD | Coexiste con FRD_019 vía modelo cruce de tres vías. **Pendiente Fase 3-P1** |
| SDD-003 | [SDD_003_GESTION_EMPLEADOS.md](SDD/SDD_003_GESTION_EMPLEADOS.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 004 — Control de Caja

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-004 | [FRD_004_CONTROL_DE_CAJA.md](FRD/FRD_004_CONTROL_DE_CAJA.md) | FRD | ⚠️ | ✅ SDD_004 | **Pendiente Fase 2B:** Eliminar referencias a PIN (D-01 resuelto) |
| FRD-004-1 | [FRD_004_1_GESTION_PIN_CAJA.md](FRD/FRD_004_1_GESTION_PIN_CAJA.md) | FRD | 🚫 DEPRECATED | — | PIN erradicado (D-01, 2026-08-07). Conservado para trazabilidad. |
| FRD-004-MC | [FRD_004_CAJA_ESTRICTA_MULTICANAL.md](FRD/FRD_004_CAJA_ESTRICTA_MULTICANAL.md) | FRD | 🟢 | 🔴 SIN SDD propio | Absorbido parcialmente por SDD_004 y SDD_027. **Revisar tras SDD_020** |
| SDD-004 | [SDD_004_CONTROL_DE_CAJA.md](SDD/SDD_004_CONTROL_DE_CAJA.md) | SDD | 🟡 Validado | — | **Pendiente Fase 2B:** Agregar referencia formal a D-01 |

---

## Módulo 005 — Auditoría

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-005-INV | [FRD_005_AUDITORIA_INVIOLABLE.md](FRD/FRD_005_AUDITORIA_INVIOLABLE.md) | FRD | 🟢 | 🔴 SIN SDD | Principio de Inmutabilidad (contrapesos). **Pendiente Fase 3-P3** |
| FRD-005-TRZ | [FRD_005_AUDITORIA_TRAZABILIDAD.md](FRD/FRD_005_AUDITORIA_TRAZABILIDAD.md) | FRD | 🟢 | 🔴 SIN SDD | Principio de Trazabilidad. Complementario a FRD_005_INVIOLABLE. **Pendiente Fase 3-P3** |

---

## Módulo 006 — Inventario

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-006 | [FRD_006_INVENTARIO.md](FRD/FRD_006_INVENTARIO.md) | FRD | 🟢 | 🔴 SIN SDD padre | Documento padre. **Pendiente Fase 3-P3** |
| FRD-006-01 | [FRD_006_01_NUCLEO_INVENTARIO.md](FRD/FRD_006_01_NUCLEO_INVENTARIO.md) | FRD | 🟢 | ✅ SDD_006_01 | — |
| FRD-006-01-01 | [FRD_006_01_01_MOVIMIENTOS_ENTRADA_INVENTARIO.md](FRD/FRD_006_01_01_MOVIMIENTOS_ENTRADA_INVENTARIO.md) | FRD | 🟢 | ✅ SDD_006_01_01 | — |
| FRD-006-01-02 | [FRD_006_01_02_MOVIMIENTOS_SALIDA_INVENTARIO.md](FRD/FRD_006_01_02_MOVIMIENTOS_SALIDA_INVENTARIO.md) | FRD | 🟢 | ✅ SDD_006_01_02 | — |
| FRD-006-02 | [FRD_006_02_GESTOR_REEMBOLSOS.md](FRD/FRD_006_02_GESTOR_REEMBOLSOS.md) | FRD | 🟢 | ✅ SDD_006_02 | — |
| FRD-006-03 | [FRD_006_03_CODIGO_PRODUCTO.md](FRD/FRD_006_03_CODIGO_PRODUCTO.md) | FRD | 🟢 | ✅ SDD_006_03 | — |
| SDD-006-01 | [SDD_006_01_NUCLEO_INVENTARIO.md](SDD/SDD_006_01_NUCLEO_INVENTARIO.md) | SDD | 🟡 Validado | — | — |
| SDD-006-01-01 | [SDD_006_01_01_MOVIMIENTOS_ENTRADA.md](SDD/SDD_006_01_01_MOVIMIENTOS_ENTRADA.md) | SDD | 🟡 Validado | — | — |
| SDD-006-01-02 | [SDD_006_01_02_MOVIMIENTOS_SALIDA.md](SDD/SDD_006_01_02_MOVIMIENTOS_SALIDA.md) | SDD | 🟡 Validado | — | — |
| SDD-006-02 | [SDD_006_02_GESTOR_REEMBOLSOS.md](SDD/SDD_006_02_GESTOR_REEMBOLSOS.md) | SDD | 🟡 Validado | — | — |
| SDD-006-03 | [SDD_006_03_CODIGO_PRODUCTO.md](SDD/SDD_006_03_CODIGO_PRODUCTO.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 007 — Ventas (POS)

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-007 | [FRD_007_VENTAS.md](FRD/FRD_007_VENTAS.md) | FRD | 🟢 | 🔴 SIN SDD padre | Documento padre. **Pendiente Fase 3-P3** |
| FRD-007-01 | [FRD_007_01_NUCLEO_POS.md](FRD/FRD_007_01_NUCLEO_POS.md) | FRD | 🟢 | ✅ SDD_007_01 | Target: RPC v3 (D-03 resuelto) |
| FRD-007-02 | [FRD_007_02_TICKET_DE_VENTA.md](FRD/FRD_007_02_TICKET_DE_VENTA.md) | FRD | 🟢 | ✅ SDD_007_02 | — |
| SDD-007-01 | [SDD_007_01_NUCLEO_POS.md](SDD/SDD_007_01_NUCLEO_POS.md) | SDD | 🟠 **Aprobado con Deuda** | — | **Pendiente Fase 2C:** Cambiar estado, actualizar §6.3 idempotencia |
| SDD-007-02 | [SDD_007_02_TICKET_DE_VENTA.md](SDD/SDD_007_02_TICKET_DE_VENTA.md) | SDD | 🟡 Validado | — | — |
| DSD-007-01-v3 | DSD_007_01_v3_MIGRATION.md | DSD | 🔴 **POR CREAR** | — | **Prioridad P1 Fase 2C** — Migración SQL para rpc_procesar_venta_v3 |

---

## Módulo 008 — Reportes

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-008 | [FRD_008_REPORTES.md](FRD/FRD_008_REPORTES.md) | FRD | 🟢 | ✅ SDD_008 | — |
| SDD-008 | [SDD_008_REPORTES.md](SDD/SDD_008_REPORTES.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 009 — Clientes

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-009 | [FRD_009_CLIENTES.md](FRD/FRD_009_CLIENTES.md) | FRD | 🟢 | ✅ SDD_009 | — |
| SDD-009 | [SDD_009_CLIENTES.md](SDD/SDD_009_CLIENTES.md) | SDD | 🟡 Validado | — | **Pendiente Fase 2C:** Agregar campo phone, Caso E búsqueda, propagación cupo global |

---

## Módulo 010 — Historial de Precios y Valoración FIFO

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-010 | [FRD_010_HISTORIAL_PRECIOS.md](FRD/FRD_010_HISTORIAL_PRECIOS.md) | FRD | 🟢 | ✅ SDD_010 | — |
| FRD-010-FIFO | [FRD_010_VALORACION_INVENTARIO_FIFO.md](FRD/FRD_010_VALORACION_INVENTARIO_FIFO.md) | FRD | 🟢 | ✅ SDD_010_016 | — |
| FRD-016 | [FRD_016_CORRECCION_COSTO_VENTAS.md](FRD/FRD_016_CORRECCION_COSTO_VENTAS.md) | FRD | 🟢 | 🔴 SIN SDD | Renumerado desde FRD_015_CORRECCION |
| SDD-010 | [SDD_010_HISTORIAL_PRECIOS.md](SDD/SDD_010_HISTORIAL_PRECIOS.md) | SDD | 🟡 Validado | — | — |
| SDD-010-016 | [SDD_010_016_VALORACION_FIFO.md](SDD/SDD_010_016_VALORACION_FIFO.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 011 — Manejo de Errores

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-011 | [FRD_011_MANEJO_ERRORES.md](FRD/FRD_011_MANEJO_ERRORES.md) | FRD | 🟢 | ✅ SDD_011 | — |
| SDD-011 | [SDD_011_MANEJO_ERRORES.md](SDD/SDD_011_MANEJO_ERRORES.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 012 — Sincronización Offline

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-012 | [FRD_012_SINCRONIZACION_OFFLINE.md](FRD/FRD_012_SINCRONIZACION_OFFLINE.md) | FRD | 🟢 | ✅ SDD_012 | Documento principal |
| FRD-012-01 | [FRD_012_01_LIMITES_SISTEMA_OFFLINE.md](FRD/FRD_012_01_LIMITES_SISTEMA_OFFLINE.md) | FRD | 🟢 | 🔴 SIN SDD | **Pendiente Fase 3-P2:** Ampliar SDD_012 con §8 Límites |
| FRD-012-R | [FRD_012_REMEDIACION_OFFLINE.md](FRD/FRD_012_REMEDIACION_OFFLINE.md) | FRD | 🟢 | 🔴 SIN SDD | **Pendiente Fase 3-P2:** Ampliar SDD_012 con §9 Remediación |
| SDD-012 | [SDD_012_SINCRONIZACION_OFFLINE.md](SDD/SDD_012_SINCRONIZACION_OFFLINE.md) | SDD | 🟡 Validado | — | Incompleto: falta §8 Límites y §9 Remediación |

---

## Módulo 013 — Gestión de Sesiones

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-013 | [FRD_013_GESTION_SESIONES.md](FRD/FRD_013_GESTION_SESIONES.md) | FRD | 🟢 | ✅ SDD_013 | — |
| SDD-013 | [SDD_013_GESTION_SESIONES.md](SDD/SDD_013_GESTION_SESIONES.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 014 — Venta Forzada y Auditoría

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-014 | [FRD_014_VENTA_FORZADA_Y_AUDITORIA.md](FRD/FRD_014_VENTA_FORZADA_Y_AUDITORIA.md) | FRD | 🟢 | ✅ SDD_014 | — |
| SDD-014 | [SDD_014_VENTA_FORZADA_Y_AUDITORIA.md](SDD/SDD_014_VENTA_FORZADA_Y_AUDITORIA.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 015 — Gestión de Dispositivos

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-015 | [FRD_015_GESTION_DISPOSITIVOS.md](FRD/FRD_015_GESTION_DISPOSITIVOS.md) | FRD | ⚠️ Viola estándar | 🔴 SIN SDD | **Pendiente Fase 2A:** Reescribir como FRD válido |
| SDD-015 | — | SDD | 🔴 POR CREAR | — | **Pendiente Fase 3-P2** (después de reescribir FRD) |

---

## Módulo 017 — Ciclo Contable y Sesiones

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-017 | [FRD_017_CICLO_CONTABLE_Y_SESIONES.md](FRD/FRD_017_CICLO_CONTABLE_Y_SESIONES.md) | FRD | 🟢 | ✅ SDD_017 | — |
| SDD-017 | [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](SDD/SDD_017_CICLO_CONTABLE_Y_SESIONES.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 018 — Control Operacional y Análisis Financiero

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-018 | [FRD_018_CONTROL_OPERACIONAL_Y_ANALISIS_FINANCIERO.md](FRD/FRD_018_CONTROL_OPERACIONAL_Y_ANALISIS_FINANCIERO.md) | FRD | ⚠️ Viola estándar | ✅ SDD_018 | **Pendiente Fase 2A:** Eliminar bloque SQL |
| SDD-018 | [SDD_018_CONTROL_OPERACIONAL.md](SDD/SDD_018_CONTROL_OPERACIONAL.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 019 — Cuentas por Pagar (Proveedores)

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-019 | [FRD_019_CUENTAS_POR_PAGAR.md](FRD/FRD_019_CUENTAS_POR_PAGAR.md) | FRD | ⚠️ Viola estándar | ✅ SDD_019 | **Pendiente Fase 2A:** Eliminar nombres de archivos/RPCs, actualizar Regla 1 (D-02) |
| SDD-019 | [SDD_019_CUENTAS_POR_PAGAR.md](SDD/SDD_019_CUENTAS_POR_PAGAR.md) | SDD | 🟡 Validado | — | **Pendiente Fase 2C:** Bloqueo sobre-abono, contrato remanente, §2.1 Trigger A (D-02), §3.2 idempotencia (D-04) |

---

## Módulo 020 — Caja Multicanal

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-020 | [FRD_020_CAJA_MULTICANAL.md](FRD/FRD_020_CAJA_MULTICANAL.md) | FRD | 🟢 | 🔴 SIN SDD | **Prioridad P1 Fase 3** — SDD_004 y SDD_027 dependen de este |
| SDD-020 | — | SDD | 🔴 POR CREAR | — | **Prioridad P1** |

---

## Módulo 021-023 — Multicanal (Historiales, Gastos, Impacto Cruzado)

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-021 | [FRD_021_HISTORIALES_MULTICANAL.md](FRD/FRD_021_HISTORIALES_MULTICANAL.md) | FRD | 🟢 | 🔴 SIN SDD | **Prioridad P1 Fase 3** |
| FRD-022 | [FRD_022_GASTOS_MULTICANAL.md](FRD/FRD_022_GASTOS_MULTICANAL.md) | FRD | 🟢 | 🔴 SIN SDD | **Prioridad P1 Fase 3** |
| FRD-023 | [FRD_023_IMPACTO_CRUZADO_MULTICANAL.md](FRD/FRD_023_IMPACTO_CRUZADO_MULTICANAL.md) | FRD | 🟢 | 🔴 SIN SDD | **Prioridad P2 Fase 3** |
| SDD-021 | — | SDD | 🔴 POR CREAR | — | **Prioridad P1** |
| SDD-022 | — | SDD | 🔴 POR CREAR | — | **Prioridad P1** |
| SDD-023 | — | SDD | 🔴 POR CREAR | — | **Prioridad P2** |

---

## Módulo 024-026 — Políticas Financieras

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-024 | [FRD_024_POLITICA_FIADOS_CLIENTES.md](FRD/FRD_024_POLITICA_FIADOS_CLIENTES.md) | FRD | 🟢 | ✅ SDD_024 | — |
| FRD-025 | [FRD_025_POLITICA_DEUDAS_PROVEEDORES.md](FRD/FRD_025_POLITICA_DEUDAS_PROVEEDORES.md) | FRD | 🟢 | ✅ SDD_025 | — |
| FRD-026 | [FRD_026_POLITICA_GASTOS_INMEDIATOS.md](FRD/FRD_026_POLITICA_GASTOS_INMEDIATOS.md) | FRD | 🟢 | ✅ SDD_026 | — |
| SDD-024 | [SDD_024_POLITICA_FIADOS.md](SDD/SDD_024_POLITICA_FIADOS.md) | SDD | 🟡 Validado | — | — |
| SDD-025 | [SDD_025_POLITICA_DEUDAS_PROVEEDORES.md](SDD/SDD_025_POLITICA_DEUDAS_PROVEEDORES.md) | SDD | 🟡 Validado | — | — |
| SDD-026 | [SDD_026_POLITICA_GASTOS_INMEDIATOS.md](SDD/SDD_026_POLITICA_GASTOS_INMEDIATOS.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 027 — Caja Diaria

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-027 | [FRD_027_NUCLEO_CAJA_DIARIA.md](FRD/FRD_027_NUCLEO_CAJA_DIARIA.md) | FRD | 🟢 | ✅ SDD_027 | — |
| FRD-027-01 | [FRD_027_01_REPORTES_DE_CAJA.md](FRD/FRD_027_01_REPORTES_DE_CAJA.md) | FRD | 🟢 | ✅ SDD_027_01 | — |
| FRD-027-02 | [FRD_027_02_LIMITE_24_HORAS_CAJA.md](FRD/FRD_027_02_LIMITE_24_HORAS_CAJA.md) | FRD | 🟢 | ✅ SDD_027_02 | — |
| SDD-027 | [SDD_027_NUCLEO_CAJA_DIARIA.md](SDD/SDD_027_NUCLEO_CAJA_DIARIA.md) | SDD | 🟡 Validado | — | — |
| SDD-027-01 | [SDD_027_01_REPORTES_CAJA.md](SDD/SDD_027_01_REPORTES_CAJA.md) | SDD | 🟡 Validado | — | — |
| SDD-027-02 | [SDD_027_02_LIMITE_24_HORAS.md](SDD/SDD_027_02_LIMITE_24_HORAS.md) | SDD | 🟡 Validado | — | — |

---

## Módulo 028 — Almacenamiento Local Seguro

| # | Documento | Tipo | Estado | SDD Cobertura | Notas |
|---|-----------|------|--------|---------------|-------|
| FRD-028 | [FRD_028_ALMACENAMIENTO_LOCAL_SEGURO.md](FRD/FRD_028_ALMACENAMIENTO_LOCAL_SEGURO.md) | FRD | 🟢 | ✅ SDD_028 | — |
| SDD-028 | [SDD_028_ALMACENAMIENTO_LOCAL.md](SDD/SDD_028_ALMACENAMIENTO_LOCAL.md) | SDD | 🟡 Validado | — | — |

---

## Documentos Especiales / Principios Transversales

| # | Documento | Tipo | Estado | Notas |
|---|-----------|------|--------|-------|
| ARQ-001 | [FRD_001_AUTORIDAD_DEL_SERVIDOR.md](FRD/FRD_001_AUTORIDAD_DEL_SERVIDOR.md) | FRD/Principio | 🔴 SIN SDD | Principio transversal. Evaluar: ¿SDD o SPEC técnica? **Pendiente Fase 3-P3** |

---

## Resumen de Cobertura Final

| Métrica | Valor | Estado |
|---------|-------|--------|
| Total FRDs Catalogados | 46 | 🟢 Alineados |
| Cobertura de SDDs | 100% | 🟢 46/46 Cubiertos |
| FRDs con SDD Saneados | 46 | 🟢 Sin violaciones de forma |
| SDDs Creados / Ampliados (Fase 3) | 13 | 🟢 Completados |
| SDDs Corregidos (Fase 2C) | 4 | 🟢 Completados |
| DSD de Migración Creado | 1 (`DSD_007_01_v3_MIGRATION.md`) | 🟢 Creado |
| SPEC Técnica Creada | 1 (`SPEC_001_AUTORIDAD_DEL_SERVIDOR.md`) | 🟢 Creado |
| FRDs Deprecated | 2 (`FRD_004_1`, `FRD_015_COSTO_VENTAS` sustituido por `FRD_016`) | 🚫 Marcados |

---

## Changelog del Catálogo

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | 2026-08-07 | Creación inicial — 76 documentos catalogados. Decisiones D-01 a D-04 incorporadas. |
| 2.0 | 2026-08-07 | Consolidación total de Fases 1, 2A, 2B, 2C y 3. Cobertura 100% SDD/SPEC completada. |

