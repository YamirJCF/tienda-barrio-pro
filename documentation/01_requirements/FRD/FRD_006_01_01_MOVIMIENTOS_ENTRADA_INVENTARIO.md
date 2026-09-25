# FRD-006-01-01: Alcance y Límites de "Movimientos de Entrada"

### Nombre de la Funcionalidad
El Ingreso Físico de Mercancía

#### Descripción
Este documento detalla y restringe el comportamiento de los "Movimientos de Entrada" (ingreso de stock) dentro del módulo de Inventario. Históricamente la interfaz mezclaba entradas, salidas y ajustes bajo el nombre "Nueva Entrada", y tendía a violar la arquitectura al intentar acoplarse a Proveedores. Su alcance se reduce estrictamente a la declaración logística de incremento físico de unidades en la bodega de la tienda.

---

## Reglas de Negocio

1. **Naturaleza Logística Pura:** La función de Entrada tiene un único mandato operativo: recibir una cantidad mayor a cero e incrementar el stock actual del producto asociado.
2. **Ceguera Financiera Absoluta:** Al confirmar una entrada de mercancía, el sistema TIENE ESTRICTAMENTE PROHIBIDO descontar dinero de la sesión de caja actual, registrar un gasto automático o alterar el saldo del flujo de efectivo.
3. **Desvinculación de Cuentas por Pagar:** Aunque la interfaz visual posea una sección de "Datos del Proveedor", esta información es exclusivamente referencial para el historial de movimientos de inventario. El ingreso de las unidades al estante TIENE PROHIBIDO generar automáticamente una deuda en el módulo de Proveedores.
4. **Registro de Costo Referencial (No Contable):** Durante la entrada, el sistema DEBE permitir registrar el "Costo de Adquisición". Este dato se guarda únicamente con fines informativos para el historial de movimientos de inventario y para actualizar el costo teórico del producto en el catálogo. Este número NO representa una transacción de dinero real en el sistema.
5. **Motivos de Entrada Permitidos (Trazabilidad):** Toda entrada DEBE registrar un "Motivo" en el historial de movimientos de inventario. Se mantienen exclusivamente los siguientes motivos logísticos:
    - **Compra:** Ingreso por adquisición a un proveedor. No afecta finanzas automáticamente.
    - **Ajuste Positivo:** Corrección de inventario al encontrar más unidades físicas que las del sistema.

6. **Normalización de Datos del Proveedor:** El campo referencial "Datos del Proveedor" en el formulario de entrada DEBE aplicar normalización automática (trim + formato título) al guardar, idéntica a la especificada en FRD-019, Regla 22. El sistema DEBE sugerir nombres de proveedores ya utilizados en entradas anteriores o facturas por pagar de la misma tienda.

---

## Casos de Uso

**Caso A: Recepción de Mercancía Pagada de Contado**
- **Actor:** Admin o empleado con permiso de entrada de inventario.
- **Precondición:** Llega mercancía al local. El usuario saca billetes físicos de la caja para pagarle al repartidor y luego procede a ingresar los productos al sistema.
- **Flujo Principal:**
    1. El usuario accede al inventario y ejecuta la función de Nueva Entrada para los productos recibidos.
    2. El sistema suma las unidades al stock y las deja listas para la venta.
    3. **Límite de Dominio:** La responsabilidad del inventario termina aquí. El sistema NO toca la caja.
    4. Para reflejar la salida del dinero físico, el usuario debe ir de forma independiente al módulo de Caja y ejecutar un Registro de Gasto (según FRD-004).
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El inventario sube correctamente. La caja baja correctamente por una acción separada. Ningún sistema invade la competencia del otro.

---

**Caso B: Recepción de Mercancía a Crédito**
- **Actor:** Admin o empleado con permiso de entrada de inventario.
- **Precondición:** Llega un pedido grande. El repartidor entrega la mercancía y una factura para pagar el próximo mes. No sale dinero de la caja.
- **Flujo Principal:**
    1. El usuario ejecuta Nueva Entrada en el inventario por las cantidades recibidas.
    2. El stock se actualiza instantáneamente.
    3. **Límite de Dominio:** El inventario no crea ninguna deuda automática.
    4. El usuario acude al módulo externo de Proveedores y anota la factura pendiente (según FRD-019).
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** Se puede vender la mercancía de inmediato, y la deuda queda registrada en su respectivo módulo aislado, sin afectar el turno de caja.

---

## Criterios de Aceptación

- [ ] CA-FRD-006-01-01-01: La operación del servidor encargada de procesar la entrada de inventario NO DEBE generar movimientos de caja ni alterar el estado de la sesión de caja.
- [ ] CA-FRD-006-01-01-02: La interfaz visual de Nueva Entrada TIENE PROHIBIDO mostrar controles que induzcan a un acoplamiento encubierto con la caja, tales como opciones de pago directo desde la entrada.
- [ ] CA-FRD-006-01-01-03: El sistema DEBE rechazar cualquier intento de Nueva Entrada donde la cantidad a ingresar sea menor o igual a cero.
- [ ] CA-FRD-006-01-01-04: El registro de una entrada de inventario NO DEBE crear registros en el módulo de cuentas por pagar.
- [ ] CA-FRD-006-01-01-05: El costo de adquisición registrado en una entrada de inventario NO DEBE generar movimientos de caja.
- [ ] CA-FRD-006-01-01-06: El campo de proveedor en el formulario de entrada aplica normalización automática y sugiere proveedores existentes.
