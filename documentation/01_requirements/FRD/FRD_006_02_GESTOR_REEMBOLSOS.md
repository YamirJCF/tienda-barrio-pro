# FRD-006-02: Gestor de Reembolsos (Devoluciones de Clientes)

### Acción Única de Devolución con Etiqueta `"merma"` y Egreso de Caja Dedicada POS (`POL-FIN-04`, `POL-LOG-02`, `FRD-003-01`)

#### Descripción
Herramienta ubicada directamente en el **Punto de Venta (POS), al lado del buscador**, diseñada para procesar devoluciones de productos por parte de clientes cuando la **Caja Dedicada POS está abierta**. Resuelve en **una sola acción** el flujo de dinero y mercancía mediante una única etiqueta opcional **`"merma"`**: si el producto devuelto lleva la etiqueta `"merma"` (porque viene dañado o vencido), el sistema lee la etiqueta, el producto **no pasa por el inventario vendible** y se ejecuta directamente su salida como merma; si no lleva la etiqueta `"merma"`, el producto se reingresa al inventario para otra venta.

---

## Reglas de Negocio

1. **Control de Acceso Basado en el Permiso `Reembolsos` (`POL-SEG-03`, `FRD-003-01`):**
   - No se requieren PINs temporales y es independiente del permiso de inventario.
   - El botón de Reembolsos (ubicado en el POS, al lado del buscador) solo puede ser ejecutado por el Administrador o por un empleado que tenga activado el permiso **`Reembolsos`** y un turno de Caja Dedicada POS abierto.

2. **Búsqueda Flexible del Producto:**
   - El operador puede localizar el producto devuelto buscando por **nombre, código de barras o PLU** (no está restringido únicamente a digitar PLU manual).

3. **Cálculo de Monto Estricto e Inmutable:**
   - Una vez seleccionado el producto e ingresada la cantidad de unidades, el sistema calcula automáticamente el valor monetario a devolver (basado en el precio de venta del sistema). Este monto total es **exacto e inalterable** manualmente por el usuario.

4. **Acción Única con Etiqueta `"merma"` y Egreso de Caja (`POL-LOG-02`, `POL-FIN-04`):**
   - Al confirmar el reembolso, el servidor ejecuta una única transacción atómica con la **firma individual** del usuario:
     - **Evento Financiero:** Registra un egreso tipificado como **Reembolso** en la Caja Dedicada POS activa por el monto exacto calculado, en el canal de salida seleccionado.
     - **Evento Logístico de Acción Única (Etiqueta `"merma"`):** El operador puede marcar una única etiqueta **`"merma"`** si el producto devuelto está dañado o no sirve para volver a vender:
       - **Con etiqueta `"merma"`:** El sistema lee la etiqueta; el producto **no pasa por el inventario vendible** (no suma ni resta del stock actual, por lo que se procesa sin bloqueo incluso si el stock vendible actual está en `0`) y se ejecuta directamente su salida/pérdida como **Merma** (valorada al costo de adquisición en el P&L de `FRD-018`).
       - **Sin etiqueta `"merma"`:** El producto se reingresa directamente al inventario vendible (`+cantidad`) para otra venta.

5. **Dependencia de Turno Activo en la Caja Dedicada POS:**
   - Para entregar dinero al cliente, el sistema exige que la Caja Dedicada POS tenga un turno abierto y vigente (<24h). El egreso queda amarrado al `session_id` actual y a la firma individual del operador.

6. **Selección de Canal y Validación de Fondos por Canal (`POL-FIN-02`):**
   - Todo reembolso DEBE especificar el canal real por el cual sale el dinero: **EFECTIVO**, **NEQUI** o **LLAVE BRE** (Efectivo preseleccionado por defecto).
   - El formulario incluye una lista desplegable para registrar el **Canal de Venta Original** (Efectivo, Nequi, Llave BRE) por trazabilidad.
   - El servidor DEBE validar fondos disponibles exclusivamente en el canal de egreso seleccionado. Si los fondos no alcanzan, rechaza la operación completa sin modificar inventario ni caja.

7. **Trazabilidad Contable e Inmutabilidad (`POL-AUD-01`, `POL-AUD-02`):**
   - El egreso se clasifica como **Reembolso** (separado de gastos menores) para que `FRD-018` calcule $\text{Ingresos Netos} = \text{Ventas Brutas} - \text{Devoluciones}$, mientras que si llevó la etiqueta `"merma"`, su costo alimenta el rubro de Mermas en el P&L.
   - El registro almacena: `session_id`, **firma individual del usuario responsable**, producto, cantidad, etiqueta `"merma"` (sí/no), monto reembolsado, canal de egreso y canal de venta original. Ambos registros son inmutables (cualquier error se corrige mediante contra-movimiento).

---

## Casos de Uso

**Caso A: Reembolso de Producto (Apto para Venta o con Etiqueta `"merma"`)**
- **Actor:** Administrador o Empleado con permiso `Reembolsos`.
- **Precondición:** Turno de Caja Dedicada POS abierto y canal de salida con fondos suficientes.
- **Flujo Principal:**
  1. En la pantalla del POS, el actor pulsa el botón **Reembolsos** (al lado del buscador).
  2. Busca el producto por nombre, código o PLU e ingresa la cantidad devuelta.
  3. Si el producto viene dañado o vencido, activa la etiqueta **`"merma"`**.
  4. El sistema muestra el total exacto e inmutable a reembolsar.
  5. El actor selecciona el **Canal de Venta Original** y verifica el **Canal de Reembolso** (Efectivo, Nequi o Llave BRE).
  6. El actor confirma la operación.
  7. El servidor valida fondos en el canal de egreso, descuenta el dinero de ese canal en la Caja Dedicada POS y procesa la mercancía en una sola acción: si tiene la etiqueta `"merma"`, no toca el stock vendible y registra directamente su salida por merma; si no la tiene, reingresa las unidades al stock vendible.
- **Flujo Alternativo (Sin Permiso o Sin Turno):** El servidor rechaza la operación con error explícito.
- **Flujo Alternativo (Fondos Insuficientes en el Canal):** El servidor aborta la operación e informa el saldo actual del canal conservando los datos del formulario para que el actor elija el canal real de entrega.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-02-01:** El botón de Reembolsos está ubicado en el **POS, al lado del buscador**, y está protegido en servidor por el permiso **`Reembolsos`** (`FRD-003-01`) y turno abierto.
- [ ] **CA-FRD-006-02-02:** Permite buscar el producto por **nombre, código o PLU** y prohíbe editar manualmente el "Monto a Reembolsar".
- [ ] **CA-FRD-006-02-03:** El reembolso opera como **una sola acción** mediante la etiqueta **`"merma"`**: si tiene la etiqueta `"merma"`, no pasa por el inventario vendible (sin bloquearse aunque el stock sea `0`) y ejecuta directamente su salida como merma al costo en el P&L; si no tiene la etiqueta, reingresa al stock vendible para otra venta.
- [ ] **CA-FRD-006-02-04:** La función backend exige un `session_id` activo y valida fondos suficientes en el canal seleccionado (**Efectivo, Nequi o Llave BRE**), abortando toda la transacción si no alcanzan.
- [ ] **CA-FRD-006-02-05:** Persiste el canal de venta original, el canal de egreso, la etiqueta `"merma"` y la **firma individual inmutable** del usuario que ejecutó el reembolso.
