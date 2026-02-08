# Reporte de Auditoría QA - Módulo: Venta Forzada y Auditoría

> **Fecha:** 2026-02-07
> **Auditor:** @/qa
> **Documentos Auditados:** FRD-014 V1.4, DSD-014 V1.4, UXD-014 V1.4

## 1. Resumen Ejecutivo
El paquete de documentación define un **Protocolo de Excepción** robusto que equilibra la operatividad del negocio con la integridad contable. La arquitectura propuesta (RPC atómico + Auditoría Inmutable) es segura por diseño.

**Puntaje de Robustez:** 92/100

---

## 2. Matriz de Hallazgos y Riesgos

| ID | Severidad | Hallazgo | Ubicación | Análisis |
|----|-----------|----------|-----------|----------|
| **R-01** | 🟠 **ALTO** | Violación potencial de Constraint `movement_type` | DSD-014 (SQL) | El script usa el tipo `'CORRECCION_SISTEMA'`. Si la tabla `inventory_movements` tiene un `CHECK constraint` restrictivo (ej. solo 'entrada', 'salida', 'venta'), el RPC fallará catastróficamente. **Requiere verificación previa.** |
| **R-02** | 🟡 **MEDIO** | `search_path` no definido en `SECURITY DEFINER` | DSD-014 (SQL) | Buenas prácticas de PostgreSQL: Funciones `SECURITY DEFINER` deben setear `SET search_path = public` para evitar hijacking si se crean objetos maliciosos en otros esquemas. |
| **R-03** | 🔵 **BAJO** | UX Offline: Persistencia del Modal | UXD-014 | No se especifica si el estado del modal y el texto de justificación sobreviven a un refresco de página o cierre accidental. Recomendable usar `Draft Storage`. |

---

## 3. Análisis de Resiliencia (Fail-Safe)

### A. Atomicidad (Aprobado)
El uso de transacciones dentro del RPC garantiza que **nunca** ocurrirá un "Inventario Ajustado sin Venta" o viceversa. O pasan ambos, o no pasa ninguno.

### B. Seguridad de Roles (Aprobado)
La verificación `IF v_role NOT IN ('admin', 'owner')` dentro del RPC (Línea 97) es la defensa final. Incluso si un hacker bypassea el UI Frontend, el Backend rechazará la excepción.

### C. Auditoría (Aprobado)
La tabla `audit_logs` con RLS `INSERT-only` para el sistema y `SELECT-only` para admins asegura que la evidencia no puede ser borrada ni siquiera por el mismo admin (desde la API pública).

---

## 4. Plan de Mitigación (Acciones Requeridas)

Para cerrar el riesgo **R-01** y **R-02**, se debe modificar el DSD-014 antes de la implementación.

1.  **Validar Constraints:** Ejecutar query de inspección sobre `inventory_movements`.
2.  **Parche SQL (DSD):**
    *   Agregar `SET search_path = public` al RPC.
    *   Si el constraint existe, incluir un `ALTER TABLE ... DROP CONSTRAINT ... ADD CONSTRAINT` para permitir `'CORRECCION_SISTEMA'`.

### Documento de Modificación (Anexo QA)
Se generará el archivo `REQ_MOD_014_QA.md` con las correcciones técnicas específicas.
