# FRD-007-01: Núcleo del Punto de Venta (POS) Desacoplado

### El POS como Embudo Único de Transacciones y Egresos

#### Descripción
Este documento toma el rol principal (documento padre) sobre las reglas del POS establecidas en el FRD-007 original. Redefine al Punto de Venta no solo como una registradora de ingresos comerciales, sino como el **Único Motor Autorizado para procesar egresos físicos de inventario**. En cumplimiento con las reglas de desacoplamiento global, el POS orquesta el cruce entre los inventarios (logística) y la sesión del turno (auditoría), determinando a qué módulo financiero enviar la cuenta (Caja, Deudas o a la Basura).

---

## Reglas de Negocio

1. **Embudo Universal de Egresos de Inventario:** El POS es la única herramienta del sistema con jurisdicción para restar unidades del stock de forma rutinaria. Toda transacción que reduzca el inventario (excepto el cuadre anual por Admin) DEBE originarse en el carrito del POS.
2. **Tipología de Cierre de Carrito (Desacoplamiento):** El comportamiento post-venta depende del método de cierre seleccionado. Ningún movimiento de inventario puede quedar sin contrapartida contable:
   - **Efectivo / Nequi (Ingreso Comercial):** El POS aprueba la resta del stock y notifica al módulo de *Caja Diaria* un INGRESO equivalente al valor pagado.
   - **Fiado (Ingreso a Crédito):** El POS aprueba la resta del stock, valida el cupo del cliente y notifica al módulo de *Cuentas por Cobrar* una DEUDA por el valor total. **TIENE PROHIBIDO** notificar a la Caja Diaria sobre ingresos de efectivo. El ingreso en caja es $0.
   - **Merma / Consumo Interno (Pérdida Operativa):** El POS aprueba la resta del stock, registra la acción para auditoría del turno, y notifica al módulo de *Gastos Operativos* un EGRESO equivalente al costo del inventario perdido/consumido. El ingreso en caja es $0.
   - **Devolución a Proveedor (Ajuste de Inventario):** El POS aprueba la resta del stock, registra la acción para auditoría del turno, y notifica al módulo de *Cuentas por Pagar* un AJUSTE (disminución de deuda o nota crédito pendiente) equivalente al valor del producto devuelto. El ingreso en caja es $0.
3. **Anclaje Obligatorio al Turno Vigente:** El POS se bloquea por completo si no existe una Sesión de Caja Activa y no caducada (Límite 24H según FRD-027-02). Toda transacción procesada desde el carrito hereda forzosamente el `session_id` actual. El cajero en turno asume la responsabilidad auditable de todo lo que cobró, fió, rompió o consumió.
4. **Respeto Absoluto al Límite Logístico:** Al intentar agregar un producto al carrito, el POS realiza una lectura estricta del inventario actual. Si el stock es cero o menor a la cantidad solicitada, el sistema emite un **Bloqueo Logístico** impidiendo la adición al carrito. Ningún cajero puede dar salida a algo que el sistema cree no tener.
5. **Políticas de Redondeo (Heredadas):**
   - Subtotales redondeados al múltiplo de $50.
   - Vueltas (Cambio) calculadas mediante algoritmo de empate hacia abajo a favor del cliente.

---

## Casos de Uso

> [!NOTE]
> Los flujos exactos de interacción de usuario (pantallas y clics) se mantienen abstractos hasta que el diseño de UX defina la interfaz específica. Estos casos de uso dictan el comportamiento a nivel de motor de reglas.

**Caso A: Transacción de Pago Inmediato (El Camino Feliz)**
- **Actor:** Usuario Operativo / Cajero (con `session_id` activo).
- **Precondición:** El cliente lleva artículos físicos a la registradora.
- **Flujo Principal:**
  1. El cajero agrega los productos al carrito. El POS descuenta temporalmente la disponibilidad de inventario para evitar doble venta concurrente.
  2. El cajero selecciona cobro por Efectivo y confirma.
  3. El POS consolida la transacción.
  4. El POS envía el evento al módulo de Inventario para que registre la salida permanente.
  5. El POS envía el evento de ingreso de dinero a la sesión de caja activa.

**Caso B: Transacción a Crédito (Fiado)**
- **Actor:** Usuario Operativo / Cajero.
- **Flujo Principal:**
  1. Productos en carrito. El cajero selecciona cierre a Crédito (Fiado).
  2. El sistema requiere seleccionar un cliente de la base de datos.
  3. Se evalúa el valor total del carrito contra el "Cupo Disponible" del cliente (FRD-024).
  4. *Si hay cupo:* El POS consolida la venta, baja el inventario y transfiere la deuda al perfil del cliente. La caja no sufre alteración en su efectivo.

**Caso C: Cierre de Transacción No Monetaria (Baja Logística)**
- **Actor:** Usuario Operativo / Cajero.
- **Precondición:** Hay productos en el local que están rotos o vencidos y deben ser botados.
- **Flujo Principal:**
  1. El cajero agrega los productos averiados al carrito del POS.
  2. En lugar de seleccionar una forma de pago, selecciona una ruta de "Baja Logística" (motivo: Merma).
  3. El POS efectúa la salida de inventario.
  4. El POS clasifica esta transacción como "Merma" y la ancla al turno actual. No emite ingresos hacia la caja.

---

## Criterios de Aceptación
- [ ] **CA-FRD-007-01-01:** Si la función de backend `rpc_get_active_session` retorna nulo o caducado, cualquier intento de procesar un carrito DEBE ser abortado lanzando una excepción de sistema.
- [ ] **CA-FRD-007-01-02:** Los cierres de carrito procesados bajo la tipología "Cierre Logístico" o "Fiado" DEBEN registrar $0 en la columna de ingresos en efectivo del flujo de caja.
- [ ] **CA-FRD-007-01-03:** El sistema DEBE garantizar la atomicidad (Transacción de Base de Datos). Si el descuento de inventario falla o el incremento de deuda de fiado falla, el carrito entero hace rollback y no se asienta ningún cambio.
