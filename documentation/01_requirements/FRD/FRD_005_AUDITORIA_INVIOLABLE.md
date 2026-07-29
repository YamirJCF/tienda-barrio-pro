# FRD-005: Auditoría Inviolable (Principio de Inmutabilidad)

### Consolidación y Protección del Historial de Operaciones

#### Descripción
Este documento establece la naturaleza indeleble de todo movimiento financiero u operativo asentado en la base de datos. Ninguna operación finalizada puede desaparecer de la historia contable del negocio. Para enmendar errores humanos u operativos, el sistema impone la lógica de "movimientos de contrapeso", protegiendo la confianza e integridad del rastro de auditoría.

---

## Reglas de Negocio
1. **Bloqueo de Modificación Póstuma:** Ningún movimiento financiero que haya sido registrado exitosamente en el servidor de base de datos PUEDE ser objeto de actualización u alteración estructural. Está rotundamente prohibido modificar montos, borrar filas u ocultar operaciones del historial.
2. **Corrección mediante Contrapartida:** Si un movimiento es considerado erróneo y el usuario desea invalidarlo, el servidor DEBE ejecutar un evento de enmienda que consistirá en la inyección de un registro de contrapeso (matemáticamente inverso al valor original) conservando la integridad de los registros previos.
3. **Trazabilidad de la Corrección:** Todo evento de enmienda originado para subsanar un error previo DEBE documentar estructuralmente el identificador exacto de la transacción original que se pretende neutralizar, garantizando la trazabilidad cruzada.

---

## Casos de Uso

**Caso A: Subsanación Inviolable de Ingreso Erróneo**
- **Actor:** Usuario Operativo / Sistema Servidor.
- **Precondición:** El usuario registra equivocadamente el ingreso de cincuenta mil unidades monetarias por concepto de "Abono de Cliente". Quince minutos después, el usuario se percata de que el abono real era de cuarenta mil unidades, no cincuenta mil.
- **Flujo Principal:**
  1. Ante la imposibilidad técnica de editar el valor grabado, el usuario solicita al sistema la orden de anulación del movimiento de abono.
  2. El servidor procesa la solicitud negándose a borrar la entrada original. En su lugar, el servidor inyecta automáticamente un movimiento de salida por cincuenta mil unidades, clasificado bajo el concepto estricto de "Anulación" o "Contrapeso".
  3. El servidor graba dentro de este movimiento de salida la referencia directa a la transacción inicial, amarrando el destino de ambos registros.
  4. La suma contable de ambos movimientos (positivo y negativo) da como resultado un impacto cero en el saldo, cancelándose mutuamente sin destruir el registro del suceso en el tiempo.
  5. El usuario procede a registrar un tercer movimiento, esta vez de ingreso válido, por las cuarenta mil unidades correspondientes.
- **Flujo Alternativo:** El usuario intenta borrar de manera directa (ej. manipulación de herramientas de base de datos no autorizadas) el registro inicial. Las políticas estrictas del servidor bloquean la orden destructiva, emitiendo una alarma de seguridad.
- **Postcondición:** La base de datos conserva la historia completa de los tres eventos temporales, garantizando a los dueños una visibilidad y auditoría perfectas del error humano y su corrección.

---

## Criterios de Aceptación
- [ ] **CA-FRD-005-01:** Los registros financieros en las tablas de repositorio contable DEBEN poseer bloqueos lógicos permanentes en el servidor contra operaciones de actualización destructiva y operaciones de eliminación forzosa.
- [ ] **CA-FRD-005-02:** El sistema DEBE proveer flujos que generen movimientos matemáticos inversos ante solicitudes de anulación, sin alterar los campos originarios del registro invalidado.
- [ ] **CA-FRD-005-03:** Todo movimiento generado por el servidor bajo la premisa de "anulación o corrección" DEBE poseer una columna referencial que vincule obligatoriamente la identificación única del movimiento originario.
