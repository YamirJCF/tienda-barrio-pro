# FRD-004: Caja Estricta Multicanal (Prohibición de Sobregiros)

### Segregación de Saldos y Protección contra Fondos Insuficientes

#### Descripción
Este documento rige la administración de la liquidez del negocio dividiendo el patrimonio en distintos canales u orígenes de pago (tales como efectivo físico, billeteras digitales o transferencias bancarias). Asegura que el sistema detenga irrevocablemente cualquier operación de extracción de dinero si el canal objetivo no posee el respaldo líquido comprobado.

---

## Reglas de Negocio
1. **Identidad del Dinero:** El servidor DEBE catalogar y almacenar cada entrada y salida de dinero manteniendo estrictamente la vinculación de origen, impidiendo la fusión matemática del dinero en un único balance general indiscriminado al momento de validar operaciones de egreso.
2. **Cálculo Particionado:** Ante la solicitud de cualquier retiro, gasto o devolución, el servidor DEBE ejecutar un cálculo de disponibilidad considerando exclusiva y aisladamente el canal de pago señalado para la transacción.
3. **Ley de Restricción Cero:** El servidor TIENE PROHIBIDO consolidar un movimiento de egreso si el cálculo matemático de saldo, tras restar el monto solicitado al balance previo del canal designado, arroja un resultado inferior a cero. 

---

## Casos de Uso

**Caso A: Bloqueo Transaccional por Insuficiencia en Billetera Digital**
- **Actor:** Usuario Operativo / Sistema Servidor.
- **Precondición:** El establecimiento presenta un consolidado patrimonial global de un millón, pero dicho dinero está disgregado: ochocientas mil unidades en efectivo físico y doscientas mil en el canal de billetera digital (Nequi).
- **Flujo Principal:**
  1. El usuario pretende registrar un egreso catalogado como "Pago de Nómina" por un valor de trescientas mil unidades, indicando que el dinero será extraído del canal de billetera digital (Nequi).
  2. El servidor intercepta la orden y aísla el cálculo. Descarta el dinero en efectivo e interroga de manera exclusiva el saldo acumulado en la billetera digital durante el período operativo.
  3. El servidor confronta el saldo exclusivo (doscientas mil unidades) contra la pretensión de gasto (trescientas mil unidades).
  4. Al identificar el déficit, el servidor interrumpe la operación a nivel de base de datos, impidiendo la grabación del egreso.
  5. El servidor rechaza la transacción y notifica el error por insuficiencia de fondos, protegiendo al canal Nequi de contraer un saldo negativo ficticio o imposible.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El egreso no se concreta, obligando al usuario a subsanar la situación operativa realizando una inyección previa de liquidez en dicho canal, o seleccionando el origen correcto de donde saldrán los fondos.

---

## Criterios de Aceptación
- [ ] **CA-FRD-004-01:** El sistema servidor DEBE particionar el cálculo del saldo consolidado utilizando el identificador único de cada canal de pago.
- [ ] **CA-FRD-004-02:** El servidor TIENE PROHIBIDO permitir el registro de movimientos de salida de capital si la suma algebraica de los movimientos de un canal resulta inferior a cero tras aplicar la operación solicitada.
- [ ] **CA-FRD-004-03:** La validación de suficiencia de fondos DEBE ocurrir de manera síncrona dentro del procesamiento del servidor, anulando transacciones si se detecta déficit, sin importar si la interfaz visual indicó saldo positivo previamente.
