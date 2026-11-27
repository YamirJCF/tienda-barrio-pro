# FRD-003-01: Matriz de Permisos de Empleados y Límites Naturales de Operación (Fuente de Verdad)

> **Estado:** 🟢 VALIDADO Y CONSOLIDADO CONTRA POLÍTICAS (`ARQ-002` v1.5 / `ARQ-005` v1.0). Fuente de verdad única de permisos, capacidades operativas base, propiedad del turno y firma individual.
> **Enmienda y reconcilia:** `FRD-001`, `FRD-003`, `FRD-004`, `FRD-005`, `FRD-006`, `FRD-006-01-01`, `FRD-006-01-02`, `FRD-006-02`, `FRD-007-01`, `FRD-008`, `FRD-009`, `FRD-017`, `FRD-018`, `FRD-019`, `FRD-022`, `FRD-024`, `FRD-026`, `FRD-027-01`, `FRD-027-02` y `FRD-030`.

### Nombre de la Funcionalidad
Modelo de Identidad Seccionada, Capacidades Base y 4 Permisos Delegables a Empleados

#### Descripción
Define, en un solo lugar y sin contradicciones, los límites naturales entre el **Administrador** (control total, configuración, clientes, proveedores y todos los reportes/auditoría) y el **Empleado** (libertad operativa fluida durante su turno dentro de sus secciones autorizadas, compensada con **firma individual inmutable** en cada movimiento). Todo permiso y límite se valida estrictamente en el servidor (`FRD-002`).

---

## Reglas de Negocio

### 1. Identidad Individual, Acceso Diario y Regla de Dispositivo Único (`POL-SEG-03`, `FRD-001`)
1. **Pase Diario validado:** Se mantiene el protocolo actual de acceso diario con Pase Diario aprobado por el Administrador (`FRD-001`). Si existe un turno de caja abierto que aún no cumple las 24 horas y cruza la medianoche, el Pase Diario de quienes operan ese turno continúa vigente hasta que se cierre dicho turno (`FRD-017`, `POL-SEG-02`).
2. **Un solo dispositivo por cuenta:** Cada persona opera desde su propia cuenta autenticada. Si otro empleado o el Administrador va a utilizar el mismo equipo físico, DEBE ingresar a su propia cuenta. No existe cambio rápido de operador por PIN dentro de una sesión ajena.
3. **Firma individual obligatoria con fotografía histórica (`POL-AUD-01`, `POL-AUD-02`):** Toda operación realizada en el sistema (venta, gasto menor de caja, merma, consumo del negocio, consumo/retiro personal, abono, reembolso, apertura/cierre de caja y cualquier acción de inventario o ajuste) DEBE guardarse en el servidor con la etiqueta de identificación individual de la cuenta que la ejecutó (`Administrador` o `Empleado específico`), conservando la fotografía histórica de su nombre y rol vigentes en ese instante aunque el perfil se edite o desactive después.

### 2. Capacidades Operativas Base (Implícitas para Todo Usuario Activo con Pase Diario)
Todo empleado activo con Pase Diario vigente posee estas capacidades operativas de mostrador sin requerir interruptores adicionales, siempre bajo su **firma individual**:
1. **Vender en el POS:** Operar el Punto de Venta cuando la Caja Dedicada POS está abierta (`FRD-003` R4, `FRD-007-01`).
2. **Registrar Gastos de Caja desde la Caja Dedicada POS:** Registrar salidas cotidianas del turno (ej. bolsas, domicilio, elementos de aseo) siempre que la caja esté abierta, seleccionando el canal real de salida (**Efectivo, Nequi o Llave BRE**) con fondos suficientes, categoría del gasto y motivo obligatorio (`FRD-004`, `FRD-022`, `FRD-026`). *(Todo pago que no salga del cajón del POS lo maneja el Administrador como **"pago externo / fuera de caja"**).*
3. **Registrar Mermas y Consumo del Negocio (`POL-LOG-03`, `FRD-006-01-02`):** Reportar mercancía dañada, rota o vencida (**Merma**) e insumos tomados para uso operativo de la tienda (**Consumo del negocio**), con motivo obligatorio y firma individual, sin requerir caja abierta y con **impacto $0 en la Caja Dedicada POS** (se valorizan internamente al costo de adquisición en el P&L de `FRD-018`, sin exponer el costo unitario a quien no tenga `Inventario completo`).
4. **Registrar Consumo / Retiro Personal (`POL-FIN-05`, `POL-LOG-03`):** Separado del consumo del negocio. Se opera literalmente como una venta en el POS (viendo sus precios y datos normales), asignada automáticamente al **propio perfil del empleado** que tiene la sesión abierta (**solo el Administrador puede seleccionar a otra persona**). Descuenta stock, tiene **impacto $0 en la Caja Dedicada POS** y alimenta el historial de consumo personal **por perfil y consolidado** (valorado al costo de adquisición con precio de venta de referencia para el Administrador).
5. **Ver únicamente sus propios movimientos del turno actual:** Al no existir permiso de reportes para empleados, durante la jornada el empleado solo puede consultar los movimientos realizados por **él mismo en el turno actual**, con toda su información operativa, para verificar su trabajo inmediato.

### 3. Modelo Simplificado de Cuatro (4) Permisos Delegables (`POL-SEG-03`)
Cada empleado tiene exactamente **cuatro interruptores independientes**, todos apagados (`false`) por defecto (se elimina el antiguo permiso `Ver reportes` y el antiguo permiso separado `Ver inventario`):
1. **`Inventario completo`**
2. **`Fiar y cobrar abonos`**
3. **`Abrir/cerrar caja`**
4. **`Reembolsos`**

### 4. Alcance Exacto por Permiso (Qué PUEDE hacer el empleado y qué es EXCLUSIVO del Administrador)

| Permiso | El empleado con este permiso PUEDE | El empleado NO PUEDE / Límites y Exclusividad del Administrador |
|---|---|---|
| **1. `Inventario completo`** | Ver catálogo, stock, **costo de adquisición** y Kardex; crear, editar y eliminar productos (**baja lógica** conservando historial y firma de quién lo eliminó); registrar **Entradas** de mercancía (`FRD-006-01-01`); ejecutar **Ajustes por conteo físico** (positivos o negativos) y **Devolución física a proveedor** (salida logística `$0` en caja), siempre con motivo obligatorio, firma individual e inmutabilidad (corrección solo por contra-movimiento, enviando alerta al Admin) | Crear o modificar facturas de compra, cuentas por pagar o pagos a proveedores (**100% exclusivo del Administrador**, `FRD-019`); alterar o borrar registros históricos del Kardex (`POL-AUD-01`) |
| **2. `Fiar y cobrar abonos`** | Seleccionar método de pago **"Fiado"** en el POS (respetando el cupo disponible del cliente); registrar **abonos** de clientes con Caja Dedicada POS abierta y selección de canal (**Efectivo, Nequi o Llave BRE**); consultar la ficha y el **estado de cuenta** de clientes activos (`FRD-009`, `FRD-024`, `FRD-030` RN-06) | **Crear, editar o eliminar clientes**, ni modificar cupos de crédito individuales o el cupo global por defecto (**100% exclusivo del Administrador**, `FRD-009`, `FRD-030`, `POL-PRIV-01`); fiar superando el cupo disponible o cobrar abonos con caja cerrada |
| **3. `Abrir/cerrar caja`** | Abrir turno en la **Caja Dedicada POS** digitando explícitamente la base inicial en efectivo; cerrar **únicamente el turno que él mismo abrió** declarando explícitamente el **efectivo físico contado en cajón** (sin conteo manual de Nequi ni Llave BRE) mediante **Cierre Asistido**: sin ver el saldo esperado, si la diferencia absoluta es menor o igual a `P_MARGEN_DESCUADRE_EFECTIVO` sella en ese intento; si supera `P_MARGEN_DESCUADRE_EFECTIVO`, **solo avisa que no coincide** dando hasta **3 intentos** y al **tercer intento** sella el cierre guardando siempre la diferencia exacta al peso y envía **notificación/alerta al Administrador** (`POL-SEG-01`, `FRD-004`, `FRD-027-01`) | **Cerrar un turno abierto por otro empleado o por el Administrador** (bloqueo estricto en servidor aunque el empleado tenga permiso de caja, `POL-SEG-03`); enviar apertura o cierre con el campo vacío; ver el monto esperado o la diferencia exacta; ejecutar Cierres Forzosos de turnos ajenos vencidos (+24h) o ver historial de turnos cerrados (**exclusivo del Administrador**, `FRD-027-02`) |
| **4. `Reembolsos`** | Acceder al botón de **Reembolsos** (ubicado en el **POS, al lado del buscador**) con Caja Dedicada POS abierta; buscar el producto por **nombre, código o PLU**; entregar el dinero desde un canal con fondos suficientes (**Efectivo, Nequi o Llave BRE**); marcar la etiqueta opcional **`"merma"`** cuando el producto devuelto viene dañado: en **una sola acción**, si **tiene la etiqueta `"merma"`**, no pasa por el inventario vendible y ejecuta directamente su salida como merma; si **no tiene la etiqueta**, reingresa al stock para otra venta (`POL-LOG-02`, `FRD-006-02`) | Ejecutar reembolsos con caja cerrada o sin fondos suficientes en el canal seleccionado (`POL-FIN-01`, `POL-FIN-02`); editar manualmente el monto calculado por el sistema; realizar anulaciones administrativas de ventas cerradas fuera del flujo de reembolso (**exclusivo del Administrador**) |

### 5. Acciones 100% Exclusivas del Administrador (No Delegables bajo Ningún Permiso)
Ningún empleado tiene acceso, ni por interfaz ni por llamada directa al servidor, a:
1. **Todos los Reportes del Negocio y Auditoría:** Resumen Diario y Abastecimiento (`FRD-008`), Panel Financiero Consolidado y P&L de 4 Pilares (`FRD-018`), Evidence Hub / Auditoría Forense (`FRD-005`), Reportes e Historial de Turnos Cerrados y Descuadres (`FRD-027-01`), Historial consolidado y por perfil de **Consumos Personales, Consumos del Negocio y Mermas**, y consulta de productos dados de baja lógica.
2. **Gestión de Clientes y Riesgo Crediticio:** Crear clientes nuevos (o reactivar archivados), editar datos de clientes, cambiar cupos individuales, cambiar el **cupo global por defecto** (el cual aplica **únicamente a clientes nuevos** creados a partir de ese momento, sin sobrescribir cupos de clientes existentes) y eliminar clientes con saldo `$0` bajo resguardo contable silencioso sin filtro de eliminados en listas (`FRD-009`, `FRD-030`, `POL-PRIV-01`, `POL-PRIV-02`).
3. **Proveedores, Cuentas por Pagar y Pagos Fuera de Caja:** Registrar facturas por pagar, registrar pagos internos a proveedores desde Caja POS y registrar **"pagos externos / fuera de caja"** (`FRD-019`, `FRD-022`).
4. **Intervención de Turnos Ajenos / Cierre Forzoso (+24h):** Cerrar un turno abierto por otro usuario o ejecutar el Cierre Forzoso de un turno caducado (+24h), en el cual **no siempre es obligatorio declarar conteo físico** (`FRD-027-02`, `FRD-017`).
5. **Administración de Equipo y Configuración:** Crear, editar o desactivar empleados, restablecer PINs, modificar los 4 permisos delegables, aprobar o revocar Pases Diarios (`FRD-001`, `FRD-003`) y seleccionar el perfil de otra persona al registrar un Consumo/Retiro Personal.

### 6. Autoridad del Servidor, Independencia y Efecto Inmediato
1. **Autoridad del servidor (`FRD-002`):** El servidor DEBE rechazar con error de seguridad explícito cualquier operación cuyo permiso o regla de propiedad (ej. intentar cerrar el turno que abrió otro compañero) no se cumpla, registrando el intento bloqueado. Ocultar un botón en pantalla NO es control de acceso.
2. **No herencia entre los 4 permisos:** Tener un permiso activado no otorga ningún otro.
3. **Efecto inmediato:** Todo cambio en los 4 permisos o en el estado activo del empleado aplica de inmediato en su siguiente operación en el servidor, sin esperar a un nuevo inicio de sesión.

---

## Casos de Uso

**Caso A: Empleado intenta una operación exclusiva del Administrador o cerrar turno de otro compañero**
- **Actor:** Empleado activo.
- **Precondición:** No posee el permiso requerido, o intenta cerrar un turno de caja que fue abierto por otro usuario.
- **Flujo Principal:**
  1. El empleado intenta ejecutar la acción (por interfaz o llamada directa).
  2. El servidor verifica su identidad, el estado del turno y sus permisos reales en base de datos.
  3. El servidor aborta la transacción con error de seguridad explícito y registra el intento.
  4. La interfaz informa claramente el bloqueo ("No tienes permiso para esta acción" o "Solo quien abrió este turno o el Administrador pueden cerrarlo").
- **Postcondición:** Ningún dato financiero o logístico se altera; el intento queda registrado para auditoría.

**Caso B: Cierre Asistido de Caja por el Empleado que Abrió el Turno**
- **Actor:** Empleado con permiso `Abrir/cerrar caja` que abrió el turno actual.
- **Precondición:** Turno abierto (<24h o por cerrar por su titular).
- **Flujo Principal:**
  1. El empleado inicia el cierre y digita explícitamente el efectivo físico contado en el cajón (sin ver el saldo esperado ni contar canales digitales).
  2. Si la diferencia absoluta en efectivo es menor o igual a `P_MARGEN_DESCUADRE_EFECTIVO`, el servidor sella el cierre con su firma guardando la diferencia exacta al peso.
  3. Si la diferencia absoluta supera `P_MARGEN_DESCUADRE_EFECTIVO`, el sistema **solo avisa que no coincide** (sin mostrar el monto esperado) permitiendo revisar o recontar hasta un máximo de **3 intentos**.
  4. Si al **tercer intento** persiste una diferencia superior a `P_MARGEN_DESCUADRE_EFECTIVO`, el servidor sella el cierre con el último monto declarado, registra el descuadre exacto al peso y envía una **notificación/alerta inmediata al Administrador**.

**Caso C: Reembolso de Producto con Etiqueta Única `"merma"`**
- **Actor:** Empleado con permiso `Reembolsos` (o Administrador).
- **Precondición:** Caja Dedicada POS abierta y canal de salida con fondos suficientes.
- **Flujo Principal:**
  1. Desde el POS (botón **Reembolsos** al lado del buscador), el operador busca el producto por nombre, código o PLU e ingresa la cantidad.
  2. Si el producto devuelto está dañado, activa la etiqueta **`"merma"`**.
  3. Al confirmar, el servidor ejecuta una sola acción atómica: descuenta el dinero del canal seleccionado en la Caja Dedicada POS y lee la etiqueta `"merma"`:
     - **Con etiqueta `"merma"`:** el producto no pasa por el inventario vendible y se registra directamente su salida/pérdida como merma al costo en el P&L, con la firma del operador.
     - **Sin etiqueta `"merma"`:** el producto se reingresa al stock vendible para otra venta.

---

## Criterios de Aceptación
- [ ] **CA-003-01-01:** El formulario de perfil de empleado ofrece exactamente los **4 permisos delegables** (`Inventario completo`, `Fiar y cobrar abonos`, `Abrir/cerrar caja`, `Reembolsos`), todos apagados por defecto, sin interruptor de `Ver reportes` ni `Ver inventario` separado.
- [ ] **CA-003-01-02:** El servidor rechaza con error de seguridad cualquier llamada directa sin el permiso requerido, cualquier intento de acceso de un empleado a reportes/clientes CRUD/proveedores CxP y cualquier intento de un empleado de cerrar un turno abierto por otro usuario.
- [ ] **CA-003-01-03:** Cada cuenta opera en un único dispositivo/sesión propia (sin cambio rápido por PIN en sesión ajena), y toda operación en cualquier sección estampa la firma individual con fotografía histórica inmutable (nombre y rol del instante).
- [ ] **CA-003-01-04:** Todo usuario activo con Pase Diario puede vender en POS (caja abierta), registrar gastos menores de caja (caja abierta, canal con fondos, categoría y motivo), registrar mermas y consumo del negocio ($0 en caja POS), registrar consumo/retiro personal como venta a su propio perfil ($0 en caja POS; solo Admin elige a otros) y ver únicamente sus propios movimientos del turno actual con toda su información.
- [ ] **CA-003-01-05:** Un empleado con `Inventario completo` puede ver costos, crear/editar/dar baja lógica a productos, registrar entradas, ejecutar **ajustes por conteo físico** y **devoluciones físicas a proveedor** ($0 en caja y sin tocar CxP), quedando todo movimiento inmutable (corrección solo por contra-movimiento) y con alerta al Admin en ajustes.
- [ ] **CA-003-01-06:** En el cierre de caja de empleados opera el **Cierre Asistido** exclusivamente sobre el efectivo físico del cajón evaluado con `P_MARGEN_DESCUADRE_EFECTIVO` (solo avisa si supera el margen, hasta **3 intentos** y al tercero sella y notifica al Administrador, guardando siempre la diferencia exacta al peso), mientras que el Administrador ve su esperado y sella en un paso; solo puede cerrar el empleado que abrió ese turno o el Administrador.
- [ ] **CA-003-01-07:** El botón de **Reembolsos** se ubica en el POS al lado del buscador, permite buscar por nombre, código o PLU, y procesa la devolución en una sola acción mediante la etiqueta **`"merma"`** (si la tiene, no pasa por stock vendible y sale como merma; si no la tiene, reingresa al stock vendible).

---

## Alcance Diferido y Decisiones Registradas (Regla 7 de Trade-offs)

| ID | Qué se decidió / difiere | Por qué (Trade-off concreto) | Bajo qué condición futura se revisa |
|---|---|---|---|
| **D-1** | **Unificación de `Inventario completo` incluyendo costos, baja lógica, salidas logísticas y ajustes por conteo físico.** | Confiar la gestión del inventario ocultando costos o bloqueando ajustes de conteo creaba contradicciones operativas. Se habilita con firma individual obligatoria, inmutabilidad por contra-movimiento y alerta automática al Administrador. | Si el dueño requiere en el futuro separar un rol de bodeguero básico sin ajustes de conteo o sin visualización de costos. |
| **D-2** | **Eliminación del permiso `Ver reportes` para empleados (reducción de 5 a 4 permisos delegables).** | Simplifica el modelo y protege la información financiera y el arqueo asistido. El empleado solo ve sus propios movimientos del turno actual con toda su información; todos los reportes del negocio quedan 100% para el Administrador. | Si en una versión futura se introduce un rol formal de Subgerente/Administrador secundario. |
| **D-3** | **Diferir la delegación a empleados del registro y pago de facturas de proveedores en mostrador (`FRD-019`).** | Mantener Proveedores y Cuentas por Pagar 100% exclusivos del Administrador simplifica los permisos actuales a 4 interruptores y evita riesgos sobre pasivos y caja. | En una actualización futura cuando se requiera habilitar pagos contra entrega a camiones repartidores en ausencia del dueño. |
| **D-4** | **Acción única con etiqueta `"merma"` en Reembolsos (`FRD-006-02`).** | Evita duplicar eventos (`+1` y `-1`) o bloquear reembolsos cuando el stock vendible es `0`: si lleva la etiqueta `"merma"`, no pasa por stock vendible y se registra directo su salida por merma; si no la lleva, reingresa para la venta. | Permanente como regla de simplicidad logística y contable. |

---

## Mapa de Documentos Reconciliados por esta Fuente de Verdad
- **`ARQ-002` y `ARQ-003`:** Políticas `POL-FIN-01/02/05`, `POL-LOG-01/02/03`, `POL-SEG-01/02/03`, `POL-AUD-01/02/03` y `POL-PRIV-01/02` actualizadas a v1.4.
- **`FRD-001` y `FRD-017`:** Pase Diario validado, 1 dispositivo por cuenta, continuidad en cruce de medianoche con turno abierto (<24h), propiedad estricta del turno al cerrar y sincronización tardía offline atribuida al vendedor.
- **`FRD-003` y `FRD-005`:** 4 permisos delegables, capacidades base, fotografía histórica de firma y reportes/Evidence Hub 100% exclusivos del Admin.
- **`FRD-004`, `FRD-008`, `FRD-018`, `FRD-022`, `FRD-026`, `FRD-027-01` y `FRD-027-02`:** Caja Dedicada POS, pagos externos/fuera de caja, canales Efectivo/Nequi/Llave BRE, Cierre Asistido (3 intentos + alerta), cierre forzoso Admin sin conteo obligatorio y P&L con mermas y consumos (negocio vs. personal por perfil y consolidado).
- **`FRD-006`, `FRD-006-01-01`, `FRD-006-01-02`, `FRD-006-02` y `FRD-007-01`:** Salidas logísticas `$0`, ajustes bajo `Inventario completo`, consumo personal como venta en POS al propio perfil, y Reembolsos al lado del buscador del POS con etiqueta única `"merma"`.
- **`FRD-009`, `FRD-019`, `FRD-024` y `FRD-030`:** Clientes CRUD y cupos exclusivos del Admin (cupo por defecto solo aplica a clientes nuevos; eliminación sin filtro de eliminados según `FRD-030`), fiar/abonar/consultar estado de cuenta bajo `Fiar y cobrar abonos`, y Proveedores/CxP exclusivos del Admin.
