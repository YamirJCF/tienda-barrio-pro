# FRD-021: Auditoría de Movimientos Multicanal

### Nombre de la Funcionalidad
Filtros de Auditoría por Método de Pago en Historiales

### Documentos Base (Referencias)
- Amplía y modifica reglas de: `FRD_005_AUDITORIA_TRAZABILIDAD.md`

#### Descripción
Expansión del centro de inteligencia e historiales para permitir al administrador o empleado auditar los flujos de dinero separando las transacciones físicas de las electrónicas. Esto consolida el rastreo de ventas, gastos y abonos bajo el prisma del método de pago utilizado.

## Reglas de Negocio

1. **Visibilidad Total de Ingresos:**
   - La vista de auditoría de caja DEBE consolidar ventas (efectivo/digitales) y abonos de clientes como "ingresos".

2. **Filtros Obligatorios:**
   - El historial de caja DEBE ofrecer un filtro primario para ver "Todos los movimientos" (efectivo, digital, abonos, gastos).
   - El historial DEBE ofrecer un filtro exclusivo para "Solo Efectivo".
   - El historial DEBE ofrecer un filtro exclusivo para "Solo Digitales", el cual DEBE permitir una sub-selección (ej. Solo Nequi, o Solo Daviplata).

3. **Identificación Visual:**
   - Cada registro en el historial DEBE identificar visualmente el método de pago utilizado para la transacción (mediante ícono, etiqueta o texto descriptivo).

## Casos de Uso

**Caso A: Filtrar Ingresos de Nequi**
- **Actor:** Administrador
- **Precondición:** Existen movimientos de efectivo y nequi en el historial.
- **Flujo Principal:**
  1. Usuario ingresa al historial de caja.
  2. Usuario selecciona el filtro "Digitales".
  3. Usuario selecciona el sub-filtro "Nequi".
  4. Sistema lista únicamente ventas, abonos y gastos pagados mediante Nequi.
  5. El usuario puede contrastar esta lista con los movimientos reportados en su app móvil de Nequi.

## Criterios de Aceptación
- [ ] Existen filtros funcionales en el frontend para: Todo, Efectivo y Digitales (con subfiltros Nequi/Daviplata).
- [ ] Los abonos de clientes aparecen en el historial de caja respetando los filtros de método de pago.
- [ ] La identificación visual del método de pago es clara en cada fila del historial.
