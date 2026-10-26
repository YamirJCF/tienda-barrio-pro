# FRD-005: Sistema de Auditoría y Trazabilidad

### Nombre de la Funcionalidad
Evidence Hub / Sistema Centralizado de Auditoría

#### Descripción
Implementación de un sistema centralizado de historiales que permite auditar todas las operaciones críticas del negocio. Este módulo sirve como la fuente de verdad para la integridad financiera y operativa.

> **Relación Documental:** Este documento define la estructura centralizada del **Evidence Hub y Sistema de Trazabilidad**. Se complementa de forma directa con [`FRD_005_AUDITORIA_INVIOLABLE.md`](FRD_005_AUDITORIA_INVIOLABLE.md), el cual rige el Principio de Inmutabilidad y movimientos de contrapeso. Ambos se conservan como documentos separados por responder a principios conceptuales independientes.

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

6. **Filtro Temporal del Evidence Hub:**
    - **Filtro por Rango:** Todo listado de eventos de auditoría DEBE poder filtrarse por un rango de fechas (desde–hasta) aplicado sobre el timestamp del evento. Ambos extremos son inclusivos y se interpretan como días completos. El rango puede dejarse abierto en cualquiera de sus extremos.
    - **Atajos Rápidos:** Junto al rango, el sistema DEBE ofrecer atajos que rellenan el rango con un solo toque: Hoy, Ayer, Últimos 7 días y Últimos 30 días. Los atajos son una forma de llenar el rango, no un filtro adicional: el usuario siempre puede ajustar manualmente los extremos.
    - **Rango por Defecto:** Al entrar a un dominio, el listado DEBE mostrar los últimos 7 días, de forma consistente con el listado de turnos de FRD-027-01.
    - **Combinación:** El rango de fechas DEBE poder combinarse con el dominio y el tipo de evento. El orden cronológico se mantiene sobre los resultados filtrados.
    - **Resultado Vacío:** Si el filtro no arroja eventos, el sistema DEBE informarlo indicando el rango aplicado y permitir ampliarlo, nunca mostrar una lista en blanco sin aviso.
    - **Carga Progresiva:** Los resultados DEBEN cargarse de forma progresiva según la estrategia definida en FRD-006 (Estrategia de Paginación para Listados Extensos), de modo que un rango amplio no sobrecargue la pantalla.
    - **Aplicabilidad Contextual:** Las mismas reglas aplican al historial accesible desde contextos lógicos (por ejemplo, el historial de un cliente), de modo que el filtro se comporte igual en ambos accesos.

---

## Clasificación de Eventos

**Nivel 1: Críticos (Integridad Financiera)**
- Transacciones de venta: tickets, anulaciones, métodos de pago
- Control de caja: aperturas, cierres, conteo de efectivo, diferencias
- Auditoría de seguridad: logins fallidos, cambios de PIN, accesos fuera de horario, bloqueos de mutación concurrente y sospechas de manipulación (`CONCURRENT_MUTATION_BLOCKED`)

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
    3. Admin ajusta el rango de fechas (por defecto, últimos 7 días; puede usar un atajo o fijar desde–hasta) y filtra por tipo de evento "Aperturas/Cierres".
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
    4. Usuario puede filtrar por rango de fechas o tipo, con el mismo comportamiento del Evidence Hub (Regla 6).
- **Postcondición:** Usuario tiene visibilidad del historial completo del cliente.

---

## Requisitos de Datos (Para Equipo Data)

**Tablas de Auditoría por Dominio:**

| Dominio | Tabla Sugerida | Contenido |
|---------|----------------|-----------|
| Ventas | Auditoría de ventas | Tickets, anulaciones, cambios |
| Caja | Auditoría de caja | Aperturas, cierres, movimientos |
| Inventario | Auditoría de inventario | Entradas, salidas, ajustes |
| Seguridad | Auditoría de seguridad | Logins, cambios de PIN, pases, bloqueos de concurrencia |
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
- [ ] El filtro por fecha ofrece rango desde–hasta (extremos inclusivos, días completos) y atajos Hoy, Ayer, Últimos 7 días y Últimos 30 días.
- [ ] Al entrar a un dominio de auditoría, el listado muestra por defecto los últimos 7 días.
- [ ] El rango de fechas se combina con el dominio y el tipo de evento, y el historial contextual (ej. cliente) usa las mismas reglas.
- [ ] Si el filtro no arroja eventos, el sistema informa el rango aplicado y permite ampliarlo.
