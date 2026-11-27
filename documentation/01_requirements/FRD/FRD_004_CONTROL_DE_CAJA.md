# FRD-004: Control de Caja (Turnos)

Módulo: Caja / Operaciones
Versión: 2.3 (Alineación con `ARQ-002` v1.5 / `ARQ-005` — arqueo físico exclusivo de efectivo, prohibición de envíos en blanco, cierre abierto para Admin y margen `P_MARGEN_DESCUADRE_EFECTIVO` para empleados)
Estado: Aprobado
SDD Asociado: SDD_004

### Nombre de la Funcionalidad
Apertura, Cierre y Arqueo de Turnos de Caja

#### Descripción
Este documento regula el ciclo de vida operativo de la caja registradora por turnos. Establece las reglas de apertura, registro de movimientos, cierre y arqueo físico, garantizando la trazabilidad del efectivo y el bloqueo operativo del punto de venta cuando la caja no está activa. El cierre de caja bloquea las operaciones monetarias pero no revoca los pases diarios de acceso, según lo establecido en FRD-001.

---

## Reglas de Negocio

1. **Unicidad de Sesión:**
   Solo puede haber UNA sesión de caja abierta por tienda en un momento dado.
   No se permiten cajas simultáneas en este MVP.

2. **Bloqueo Operativo (POS Inaccesible):**
   Si la caja está cerrada, el sistema de ventas DEBE estar completamente bloqueado.
   Esto aplica a TODOS los roles, incluyendo el Admin.
   Nadie puede vender sin caja abierta.
   En estado cerrado, solo se permite consultar precios e inventario en modo lectura.
   El cierre de caja NO revoca los pases diarios activos. Los empleados con pase vigente pueden permanecer dentro del sistema, pero no pueden ejecutar operaciones monetarias que requieran caja abierta, según FRD-001.

3. **Requisito para Operar Caja y Propiedad Estricta del Turno (`POL-SEG-03`, `FRD-003-01`):**
   - **Abrir caja:** Solo el Administrador o empleados con el permiso `Abrir/cerrar caja` pueden abrir un turno en la **Caja Dedicada POS**.
   - **Cerrar caja (Propiedad estricta):** Únicamente **el empleado específico que abrió ese turno o el Administrador** tienen potestad para cerrarlo. Si otro empleado está dentro y también posee el permiso `Abrir/cerrar caja`, el servidor DEBE **bloquearle estrictamente** el cierre del turno ajeno.
   - **Registrar gastos menores de turno:** Cualquier usuario activo (Administrador o empleado con Pase Diario) puede registrar gastos menores desde la Caja Dedicada POS mientras exista un turno abierto, bajo su firma individual.

4. **Nota de Arquitectura (Decisión D-01, 2026-08-07):**
   El PIN de caja fue erradicado por redundancia de seguridad.
   La validación se delega al control de acceso basado en permisos.

5. **Inmutabilidad de Transacciones:**
   Una vez registrado un movimiento (ingreso/gasto), NO puede borrarse ni editarse.
   Si hubo error, se DEBE crear un contra-movimiento correctivo.

6. **Fórmula de Conciliación, Prohibición de Envíos en Blanco y Cierre Diferenciado por Rol (`POL-SEG-01`, `POL-FIN-01`, `POL-PROD-01`):**
   - `Saldo Esperado por Canal = Base Inicial + Ventas del Canal + Abonos del Canal - Gastos Menores del Canal - Reembolsos del Canal`
   - **Declaración explícita obligatoria:** Tanto al abrir turno (base inicial en efectivo) como al cerrarlo (efectivo contado en cajón), el sistema DEBE exigir que el usuario digite explícitamente un valor numérico mayor o igual a cero (`$0` solo es válido si el usuario escribe `0` de forma deliberada). Un campo sin diligenciar (`vacío`) TIENE PROHIBIDO procesarse o asumirse silenciosamente como `$0`.
   - **Alcance estrictamente físico del arqueo:** La base inicial de apertura y el conteo manual de cierre corresponden **exclusivamente al canal EFECTIVO** (los billetes y monedas del cajón físico). Los canales digitales (**NEQUI, LLAVE BRE**) inician cada turno con base `$0` y **NO se cuentan manualmente en el cierre**; el servidor conserva sus saldos calculados de forma segregada (`POL-FIN-02`) como resumen informativo de transferencias del turno para el Administrador.
   - **Cierre cuando opera el Administrador (Dueño):** El sistema DEBE mostrar al Administrador el efectivo esperado en cajón junto con el resumen informativo de movimientos por Nequi y Llave BRE del turno, permitiéndole declarar el efectivo contado y sellar el cierre en un único paso sin bloqueos de reintento ni auto-alertas.
   - **Cierre cuando opera el Empleado titular (Arqueo Ciego con Cierre Asistido y Margen):** El saldo esperado y la diferencia permanecen estrictamente ocultos para el empleado antes, durante y después del cierre. El empleado declara el efectivo físico contado en cajón y el servidor evalúa la diferencia absoluta contra el parámetro global fijo del sistema `P_MARGEN_DESCUADRE_EFECTIVO` (`ARQ-004`):
     - Si la diferencia absoluta en efectivo es **menor o igual** a `P_MARGEN_DESCUADRE_EFECTIVO`, el turno se sella de inmediato en ese intento sin rebote ni alerta crítica.
     - Si la diferencia absoluta **supera** `P_MARGEN_DESCUADRE_EFECTIVO`, el sistema **solo avisa que no coincide** dando hasta **3 intentos** para revisar o recontar; si al **tercer intento** persiste una diferencia superior al margen, sella el cierre y envía **notificación/alerta inmediata al Administrador**.
   - **Exactitud contable inmutable:** En todos los cierres (Administrador o empleado, dentro o fuera de `P_MARGEN_DESCUADRE_EFECTIVO`), el servidor DEBE guardar siempre la diferencia exacta al peso (`Efectivo Contado - Efectivo Esperado`) sin redondearla ni ocultarla en los reportes del Administrador.
   - Los pagos marcados como **"pago externo / fuera de caja"** y las bajas logísticas `$0` (mermas, consumo del negocio, consumo/retiro personal y ajustes) NO afectan el saldo esperado de la Caja Dedicada POS.

7. **Separación entre Pase Diario y Caja:**
   El pase diario controla el acceso al sistema.
   La caja abierta controla la ejecución de operaciones monetarias.
   Un pase diario vigente NO autoriza ventas si la caja está cerrada.
   Una caja abierta NO autoriza ventas si el pase diario no está aprobado.
   Esta separación se rige por FRD-001.

---

## Casos de Uso

**Caso A: Apertura de Turno**

- **Actor:** Admin o empleado con permiso para abrir y cerrar caja.
- **Precondición:** Caja cerrada, pase diario aprobado.
- **Flujo Principal:**
    1. Usuario ingresa al módulo de control de caja.
    2. Sistema verifica permisos y estado de caja.
    3. Muestra pantalla "Apertura de Turno" con el campo de base inicial en estado vacío (sin asumir `$0` por omisión).
    4. Usuario digita explícitamente la base inicial en efectivo (fondo de cambio físico en el cajón; si abre sin base debe digitar `0` deliberadamente). Este monto se asigna al canal EFECTIVO. Los canales digitales (Nequi, Llave BRE) inician automáticamente con base `$0`.
    5. Usuario confirma.
    6. Sistema abre sesión y habilita el POS.
- **Flujo Alternativo:** Si el usuario intenta confirmar dejando el campo vacío sin digitar ningún número, el sistema mantiene bloqueada la confirmación e impide abrir el turno.
- **Postcondición:** Caja abierta, ventas habilitadas.

---

**Caso B: Cierre de Turno (Arqueo Físico de Efectivo Diferenciado por Rol)**

- **Actor:** Únicamente el empleado específico que abrió el turno (con permiso `Abrir/cerrar caja`) o el Administrador.
- **Precondición:** Caja abierta.
- **Flujo Principal:**
    1. El titular que abrió el turno (o el Admin) selecciona "Cerrar Turno". (Si otro empleado intenta cerrarlo, el servidor lo bloquea estrictamente).
    2. El sistema solicita exclusivamente el **efectivo contado en cajón** (con el campo inicialmente vacío, sin pedir conteo manual de Nequi ni Llave BRE):
       - Si quien cierra es el **Administrador**, la pantalla le muestra el efectivo esperado en cajón y el resumen informativo de movimientos por Nequi y Llave BRE del turno.
       - Si quien cierra es el **empleado titular**, el sistema oculta por completo los saldos esperados.
    3. El usuario cuenta los billetes y monedas del cajón y digita explícitamente el monto de efectivo real.
    4. El usuario pulsa "Confirmar Cierre".
    5. El servidor registra la diferencia exacta al peso en efectivo y resuelve según el rol:
       - **Administrador:** Sella la sesión en ese único paso sin reintentos ni alertas.
       - **Empleado titular:** Si la diferencia absoluta en efectivo es menor o igual a `P_MARGEN_DESCUADRE_EFECTIVO`, sella de inmediato sin alerta. Si supera `P_MARGEN_DESCUADRE_EFECTIVO`, **solo avisa que no coincide** dando hasta **3 intentos** para revisar o recontar; al **tercer intento** sella la sesión, guarda la diferencia exacta al peso y dispara **notificación/alerta inmediata al Administrador**.
- **Flujo Alternativo:** Si el usuario intenta confirmar con el campo de efectivo vacío (sin haber digitado un número), el sistema impide enviar el cierre.
- **Postcondición:** Caja cerrada, operaciones monetarias bloqueadas, POS bloqueado hasta próxima apertura. Los pases diarios permanecen vigentes hasta fin del día o revocación manual, según FRD-001.

---

**Caso C: Registro de Gasto de Caja desde la Caja Dedicada POS**

- **Actor:** Cualquier usuario activo (Administrador o empleado con Pase Diario).
- **Precondición:** Caja Dedicada POS abierta y fondos suficientes en el canal seleccionado.
- **Flujo Principal:**
    1. Usuario saca dinero del turno para pagar un gasto menor cotidiano (ej: bolsas, domicilio, elementos de aseo). *(Los pagos a proveedores y pagos externos/fuera de caja son exclusivos del Administrador en `FRD-019`).*
    2. Ingresa a "Gastos de Caja" → "Nuevo Gasto".
    3. Digita monto, selecciona el canal de origen (**Efectivo, Nequi o Llave BRE**), elige la categoría del gasto y añade un motivo obligatorio.
    4. Sistema valida fondos en el canal seleccionado, registra el movimiento con la **firma individual** del usuario y resta del Saldo Esperado de ese canal inmediatamente.
- **Flujo Alternativo:** Si el canal no posee fondos suficientes, el servidor rechaza la operación.
- **Postcondición:** Movimiento registrado con firma individual, saldo del canal actualizado.

---

**Caso D: Recuperación de Turno Olvidado (+24h)**

- **Actor:** Únicamente el empleado que abrió originalmente ese turno vencido o el Administrador (`FRD-027-02`).
- **Precondición:** Existe un turno que superó las 24 horas en estado Expirado/Bloqueado.
- **Flujo Principal:**
    1. Usuario inicia sesión.
    2. Sistema detecta turno caducado (+24h) y bloquea operaciones monetarias.
    3. Si el usuario es el empleado que abrió ese turno: el sistema lo dirige al cierre con **Cierre Asistido** (hasta 3 intentos) para contar el dinero real y cerrar el turno vencido.
    4. Si el empleado titular no está disponible: el **Administrador** ejecuta el **Cierre Forzoso** (donde **no siempre es obligatorio declarar conteo físico**).
    5. Sistema cierra el turno antiguo con alerta de caducidad y libera el bloqueo para abrir un Nuevo Turno.
- **Flujo Alternativo:** Si otro empleado (distinto al que abrió el turno) intenta cerrarlo, el servidor rechaza la acción estrictamente.
- **Postcondición:** Turno viejo cerrado, sistema listo para operar hoy.

---

## Requisitos de Datos (Para Equipo Data)

### Entidad Sesión de Caja

- Identificador único
- Relación con Tienda
- Usuario que abrió (firma individual)
- Usuario que cerró (firma individual: **solo puede ser el mismo empleado que abrió la sesión o un Administrador**)
- Balance de apertura (declarado explícitamente y asignado al canal EFECTIVO; canales digitales Nequi y Llave BRE inician en `$0`)
- Efectivo físico de cierre (declarado explícitamente por el usuario; no existe conteo manual de canales digitales)
- Saldos calculados por canal (efectivo esperado en cajón y acumulados informativos de Nequi y Llave BRE, ocultos al empleado)
- Diferencia exacta al peso en efectivo (conservada siempre sin redondeo, dentro o fuera de `P_MARGEN_DESCUADRE_EFECTIVO`)
- Estado: abierta / expirada-bloqueada / cerrada
- Marcas de tiempo de inicio y fin

### Entidad Transacción de Caja

- Identificador único
- Relación con Sesión
- **Usuario responsable (firma individual con fotografía histórica de nombre y rol)**
- **Canal de pago (Efectivo, Nequi, Llave BRE)**
- Tipo: ingreso/gasto/reembolso
- Categoría del gasto y descripción obligatoria
- Monto
- Referencia a venta o reembolso (si aplica)
- Marca de tiempo

---

## Criterios de Aceptación

- [ ] No se puede abrir caja si ya hay una abierta.
- [ ] Tanto en apertura como en cierre se rechaza o bloquea el envío mientras el campo de monto permanezca vacío sin digitar (`$0` requiere escribir explícitamente `0`).
- [ ] El POS está completamente bloqueado cuando la caja está cerrada.
- [ ] Abrir caja requiere rol Admin o permiso `Abrir/cerrar caja`; **cerrar caja está estrictamente restringido al empleado específico que la abrió o al Administrador**.
- [ ] El cierre solicita únicamente el **efectivo contado en cajón** (sin campos de conteo manual para Nequi ni Llave BRE).
- [ ] Cuando cierra el Administrador, visualiza el efectivo esperado y el resumen informativo de canales digitales y sella en un único paso; cuando cierra el empleado titular, opera **Arqueo Ciego con Cierre Asistido** evaluado con `P_MARGEN_DESCUADRE_EFECTIVO` (hasta **3 intentos** y alerta al Administrador si al tercero supera el margen).
- [ ] Cualquier usuario activo en turno abierto puede registrar gastos de caja indicando canal con fondos, categoría del gasto, motivo obligatorio y firma individual.
- [ ] El cierre genera un registro inmutable con la diferencia exacta al peso en efectivo (guardada siempre íntegra, dentro o fuera de `P_MARGEN_DESCUADRE_EFECTIVO`, y visible solo para el Administrador).
- [ ] Al cerrar la caja, las operaciones monetarias quedan bloqueadas.
- [ ] El sistema detecta y bloquea turnos que superen las 24 horas (`FRD-027-02`).
- [ ] No se permite abrir un nuevo turno si existe uno caducado pendiente de cierre.
- [ ] Las mermas y consumos tienen impacto $0 en la Caja Dedicada POS y se contabilizan al costo en el P&L (`FRD-018`).
- [ ] El cierre de caja NO expira los pases diarios activos, según FRD-001.
- [ ] Los empleados con pase diario vigente pueden permanecer dentro del sistema tras el cierre de caja para labores logísticas no monetarias.
