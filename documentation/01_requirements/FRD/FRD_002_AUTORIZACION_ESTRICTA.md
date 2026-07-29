# FRD-002: Autorización Estricta (Protección Integral End-to-End)

### Validación Inviolable de Privilegios Operativos

#### Descripción
Este documento establece que la seguridad y autorización de operaciones recae enteramente en el servidor de base de datos. Ninguna transacción de impacto, ya sea de modificación o inserción de datos financieros, logísticos o administrativos, será aprobada basándose en la aparente autoridad del cliente emisor. La validación debe realizarse mediante consulta directa y en tiempo real al registro central de privilegios de usuario.

---

## Reglas de Negocio
1. **Revalidación Ciega:** El servidor TIENE PROHIBIDO asumir que una petición entrante es válida por el mero hecho de que proviene de un cliente supuestamente autenticado. Cada función de servidor con capacidad de escritura DEBE iniciar con un bloque de comprobación de autoridad.
2. **Origen de los Permisos:** El servidor DEBE consultar el perfil de permisos del usuario emisor directamente en las tablas oficiales del sistema. Se encuentra estrictamente vetado evaluar privilegios basados en datos o metadatos inyectados desde la interfaz de usuario.
3. **Rechazo Discreto:** Toda operación solicitada que viole el perfil de permisos del usuario emisor DEBE ser abortada inmediatamente, descartando cualquier modificación subyacente. El sistema DEBE emitir una señal de rechazo de seguridad clara y sin excepciones.

---

## Casos de Uso

**Caso A: Bloqueo de Modificación Extrínseca sin Privilegios**
- **Actor:** Empleado / Usuario Operativo.
- **Precondición:** El empleado tiene un nivel de acceso básico que le prohíbe administrar pagos financieros. La interfaz gráfica oculta los botones de pago correctamente.
- **Flujo Principal:**
  1. El empleado, a través de manipulación técnica e instrumentación directa (omitiendo la interfaz visual tradicional), envía un paquete de datos ordenando un desembolso por concepto de "Pago a Proveedores".
  2. El servidor central captura la petición y extrae el identificador del empleado asociado a la sesión activa.
  3. El servidor detiene la lógica financiera y acude al perfil centralizado del empleado para interrogar el privilegio explícito de administración de pagos.
  4. Al detectar que el valor del privilegio es negativo o inexistente, el servidor detiene la operación de inmediato.
  5. El servidor rechaza la escritura en las tablas contables y retorna un código de advertencia por privilegios insuficientes, impidiendo la manipulación operativa.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** Los fondos financieros no sufren alteraciones, y la transacción espuria es erradicada antes de iniciar el ciclo contable.

---

## Criterios de Aceptación
- [ ] **CA-FRD-002-01:** Toda operación de inserción o actualización de datos DEBE evaluar los privilegios del usuario activo consultando su registro en la base de datos en tiempo real.
- [ ] **CA-FRD-002-02:** El servidor carece por completo de lógica que confíe en variables de estado, afirmaciones o banderas de autoridad enviadas desde el entorno de cliente.
- [ ] **CA-FRD-002-03:** El sistema DEBE abortar transacciones y emitir un código de error de seguridad explícito si la lectura del perfil de base de datos determina una insuficiencia de privilegios para la acción solicitada.
