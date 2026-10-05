# FRD-006-02: Gestor de Reembolsos (Devoluciones de Clientes)

### Orquestación Atómica de Ingresos Logísticos y Egresos Monetarios

#### Descripción
Herramienta especializada ubicada en la pantalla de "Administración" (sección "Equipo"), diseñada exclusivamente para manejar las devoluciones de productos por parte de clientes. Su propósito es resolver la "paradoja de la devolución": ingresar stock y sacar dinero simultáneamente. Al ser un módulo independiente, evita contaminar las ventas del POS y prohíbe la manipulación manual de inventarios, asegurando que el dinero reembolsado cuadre perfectamente en el turno de caja actual.

---

## Reglas de Negocio

1. **Control de Acceso Basado en Perfil:** No se requieren PINs temporales. El acceso a esta herramienta está gobernado estrictamente por el sistema de permisos. Un empleado solo podrá visualizar y ejecutar esta función si el Administrador le ha otorgado explícitamente dicho permiso en su perfil de usuario.
2. **Entrada Manual por PLU:** El registro del producto a devolver se realiza digitando manualmente su código identificador interno (PLU), prescindiendo del uso del escáner de código de barras.
3. **Cálculo de Monto Estricto e Inmutable:** Una vez ingresado el PLU y la cantidad de unidades, el sistema calcula automáticamente el valor monetario a devolver (basado en el precio de venta del sistema). Este monto total desglosado es **exacto e inalterable** por el usuario. El sistema y el cajero asumen este valor como la única verdad contable para el reembolso.
4. **Transacción Atómica Bidireccional:** Al confirmar el reembolso, el sistema ejecuta una única transacción en la base de datos que dispara dos eventos simultáneos:
   - **Evento Logístico:** Incrementa el inventario del PLU en la cantidad especificada.
   - **Evento Financiero:** Registra un "Egreso" (salida de efectivo) en la sesión de caja activa por el monto exacto calculado.
5. **Dependencia de Turno Activo:** Para poder entregar dinero al cliente, el sistema exige que el usuario tenga un Turno de Caja (Sesión) abierto y vigente. El egreso queda amarrado al `session_id` actual, asegurando que el arqueo de caja al final del día refleje el dinero entregado por la devolución.
6. **Selección de Canal y Validación de Fondos por Canal:**
   - Todo reembolso DEBE especificar el canal por el cual sale el dinero: **EFECTIVO**, **NEQUI** o **LLAVE BRE** (los tres canales fijos de FRD-004 Caja Estricta Multicanal). La interfaz DEBE preseleccionar **EFECTIVO** por defecto, permitiendo al usuario modificarlo a cualquiera de los otros canales permitidos.
   - Para garantizar total transparencia y trazabilidad contable, el formulario DEBE incluir una lista desplegable para registrar el **Canal de Venta Original** (Efectivo, Nequi, Llave BRE) por el cual el cliente pagó la compra inicial.
   - El canal de egreso seleccionado DEBE ser el origen real del dinero entregado al cliente (mismo principio de FRD-026). El saldo de cada canal se evalúa de forma aislada por turno (FRD-027, Regla 2).
   - El servidor DEBE validar los fondos disponibles exclusivamente en el canal de egreso seleccionado (FRD-027, Regla 3). Si los fondos no alcanzan, el servidor DEBE rechazar la operación completa: no se ingresa stock ni se registra egreso. No se compensa con saldo de otro canal ni se permite sobregiro.
   - La pantalla de reembolsos NO DEBE ofrecer ni requerir ingresos manuales ficticios para habilitar un reembolso.
   - Cuando el canal de egreso difiere del canal de venta original, el sistema registra ambos canales de forma transparente para auditoría sin realizar transferencias automáticas entre canales: cada canal concilia su realidad contable independientemente.
7. **Trazabilidad Contable del Reembolso (POL-AUD-02):**
   - El Egreso generado DEBE clasificarse con el tipo o subtipo **Reembolso**, diferenciado claramente de los gastos operativos estándar, para que los reportes de caja (FRD-027-01) y el análisis financiero (FRD-018, fórmula: $\text{Ingresos Netos} = \text{Ventas Brutas} - \text{Devoluciones}$) puedan identificarlo, aislarlo y descontarlo correctamente.
   - El Egreso de caja y el Ingreso de inventario de una misma operación DEBEN quedar vinculados entre sí con un identificador común de operación, almacenando: `session_id`, usuario responsable, PLU, cantidad, monto total reembolsado, canal de egreso y canal de venta original.
   - Ambos registros son inmutables. Cualquier error en el proceso se corrige mediante contra-movimiento auditable (FRD-004 Control de Caja, Regla 5).

---

## Casos de Uso

**Caso A: Reembolso por Producto Devuelto**
- **Actor:** Administrador o Empleado con permiso explícito de Reembolso.
- **Precondición:** El cliente devuelve mercancía en buen estado. El actor tiene un turno de caja activo.
- **Flujo Principal:**
  1. El actor navega a la pantalla de "Administración", bajo la sección "Equipo", y abre la herramienta de Reembolsos.
  2. Digita manualmente el código PLU del producto.
  3. Ingresa la cantidad de productos a devolver.
  4. El sistema calcula y muestra en pantalla el total exacto a reembolsar al cliente.
  5. El actor selecciona en la lista desplegable el **Canal de Venta Original** (Efectivo, Nequi o Llave BRE) por el que pagó el cliente.
  6. El actor verifica el **Canal de Reembolso** (Efectivo preseleccionado por defecto) y lo modifica si entregará el dinero por un canal digital.
  7. El actor confirma la operación.
  8. El sistema valida fondos en el canal de egreso, extrae el dinero contablemente de dicho canal en la sesión de caja, registra el canal original para trazabilidad y suma el stock al inventario de forma atómica.
- **Flujo Alternativo (Sin Permiso):** Si un cajero sin autorización intenta acceder a la ruta, el sistema le deniega el acceso visual o funcional.
- **Flujo Alternativo (Sin Turno):** Si el actor tiene permisos pero su caja está cerrada, el sistema aborta la operación advirtiendo que no hay caja de dónde sacar el dinero.
- **Flujo Alternativo (Fondos Insuficientes en el Canal):** Si el canal de reembolso seleccionado no posee saldo suficiente en el turno activo, el sistema aborta la operación completa y muestra: "Fondos insuficientes en [canal]. Saldo actual: $X. Selecciona el canal por el que realmente entregarás el dinero." El formulario conserva el PLU, la cantidad y el canal original para que el actor ajuste el canal de entrega y reintente sin perder los datos ingresados. No se modifica inventario ni caja.
- **Postcondición:** El inventario aumenta, el flujo de caja del turno actual registra un egreso tipificado como Reembolso en el canal de salida, el canal original queda registrado para auditoría y el arqueo de cada canal cuadra con la realidad física y digital.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-02-01:** La herramienta de devoluciones DEBE estar protegida por la matriz de roles y permisos existente, denegando el renderizado o ejecución a usuarios sin autorización.
- [ ] **CA-FRD-006-02-02:** La interfaz DEBE requerir la digitación del PLU y PROHIBIR la edición manual del campo "Monto a Reembolsar", el cual debe ser un cálculo inyectado por el sistema.
- [ ] **CA-FRD-006-02-03:** El backend DEBE abortar (rollback) la operación si la inserción del ingreso de inventario falla, o si la inserción del egreso de caja falla, garantizando consistencia.
- [ ] **CA-FRD-006-02-04:** La función backend DEBE exigir un `session_id` activo para procesar el egreso de dinero.
- [ ] **CA-FRD-006-02-05:** La interfaz muestra el canal de egreso con Efectivo preseleccionado por defecto, permitiendo cambiarlo a Nequi o Llave BRE.
- [ ] **CA-FRD-006-02-06:** La interfaz incluye una lista desplegable obligatoria para registrar el canal de venta original (Efectivo, Nequi, Llave BRE) y el sistema lo persiste junto a la transacción.
- [ ] **CA-FRD-006-02-07:** El backend DEBE rechazar el reembolso completo (sin ingresar stock ni registrar egreso) si el canal de salida no tiene fondos suficientes en el turno, sin compensar con otros canales.
- [ ] **CA-FRD-006-02-08:** El egreso generado queda tipificado como Reembolso (diferenciado de gastos operativos) para asegurar el cálculo de Ingresos Netos según FRD-018.
- [ ] **CA-FRD-006-02-09:** El egreso de caja y el ingreso de inventario quedan vinculados atómicamente con trazabilidad completa (turno, usuario, PLU, cantidad, monto, canal de salida y canal original).
