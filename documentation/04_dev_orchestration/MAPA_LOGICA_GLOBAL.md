# 🗺️ Mapa de Lógica Global (v3.0)

> **Módulos documentados:** 46 / 46 (100% FRD/SDD)

---

## 📁 Estructura Principal de Carpetas (`documentation/`)

```
documentation/
├── 01_requirements/     # Catálogo Maestro, FRDs, SDDs, DSDs, Reglas de Negocio
├── 02_architecture/     # Diseño de Base de Datos, Políticas de Seguridad, Arquitectura Técnica
├── 03_ui_ux_design/     # Diseño de Interfaz, Flujos de Usuario, Wireframes y Sistema de Diseño
├── 04_dev_orchestration/# Mapas de Lógica, Órdenes de Trabajo (WO), QA y Reportes de Auditoría
└── archive/             # Documentos obsoletos o sueltos archivados para trazabilidad
```

---

## 🎨 Estructura de Carpeta 03_UI_UX_DESIGN

```
03_ui_ux_design/
├── README.md                       # Índice y principios de diseño
├── 01_USER_FLOWS.md                # Flujos de usuario
├── 02_INFORMATION_ARCHITECTURE.md  # Arquitectura de información
├── 03_WIREFRAMES_DESCRIPTIVOS.md   # Wireframes detallados
├── 04_DESIGN_SYSTEM.md             # Sistema de diseño
├── 05_COMPONENT_LOGIC.md           # Lógica de componentes
├── 06_SECURITY_ACCESS_UX.md        # UX de acceso y seguridad
├── 07_UUID_ADAPTATION.md           # Adaptaciones UX para UUID
├── 08_POS_CHECKOUT.md              # Flujo UX del POS
├── 09_REPORTS_DASHBOARD.md         # Dashboard y Reportes
└── UXD/                            # Documentos de diseño UX modulares (UXD_*)
    ├── UXD_002_WAITING_ROOM.md
    ├── UXD_008_SMART_DAILY_SUMMARY.md
    ├── UXD_008_SMART_SUPPLY.md
    ├── UXD_019_CUENTAS_POR_PAGAR.md
    ├── UXD_HISTORY_UI.md
    └── UXD_STORE_CONFIGURATION.md
```

---

## 🏗️ Estructura de Carpeta 02_ARCHITECTURE

> **Nota:** El detalle completo del estado y desfase de estos documentos se encuentra en el `AUDIT_REPORT_ARCHITECTURE.md`.

```
02_architecture/
├── DATA_DICTIONARY.md                  # Diccionario Central de Datos
├── DATA_MODEL_ERD.md                   # Diagrama ERD Central
├── DATA_001_REFACTOR_STRATEGY.md       # DSD: Config versioning / Payment Methods
├── DATA_002_MIGRATION_CATALOG.md       # DSD: Catálogo de procesos a migrar
├── DATA_MODEL_RPC_REPORTES.md          # DSD: RPC Dashboard Reportes
├── DSD_001_REGISTRO_NATIVO.md          # DSD: Trigger automático de registro
├── DSD_007_01_v3_MIGRATION.md          # DSD: Migración rpc_procesar_venta_v3
├── DSD_008_SMART_SUPPLY.md             # DSD: Proveedores y Smart Supply
├── DSD_014_AUDITORIA_VENTAS.md         # DSD: Auditoría de ventas y ajustes
├── DSD_019_CUENTAS_POR_PAGAR.md        # DSD: Cuentas por pagar (Facturas)
├── DSD_020_CAJA_MULTICANAL.md          # DSD: Caja multicanal por método de pago
├── RLS_POLICIES.md                     # Políticas de Seguridad Row Level Security
├── supabase-schema-v2.sql              # ⚠️ Script Maestro (Core) - Pendiente sincronizar con DSDs
├── migrations/                         # Scripts SQL de migraciones de Work Orders
│   ├── WO-PHASE5-001_SCHEMA_MIGRATION.sql
│   └── WO-PHASE5-001_VERIFICATION.sql
├── optimizations/                      # Parches de rendimiento (índices)
└── patches/                            # Parches de lógica de negocio
```

---

## 📲 Estructura de Carpeta 04_DEV_ORCHESTRATION

```
04_dev_orchestration/
├── MAPA_LOGICA_GLOBAL.md               # ✅ Este documento
├── DATA_FLOW_CONTRACT.md               # Contrato normativo global (Backend ⇔ Frontend)
└── WO_*/                               # Work Orders por módulo
```

---

## 📖 Estructura de Carpeta TECHNICAL_GUIDES

```
technical_guides/
└── SUPABASE_SETUP_GUIDE.md             # ✅ Vigente: Guía de configuración de entorno
```

---

## 📁 Estructura de Carpeta 01_REQUIREMENTS

> **Nota:** Para el listado completo y detallado, consultar [`CATALOGO_MAESTRO_DOCUMENTOS.md`](../01_requirements/CATALOGO_MAESTRO_DOCUMENTOS.md).

```
01_requirements/
├── CATALOGO_MAESTRO_DOCUMENTOS.md  # ✅ [FUENTE DE VERDAD]
├── DOCUMENTATION_STANDARD.md       # ✅ [ESTÁNDAR ARQ-001]
├── FRD/                            # (Functional Requirement Documents - 30+ docs)
├── SDD/                            # (Software Design Documents - 20+ docs)
├── DSD/                            # (Database Specification Documents)
├── DICT/                           # Diccionarios de datos
├── STANDARDS/                      # Estándares (Decimal, Redondeo)
└── ...
```

## 📏 Estándares y Estrategias Técnicas

Documentos transversales que rigen la calidad y arquitectura (Ubicados en `01_requirements` y `02_architecture`):

| Documento | Propósito | Estado |
|-----------|-----------|--------|
| `DOCUMENTATION_STANDARD.md` | Estándar oficial para la redacción de FRD/SDD | ✅ Vigente |
| `FRONTEND_STANDARDS.md` | Estándares de Vue, Store (Pinia) y Componentes | ✅ Vigente |
| `SECURITY_STANDARDS.md` | Especificación Técnica de Seguridad y Encriptación | ✅ Vigente |
| `MONETARY_STANDARD.md` | Estandarización de redondeo, decimales y moneda | ✅ Vigente |
| `RLS_POLICIES.md` | Reglas y validaciones Row Level Security (Supabase) | ✅ Vigente |

---

## 📊 Resumen Ejecutivo y Cobertura

| Métrica | Valor |
|---------|-------|
| Total FRDs Catalogados | 46 |
| Cobertura de SDDs | 100% |
| DSDs Individuales en `02_architecture/` | 10 documentos |
| Documentos de diseño UX/UI (`03_ui_ux_design/`) | 17 |
| Diccionarios de Datos (`02_architecture/`) | Centralizados (Core) + Modulares |
| Documentos en `archive/` | 19 archivos (históricos + legacy)

---

## 🗂️ Tabla de Sincronización de Módulos Core (Resumen)

| Módulo Core | FRD / SDD (Referencia) | Estado |
|-------------|-------------------------|--------|
| **Seguridad Diaria** | FRD-001 / SDD-001 | 🟢 Validado |
| **Registro y Autenticación** | FRD-002 / SDD-002 | 🟢 Validado |
| **Gestión Empleados** | FRD-003 / SDD-003 | 🟢 Validado |
| **Control de Caja** | FRD-004 / SDD-004 | 🟢 Validado |
| **Auditoría (Inviolable/Trazable)** | FRD-005 | 🟢 Validado |
| **Inventario (Núcleo, Mov, Reembolso)**| FRD-006 / SDD-006 | 🟢 Validado |
| **Ventas y POS** | FRD-007 / SDD-007 | 🟠 Aprobado con Deuda (RPC v3) |
| **Reportes** | FRD-008 / SDD-008 | 🟢 Validado |
| **Clientes** | FRD-009 / SDD-009 | 🟢 Validado |
| **Valoración FIFO / Costo Ventas** | FRD-010 / SDD-010 | 🟢 Validado |
| **Sincronización Offline** | FRD-012 / SDD-012 | 🟡 Validado (Requiere ampliación) |
| **Gestión Sesiones / Ciclo Contable**| FRD-013 / FRD-017 | 🟢 Validado |
| **Cuentas por Pagar (Proveedores)** | FRD-019 / SDD-019 | 🟢 Validado |

> Para el desglose completo de tareas de frontend asociadas a estos módulos, consultar los correspondientes `WO` (Work Orders) en `04_dev_orchestration/`.

---

## 📦 Lista de Documentos Sueltos Archivados en Raíz (`documentation/archive/`)

Durante la auditoría (2026-08-17), se consolidaron los siguientes documentos heredados/sueltos en la carpeta de archivo para mantener la higiene del directorio raíz:

1. `ADDENDUM_AUDITORIA_CRUZADA.md`
2. `ANALYSIS_PHASE2_LOGIC.md`
3. `ARCHITECTURE_MAP.md`
4. `AUDITORIA_DATOS_ANALYTICS.md`
5. `CHANGELOG.md`
6. `DB_ALIGNMENT_PHASE1.md`
7. `FRD_Reportes_Historiales_v1.0.md`
8. `GAP_ANALYSIS_FRD_vs_CODE.md`
9. `HISTORIAL_ESTADO_ACTUAL.md`
10. `HOJA_DE_RUTA_ESTABILIZACION.md`
11. `MAPA_RIESGOS_SISTEMA.md`
12. `ORDENES_DE_TRABAJO.md`
13. `REPORTE_AUDITORIA_PREPRODUCCION.md`
14. `REPORTE_ESTADO_ACTUAL.md`

*(Si se requiere alguna información de estos reportes, debe migrarse a un SDD/FRD o Work Order correspondiente).*

---

## 🎉 Conclusiones de las Auditorías Documentales (FRD & Arquitectura)

1. **Catálogo Maestro unificado:** El proyecto cuenta con `CATALOGO_MAESTRO_DOCUMENTOS.md` como fuente única de verdad para Requisitos (FRD) y Diseño Técnico (SDD).
2. **Cobertura 100% lograda:** Todos los 46 módulos FRD cuentan con su SDD correspondiente.
3. **Saneamiento documental ejecutado (2026-08-17):** Se reubicaron 10 documentos de datos dispersos en la carpeta correcta (`02_architecture/`), se archivaron documentos históricos completados, y se centralizó el Contrato de Flujo en `04_dev_orchestration/`.
4. **Estado de la Arquitectura de Datos:** Se identificó un “Schema Drift” entre `supabase-schema-v2.sql` (Core) y los DSDs Modulares más recientes. Detallado en `AUDIT_REPORT_ARCHITECTURE.md`.
5. **Próximo Paso Crítico:** Consolidar `supabase-schema-v2.sql` con los DSDs modulares antes de ejecutar nuevas migraciones en producción.
