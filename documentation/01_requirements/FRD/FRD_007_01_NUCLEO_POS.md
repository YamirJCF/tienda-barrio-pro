# FRD-007-01: Núcleo del Punto de Venta (POS) y Caja Dedicada

### El POS como Caja Dedicada de Transacciones de Mostrador (`POL-FIN-01`, `POL-FIN-05`, `FRD-003-01`)

#### Descripción
Este documento rige las reglas del Punto de Venta (POS) como **Caja Dedicada** del mostrador. El POS procesa ventas de contado/digitales, ventas a crédito (Fiado), retiros de **Consumo/Retiro Personal** (operados literalmente como una venta asignada al perfil propio) y aloja al lado de su buscador el acceso rápido a **Reembolsos** (`FRD-006-02`). Las salidas logísticas de bodega/estante (Mermas, Consumo del negocio, Devoluciones físicas a proveedor y Ajustes por conteo físico) se gestionan según `FRD-006-01-02` sin simular ventas ni alterar automáticamente Cuentas por Pagar.

---

## Reglas de Negocio

1. **Alcance del Carrito del POS y Botón de Reembolsos:**
   - El carrito del POS procesa las salidas de mercancía por **Venta Comercial** (Efectivo, Nequi, Llave BRE o Fiado) y por **Consumo / Retiro Personal**.
   - Al lado del buscador del POS se ubica el acceso a **Reembolsos** (`FRD-006-02`), habilitado para usuarios con el permiso `Reembolsos` y turno abierto.

2. **Tipología de Cierre de Carrito (`POL-FIN-05`):**
   El comportamiento al finalizar un carrito en el POS depende del método seleccionado y estampa siempre la **firma individual** de la cuenta activa:
   - **Efectivo / Nequi / Llave BRE (Ingreso Comercial):** Descuenta stock y registra en la **Caja Dedicada POS** un ingreso en el canal seleccionado por el valor pagado.
   - **Fiado (Ingreso a Crédito, requiere permiso `Fiar y cobrar abonos`):** Descuenta stock, valida el cupo disponible del cliente (`FRD-009`, `FRD-024`) y registra la deuda en Cuentas por Cobrar. **TIENE PROHIBIDO** sumar dinero a la Caja Dedicada POS (impacto en caja = **$0**).
   - **Consumo / Retiro Personal (`POL-LOG-03`, `FRD-006-01-02`):** Disponible para cualquier usuario activo. Opera **literalmente como una venta** (mostrando sus precios e información normal), asignada automáticamente al **propio perfil del empleado** que opera la sesión (**solo el Administrador puede seleccionar el perfil de otra persona**). Descuenta stock, registra **$0 en la Caja Dedicada POS** y contabiliza el retiro al **costo de adquisición** (con precio de venta de referencia) en el historial por perfil y consolidado del P&L (`FRD-018`).

3. **Anclaje Obligatorio al Turno Vigente y Visibilidad Propia:**
   - El POS se bloquea para ventas, consumo personal en carrito y reembolsos si no existe una Sesión de Caja Dedicada POS abierta y no caducada (límite 24h según `FRD-027-02`).
   - Toda transacción procesada desde el POS hereda forzosamente el `session_id` actual y la **firma individual** (con fotografía histórica de nombre y rol) de la cuenta que la ejecutó.
   - Durante el turno, el empleado puede consultar únicamente **sus propios movimientos del turno actual, con toda su información** (`FRD-003-01` R2.5).

4. **Respeto Absoluto al Límite Logístico (`POL-LOG-02`):**
   - Al agregar un producto al carrito del POS, el sistema verifica el stock actual. Si el stock es cero o menor a la cantidad solicitada, emite un **Bloqueo Logístico** impidiendo la salida.

5. **Políticas de Redondeo (Heredadas):**
   - Subtotales redondeados al múltiplo de $50.
   - Vueltas (Cambio) calculadas mediante algoritmo de empate hacia abajo a favor del cliente.

6. **Pausa Operativa Exclusiva para Empleados (`POL-PROD-01`, `ARQ-005`):**
   - El control de pausa de actividad del turno dentro del POS (diseñado para reportar estado de presencia ante el supervisor) DEBE presentarse únicamente cuando quien opera la sesión es un **empleado**, permaneciendo oculto cuando quien opera es el propio **Administrador**.

---

## Casos de Uso

**Caso A: Transacción de Pago Inmediato (Contado / Digital)**
- **Actor:** Usuario activo con Pase Diario y turno de Caja Dedicada POS abierto.
- **Flujo Principal:**
  1. El operador agrega los productos al carrito.
  2. Selecciona cobro por **Efectivo, Nequi o Llave BRE** y confirma.
  3. El servidor descuenta el stock, registra el ingreso en el canal elegido de la Caja Dedicada POS y estampa la firma individual del operador.

**Caso B: Transacción a Crédito (Fiado)**
- **Actor:** Administrador o Empleado con permiso **`Fiar y cobrar abonos`**.
- **Flujo Principal:**
  1. Productos en carrito. El operador selecciona cierre a **Fiado** y elige un cliente activo.
  2. El servidor verifica que el usuario tenga el permiso `Fiar y cobrar abonos` y evalúa el total contra el cupo disponible del cliente (`FRD-024`).
  3. Si tiene permiso y cupo, consolida la venta con su firma individual, descuenta stock y suma la deuda al cliente ($0 en Caja Dedicada POS).

**Caso C: Registro de Consumo / Retiro Personal desde el POS**
- **Actor:** Cualquier usuario activo (Empleado o Administrador).
- **Flujo Principal:**
  1. El usuario agrega al carrito del POS los productos que va a retirar para consumo personal (viendo sus precios y datos normales como en una venta).
  2. Selecciona el cierre como **Consumo / Retiro Personal** (si es empleado, queda asignado obligatoriamente a su propio perfil; si es Administrador, puede asignarlo a sí mismo o seleccionar a otro perfil).
  3. El servidor descuenta el stock, registra **$0 en la Caja Dedicada POS** y guarda el movimiento con firma individual en el historial de consumo personal por perfil y consolidado (`FRD-018`).

---

## Criterios de Aceptación
- [ ] **CA-FRD-007-01-01:** Si la sesión de Caja Dedicada POS está cerrada o expirada (+24h), cualquier intento de procesar un carrito en el POS es abortado por el servidor.
- [ ] **CA-FRD-007-01-02:** Los cierres de carrito bajo **"Fiado"** (exclusivo para Admin o permiso `Fiar y cobrar abonos`) o **"Consumo / Retiro Personal"** (asignado al propio perfil del empleado; solo Admin elige a otros) registran **$0** de ingreso en la Caja Dedicada POS.
- [ ] **CA-FRD-007-01-03:** El botón de **Reembolsos** se encuentra en el POS al lado del buscador y opera según `FRD-006-02`.
- [ ] **CA-FRD-007-01-04:** Toda transacción es atómica en base de datos y estampa la firma individual inmutable de la cuenta ejecutora.
- [ ] **CA-FRD-007-01-05:** El botón y estado de pausa de supervisión en el POS se muestran exclusivamente a perfiles de empleado y nunca al propio Administrador.
