# Solicitud de Trabajo: Modelo de Datos del Sistema

> **De:** Arquitecto de Producto y Requisitos  
> **Para:** Equipo Data (@[/data])  
> **Fecha:** 2026-01-28  
> **Prioridad:** Alta  
> **Estado:** ✅ COMPLETADO Y APROBADO

---

## ✅ Aprobación Formal

| Rol | Fecha | Veredicto | Puntaje |
|-----|-------|-----------|---------|
| **Arquitecto** | 2026-01-28 | ✅ APROBADO | 92/100 |
| **QA** | 2026-01-28 | ✅ APROBADO | 92/100 |

### Entregables Recibidos

| Documento | Líneas | Estado |
|-----------|--------|--------|
| `DATA_MODEL_ERD.md` | 267 | ✅ |
| `DATA_DICTIONARY.md` | 285 | ✅ |
| `RLS_POLICIES.md` | 320 | ✅ |
| `supabase-schema-v2.sql` | 1446 | ✅ |

### Verificación QA

- ✅ RLS habilitado en 17/17 tablas
- ✅ PINs hasheados con `crypt()` + `bcrypt`
- ✅ 7 tablas inmutables verificadas
- ✅ Aislamiento multitenant confirmado
- ✅ 0 hallazgos críticos

---

## 1. Contexto

Los Documentos de Requisitos Funcionales (FRDs) han sido actualizados y consolidados. El sistema cuenta actualmente con **14 FRDs** que definen el comportamiento esperado del sistema.

El esquema de base de datos existente (`supabase-schema.sql`) está **DESACTUALIZADO** y no refleja los requisitos actuales. Se requiere regenerar el modelo de datos desde cero basándose en los FRDs vigentes.

---

## 2. Objetivo

El Equipo Data DEBE producir un modelo de datos completo que:
1. Implemente TODOS los requisitos de datos descritos en los FRDs
2. Siga las políticas de seguridad definidas (RLS, hashing de PINs)
3. Sea ejecutable en Supabase/PostgreSQL

---

## 3. Documentos de Entrada (Fuente de Verdad)

El Equipo Data DEBE leer y extraer requisitos de los siguientes documentos:

| FRD | Ubicación | Entidades Esperadas |
|-----|-----------|---------------------|
| FRD_001 | `01_REQUIREMENTS/FRD/FRD_001_SEGURIDAD_DIARIA.md` | Pase Diario, Dispositivo |
| FRD_002 | `01_REQUIREMENTS/FRD/FRD_002_REGISTRO_ADMIN.md` | Tienda, Perfil Admin |
| FRD_003 | `01_REQUIREMENTS/FRD/FRD_003_GESTION_EMPLEADOS.md` | Empleado, Permisos |
| FRD_004 | `01_REQUIREMENTS/FRD/FRD_004_CONTROL_DE_CAJA.md` | Sesión de Caja, Transacción |
| FRD_004.1 | `01_REQUIREMENTS/FRD/FRD_004_1_GESTION_PIN_CAJA.md` | Extensión PIN Tienda |
| FRD_005 | `01_REQUIREMENTS/FRD/FRD_005_AUDITORIA_TRAZABILIDAD.md` | Logs de Auditoría |
| FRD_006 | `01_REQUIREMENTS/FRD/FRD_006_INVENTARIO.md` | Producto, Movimiento Inventario |
| FRD_007 | `01_REQUIREMENTS/FRD/FRD_007_VENTAS.md` | Venta, Detalle de Venta |
| FRD_008 | `01_REQUIREMENTS/FRD/FRD_008_REPORTES.md` | Vistas/Queries de Reporte |
| FRD_009 | `01_REQUIREMENTS/FRD/FRD_009_CLIENTES.md` | Cliente, Transacción Cliente |
| FRD_010 | `01_REQUIREMENTS/FRD/FRD_010_HISTORIAL_PRECIOS.md` | Historial de Precios |
| FRD_011 | `01_REQUIREMENTS/FRD/FRD_011_MANEJO_ERRORES.md` | (Sin entidades nuevas) |
| FRD_012 | `01_REQUIREMENTS/FRD/FRD_012_SINCRONIZACION_OFFLINE.md` | Campos de sincronización |
| FRD_013 | `01_REQUIREMENTS/FRD/FRD_013_GESTION_SESIONES.md` | Sesión de Usuario |

Cada FRD contiene una sección **"Requisitos de Datos (Para Equipo Data)"** que describe las entidades y atributos requeridos en lenguaje natural.

---

## 4. Entregables Esperados

El Equipo Data DEBE producir los siguientes documentos:

### 4.1 Diagrama Entidad-Relación (ERD)

- **Ubicación:** `02_ARCHITECTURE/DATA_MODEL_ERD.md`
- **Formato:** Diagrama Mermaid
- **Contenido:**
  - Todas las entidades del sistema
  - Relaciones entre entidades
  - Cardinalidad (1:1, 1:N, N:M)

### 4.2 Diccionario de Datos

- **Ubicación:** `02_ARCHITECTURE/DATA_DICTIONARY.md`
- **Formato:** Tablas Markdown
- **Contenido por cada entidad:**
  - Nombre de tabla
  - Columnas con tipos de datos
  - Restricciones (NOT NULL, UNIQUE, CHECK)
  - Valores por defecto
  - Descripción de cada campo
  - FRD de origen (trazabilidad)

### 4.3 Políticas de Seguridad (RLS)

- **Ubicación:** `02_ARCHITECTURE/RLS_POLICIES.md`
- **Contenido:**
  - Política RLS para cada tabla
  - Justificación de cada política
  - Matriz de acceso (quién puede hacer qué)

### 4.4 Script SQL Ejecutable

- **Ubicación:** `02_ARCHITECTURE/supabase-schema-v2.sql`
- **Requisitos:**
  - Debe ejecutarse sin errores en Supabase
  - Incluir todas las tablas, índices y RLS
  - Incluir funciones RPC necesarias
  - Comentarios explicativos

---

## 5. Criterios de Aceptación

El trabajo del Equipo Data será aceptado si y solo si:

### Completitud
- [ ] Todas las entidades mencionadas en los FRDs están implementadas
- [ ] Todos los atributos de cada entidad están definidos
- [ ] El ERD refleja TODAS las relaciones del sistema

### Seguridad
- [ ] TODAS las tablas tienen RLS habilitado
- [ ] Los PINs se almacenan hasheados (nunca en texto plano)
- [ ] Ningún dato sensible es accesible sin autenticación

### Trazabilidad
- [ ] Cada tabla referencia el FRD de origen
- [ ] Cada política RLS tiene justificación documentada

### Ejecutabilidad
- [ ] El script SQL ejecuta sin errores en una instancia limpia de Supabase
- [ ] Las funciones RPC retornan el formato esperado

### Consistencia con FRDs
- [ ] No se inventan campos no requeridos por los FRDs
- [ ] No se omiten campos requeridos por los FRDs
- [ ] Las restricciones de negocio (ej: "no negativo") están implementadas como CHECKs

---

## 6. Restricciones

El Equipo Data NO DEBE:
- Inventar nuevas reglas de negocio no documentadas en FRDs
- Modificar los FRDs existentes
- Tomar decisiones de UI o flujos de usuario

Si el Equipo Data encuentra ambigüedades o inconsistencias en los FRDs, DEBE escalar al Arquitecto antes de implementar.

---

## 7. Orden de Ejecución Sugerido

1. **Leer todos los FRDs** - Extrayendo secciones "Requisitos de Datos"
2. **Crear ERD inicial** - Identificando entidades y relaciones
3. **Diccionario de Datos** - Detallando campos y tipos
4. **Políticas RLS** - Definiendo seguridad por tabla
5. **Script SQL** - Implementación ejecutable
6. **Validación cruzada** - Verificar contra criterios de aceptación

---

## 8. Fecha de Entrega

**Pendiente de definir por el equipo.**

---

## Firma

**Arquitecto de Producto y Requisitos**  
Documento generado: 2026-01-28
