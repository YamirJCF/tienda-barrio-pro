# Auditoría de Cumplimiento: FRD-003 Gestión de Empleados

**Estado General:** 🔴 NO CUMPLE (Requiere Refactorización)
**Fecha:** 2026-01-23
**Versión de Código Analizada:** `feat/email-verification` (merged)

## 🚨 Hallazgos Críticos (Bloqueantes)

### 1. Violación de Regla de Negocio: Límite de Empleados
*   **Requerimiento (FRD-003.4):** "Si se alcanza el límite (5/5), el botón 'Nuevo Empleado' se bloquea."
*   **Implementación Actual:** No existe ninguna validación de conteo en `EmployeeManagerView.vue` ni en `employees.ts`. El sistema permite crear infinitos empleados.
*   **Severidad:** Crítica (Rompe modelo de negocio).

### 2. Violación de Integridad de Datos: Unicidad de Usuario
*   **Requerimiento (FRD-003.1):** "Identificador Único... No pueden existir dos cuentas con el mismo username".
*   **Implementación Actual:** El método `save()` en `EmployeeFormModal.vue` no verifica si el usuario ya existe. `addEmployee` en el store simplemente hace push al array.
*   **Severidad:** Alta (Riesgo de colisión de credenciales).

## ⚠️ Hallazgos Mayores (Funcionalidad Incompleta/Incorrecta)

### 3. Divergencia en Matriz de Permisos
El código implementado no corresponde a los interruptores (toggles) solicitados por Producto.

| Permiso | FRD-003 (Requerido) | Código Actual | Veredicto |
| :--- | :--- | :--- | :--- |
| `canSell` | ✅ Default (True) | ✅ Default (True) | CUMPLE |
| `canViewInventory` | ✅ Toggle (Opcional) | ❌ Hardcoded `True` | **NO CUMPLE** |
| `canFiar` | ✅ Toggle (Opcional) | ❌ Hardcoded `False` (Oculto) | **NO CUMPLE** |
| `canViewReports` | ✅ Toggle (Opcional) | ❌ Hardcoded `False` (Oculto) | **NO CUMPLE** |
| `canOpenCloseCash` | ✅ Toggle (Opcional) | ✅ Toggle (Opcional) | CUMPLE |
| `canManageInventory` | ❌ No existe | ⚠️ Toggle (Extra) | **INVENTADO** |

> **Nota:** El desarrollador anterior "inventó" un permiso `canManageInventory` que otorga acceso de escritura completo, mientras que "ocultó" reportes y fiado.

## ✅ Puntos de Cumplimiento
*   [x] El PIN se valida correctamente como 4 dígitos numéricos.
*   [x] El toggle de Activo/Inactivo funciona correctamente.
*   [x] El reseteo de PIN por parte del Admin esté implementado.

## Recomendación de Acción
Se requiere una **Orden de Trabajo de Corrección** para:
1.  Implementar la validación de `activeEmployees.length >= 5` en la vista.
2.  Inyectar la validación de `username` no duplicado en el formulario.
3.  Refactorizar `EmployeeFormModal` para exponer los checkboxes correctos (`viewInventory`, `fiar`, `reports`) y eliminar el "inventado" o mapearlo correctamente.
