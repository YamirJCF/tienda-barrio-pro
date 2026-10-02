# FRD-020: Control de Caja Multicanal (Físico y Digital)

### Nombre de la Funcionalidad
Arqueo y Control de Turnos Multicanal

### Documentos Base (Referencias)
- Amplía y modifica reglas de: `FRD_004_CONTROL_DE_CAJA.md`, `FRD_009_CLIENTES.md` y `FRD_017_CICLO_CONTABLE_Y_SESIONES.md`.

#### Descripción
La caja ya no es exclusivamente un control del dinero físico en el cajón. Se transforma en un "Turno Operativo" que concilia todo el flujo de dinero, incluyendo canales digitales (ej. Nequi, Daviplata). Permite registrar abonos de clientes asegurando que el dinero impacte el canal correcto y sea sujeto de auditoría en el arqueo final.

## Reglas de Negocio

1. **Obligatoriedad del Método de Pago:**
   - TODO ingreso de dinero (Venta, Abono de Deuda o Ingreso Manual) DEBE especificar el método de pago utilizado (ej. Efectivo, Nequi, Daviplata).
   - Ningún movimiento financiero de ingreso puede quedar huérfano de método de pago en `cash_movements`.

2. **Registro de Abonos a Caja:**
   - Cuando un cliente realiza un abono a su deuda, este ingreso DEBE sumarse al "Saldo Esperado" del turno de caja actual.
   - El abono DEBE registrarse en el canal correspondiente (ej. si pagó con Nequi, suma al esperado de Nequi).
   - NO SE PUEDE registrar un abono si la caja está cerrada, ya que viola el principio de trazabilidad del turno.

3. **Arqueo Desglosado (Cierre Multicanal y Cierre Forzado):**
   - El sistema NO PUEDE exigir un único "Saldo Real" consolidado al cerrar el turno.
   - El sistema DEBE exigir un arqueo independiente para cada canal activo que haya tenido movimientos en ese turno (Efectivo, Nequi, Daviplata).
   - Esta regla APLICA TAMBIÉN para el proceso de Cierre Forzado de 24h (operación de cierre forzado en el servidor y el modal de auditoría). Si el administrador audita un turno expirado, el modal debe solicitar la conciliación multicanal.
   - A nivel de base de datos, este desglose SE DEBE soportar estructurando el balance en una tabla separada (`cash_session_balances`), y no agrupado en JSON, para favorecer consultas limpias de agregación financiera.

4. **Inicialización de Canales en Apertura:**
   - Al abrir un turno de caja, el monto base declarado por el usuario (FRD-004, Caso A) se registra como base del canal **EFECTIVO** exclusivamente.
   - Los canales digitales (**Nequi** y **Llave BRE**) se inicializan automáticamente con base **$0**, sin requerir entrada del usuario.
   - El saldo esperado de cada canal al cierre se calcula como: `Base Canal + Ingresos Canal − Egresos Canal`.
   - Esta regla cierra el circuito contable entre la apertura (FRD-004) y el arqueo desglosado al cierre (Regla 3 de este documento).

## Casos de Uso

**Caso A: Cierre de Turno Multicanal**
- **Actor:** Empleado con permiso de caja
- **Precondición:** Caja abierta con movimientos en Efectivo y Nequi.
- **Flujo Principal:**
  1. Usuario selecciona "Cerrar Turno".
  2. Sistema muestra el Saldo Esperado desglosado: para Efectivo y para Nequi.
  3. Usuario cuenta el dinero físico e ingresa el monto en el campo "Efectivo Real".
  4. Usuario verifica su aplicación móvil de Nequi e ingresa el monto reportado en el campo "Nequi Real".
  5. Usuario confirma cierre (firma con PIN si aplica).
  6. Sistema calcula discrepancias por separado y cierra el turno registrando en la tabla de balances.

**Caso B: Cierre Forzado de Turno Expirado (Auditoría Admin)**
- **Actor:** Administrador
- **Precondición:** Existe un turno expirado con movimientos en Efectivo y Daviplata.
- **Flujo Principal:**
  1. Admin inicia sesión, se le bloquea la navegación mostrando el modal de cierre forzado.
  2. El modal detalla los montos esperados de Efectivo y Daviplata.
  3. El Admin declara ambos saldos reales en campos separados.
  4. El sistema cierra el turno asíncrono grabando el balance en `cash_session_balances`.

## Criterios de Aceptación
- [ ] El cierre de caja regular solicita saldos reales por separado para cada canal activo.
- [ ] El Cierre Forzado a 24h asimila el comportamiento multicanal, actualizando su RPC y su interfaz (ForcedCloseAuditModal).
- [ ] Los abonos de clientes modifican el saldo esperado del canal seleccionado para el turno actual.
- [ ] El sistema bloquea el registro de abonos si la caja está cerrada.
- [ ] Al abrir el turno, la base declarada se asigna al canal EFECTIVO y los canales digitales inician en $0 sin intervención del usuario.
