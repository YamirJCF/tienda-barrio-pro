# FRD-027-01: Reportes y Auditoría de Caja Diaria

### Veracidad Financiera y Reportes Blindados

#### Descripción
Este documento rige la generación, visualización y protección de la información financiera extraída del núcleo de caja (definido en FRD-027). Establece una separación estricta entre la información operativa (diseñada para el usuario de mostrador) y la información de auditoría interna (diseñada para el sistema y el propietario). El objetivo primordial es garantizar la fidelidad matemática, prevenir la manipulación de datos y aplicar medidas de seguridad de alto nivel operativo como el "arqueo ciego".

---

## Reglas de Negocio
1. **Exclusividad de Reportes de Caja para el Administrador y Visibilidad Propia del Empleado (`POL-SEG-03`, `POL-AUD-02`, `FRD-003-01`):**
   - **Visibilidad del Empleado durante el turno:** El empleado no posee permiso de reportes; durante su jornada únicamente puede ver **sus propios movimientos realizados en el turno actual, con toda su información**, sin acceso a saldos esperados de caja ni movimientos de otros usuarios.
   - **Reporte de Auditoría y Cierre de Caja (100% Exclusivo del Administrador):** Muestra los resúmenes limpios por canal (**Efectivo, Nequi y Llave BRE**), cada movimiento con su firma individual, intentos fallidos, reembolsos (con o sin etiqueta `"merma"`), gastos menores de turno y discrepancias entre lo físico declarado y lo calculado.
2. **Arqueo Físico de Efectivo y Cierre Diferenciado por Rol (`POL-SEG-01`, `POL-PROD-01`):** El conteo manual de cierre aplica exclusivamente al **efectivo físico del cajón** (exigiendo digitación explícita y prohibiendo campos vacíos asumidos como `$0`), mientras los canales digitales (**Nequi y Llave BRE**) se calculan en el servidor como resumen informativo de transferencias del turno. Cuando cierra el **Administrador**, visualiza el efectivo esperado y el resumen digital del turno y sella en un paso. Cuando cierra el **empleado titular**, el sistema TIENE PROHIBIDO mostrarle el saldo esperado o la diferencia: si la diferencia absoluta en efectivo es menor o igual a `P_MARGEN_DESCUADRE_EFECTIVO` (`ARQ-004`), sella en ese intento sin rebote ni alerta; si supera `P_MARGEN_DESCUADRE_EFECTIVO`, **solo avisa que no coincide** dando hasta **3 intentos** para revisar o recontar y, al **tercer intento**, sella el cierre y envía una **notificación/alerta inmediata al Administrador**.
3. **Inmutabilidad del Cierre y Exactitud al Peso (Sello de Tiempo):** En el instante en que se confirma el cierre, el servidor DEBE generar una instantánea matemática irreversible con los acumulados por canal y la **diferencia exacta al peso en efectivo** (`Efectivo Contado - Efectivo Esperado`), tanto si dicha diferencia estuvo dentro como fuera de `P_MARGEN_DESCUADRE_EFECTIVO`, sujeta únicamente a la excepción auditada de sincronización tardía offline (`LATE_SYNC_UPDATE` de `FRD-017` atribuida a quien vendió sin conexión).
4. **Fidelidad al Flujo Puro de la Caja Dedicada POS (`POL-FIN-01`):** Fiel a las reglas de caja, los reportes de turno TIENEN PROHIBIDO proyectar ingresos futuros (fiados no cobrados), egresos futuros (facturas pendientes), pagos marcados como **"pago externo / fuera de caja"** o bajas logísticas `$0` (mermas y consumos). El reporte de caja refleja exclusivamente la liquidez que cambió de manos en los canales de la Caja Dedicada POS en ese turno.
5. **Autenticidad de Descuadres y Alerta al Tercer Intento (`POL-AUD-03`, `POL-SEG-01`):** Toda diferencia distinta de cero entre el efectivo físico declarado y el efectivo esperado DEBE quedar registrada al peso exacto en el reporte de auditoría del Administrador. Cuando un empleado titular supera `P_MARGEN_DESCUADRE_EFECTIVO` tras agotar los **3 intentos** del Cierre Asistido, el sistema DEBE además emitir una notificación/alerta inmediata al Administrador.
6. **Navegación Temporal por Turnos Cerrados:** El módulo de reportes DEBE permitir al Administrador consultar turnos cerrados anteriores mediante un mecanismo de selección temporal.
   - **Unidad de consulta:** El turno (sesión de caja) es la unidad atómica. No existe un "reporte diario" consolidado; cada turno se inspecciona individualmente.
   - **Listado de turnos:** El sistema DEBE presentar una lista cronológica de turnos cerrados, mostrando para cada uno: fecha, hora de apertura, hora de cierre, empleado responsable y estado de cuadre (con/sin descuadre).
   - **Filtro por rango de fechas:** El listado de turnos cerrados DEBE ser filtrable por un rango de fechas (desde–hasta). Por defecto, el sistema muestra los turnos de los últimos 7 días.
   - **Acceso al detalle:** Al seleccionar un turno cerrado de la lista, el sistema DEBE mostrar el reporte de auditoría interna completo de ese turno, con los mismos datos que se generaron al momento del cierre (instantánea inmutable, Regla 3).

---

## Casos de Uso

**Caso A: Ejecución de Arqueo Ciego con Cierre Asistido por un Empleado (Hasta 3 Intentos con Margen)**
- **Actor:** Empleado titular que abrió el turno.
- **Precondición:** Llega el final de la jornada. El sistema sabe internamente cuál es el efectivo esperado en la gaveta física.
- **Flujo Principal:**
  1. El empleado titular inicia el proceso de cierre.
  2. El sistema solicita digitar explícitamente el efectivo físico contado en la gaveta, ocultando el valor esperado y sin exigir conteo manual de Nequi ni Llave BRE.
  3. El empleado cuenta los billetes y monedas e ingresa un monto cuya diferencia frente al esperado supera `P_MARGEN_DESCUADRE_EFECTIVO`.
  4. El servidor detecta que la diferencia excede `P_MARGEN_DESCUADRE_EFECTIVO` y **solo avisa que no coincide** (sin mostrar el monto esperado), permitiendo revisar o recontar hasta un máximo de **3 intentos**.
  5. Si al **tercer intento** persiste una diferencia superior a `P_MARGEN_DESCUADRE_EFECTIVO`, el servidor sella el turno con el monto declarado, guarda la instantánea inmutable con la diferencia exacta al peso para el Administrador y dispara una **notificación/alerta inmediata al Administrador**.
- **Flujo Alternativo:** Si en el primer, segundo o tercer intento la diferencia absoluta en efectivo es menor o igual a `P_MARGEN_DESCUADRE_EFECTIVO`, el turno se sella de inmediato sin alerta crítica, guardando igualmente la diferencia exacta al peso en el reporte del Administrador. (Cuando quien cierra es el propio Administrador, visualiza el efectivo esperado y el resumen digital del turno y cierra en un solo paso).
- **Postcondición:** El turno se cierra preservando la verdad contable al peso, evitando fatiga de alertas por monedas sueltas y sin revelar el monto esperado al empleado.

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
- [ ] **CA-FRD-027-01-01:** La interfaz visual orientada al empleado DEBE ocultar obligatoriamente el acumulado de efectivo esperado antes, durante y después del formulario de cierre de turno, mientras que al Administrador sí le muestra el efectivo esperado y el resumen informativo de canales digitales al cerrar.
- [ ] **CA-FRD-027-01-02:** El servidor DEBE rechazar cualquier petición de base de datos que intente aplicar una operación de edición (UPDATE) o borrado (DELETE) sobre el registro histórico de un turno ya cerrado.
- [ ] **CA-FRD-027-01-03:** El servidor DEBE almacenar de manera inmutable y exacta al peso toda diferencia entre el efectivo esperado y el efectivo declarado (esté dentro o fuera de `P_MARGEN_DESCUADRE_EFECTIVO`), disparando alerta inmediata al Administrador cuando un empleado supere dicho margen al tercer intento.
- [ ] **CA-FRD-027-01-04:** El módulo de reportes DEBE presentar una lista cronológica de turnos cerrados filtrable por rango de fechas (desde–hasta).
- [ ] **CA-FRD-027-01-05:** Cada turno cerrado en la lista DEBE mostrar: fecha, hora de apertura, hora de cierre, empleado responsable y estado de cuadre.
- [ ] **CA-FRD-027-01-06:** Al seleccionar un turno cerrado, el sistema DEBE mostrar la instantánea inmutable del reporte de auditoría de ese turno.
