# FRD-027: Núcleo de Caja Diaria (Flujo de Caja Puro)

### El Corazón Financiero y la Frontera de Liquidez

#### Descripción
Este documento establece el comportamiento central del módulo de Caja (Control de Turnos). Funciona como la máxima autoridad sobre el estado financiero diario del negocio. Basado en las nuevas directrices de arquitectura, la Caja se redefine como un sistema de "Flujo de Caja Puro": rastrea única y exclusivamente la liquidez real (física o digital) en el momento exacto en que cambia de manos, aislándose por completo de las operaciones de crédito, fiados y cuentas por pagar.

---

## Reglas de Negocio

1. **Límite de Liquidez Real:** El sistema de caja TIENE PROHIBIDO consolidar, sumar o restar valores monetarios asociados a transacciones a crédito (fiados de clientes o facturas de proveedores). La caja debe ignorar cualquier promesa de pago, calculando su saldo basándose estrictamente en ingresos líquidos y egresos líquidos.
2. **Segregación Estricta de Canales:** El saldo del turno DEBE calcularse, mostrarse y auditarse de manera separada e independiente para cada origen de fondos (por ejemplo: Efectivo, Transferencia Bancaria, Billetera Digital). Se encuentra vetada la fusión matemática de estos canales para sortear validaciones de extracción de dinero.
3. **Bloqueo Matemático de Sobregiro:** El servidor central DEBE abortar irrevocablemente cualquier intento de extraer liquidez (gastos, pagos a proveedores, devoluciones) si el canal específico designado no posee el saldo suficiente para cubrir la operación. 
4. **Independencia Logística Absoluta:** La caja opera de manera completamente agnóstica respecto a la bodega de inventario. La salida física de un producto no garantiza un ingreso en caja (caso de los fiados), y un ingreso en caja no requiere la salida simultánea de un producto (caso de los abonos a deudas pasadas).

---

## Casos de Uso

**Caso A: Cuadre de Turno con Desfase Logístico (El Cierre Limpio)**
- **Actor:** Usuario Operativo / Cajero.
- **Precondición:** Durante el turno, el usuario realizó cincuenta ventas en efectivo y diez ventas a crédito (fiados).
- **Flujo Principal:**
  1. El usuario solicita el cierre de su turno de caja.
  2. El servidor consolida todos los movimientos del día, aislando las diez ventas a crédito hacia el módulo externo de Cuentas por Cobrar.
  3. El servidor genera el reporte de cuadre exigiendo al cajero que reporte únicamente el total del dinero en efectivo recibido por las cincuenta ventas reales.
  4. El usuario cuenta las monedas y billetes, coincidiendo exactamente con la expectativa del servidor.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El turno se cierra de manera exitosa sin descuadres artificiales provocados por la mercancía fiada, protegiendo al cajero de rendir cuentas por dinero que nunca tocó la caja.

**Caso B: Ingreso Diferido (Recepción de Abono)**
- **Actor:** Usuario Operativo / Cajero.
- **Precondición:** Un cliente que adquirió productos a crédito la semana pasada acude al local para pagar su deuda entregando un billete físico.
- **Flujo Principal:**
  1. El usuario registra la recepción del dinero en el módulo de Cuentas por Cobrar, asociando el pago al canal "Efectivo".
  2. El servidor descuenta la deuda del cliente en el módulo externo.
  3. De manera automática e instantánea, el servidor inyecta ese dinero como un "Ingreso por Abono" dentro del turno de caja vigente.
  4. El saldo de efectivo del turno actual aumenta, y el cajero deposita el billete en la registradora.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El efectivo entra al sistema contable en el instante exacto en que ingresa al establecimiento, justificando el incremento físico de billetes durante el cierre del turno.

---

## Criterios de Aceptación
- [ ] **CA-FRD-027-01:** El reporte de cierre de caja DEBE omitir de sus sumatorias globales cualquier valor clasificado estructuralmente como cuenta por cobrar, cuenta por pagar o venta a crédito.
- [ ] **CA-FRD-027-02:** El sistema carece de opciones para mezclar saldos de diferentes canales (ej. sumar Efectivo y Nequi) con el propósito de autorizar un egreso de dinero unificado.
- [ ] **CA-FRD-027-03:** Todo movimiento monetario inyectado hacia la caja desde módulos externos (pago de deudas, recepción de abonos) afecta indefectiblemente el saldo del turno vigente en el canal seleccionado, sin excepciones lógicas.
