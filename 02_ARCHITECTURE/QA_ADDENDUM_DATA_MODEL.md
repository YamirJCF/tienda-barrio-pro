# Adendum de Seguridad y QA: Modelo de Datos

> **De:** Equipo QA y Auditoría (@[/qa])  
> **Para:** Equipo Data (@[/data])  
> **Complementa:** `WORK_REQUEST_DATA_MODEL.md`  
> **Fecha:** 2026-01-28  
> **Estado:** Fase 1 - Requisitos Preventivos

---

## 1. Propósito

Este documento complementa la Solicitud de Trabajo del Arquitecto con los **requisitos de seguridad, resiliencia y auditoría** que el Equipo Data DEBE cumplir. Sirve como guía preventiva para evitar rechazos en la revisión final de QA.

---

## 2. Contexto de Seguridad

### 2.1 Perfil de Riesgo del Sistema

| Factor | Valor | Implicación |
|--------|-------|-------------|
| **Datos sensibles** | Alto | PINs, información de clientes, transacciones financieras |
| **Usuarios** | Baja sofisticación técnica | No detectarán ataques; el sistema debe protegerlos |
| **Dispositivos** | Android compartidos | Riesgo de acceso físico no autorizado |
| **Conectividad** | Intermitente | Datos offline que se sincronizan después |

### 2.2 Vectores de Amenaza Identificados

| Vector | Descripción | Tabla(s) Afectada(s) |
|--------|-------------|----------------------|
| **V-001** | Empleado malicioso accediendo a datos de otra tienda | Todas |
| **V-002** | Escalación de privilegios (Empleado → Admin) | Empleados, Permisos |
| **V-003** | Lectura de PINs/contraseñas en texto plano | Tienda, Empleados |
| **V-004** | Manipulación de ventas offline antes de sincronización | Ventas, Detalles |
| **V-005** | Inyección SQL via campos de texto libre | Productos, Clientes |
| **V-006** | Acceso a logs de auditoría para cubrir pistas | Logs de Auditoría |

---

## 3. Políticas de Seguridad Obligatorias

### 3.1 Row Level Security (RLS)

> 🔴 **CRÍTICO:** Cada tabla DEBE tener RLS habilitado. NO hay excepciones.

| Regla | Descripción |
|-------|-------------|
| **RLS-001** | Toda tabla DEBE tener `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` |
| **RLS-002** | Toda tabla DEBE tener al menos una política de SELECT |
| **RLS-003** | La política DEBE filtrar por `store_id` del usuario autenticado |
| **RLS-004** | Las tablas de auditoría DEBEN ser INSERT-only (sin UPDATE ni DELETE) |

### 3.2 Manejo de Credenciales

| Regla | Descripción |
|-------|-------------|
| **CRED-001** | PINs DEBEN almacenarse hasheados con `crypt()` y `gen_salt('bf')` |
| **CRED-002** | Contraseñas de Admin son manejadas por Supabase Auth (NO en tablas custom) |
| **CRED-003** | Ningún SELECT debe retornar columnas de hash |
| **CRED-004** | Validación de PIN DEBE hacerse via función `SECURITY DEFINER` |

### 3.3 Aislamiento Multi-Tenant

| Regla | Descripción |
|-------|-------------|
| **TENANT-001** | Toda tabla operativa DEBE tener columna `store_id` |
| **TENANT-002** | Toda política RLS DEBE validar `store_id = get_current_store_id()` |
| **TENANT-003** | No debe existir forma de listar tiendas ajenas |

---

## 4. Requisitos de Auditoría

### 4.1 Campos de Auditoría Obligatorios

Toda tabla que almacene datos modificables DEBE incluir:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `created_at` | TIMESTAMPTZ | Fecha de creación (DEFAULT now()) |
| `created_by` | UUID | Referencia al usuario que creó el registro |
| `updated_at` | TIMESTAMPTZ | Fecha de última modificación |

### 4.2 Tablas Inmutables

Las siguientes entidades NO DEBEN permitir UPDATE ni DELETE después de creadas:

| Entidad | Justificación |
|---------|---------------|
| Ventas | Integridad contable |
| Detalles de Venta | Integridad contable |
| Movimientos de Inventario | Trazabilidad de stock |
| Logs de Auditoría | Evidencia forense |
| Transacciones de Caja | Integridad financiera |

> [!IMPORTANT]
> **Excepción - Ventas Offline Pendientes:**  
> Los registros de ventas creados offline que aún NO han sido sincronizados al servidor SÍ pueden ser modificados o eliminados por el usuario (ver FRD_012: Resolución de Conflictos). La inmutabilidad aplica únicamente a registros **ya sincronizados** en la base de datos del servidor.

> Para "corregir" errores en estas tablas, el sistema usa registros compensatorios (ej: ajuste de inventario), NO modificaciones directas.

### 4.3 Logs de Seguridad

El sistema DEBE registrar automáticamente:

| Evento | Severidad |
|--------|-----------|
| Login exitoso | Info |
| Login fallido (PIN incorrecto) | Warning |
| Múltiples intentos fallidos | Critical |
| Cambio de PIN | Warning |
| Desactivación de empleado | Warning |
| Cierre de sesión remoto | Info |

---

## 5. Patrones Prohibidos

El Equipo Data NO DEBE implementar:

| Patrón | Razón |
|--------|-------|
| ❌ `SECURITY INVOKER` en funciones que acceden a datos sensibles | Bypass de RLS |
| ❌ `SELECT *` en funciones RPC | Exposición de columnas futuras |
| ❌ Concatenación de strings para construir SQL | Inyección SQL |
| ❌ Retornar filas completas a usuarios anónimos | Fuga de datos |
| ❌ Usar `TEXT` para PINs sin hashear | Violación de privacidad |
| ❌ Políticas RLS con `USING (true)` | Acceso universal |

---

## 6. Recomendaciones de Implementación

### 6.1 Función de Contexto de Tienda

Se recomienda crear una función helper para simplificar las políticas RLS:

```
-- Pseudocódigo (Data decide sintaxis exacta)
FUNCTION get_current_store_id() RETURNS UUID
  → Extrae store_id del token JWT del usuario autenticado
```

### 6.2 Formato de Respuesta RPC

Todas las funciones RPC DEBEN retornar estructura estandarizada:

```
{
  "success": boolean,
  "data": {} | null,
  "error": string | null,
  "code": string | null  -- Para que Frontend traduzca mensajes
}
```

### 6.3 Índices de Seguridad

Se recomienda crear índices en columnas usadas por RLS:

| Columna | Tabla(s) | Razón |
|---------|----------|-------|
| `store_id` | Todas las operativas | Performance de filtrado RLS |
| `employee_id` | Ventas, Movimientos | Auditoría por empleado |
| `created_at` | Logs, Ventas | Queries de rango de fecha |

---

## 7. Criterios de Aceptación de QA

El Equipo Data DEBE cumplir estos criterios para aprobar la revisión final:

### Seguridad (Bloqueo si falla)

| ID | Criterio | Severidad |
|----|----------|-----------|
| QA-SEC-001 | Todas las tablas tienen RLS habilitado | 🔴 Crítico |
| QA-SEC-002 | Ninguna política usa `USING (true)` sin justificación | 🔴 Crítico |
| QA-SEC-003 | PINs almacenados con `crypt()` | 🔴 Crítico |
| QA-SEC-004 | Funciones RPC sensibles usan `SECURITY DEFINER` | 🔴 Crítico |
| QA-SEC-005 | No hay SELECT de columnas de hash expuestas | 🔴 Crítico |

### Auditoría (Bloqueo si falla)

| ID | Criterio | Severidad |
|----|----------|-----------|
| QA-AUD-001 | Tablas inmutables no permiten UPDATE/DELETE | 🟠 Alto |
| QA-AUD-002 | Campos `created_at`, `created_by` presentes | 🟠 Alto |
| QA-AUD-003 | Tabla de logs de auditoría existe y funciona | 🟠 Alto |

### Aislamiento (Bloqueo si falla)

| ID | Criterio | Severidad |
|----|----------|-----------|
| QA-ISO-001 | Toda tabla operativa tiene `store_id` | 🔴 Crítico |
| QA-ISO-002 | Prueba de aislamiento: Usuario A no ve datos de Usuario B | 🔴 Crítico |

### Resiliencia (Corrección requerida)

| ID | Criterio | Severidad |
|----|----------|-----------|
| QA-RES-001 | Errores retornan JSON estructurado, no excepciones crudas | 🟡 Medio |
| QA-RES-002 | Transacciones críticas son atómicas (ROLLBACK en fallo) | 🟠 Alto |

---

## 8. Proceso de Revisión Final

1. **Fase 1 (Actual):** Este documento define los requisitos preventivos
2. **Fase 2 (Futura):** Revisión del entregable contra estos criterios
3. **Resultado:** Aprobado / Rechazado con hallazgos

> La Fase 2 será ejecutada cuando el usuario lo solicite.

---

## 9. Checklist Pre-Entrega para Data

Antes de entregar, el Equipo Data DEBE verificar:

- [ ] Ejecuté `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` en TODAS las tablas
- [ ] Cada tabla tiene al menos una política de SELECT
- [ ] Probé que Usuario A no puede ver datos de otra tienda
- [ ] Los PINs se almacenan con `crypt()`
- [ ] Las funciones que validan PINs usan `SECURITY DEFINER`
- [ ] Las tablas de ventas/movimientos no permiten UPDATE
- [ ] Todas las tablas tienen `created_at` y `created_by`
- [ ] Los errores retornan JSON, no stack traces

---

## Firma

**Equipo QA y Auditoría**  
Documento generado: 2026-01-28
