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

3. **Requisito para Operar Caja:**
   Solo el Admin o empleados con permiso para abrir y cerrar caja pueden ejecutar esas acciones.
   El sistema DEBE verificar la autorización del usuario en cada operación de apertura o cierre.
   El Admin siempre tiene este permiso de forma implícita.

4. **Nota de Arquitectura (Decisión D-01, 2026-08-07):**
   El PIN de caja fue erradicado por redundancia de seguridad.
   La validación se delega al control de acceso basado en permisos.

5. **Inmutabilidad de Transacciones:**
   Una vez registrado un movimiento (ingreso/gasto), NO puede borrarse ni editarse.
   Si hubo error, se DEBE crear un contra-movimiento correctivo.

6. **Fórmula de Conciliación:**
   Saldo Esperado = Base Inicial + Ventas Efectivo + Ingresos Manuales - Gastos/Retiros
   Esta fórmula se calcula automáticamente y se muestra al cerrar.
   Las pérdidas de inventario (mermas) NO afectan esta fórmula de efectivo físico y se reportan en una sección separada del cierre, según FRD-006-01-02.
   La base inicial declarada en la apertura de turno corresponde exclusivamente al canal EFECTIVO. Los canales digitales (Nequi, Llave BRE) inician cada turno con base $0 automáticamente, sin intervención del usuario. La conciliación por canal al cierre (FRD-020, Regla 3) utiliza esta asignación para calcular el saldo esperado de cada canal de forma independiente.

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

**Caso B: Cierre de Turno (Arqueo)**

- **Actor:** Admin o empleado con permiso para abrir y cerrar caja.
- **Precondición:** Caja abierta.
- **Flujo Principal:**
    1. Usuario selecciona "Cerrar Turno".
    2. Sistema solicita conteo de dinero físico (Arqueo Ciego).
    3. Usuario realiza conteo físico e ingresa el dinero real que tiene en mano.
    4. Usuario pulsa "Confirmar Cierre".
    5. Sistema cierra la sesión y guarda el reporte histórico.
    6. Sistema calcula y registra la diferencia entre esperado y real.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** Caja cerrada, operaciones monetarias bloqueadas, POS bloqueado hasta próxima apertura. Los pases diarios permanecen vigentes hasta fin del día o revocación manual, según FRD-001.

---

**Caso C: Registro de Gasto (Salida de Dinero)**

- **Actor:** Empleado.
- **Precondición:** Caja abierta.
- **Flujo Principal:**
    1. Usuario saca dinero para pagar algo (ej: proveedor, almuerzo).
    2. Ingresa a "Gastos" → "Nuevo Gasto".
    3. Digita monto y motivo obligatorio.
    4. Sistema registra el movimiento y resta del Saldo Esperado inmediatamente.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** Movimiento registrado, saldo actualizado.

---

**Caso D: Recuperación de Turno Olvidado**

- **Actor:** Admin o empleado con permiso para abrir y cerrar caja.
- **Precondición:** Existe un turno abierto con fecha anterior a hoy.
- **Flujo Principal:**
    1. Usuario inicia sesión.
    2. Sistema detecta turno caducado.
    3. Sistema muestra alerta bloqueante: "Turno anterior no cerrado".
    4. Sistema redirige forzosamente a la pantalla de Cierre de Caja.
    5. Usuario realiza el conteo del dinero actual (real).
    6. Usuario confirma cierre.
    7. Sistema cierra el turno antiguo con fecha de cierre actual.
    8. Sistema libera el bloqueo y permite abrir un Nuevo Turno.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** Turno viejo cerrado, sistema listo para operar hoy.

---

## Requisitos de Datos (Para Equipo Data)

### Entidad Sesión de Caja

- Identificador único
- Relación con Tienda
- Empleado que abrió
- Empleado que cerró. El sistema acepta que este empleado sea distinto al empleado que abrió la sesión.
- Balance de apertura (asignado al canal EFECTIVO; canales digitales inician en $0)
- Balance de cierre (declarado por usuario)
- Balance calculado (por el sistema)
- Diferencia
- Estado: abierta/cerrada
- Marcas de tiempo de inicio y fin

### Entidad Transacción de Caja

- Identificador único
- Relación con Sesión
- Tipo: ingreso/gasto
- Monto
- Descripción obligatoria
- Referencia a venta (si aplica)
- Marca de tiempo

---

## Criterios de Aceptación

- [ ] No se puede abrir caja si ya hay una abierta.
- [ ] El POS está completamente bloqueado cuando la caja está cerrada.
- [ ] Solo el Admin o empleados con permiso para abrir y cerrar caja pueden ejecutar las acciones de abrir o cerrar caja.
- [ ] El cierre de caja no requiere PIN (Decisión D-01).
- [ ] Cada movimiento de caja tiene descripción obligatoria.
- [ ] El cierre genera un registro inmutable con la diferencia calculada.
- [ ] Al cerrar la caja, las operaciones monetarias quedan bloqueadas.
- [ ] El sistema detecta y bloquea turnos con fecha de apertura anterior al día actual.
- [ ] No se permite abrir un nuevo turno si existe uno caducado pendiente de cierre.
- [ ] Las pérdidas de inventario (mermas) se reportan separadas del efectivo en el cierre, según FRD-006-01-02.
- [ ] El cierre de caja NO expira los pases diarios activos, según FRD-001.
- [ ] Los empleados con pase diario vigente pueden permanecer dentro del sistema tras el cierre de caja, pero no pueden ejecutar operaciones monetarias.
