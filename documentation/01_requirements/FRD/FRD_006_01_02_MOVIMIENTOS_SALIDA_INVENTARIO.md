# FRD-006-01-02: Prohibición de Salidas Manuales y Delegación al POS

### El POS como Embudo Único de Egresos

#### Descripción
Este documento erradica la subfunción de "Salidas Manuales" (Mermas, Consumos, Devoluciones) del módulo de Inventario. Históricamente, permitir que el inventario descuente productos de forma aislada creaba un "agujero negro contable", donde la mercancía desaparecía sin dejar rastro financiero en la jornada laboral. Para garantizar una auditoría estricta, **toda salida de mercancía que implique una pérdida o movimiento de activos DEBE canalizarse obligatoriamente a través de la caja registradora (POS)**.

---

## Reglas de Negocio

1. **Prohibición de Egresos Ciegos:** El módulo de Inventario TIENE PROHIBIDO ofrecer interfaces o botones para registrar salidas de mercancía (Pérdidas, Mermas, Consumo Interno, Devolución a Proveedor). El módulo de inventario queda restringido exclusivamente a **Entradas** (recibir mercancía) y **Ajustes de Cuadre** (Inventario físico anual/mensual por el Admin).
2. **El POS como Motor Único de Salida:** Toda reducción de stock operativo DEBE procesarse escaneando el producto en la interfaz del Punto de Venta (POS). Para el sistema, una botella rota es una "transacción" tan importante como una venta exitosa.
3. **Clasificación del Gasto en POS:** En la pantalla de cobro del POS, el sistema habilitará métodos de "Cierre Alternativo" que no involucran dinero del cliente. En lugar de cobrar en Efectivo, el cajero cerrará el carrito usando opciones como:
   - *Baja por Merma*
   - *Consumo Interno*
   - *Devolución a Proveedor*
4. **Anclaje Inquebrantable al Turno de Caja:** Al canalizar las salidas por el POS, el valor monetario (a costo o precio de venta) de la mercancía destruida o consumida queda **anclado permanentemente al turno activo del cajero**. Esto permite que el Arqueo de Caja (Reporte Z) audite exactamente cuánta mercancía se "perdió" bajo la guardia de un empleado específico.
5. **Aislamiento de la Utilidad:** Las transacciones cerradas como Merma o Consumo Interno NO SUMAN al "Total de Ventas" (ingresos) del turno, pero sí se totalizan en una sección separada del reporte llamada "Pérdidas / Bajas del Turno".

---

## Casos de Uso

**Caso A: Registro de Merma (Ej. Botella Rota)**
- **Actor:** Usuario Operativo / Cajero.
- **Precondición:** Un empleado accidentalmente rompe una botella de aceite en el pasillo. La botella es insalvable y debe ir a la basura.
- **Flujo Principal:**
  1. El empleado lleva el código de barras (o el producto) a la caja registradora y lo escanea en el POS.
  2. En lugar de presionar "Cobrar", selecciona la opción especial "Baja de Inventario" y elige "Pérdida/Merma".
  3. El POS registra una transacción con valor de ingreso cero ($0) para la caja, pero anota la salida del producto.
  4. El sistema descuenta 1 unidad del stock de inventario.
- **Flujo Alternativo:** Si el sistema marca que hay 0 botellas en stock, el POS prohíbe darla de baja (Bloqueo Logístico), obligando a realizar un Cuadre de Inventario primero.
- **Postcondición:** El inventario físico cuadra. El dueño, al revisar el reporte de caja de ese día, verá en la sección de bajas: *"1 Botella de Aceite - Merma - Registrado por Cajero X"*.

**Caso B: Consumo Interno**
- **Actor:** Usuario Operativo / Cajero.
- **Precondición:** El dueño autoriza al cajero a tomarse un refresco y unas galletas de la tienda para su refrigerio.
- **Flujo Principal:**
  1. El cajero escanea el refresco y las galletas en el POS.
  2. Selecciona el cierre especial "Consumo Interno".
  3. El inventario se descuenta.
  4. La transacción queda amarrada al turno actual.
- **Postcondición:** Los productos salen del inventario legalmente sin afectar el descuadre del efectivo en caja.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-01-02-01:** La interfaz visual del módulo de Inventario (`/inventory`) DEBE carecer por completo de pestañas, botones o formularios etiquetados como "Salida", "Devolución" o "Merma".
- [ ] **CA-FRD-006-01-02-02:** El componente del POS (`POSView`) DEBE incluir un flujo o botón de "Baja/Merma" que permita vaciar el carrito actual catalogando los productos como egresos no monetarios.
- [ ] **CA-FRD-006-01-02-03:** El Reporte de Turno de Caja (FRD-027-01) DEBE ser capaz de consultar y listar las transacciones de tipo "Merma/Consumo" que ocurrieron usando el `session_id` del turno.
