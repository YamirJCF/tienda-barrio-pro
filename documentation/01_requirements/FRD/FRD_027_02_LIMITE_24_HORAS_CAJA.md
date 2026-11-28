# FRD-027-02: Límite de 24 Horas y Caducidad de Caja

### Frontera Temporal y Cierre Obligatorio de Turnos

#### Descripción
Este documento rige el ciclo de vida temporal del núcleo de caja. Para garantizar la pureza del flujo de caja diario y evitar la fusión contable de múltiples días operativos (por negligencia u olvido de cierre), se impone un límite de existencia estricto de 24 horas para cualquier turno abierto. Este límite protege la veracidad de los reportes y fuerza la conciliación física del dinero.

---

## Reglas de Negocio
1. **Caducidad Estricta (Límite de Vida):** Ningún turno operativo PUEDE permanecer en estado "Activo" o recibir nuevas transacciones (ventas, gastos, ingresos, abonos) una vez transcurridas exactamente 24 horas desde su marca de tiempo (timestamp) de apertura original.
2. **Bloqueo Operativo Automático:** Al cruzarse el umbral de las 24 horas, el sistema servidor DEBE transicionar automáticamente el estado del turno a "Expirado/Bloqueado". El servidor rechazará inmediatamente cualquier inyección o extracción de liquidez que intente asociarse a dicho turno.
3. **Resolución por el Titular que Abrió el Turno (`POL-SEG-02`, `POL-SEG-03`):** Sobre un turno "Expirado/Bloqueado", el **único empleado** autorizado para ejecutar el proceso de Cierre de Caja (bajo Cierre Asistido de hasta 3 intentos) es **quien abrió originalmente ese turno**. Cualquier otro empleado, aunque tenga permiso de caja, tiene estrictamente bloqueado cerrar ese turno ajeno.
4. **Bandera de Anomalía Administrativa:** Todo turno que alcance el límite de 24 horas y caiga en estado expirado DEBE ser marcado permanentemente en el Reporte de Auditoría Interna con una etiqueta de "Cierre por Caducidad" o "Negligencia de Cierre", sirviendo como alerta administrativa para el propietario.
5. **Intervención Administrativa (Cierre Forzoso con Declaración Obligatoria):** Si un turno caducado (+24h) debe ser cerrado por el **Administrador** (sea propio o abierto por un empleado ausente), el sistema DEBE mostrarle exclusivamente al Administrador la ficha resumen del turno vencido (quién lo abrió, base inicial, efectivo esperado en cajón y resumen informativo de Nequi y Llave BRE) y **exigirle obligatoriamente declarar explícitamente el efectivo físico recuperado** (`0` o mayor, prohibiendo envíos en blanco o cierres sin conteo). Cuando el turno vencido fue abierto por otro usuario (empleado), el Administrador DEBE registrar además una observación breve obligatoria explicando la intervención. El servidor guarda siempre la diferencia exacta al peso (`Efectivo Declarado - Efectivo Esperado`), marca el cierre con bandera de caducidad (`+24h`) y registra el evento de auditoría.

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

**Caso B: Cierre Forzoso Administrativo ante Olvido o Abandono (+24h)**
- **Actor:** Administrador / Propietario.
- **Precondición:** Un turno (abierto por el propio Administrador o por un empleado ausente) supera las 24 horas y queda bloqueado para operar.
- **Flujo Principal:**
  1. El Administrador ingresa al sistema y visualiza la ficha resumen del turno vencido (quién abrió, fecha/hora, base inicial, efectivo esperado en cajón y resumen informativo de transferencias digitales).
  2. El Administrador verifica el efectivo físico real del cajón y digita obligatoriamente el monto recuperado (`0` o mayor; el sistema prohíbe confirmar en blanco o sin conteo).
  3. Si el turno vencido fue abierto por un empleado, el Administrador digita además una observación breve obligatoria (ej. *"Empleado no asistió hoy, conté gaveta"*).
  4. El servidor sella el cierre con la diferencia exacta al peso (`Efectivo Declarado - Efectivo Esperado`), estampa la marca de caducidad (`+24h`) y registra el evento de auditoría bajo la firma del Administrador.
- **Flujo Alternativo:** Si el Administrador intenta confirmar con el monto vacío o (en turno ajeno) sin observación, el sistema rechaza la operación.
- **Postcondición:** La tienda queda desbloqueada para abrir un nuevo turno y el historial contable conserva el saldo físico real declarado sin cifras asumidas.

---

## Criterios de Aceptación
- [ ] **CA-FRD-027-02-01:** Toda función RPC del servidor que registre movimientos de dinero DEBE validar primero que la diferencia entre `now()` y `opened_at` del turno activo sea estrictamente menor a 24 horas, abortando con error si se supera.
- [ ] **CA-FRD-027-02-02:** La interfaz visual DEBE inhabilitar (bloquear visualmente) las funciones operativas de venta, gastos y abonos si detecta que el estado del turno local ha cruzado el límite de 24 horas.
- [ ] **CA-FRD-027-02-03:** El sistema DEBE estampar de manera permanente un indicador booleano de "caducidad_superada" o similar en la tabla del turno, activado únicamente si el cierre ocurre posterior al límite.
