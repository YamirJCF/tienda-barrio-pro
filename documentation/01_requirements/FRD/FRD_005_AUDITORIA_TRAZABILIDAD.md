# FRD-005: Sistema de Auditoría y Trazabilidad

### Nombre de la Funcionalidad
Evidence Hub / Sistema Centralizado de Auditoría

#### Descripción
Implementación de un sistema centralizado de historiales que permite auditar todas las operaciones críticas del negocio. Este módulo sirve como la fuente de verdad para la integridad financiera y operativa.

---

## Reglas de Negocio

1. **Inmutabilidad:**
    - Ningún registro histórico puede ser eliminado o editado.
    - Los errores se corrigen únicamente mediante contra-operaciones registradas.
    - Ejemplo: una devolución anula una venta, pero ambos registros existen.

2. **Trazabilidad Completa:**
    - Cada registro DEBE contener obligatoriamente:
        - Timestamp exacto
        - Usuario responsable
        - Tipo de operación
        - Datos del evento (payload)

3. **Seguridad por Niveles:**
    - El acceso a ciertos historiales (ej: Auditoría de Seguridad) está restringido estrictamente al rol Admin.
    - Empleados solo pueden ver historiales operativos según sus permisos.

4. **Estructura de Almacenamiento:**
    - El sistema utiliza **tablas separadas por dominio** para mejor rendimiento y organización.
    - Dominios definidos:
        - Ventas
        - Caja
        - Inventario
        - Seguridad
        - Precios
        - Créditos

5. **Acceso Contextual:**
    - Los historiales DEBEN ser accesibles tanto desde una vista centralizada como desde contextos lógicos.
    - Ejemplo: ver historial de un cliente desde el perfil del cliente.

---

## Clasificación de Eventos

**Nivel 1: Críticos (Integridad Financiera)**
- Transacciones de venta: tickets, anulaciones, métodos de pago
- Control de caja: aperturas, cierres, conteo de efectivo, diferencias
- Auditoría de seguridad: logins fallidos, cambios de PIN, accesos fuera de horario

**Nivel 2: Operativos (Control de Gestión)**
- Kardex de inventario: compras, ventas, mermas, ajustes de stock
- Gastos operativos: salidas de dinero de caja menor

**Nivel 3: Valor Agregado**
- Historial de créditos: abonos, nuevas deudas, liquidaciones
- Historial de precios: cambios en costo y precio de venta

---

## Casos de Uso

**Caso A: Auditoría Forense (Investigación)**
- **Actor:** Admin
- **Precondición:** Sospecha de anomalía (ej: faltante de dinero).
- **Flujo Principal:**
    1. Admin ingresa a "Reportes" → "Auditoría".
    2. Admin selecciona dominio: "Caja".
    3. Admin filtra por fecha y tipo de evento "Aperturas/Cierres".
    4. Sistema muestra lista cronológica con: quién abrió, cuánto declaró, diferencia final.
    5. Admin expande detalle para ver información del dispositivo usado en el cierre.
    6. Admin identifica el turno problemático.
- **Postcondición:** Información encontrada para tomar decisiones.

**Caso B: Historial de Cliente (Acceso Contextual)**
- **Actor:** Admin o Empleado con permiso
- **Precondición:** Visualizando perfil de un cliente.
- **Flujo Principal:**
    1. Usuario está en el detalle de un cliente.
    2. Selecciona pestaña "Historial".
    3. Sistema muestra todas las transacciones relacionadas: compras, abonos, créditos.
    4. Usuario puede filtrar por fecha o tipo.
- **Postcondición:** Usuario tiene visibilidad del historial completo del cliente.

---

## Requisitos de Datos (Para Equipo Data)

**Tablas de Auditoría por Dominio:**

| Dominio | Tabla Sugerida | Contenido |
|---------|----------------|-----------|
| Ventas | Auditoría de ventas | Tickets, anulaciones, cambios |
| Caja | Auditoría de caja | Aperturas, cierres, movimientos |
| Inventario | Auditoría de inventario | Entradas, salidas, ajustes |
| Seguridad | Auditoría de seguridad | Logins, cambios de PIN, pases |
| Precios | Auditoría de precios | Cambios de costo/precio |
| Créditos | Auditoría de créditos | Deudas, abonos, liquidaciones |

**Campos Comunes Obligatorios:**
- Identificador único
- Timestamp
- Usuario responsable
- Tipo de evento
- Datos del evento (estructura flexible)

---

## Criterios de Aceptación

- [ ] Las tablas de auditoría solo permiten inserción (append-only).
- [ ] No existe funcionalidad de "Borrar Historial" en ninguna interfaz.
- [ ] Cada evento está vinculado a un usuario válido.
- [ ] Los historiales de seguridad solo son visibles para Admin.
- [ ] Se puede acceder al historial desde la vista centralizada Y desde contextos relacionados.
- [ ] El filtro por fecha y tipo funciona correctamente.
