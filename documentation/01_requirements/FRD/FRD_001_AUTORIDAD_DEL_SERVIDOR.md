# FRD-001: La Verdad Reside en el Servidor (Autoridad Exclusiva)

### Autoridad Centralizada de Cálculos y Datos

#### Descripción
Este documento establece que la única fuente de verdad para validaciones de negocio, cálculos matemáticos y decisiones financieras es el servidor de datos central. El sistema visual (interfaz de usuario) debe considerarse una entidad pasiva de presentación que carece de autoridad para determinar el estado real del negocio.

---

## Reglas de Negocio
1. **Delegación Estricta:** La interfaz visual TIENE PROHIBIDO ejecutar cálculos de saldos, aplicar fórmulas para determinar impuestos, sumar totales definitivos de ventas o validar reglas de inventario utilizando datos locales. Toda operación matemática con impacto financiero DEBE resolverse en el servidor.
2. **Ignorancia de Cálculos Ajenos:** El servidor TIENE PROHIBIDO confiar en un total, subtotal o cálculo financiero enviado directamente por el cliente visual. El servidor DEBE recibir únicamente las unidades transaccionales puras (por ejemplo: identificador del producto y cantidad a vender) y realizar su propio cómputo utilizando los precios y reglas oficiales almacenadas en la base de datos central.
3. **Manejo de Desincronización:** Cualquier discrepancia entre la expectativa del cliente y el cálculo real del servidor (por ejemplo, cambios de precios concurrentes) DEBE resolverse a favor del servidor, denegando la transacción y obligando a la interfaz visual a actualizarse y mostrar los nuevos valores.

---

## Casos de Uso

**Caso A: Recálculo Transaccional Seguro**
- **Actor:** Empleado Operativo / Sistema Visual.
- **Precondición:** El empleado reúne un listado de productos para la venta. La interfaz visual agrupa estos elementos de manera estética para el usuario.
- **Flujo Principal:**
  1. El empleado presiona el botón de confirmación de venta en el sistema visual.
  2. El sistema visual transmite al servidor una lista cruda que contiene únicamente identificadores de productos y sus respectivas cantidades.
  3. El servidor recibe la lista e interroga a la base de datos oficial para extraer el precio unitario vigente de cada elemento y sus impuestos asociados.
  4. El servidor realiza las multiplicaciones, sumas y recargos correspondientes para generar un total definitivo inquebrantable.
  5. El servidor asienta la transacción con este valor y devuelve el recibo definitivo al sistema visual.
- **Flujo Alternativo:** El sistema visual intenta enviar un campo de "precio final esperado". El servidor desecha ese dato por considerarlo inseguro y continúa con el flujo principal.
- **Postcondición:** La transacción se consolida en la contabilidad basándose exclusivamente en los datos certificados por el servidor.

---

## Criterios de Aceptación
- [ ] **CA-FRD-001-01:** El servidor DEBE recalcular el costo total de toda transacción utilizando las tarifas y reglas resguardadas en la base de datos, abortando cualquier operación que pretenda dictar montos finales desde el exterior.
- [ ] **CA-FRD-001-02:** La interfaz visual carece de lógica de almacenamiento a largo plazo que pretenda fungir como fuente de verdad sobre saldos o disponibilidad de inventario.
- [ ] **CA-FRD-001-03:** El sistema DEBE abortar transacciones y emitir un mensaje de desincronización si el servidor detecta que las premisas bajo las cuales el cliente solicitó la transacción ya no son válidas en la base de datos.
