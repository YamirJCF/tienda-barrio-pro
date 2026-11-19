# FRD-004: Control de Caja (Turnos)

Módulo: Caja / Operaciones
Versión: 2.2 (Parche de alineación con FRD-001 v3 — desacople pase diario / cierre de caja)
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

6. **Fórmula de Conciliación y Cierre Asistido (`POL-SEG-01`, `POL-FIN-01`):**
   - `Saldo Esperado por Canal = Base Inicial + Ventas del Canal + Abonos del Canal - Gastos Menores del Canal - Reembolsos del Canal`
   - Esta fórmula se calcula automáticamente en el servidor y **permanece oculta** para el empleado antes, durante y en el formulario de cierre.
   - Al cerrar opera el **Cierre Asistido**: si el monto declarado no coincide con el cálculo interno, el sistema **solo avisa que no coincide** dando hasta **3 intentos** para revisar o recontar; al **tercer intento** sella el cierre y envía **notificación/alerta al Administrador**.
   - Los pagos marcados como **"pago externo / fuera de caja"** y las bajas logísticas `$0` (mermas, consumo del negocio, consumo/retiro personal y ajustes) NO afectan el saldo esperado de la Caja Dedicada POS.
   - La base inicial declarada en la apertura de turno corresponde exclusivamente al canal **EFECTIVO**. Los canales digitales (**NEQUI, LLAVE BRE**) inician cada turno con base $0 automáticamente.

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
    3. Muestra pantalla "Apertura de Turno".
    4. Usuario ingresa monto base de efectivo (fondo de cambio físico en el cajón). Este monto se asigna al canal EFECTIVO. Los canales digitales (Nequi, Llave BRE) inician automáticamente con base $0.
    5. Usuario confirma.
    6. Sistema abre sesión y habilita el POS.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** Caja abierta, ventas habilitadas.

---

**Caso B: Cierre de Turno (Arqueo Ciego con Cierre Asistido)**

- **Actor:** Únicamente el empleado específico que abrió el turno (con permiso `Abrir/cerrar caja`) o el Administrador.
- **Precondición:** Caja abierta.
- **Flujo Principal:**
    1. El titular que abrió el turno (o el Admin) selecciona "Cerrar Turno". (Si otro empleado intenta cerrarlo, el servidor lo bloquea estrictamente).
    2. Sistema solicita conteo de dinero real sin mostrar el saldo esperado.
    3. Usuario realiza conteo e ingresa el monto real que tiene en mano.
    4. Usuario pulsa "Confirmar Cierre".
    5. Si el monto no coincide con el cálculo interno, el sistema **solo avisa que no coincide** dando hasta **3 intentos** para revisar o recontar; al **tercer intento** sella la sesión, guarda la diferencia para el Administrador y dispara **notificación/alerta al Administrador**. Si coincide en cualquiera de los intentos, sella de inmediato.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** Caja cerrada, operaciones monetarias bloqueadas, POS bloqueado hasta próxima apertura. Los pases diarios permanecen vigentes hasta fin del día o revocación manual, según FRD-001.

---

**Caso C: Registro de Gasto Menor desde la Caja Dedicada POS**

- **Actor:** Cualquier usuario activo (Administrador o empleado con Pase Diario).
- **Precondición:** Caja Dedicada POS abierta y fondos suficientes en el canal seleccionado.
- **Flujo Principal:**
    1. Usuario saca dinero del turno para pagar un gasto menor operativo (ej: bolsas, domicilio, elementos de aseo). *(Los pagos a proveedores y pagos externos/fuera de caja son exclusivos del Administrador en `FRD-019`).*
    2. Ingresa a "Gastos" → "Nuevo Gasto".
    3. Digita monto, selecciona el canal de origen (**Efectivo, Nequi o Llave BRE**), elige la categoría OPEX y añade un motivo obligatorio.
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
- Balance de apertura (asignado al canal EFECTIVO; canales digitales Nequi y Llave BRE inician en $0)
- Balance de cierre (declarado por usuario)
- Balance calculado (por el sistema, oculto al empleado)
- Diferencia
- Estado: abierta / expirada-bloqueada / cerrada
- Marcas de tiempo de inicio y fin

### Entidad Transacción de Caja

- Identificador único
- Relación con Sesión
- **Usuario responsable (firma individual con fotografía histórica de nombre y rol)**
- **Canal de pago (Efectivo, Nequi, Llave BRE)**
- Tipo: ingreso/gasto/reembolso
- Categoría OPEX (para gastos) y descripción obligatoria
- Monto
- Referencia a venta o reembolso (si aplica)
- Marca de tiempo

---

## Criterios de Aceptación

- [ ] No se puede abrir caja si ya hay una abierta.
- [ ] El POS está completamente bloqueado cuando la caja está cerrada.
- [ ] Abrir caja requiere rol Admin o permiso `Abrir/cerrar caja`; **cerrar caja está estrictamente restringido al empleado específico que la abrió o al Administrador**.
- [ ] El cierre de caja aplica **Cierre Asistido** (sin PIN: si no coincide, solo avisa dando hasta **3 intentos** y al tercero sella y envía alerta al Administrador).
- [ ] Cualquier usuario activo en turno abierto puede registrar gastos menores de Caja POS indicando canal con fondos, categoría OPEX, motivo obligatorio y firma individual.
- [ ] El cierre genera un registro inmutable con la diferencia calculada (visible solo para el Administrador).
- [ ] Al cerrar la caja, las operaciones monetarias quedan bloqueadas.
- [ ] El sistema detecta y bloquea turnos que superen las 24 horas (`FRD-027-02`).
- [ ] No se permite abrir un nuevo turno si existe uno caducado pendiente de cierre.
- [ ] Las mermas y consumos tienen impacto $0 en la Caja Dedicada POS y se contabilizan al costo en el P&L (`FRD-018`).
- [ ] El cierre de caja NO expira los pases diarios activos, según FRD-001.
- [ ] Los empleados con pase diario vigente pueden permanecer dentro del sistema tras el cierre de caja para labores logísticas no monetarias.
