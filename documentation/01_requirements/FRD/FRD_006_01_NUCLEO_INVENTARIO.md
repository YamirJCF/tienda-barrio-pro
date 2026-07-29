# FRD-006-01: Núcleo de Inventario Desacoplado

### Frontera Logística y Aislamiento Contable

#### Descripción
Este documento toma el rol principal (documento padre) sobre las reglas establecidas en el FRD-006 original. Su propósito es redefinir el Inventario estrictamente como un **ente logístico aislado**. Bajo la nueva arquitectura de sistemas desacoplados, el Inventario se desvincula por completo del Flujo de Caja y de las Cuentas por Pagar/Cobrar. Su única jurisdicción es la existencia física de la mercancía, ignorando el estado financiero del negocio.

---

## Reglas de Negocio

1. **Aislamiento Financiero Total:** El módulo de inventario (Kardex) TIENE PROHIBIDO condicionar sus movimientos logísticos al estado financiero de una transacción. La salida física de un producto ocurre independientemente de si el cliente pagó en efectivo, por transferencia, o si la mercancía se entregó a crédito (fiado).
2. **Autoridad Logística Exclusiva (Cantidades, No Dinero):** La única métrica de verdad del inventario son las cantidades físicas (unidades, kilos, gramos). Los reportes de inventario DEBEN omitir cualquier cruce matemático con el flujo de caja diario. El inventario no sabe ni le importa cuánto dinero hay en la registradora.
3. **Bloqueo Estrictamente Físico:** El sistema DEBE abortar cualquier operación de salida (venta, merma, devolución a proveedor) si el cálculo resultante llevara el stock a un número negativo. Este es un bloqueo logístico absoluto y funciona de manera autónoma a las validaciones de caja.
4. **Desacoplamiento de Proveedores:** El ingreso de mercancía al almacén (Entrada de Inventario) suma las unidades de manera instantánea al catálogo. Esta operación logística TIENE PROHIBIDO disparar un egreso automático en la caja diaria. Si la mercancía se paga de inmediato, es un evento separado manejado por el módulo de Gastos/Caja; si se debe, es manejado por Cuentas por Pagar.
5. **Independencia Histórica (Inmutabilidad Financiera):** Las actualizaciones de catálogo (cambios de precio, corrección de costos, o eliminación lógica de un producto) TIENEN PROHIBIDO alterar retrospectivamente el valor monetario de las ventas o ingresos ya registrados en la caja o en el historial de deudas.

---

## Casos de Uso

**Caso A: Venta a Crédito (Salida Logística Pura)**
- **Actor:** Usuario Operativo / Cajero.
- **Precondición:** Un cliente asiduo toma una bolsa de arroz de la estantería, pero solicita que se le anote en su cuenta (Fiado).
- **Flujo Principal:**
  1. El usuario registra la transacción como Venta a Crédito.
  2. El módulo de ventas notifica al módulo de inventario sobre la salida de 1 bolsa de arroz.
  3. El inventario descuenta 1 unidad de su stock físico y lo registra en el Kardex como "Salida por Venta".
  4. La transacción finaliza sin enviar ninguna notificación de ingreso al módulo de Caja.
- **Flujo Alternativo:** Si el inventario del arroz era 0 antes de la operación, el sistema bloquea la venta completa y emite un error de "Stock insuficiente", a pesar de ser un fiado.
- **Postcondición:** La mercancía abandona el local físicamente (Kardex ajustado), pero el dinero en la caja diaria permanece intacto.

**Caso B: Recepción de Mercancía a Crédito**
- **Actor:** Usuario con permisos de gestión de inventario.
- **Precondición:** Llega el camión de refrescos y deja 50 unidades, otorgando un plazo de 15 días para pagar la factura.
- **Flujo Principal:**
  1. El usuario registra una "Entrada" en el inventario por 50 unidades de refresco.
  2. El sistema actualiza el stock, habilitando esos productos para la venta inmediata.
  3. El sistema NO extrae dinero de la caja diaria, aislando el impacto logístico del impacto financiero.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El inventario sube al instante, permitiendo ventas inmediatas, pero el flujo de caja del turno no sufre ninguna alteración (cero egresos).

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-01-01:** Las funciones de base de datos responsables de actualizar el stock (Kardex) DEBEN carecer por completo de dependencias lógicas hacia la tabla de sesiones de caja.
- [ ] **CA-FRD-006-01-02:** Los reportes de inventario (historial de movimientos) TIENEN PROHIBIDO sumar, proyectar o mostrar columnas referentes a "Dinero cobrado en caja".
- [ ] **CA-FRD-006-01-03:** Una operación de ingreso de mercancía DEBE actualizar el stock en tiempo real, incluso si el turno de caja se encuentra cerrado o caducado.
