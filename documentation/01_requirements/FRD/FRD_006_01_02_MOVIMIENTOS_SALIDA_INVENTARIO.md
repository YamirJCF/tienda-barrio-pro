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

> [!NOTE]
> **Alcance Diferido:** Los casos de uso exactos (flujo de interacción del usuario) para registrar Mermas, Devoluciones y Consumo Interno quedan intencionalmente omitidos en este documento. Su definición técnica y visual queda sujeta al rediseño de la interfaz del Punto de Venta (POS). No se documentarán flujos ficticios hasta que no se defina cómo el POS absorberá esta responsabilidad nativamente.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-01-02-01:** La interfaz visual del módulo de Inventario (`/inventory`) DEBE carecer por completo de pestañas, botones o formularios etiquetados como "Salida", "Devolución a Proveedor" o "Merma".
- [ ] **CA-FRD-006-01-02-02:** El módulo del POS DEBE absorber la responsabilidad de procesar salidas no monetarias, mediante un mecanismo de UX/UI que será definido posteriormente (Documentación Pendiente).
- [ ] **CA-FRD-006-01-02-03:** El Reporte de Turno de Caja (FRD-027-01) DEBE listar las transacciones de salidas (Mermas, Consumo, etc.) vinculadas al `session_id` del turno, separadas del efectivo real.
