# FRD-004: Caja Estricta Multicanal (Canales Fijos Limitados)

### Nombre de la Funcionalidad
Segregación de Saldos, Canales Fijos (Efectivo, Nequi, Llave BRE) y Protección contra Fondos Insuficientes.

#### Descripción
Este documento rige la administración de la liquidez del negocio dividiendo el patrimonio en distintos canales de pago. Para mantener la simplicidad operativa y evitar configuraciones complejas, el sistema limita estrictamente los canales de dinero a tres (3) orígenes fijos. El sistema no ejecuta el cobro (fuera de alcance), pero documenta y separa contablemente los movimientos de cada canal para asegurar que no se produzcan sobregiros (saldos negativos) en ninguno de ellos.

---

## Reglas de Negocio

1. **Trinidad de Canales Fijos:**
   El sistema soporta única y exclusivamente tres (3) canales de pago inmutables, sin opción a crear nuevos por parte del administrador:
   - **EFECTIVO:** Canal principal. Representa el dinero físico en el cajón.
   - **NEQUI:** Billetera digital de uso común.
   - **LLAVE BRE:** Recurso fiscal (Colombia) para unificar transferencias interbancarias de bajo monto sin comisión.

2. **Simplicidad de Configuración (Zero Config):**
   - El sistema NO requiere, ni permite, configuración de cuentas bancarias, credenciales de API o pasarelas de pago.
   - El proceso real de cobro ocurre "fuera de banda" (el cliente transfiere a través de su app bancaria). El sistema se limita a documentar fidedignamente que el dinero ingresó o salió por dicho canal.

3. **Identidad y Segregación del Dinero (POL-FIN-02):**
   - El servidor DEBE catalogar cada entrada y salida manteniendo estrictamente la vinculación de origen (Efectivo, Nequi o Llave BRE).
   - TIENE PROHIBIDO fusionar matemáticamente el dinero en un balance general consolidado al momento de validar operaciones de egreso. El balance total es solo informativo; las validaciones son por canal.

4. **Cálculo Particionado y Ley de Restricción Cero:**
   - Ante cualquier solicitud de retiro, gasto o devolución, el servidor DEBE ejecutar un cálculo de disponibilidad considerando exclusiva y aisladamente el canal señalado.
   - El servidor TIENE PROHIBIDO consolidar un movimiento de egreso si el cálculo arroja un resultado inferior a cero en el canal designado. No se puede "prestar" saldo del Efectivo a Nequi.

---

## Casos de Uso

**Caso A: Bloqueo Transaccional por Insuficiencia en Canal Digital**
- **Actor:** Empleado Operativo / Sistema Servidor.
- **Precondición:** La caja tiene un saldo de $800.000 en Efectivo y $20.000 en Llave BRE.
- **Flujo Principal:**
  1. El empleado intenta registrar un egreso de "Pago a Proveedor" por $50.000, marcando como origen "Llave BRE".
  2. El servidor aísla el cálculo. Ignora los $800.000 en efectivo e interroga exclusivamente el saldo de Llave BRE ($20.000).
  3. El servidor identifica que $20.000 - $50.000 = -$30.000.
  4. La transacción se rechaza a nivel de base de datos antes de guardarse.
  5. El sistema notifica: "Fondos insuficientes en Llave BRE. Saldo actual: $20.000".
- **Postcondición:** El movimiento se aborta. El empleado debe seleccionar Efectivo (donde sí hay fondos) o inyectar liquidez a Llave BRE.

**Caso B: Recepción de Pago Mixto (Próximamente POS)**
- **Actor:** Empleado en el POS.
- **Flujo Principal:**
  1. Cliente realiza una compra de $10.000.
  2. Cliente paga $5.000 en Efectivo y transfiere $5.000 a Llave BRE.
  3. El sistema registra las transacciones y aumenta los saldos correspondientes de manera aislada.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| Base de Datos (Enum) | Creación de tipo `payment_channel` con valores `('CASH', 'NEQUI', 'BRE_KEY')`. |
| Interfaz UI | Selectores de método de pago hardcodeados a 3 opciones (Efectivo, Nequi, Llave BRE). Eliminar botones de "Añadir método de pago". |
| Backend (RPC) | Funciones de validación de fondos particionadas por el enum `payment_channel`. |

---

## Criterios de Aceptación
- [ ] **CA-FRD-004-01:** La base de datos restringe los canales a nivel de Enum/Check constraint (`CASH`, `NEQUI`, `BRE_KEY`).
- [ ] **CA-FRD-004-02:** El servidor DEBE particionar el cálculo del saldo utilizando el identificador del canal.
- [ ] **CA-FRD-004-03:** El servidor rechaza egresos si la suma algebraica del canal resulta inferior a cero.
- [ ] **CA-FRD-004-04:** La interfaz visual carece de pantallas para crear o eliminar canales de pago.
