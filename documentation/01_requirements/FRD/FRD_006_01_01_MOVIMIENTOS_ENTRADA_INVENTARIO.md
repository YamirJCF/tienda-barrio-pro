# FRD-006-01-01: Alcance y Límites de "Movimientos de Entrada"

### El Ingreso Físico de Mercancía

#### Descripción
Este documento detalla y restringe el comportamiento de los "Movimientos de Entrada" (ingreso de stock) dentro del módulo de Inventario. Históricamente la interfaz mezclaba entradas, salidas y ajustes bajo el nombre "Nueva Entrada", y tendía a violar la arquitectura al intentar acoplarse a Proveedores. Su alcance se reduce estrictamente a la **declaración logística de incremento físico de unidades** en la bodega de la tienda.

---

## Reglas de Negocio

1. **Naturaleza Logística Pura:** La función de Entrada tiene un único mandato operativo: recibir una cantidad 'X' mayor a cero e incrementar el stock actual del producto asociado. 
2. **Ceguera Financiera Absoluta:** Al confirmar una entrada de mercancía, el sistema TIENE ESTRICTAMENTE PROHIBIDO descontar dinero de la sesión de caja actual, registrar un "Gasto" automático o alterar el saldo del flujo de efectivo. 
3. **Desvinculación de Cuentas por Pagar (El Formulario UI):** Aunque la interfaz visual posea una sección de "Datos del Proveedor", esta información es **exclusivamente referencial** para el historial del Kardex. El ingreso de las unidades al estante TIENE PROHIBIDO generar automáticamente una deuda en el módulo de Proveedores.
4. **Registro de Costo Referencial (No Contable):** Durante la entrada, el sistema permite registrar el "Costo de Adquisición". Este dato se guarda **únicamente** con fines informativos para el Kardex y para actualizar el costo teórico del producto en el catálogo. Este número NO representa una transacción de dinero real en el sistema.
5. **Motivos de Entrada Permitidos (Trazabilidad):** Toda entrada DEBE registrar un "Motivo" en el historial de movimientos (Kardex). Se mantienen exclusivamente los siguientes motivos logísticos:
   - **Compra:** Ingreso por adquisición a un proveedor. (No afecta finanzas automáticamente).
   - **Devolución Cliente:** Un cliente devuelve un producto. (El reembolso del dinero se hace por Caja, el ingreso físico por Inventario).
   - **Ajuste Positivo:** Corrección de inventario al encontrar más unidades físicas que las del sistema.

---

## Casos de Uso

**Caso A: Recepción de Mercancía Pagada de Contado**
- **Actor:** Usuario Operativo / Administrador.
- **Precondición:** Llega mercancía al local. El operario saca billetes físicos de la caja para pagarle al repartidor y luego procede a ingresar los productos al sistema.
- **Flujo Principal:**
  1. El usuario accede al inventario y ejecuta la función "Nueva Entrada" para los productos recibidos.
  2. El sistema suma las unidades al stock y las deja listas para la venta.
  3. *Límite de Dominio:* La responsabilidad del inventario termina aquí. El sistema NO toca la caja.
  4. Para reflejar la salida del dinero físico, el operario debe ir de forma independiente al módulo de Caja y ejecutar un "Gasto Inmediato" (según FRD-026).
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El inventario sube correctamente. La caja baja correctamente (por una acción separada). Ningún sistema invade la competencia del otro.

**Caso B: Recepción de Mercancía a Crédito (Factura a 30 días)**
- **Actor:** Usuario Operativo / Administrador.
- **Precondición:** Llega un pedido grande. El repartidor entrega la mercancía y una factura para pagar el próximo mes. No sale dinero de la caja.
- **Flujo Principal:**
  1. El usuario ejecuta "Nueva Entrada" en el inventario por las cantidades recibidas.
  2. El stock se actualiza instantáneamente.
  3. *Límite de Dominio:* El inventario no crea ninguna deuda automática.
  4. El operario acude al módulo externo de Proveedores ("La Libreta de Post-its") y anota la factura pendiente (según FRD-025).
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** Se puede vender la mercancía de inmediato, y la deuda queda registrada en su respectivo módulo asilado, sin afectar el turno de caja.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-01-01-01:** La función RPC o endpoint encargado de procesar la entrada de inventario (`add_inventory_entry` o similar) NO DEBE contener comandos `INSERT` o `UPDATE` dirigidos a las tablas `cash_movements` o `cash_sessions`.
- [ ] **CA-FRD-006-01-01-02:** La interfaz visual de "Nueva Entrada" TIENE PROHIBIDO mostrar checkboxes o toggles como "Pagar con dinero de la caja" que induzcan a un acoplamiento encubierto.
- [ ] **CA-FRD-006-01-01-03:** El sistema DEBE rechazar cualquier intento de "Nueva Entrada" donde la cantidad a ingresar sea menor o igual a cero.
