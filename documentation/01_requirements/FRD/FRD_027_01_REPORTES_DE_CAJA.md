# FRD-027-01: Reportes y Auditoría de Caja Diaria

### Veracidad Financiera y Reportes Blindados

#### Descripción
Este documento rige la generación, visualización y protección de la información financiera extraída del núcleo de caja (definido en FRD-027). Establece una separación estricta entre la información operativa (diseñada para el usuario de mostrador) y la información de auditoría interna (diseñada para el sistema y el propietario). El objetivo primordial es garantizar la fidelidad matemática, prevenir la manipulación de datos y aplicar medidas de seguridad de alto nivel operativo como el "arqueo ciego".

---

## Reglas de Negocio
1. **Dicotomía del Reporte:** El sistema DEBE proveer dos perfiles de extracción de información del turno:
   - **Reporte Operativo (Visual/Humano):** Diseñado para el cajero. Muestra resúmenes limpios por canal (sin mezclar), orientados exclusivamente a facilitar el cuadre físico y digital del momento.
   - **Reporte de Auditoría Interna (Sistema/Dueño):** Diseñado para la seguridad. Rastrea y documenta cada movimiento, intentos fallidos de sobregiro, transacciones de contrapeso (anulaciones) y discrepancias entre lo físico y lo calculado.
2. **Ceguera Operativa (Arqueo Ciego):** Durante el transcurso de un turno activo y en el instante de cerrarlo, el sistema TIENE PROHIBIDO mostrarle al usuario cajero cuál es el saldo total esperado en efectivo. El operario DEBE contar el dinero a ciegas y declarar la suma real, previniendo que manipule los billetes para hacerlos cuadrar artificialmente con la expectativa del software.
3. **Inmutabilidad del Cierre (Sello de Tiempo):** En el instante en que el operario declara el monto físico y cierra el turno, el servidor DEBE generar una instantánea matemática irreversible de los totales y el descuadre (si lo hubiere). Este reporte queda sellado criptográficamente o bloqueado a nivel de base de datos; nadie, ni siquiera un administrador, PUEDE alterarlo o recalcularlo en el futuro.
4. **Fidelidad al Flujo Puro:** Fiel a las reglas de caja, los reportes TIENEN PROHIBIDO proyectar ingresos futuros (fiados no cobrados) o egresos futuros (facturas de proveedores pendientes). El reporte es un reflejo dogmático de la liquidez exclusiva que cambió de manos en ese periodo.
5. **Autenticidad de Descuadres:** Si el monto físico declarado por el operario difiere del monto líquido calculado por el servidor, el sistema DEBE generar un registro de ajuste por diferencia (faltante o sobrante) que impacte el reporte de auditoría de manera indeleble, emitiendo alertas de seguridad silenciosas a los perfiles de administración.
6. **Navegación Temporal por Turnos Cerrados:** El módulo de reportes DEBE permitir al Administrador consultar turnos cerrados anteriores mediante un mecanismo de selección temporal.
   - **Unidad de consulta:** El turno (sesión de caja) es la unidad atómica. No existe un "reporte diario" consolidado; cada turno se inspecciona individualmente.
   - **Listado de turnos:** El sistema DEBE presentar una lista cronológica de turnos cerrados, mostrando para cada uno: fecha, hora de apertura, hora de cierre, empleado responsable y estado de cuadre (con/sin descuadre).
   - **Filtro por rango de fechas:** El listado de turnos cerrados DEBE ser filtrable por un rango de fechas (desde–hasta). Por defecto, el sistema muestra los turnos de los últimos 7 días.
   - **Acceso al detalle:** Al seleccionar un turno cerrado de la lista, el sistema DEBE mostrar el reporte de auditoría interna completo de ese turno, con los mismos datos que se generaron al momento del cierre (instantánea inmutable, Regla 3).

---

## Casos de Uso

**Caso A: Ejecución de Arqueo Ciego y Cierre de Turno**
- **Actor:** Usuario Operativo / Cajero.
- **Precondición:** Llega el final de la jornada. El sistema sabe internamente que la caja debe contener doscientas mil unidades en efectivo, producto de ventas puras.
- **Flujo Principal:**
  1. El usuario inicia el proceso de cierre de turno. El sistema bloquea la entrada de nuevas transacciones.
  2. El sistema solicita al usuario introducir la cantidad de efectivo físico que hay en la gaveta, ocultando el valor esperado (doscientas mil unidades).
  3. El usuario cuenta el dinero e ingresa el monto: ciento noventa y cinco mil unidades.
  4. El servidor recibe el monto, compara y detecta un faltante de cinco mil unidades.
  5. El servidor sella el turno, crea la instantánea del reporte operativo (indicando el valor entregado) y genera un evento crítico de faltante en el reporte de auditoría interna.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El turno se cierra preservando la verdad sobre el faltante. El cajero no pudo ajustar el dinero de su bolsillo para simular un cuadre perfecto porque desconocía la meta.

**Caso B: Inspección Forense del Propietario**
- **Actor:** Administrador / Propietario.
- **Precondición:** El propietario revisa el desempeño financiero de la semana pasada, sospechando de movimientos inusuales el día martes.
- **Flujo Principal:**
  1. El administrador ingresa al módulo de reportes y extrae la auditoría interna del día martes.
  2. El sistema revela no solo las ventas y gastos exitosos, sino el "ruido operativo": expone tres intentos de gasto rechazados por falta de fondos en el canal Nequi y dos anulaciones de ventas mediante movimientos de contrapeso.
  3. El reporte interno confirma que el cajero entregó dinero con un faltante, protegiendo al dueño con la verdad.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El propietario adquiere visibilidad total del comportamiento operativo real, garantizado por registros que no pudieron ser borrados por el cajero.

---

## Criterios de Aceptación
- [ ] **CA-FRD-027-01-01:** La interfaz visual orientada al cajero DEBE ocultar obligatoriamente el acumulado de efectivo esperado antes y durante el formulario de cierre de turno.
- [ ] **CA-FRD-027-01-02:** El servidor DEBE rechazar cualquier petición de base de datos que intente aplicar una operación de edición (UPDATE) o borrado (DELETE) sobre el registro histórico de un turno ya cerrado.
- [ ] **CA-FRD-027-01-03:** El sistema DEBE clasificar automáticamente cualquier discrepancia entre el monto esperado por cálculo y el monto declarado por conteo como una "anomalía de cuadre", registrándola de manera separada en la auditoría.
- [ ] **CA-FRD-027-01-04:** El módulo de reportes DEBE presentar una lista cronológica de turnos cerrados filtrable por rango de fechas (desde–hasta).
- [ ] **CA-FRD-027-01-05:** Cada turno cerrado en la lista DEBE mostrar: fecha, hora de apertura, hora de cierre, empleado responsable y estado de cuadre.
- [ ] **CA-FRD-027-01-06:** Al seleccionar un turno cerrado, el sistema DEBE mostrar la instantánea inmutable del reporte de auditoría de ese turno.
