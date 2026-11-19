# FRD-006-01-02: Salidas Logísticas, Consumos (Negocio vs. Personal) y Ajustes de Conteo Físico

### Separación Contable y Logística con Firma Individual (`POL-LOG-03`, `POL-FIN-05`, `FRD-003-01`)

#### Descripción
Este documento regula las reducciones y correcciones no comerciales de inventario (**Mermas, Consumo del Negocio, Consumo/Retiro Personal, Devolución Física a Proveedor y Ajustes por Conteo Físico**). Elimina la antigua prohibición que bloqueaba las salidas en Inventario y obligaba a simular todas las bajas en el POS con caja abierta. Separa claramente la **Logística** (unidades físicas en estante), la **Contabilidad de Caja Dedicada POS** (impacto **$0** en el cajón del turno) y la **Rentabilidad del Negocio (`P&L` en `FRD-018`)** (valoración al **costo de adquisición**), exigiendo siempre **firma individual inmutable** y motivo obligatorio.

---

## Reglas de Negocio

1. **Impacto $0 en la Caja Dedicada POS e Independencia de Turno para Bodega (`POL-FIN-01`, `POL-LOG-01`):**
   - Ninguna merma, consumo del negocio, consumo/retiro personal, devolución física a proveedor ni ajuste de conteo suma o resta dinero de la **Caja Dedicada POS** (su efecto en el arqueo de efectivo y canales digitales es **$0**).
   - Las salidas de bodega/estante (**Merma, Consumo del negocio, Devolución física a proveedor y Ajuste por conteo físico**) NO requieren que la Caja Dedicada POS esté abierta (si existe un turno abierto, se asocia únicamente como referencia informativa).

2. **Mermas y Consumo Operativo del Negocio (Abiertos a Cualquier Usuario Activo, `POL-LOG-03`):**
   - **Cualquier usuario activo** (Administrador o empleado con Pase Diario, sin requerir el permiso `Inventario completo`) puede registrar:
     - **Merma:** producto roto, dañado o vencido.
     - **Consumo del Negocio:** insumos o productos del estante usados para la operación propia de la tienda (aseo, atención, bolsas).
   - Ambos descuentan stock de inmediato, exigen **motivo obligatorio** y **firma individual**, no muestran el costo unitario si el empleado no posee `Inventario completo`, y se contabilizan internamente al **costo de adquisición** en el Estado de Resultados (`FRD-018`).

3. **Consumo / Retiro Personal (Separado del Consumo del Negocio y Operado como Venta en POS, `POL-FIN-05`):**
   - El **Consumo/Retiro Personal** (productos tomados para consumo propio por un empleado o el dueño) se separa explícitamente del Consumo del Negocio.
   - Se opera **literalmente como una venta en el POS** (mostrando sus precios e información normal):
     - Si lo registra un **Empleado**, queda asignado automáticamente a **su propio perfil** (un empleado tiene prohibido seleccionar el perfil de otro compañero).
     - **Solo el Administrador** puede seleccionar el perfil de otra persona al registrar un Consumo/Retiro Personal.
   - Descuenta stock de inmediato, registra **$0 en la Caja Dedicada POS** y se guarda con firma individual para que el Administrador pueda consultar el **historial por perfil y consolidado** (valorado al costo de adquisición y conservando el precio de venta como referencia en `FRD-018`).

4. **Ajustes por Conteo Físico y Devolución Física a Proveedor (Bajo Permiso `Inventario completo`, `FRD-003-01`):**
   - Cualquier usuario con el permiso **`Inventario completo`** (o el Administrador) puede ejecutar:
     - **Ajuste por Conteo Físico:** corrección positiva o negativa al detectar diferencias entre el conteo físico de estantería y el stock del sistema, exigiendo motivo obligatorio, firma individual y generando una **alerta de auditoría para el Administrador**.
     - **Devolución Física a Proveedor:** salida logística de unidades devueltas físicamente al repartidor/proveedor, con motivo obligatorio y firma individual. Esta operación tiene impacto **$0 en Caja POS** y **NO altera automáticamente Cuentas por Pagar** (`POL-LOG-01`, `FRD-019` — cualquier ajuste en facturas por pagar es exclusivo del Administrador).

5. **Inmutabilidad de Registros (`POL-AUD-01`):**
   - Ningún registro de merma, consumo (del negocio o personal), devolución física o ajuste por conteo físico puede borrarse ni editarse una vez confirmado. Cualquier error de digitación se corrige exclusivamente mediante un contra-movimiento o ajuste auditable con firma individual.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-01-02-01:** Cualquier usuario activo puede registrar **Mermas** y **Consumo del Negocio** con motivo obligatorio y firma individual, sin exigir caja abierta ni alterar el saldo de la Caja Dedicada POS ($0).
- [ ] **CA-FRD-006-01-02-02:** El **Consumo/Retiro Personal** está separado del Consumo del Negocio, se opera literalmente como una venta en el POS ($0 en Caja POS) asignada al propio perfil del empleado (solo el Admin puede elegir a otros), y es consultable por el Administrador en historial **por perfil y consolidado** (`FRD-018`).
- [ ] **CA-FRD-006-01-02-03:** Los **Ajustes por Conteo Físico** y la **Devolución Física a Proveedor** (sin tocar Cuentas por Pagar) están habilitados para el Administrador y empleados con permiso `Inventario completo`, dejando firma individual, alerta administrativa y registro inmutable (corrección solo por contra-movimiento).
