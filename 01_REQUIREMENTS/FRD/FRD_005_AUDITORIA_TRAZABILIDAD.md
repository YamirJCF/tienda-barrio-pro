# FRD-005: Sistema de Auditoría y Trazabilidad

### Nombre de la Funcionalidad
Evidence Hub / Sistema Centralizado de Auditoría

> **Basado en:** SPEC-009 (Legacy)

#### Descripción
Implementación de un sistema centralizado de historiales que permita auditar todas las operaciones críticas del negocio. Este módulo servirá como la fuente de verdad para la integridad financiera y operativa.

#### Reglas de Negocio
1.  **Inmutabilidad:** Ningún registro histórico puede ser eliminado o editado, solo anulado mediante una contra-operación registrada (ej: devolución anula venta).
2.  **Trazabilidad Completa:** Cada registro debe contener obligatoriamente: `timestamp`, `usuario_responsable`, `tipo_operacion` y `payload` (datos del evento).
3.  **Seguridad por Niveles:** El acceso a ciertos historiales (ej: Auditoría de Seguridad) está restringido estrictamente al rol `admin`.
4.  **Acceso Contextual:** Los historiales deben ser accesibles tanto desde una vista centralizada como desde contextos lógicos (ej: ver historial de cliente desde perfil de cliente).

#### Clasificación de Eventos

**🚨 Nivel 1: Críticos (Integridad Financiera)**
*   **Transacciones de Venta:** Tickets, anulaciones, métodos de pago.
*   **Control de Caja:** Aperturas, cierres, conteo de efectivo, diferencias reportadas.
*   **Auditoría de Seguridad:** Logins fallidos, cambios de PIN, accesos fuera de horario.

**⚠️ Nivel 2: Operativos (Control de Gestión)**
*   **Kardex de Inventario:** Compras, ventas, mermas, ajustes de stock.
*   **Gastos Operativos:** Salidas de dinero de caja menor.

**ℹ️ Nivel 3: Valor Agregado**
*   **Historial de Créditos:** Abonos, nuevas deudas, liquidaciones.
*   **Historial de Precios:** Cambios en costo y precio de venta.

#### Casos de Uso

**Caso A: Auditoría Forense (Investigación)**
- **Actor:** Admin
- **Precondición:** Sospecha de anomalía (ej: faltante de dinero).
- **Flujo:**
    1.  Admin ingresa a "Reportes" -> "Auditoría".
    2.  Filtra por fecha y tipo de evento "Aperturas/Cierres".
    3.  Sistema muestra lista cronológica con: Quién abrió, Cuánto declaró, Diferencia final.
    4.  Admin expande detalle para ver el `device_fingerprint` del cierre conflictivo.

#### Criterios de Aceptación
- [ ] La tabla de auditoría debe ser "append-only" (solo inserción).
- [ ] No debe existir funcionalidad de "Borrar Historial" en la UI.
- [ ] Cada evento debe estar vinculado a un `user_id` válido.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| **DB Schema** | Crear tablas `audit_logs` (general) o tablas específicas por dominio si el volumen es alto. |
| **Admin Hub** | Nueva sección "Auditoría". |
