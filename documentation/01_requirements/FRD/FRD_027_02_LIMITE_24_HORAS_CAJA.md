# FRD-027-02: Límite de 24 Horas y Caducidad de Caja

### Frontera Temporal y Cierre Obligatorio de Turnos

#### Descripción
Este documento rige el ciclo de vida temporal del núcleo de caja. Para garantizar la pureza del flujo de caja diario y evitar la fusión contable de múltiples días operativos (por negligencia u olvido de cierre), se impone un límite de existencia estricto de 24 horas para cualquier turno abierto. Este límite protege la veracidad de los reportes y fuerza la conciliación física del dinero.

---

## Reglas de Negocio
1. **Caducidad Estricta (Límite de Vida):** Ningún turno operativo PUEDE permanecer en estado "Activo" o recibir nuevas transacciones (ventas, gastos, ingresos, abonos) una vez transcurridas exactamente 24 horas desde su marca de tiempo (timestamp) de apertura original.
2. **Bloqueo Operativo Automático:** Al cruzarse el umbral de las 24 horas, el sistema servidor DEBE transicionar automáticamente el estado del turno a "Expirado/Bloqueado". El servidor rechazará inmediatamente cualquier inyección o extracción de liquidez que intente asociarse a dicho turno.
3. **Resolución Única (Arqueo de Desbloqueo):** La única acción permitida sobre un turno "Expirado" es la ejecución del proceso de Cierre de Caja (Arqueo Ciego). El usuario responsable está obligado a realizar el conteo físico para clausurar el turno caducado antes de poder abrir uno nuevo y reanudar las operaciones de la tienda.
4. **Bandera de Anomalía Administrativa:** Todo turno que alcance el límite de 24 horas y caiga en estado expirado DEBE ser marcado permanentemente en el Reporte de Auditoría Interna con una etiqueta de "Cierre por Caducidad" o "Negligencia de Cierre", sirviendo como alerta administrativa para el propietario.
5. **Intervención Administrativa (Cierre Forzoso):** Si el cajero original no se encuentra disponible para cerrar su turno caducado, el sistema DEBE permitir a un usuario con privilegios de Administrador realizar un "Cierre Forzoso". Esta acción sellará el turno asumiendo el saldo esperado por el servidor como el saldo físico real, y registrará una alerta de máxima severidad en la auditoría interna detallando qué administrador forzó la clausura.

---

## Casos de Uso

**Caso A: Interrupción de Venta por Olvido (Día Siguiente)**
- **Actor:** Usuario Operativo / Cajero.
- **Precondición:** El cajero abrió la caja el lunes a las 08:00 AM. Al finalizar el día, se retira sin realizar el cierre. Regresa el martes a las 08:30 AM (24.5 horas después) e intenta registrar la primera venta del día.
- **Flujo Principal:**
  1. El usuario intenta procesar el cobro de la venta.
  2. El servidor evalúa la diferencia entre la hora actual y la hora de apertura del turno asociado al cajero.
  3. El servidor detecta que han pasado más de 24 horas, rechaza la transacción financiera e impide imprimir el recibo.
  4. El sistema notifica al cajero que su turno anterior ha caducado.
  5. El cajero es forzado a realizar el Arqueo Ciego del dinero del lunes para cerrar ese turno, antes de poder abrir un turno nuevo para el martes y concretar la venta pendiente.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** Se preserva la pureza contable del lunes, impidiendo que el dinero del martes contamine el reporte del día anterior.

**Caso B: Cierre Forzoso Administrativo ante Abandono**
- **Actor:** Administrador / Propietario.
- **Precondición:** Un empleado abrió turno, trabajó, pero abandonó su puesto de trabajo de manera definitiva sin cerrar caja ni cuadrar el dinero. El turno alcanza las 24 horas y se bloquea.
- **Flujo Principal:**
  1. El Administrador ingresa al sistema y detecta que las operaciones están detenidas por el turno caducado del empleado ausente.
  2. Al no poder contar con el empleado para el arqueo ciego, el Administrador selecciona la opción de "Cierre Forzoso de Emergencia".
  3. El servidor cierra el turno, asumiendo matemáticamente que el dinero físico en la gaveta es exactamente el que el sistema esperaba, dejando el descuadre operativo en cero.
  4. El servidor inyecta una advertencia de auditoría indeleble indicando que los fondos reales son desconocidos debido al cierre forzoso, responsabilizando administrativamente al evento.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** La tienda se desbloquea para abrir nuevos turnos, pero el historial forense guarda la prueba del quiebre de seguridad.

---

## Criterios de Aceptación
- [ ] **CA-FRD-027-02-01:** Toda función RPC del servidor que registre movimientos de dinero DEBE validar primero que la diferencia entre `now()` y `opened_at` del turno activo sea estrictamente menor a 24 horas, abortando con error si se supera.
- [ ] **CA-FRD-027-02-02:** La interfaz visual DEBE inhabilitar (bloquear visualmente) las funciones operativas de venta, gastos y abonos si detecta que el estado del turno local ha cruzado el límite de 24 horas.
- [ ] **CA-FRD-027-02-03:** El sistema DEBE estampar de manera permanente un indicador booleano de "caducidad_superada" o similar en la tabla del turno, activado únicamente si el cierre ocurre posterior al límite.
