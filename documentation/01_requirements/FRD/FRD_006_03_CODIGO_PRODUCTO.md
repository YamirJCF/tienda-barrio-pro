# FRD-006-03: Código de Producto (PLU y Código de Barras)

### Descripción
Este documento rige la especificación del Código de Producto (PLU), que sirve como la interfaz principal entre el cajero (vía teclado numérico) y el sistema. Dado que **el sistema POS no utiliza ni utilizará escáneres de hardware**, el formato y comportamiento de este código están estrictamente diseñados para optimizar la velocidad de digitación humana y la búsqueda rápida, manteniendo el desacoplamiento estricto de la identidad contable del producto.

---

## Reglas de Negocio

1. **Unicidad Operativa:** El Código de Producto DEBE ser estrictamente único dentro de los productos activos de una misma tienda. El sistema TIENE PROHIBIDO permitir la existencia de dos productos activos con el mismo código, ya que esto causaría una colisión en el Punto de Venta (POS).
2. **Independencia de Identidad (Desacoplamiento Absoluto):** El Código de Producto **NO DEBE** usarse como identificador operativo para vincular entidades del sistema (como tickets, kardex o proveedores). El sistema DEBE utilizar un identificador interno inmutable para enlazar las entidades. Esto garantiza que si un código cambia o se reutiliza, el historial contable y de auditoría no se corrompe.
3. **Optimización para Teclado Numérico (Formato):** Dado que la interacción es 100% manual, el campo de código DEBE ser puramente numérico (o alfanumérico corto) y estrictamente limitado en longitud para evitar errores de digitación. 
   - Debe cumplir con los límites de longitud mínima y máxima configurados para la tienda.
   - El sistema DEBE procesar los códigos manteniendo los ceros a la izquierda (por ejemplo, "001" y "1" son códigos distintos).
4. **Política de Reutilización (Baja Lógica):** Si un producto es dado de baja (marcado como inactivo), su Código de Producto queda **LIBERADO** de inmediato y puede ser asignado a un producto completamente nuevo. Esta reutilización es contablemente segura debido a la Regla 2 (Desacoplamiento).
5. **Autogeneración Inteligente:** Si al crear un producto el usuario deja el campo de código vacío, el sistema DEBE autogenerar un código numérico secuencial corto. Este código será el número consecutivo más alto disponible que cumpla con la semilla de inicio configurada.
6. **Búsqueda Exacta y Rápida en POS:** Cuando el cajero en el POS realiza una consulta por código, la búsqueda DEBE ser una coincidencia exacta y absoluta. El sistema NO ejecutará autocompletado ni búsquedas parciales para el código; si no coincide exactamente, el producto no se agrega. Las búsquedas parciales se reservan exclusivamente para el campo "Nombre del Producto" (ver FRD-006 para la navegación del catálogo). La especificación del comportamiento de búsqueda por nombre dentro del POS (campo unificado, detección automática PLU vs nombre, resultados desplegables con carga progresiva) se encuentra en FRD-007 (Búsqueda Inteligente en el POS).

---

## Casos de Uso

**Caso A: Reasignación de Código de Producto (PLU)**
- **Actor:** Empleado con permisos de gestión de inventario.
- **Precondición:** El producto "Gaseosa Cola" existe con el código `015`. El dueño decide que ahora las gaseosas usarán la serie de los `300`.
- **Flujo Principal:**
  1. El empleado edita el producto en el sistema.
  2. Borra el código `015` y digita el nuevo código `301`.
  3. El sistema valida que el nuevo código no esté asignado a otro producto activo en la tienda.
  4. El empleado guarda los cambios exitosamente.
- **Postcondición:** Las ventas futuras del producto se procesarán al digitar `301`. Los comprobantes pasados generados con el código `015` permanecen intactos y siguen referenciando de manera correcta a "Gaseosa Cola".

**Caso B: Reutilización de un Código Liberado**
- **Actor:** Empleado con permisos de gestión de inventario.
- **Precondición:** El código `100` pertenecía al producto "Pan de Bono" que ya fue dado de baja (marcado inactivo).
- **Flujo Principal:**
  1. El empleado registra un nuevo producto llamado "Pan Integral".
  2. Asigna el código `100`.
  3. El sistema valida la disponibilidad excluyendo los productos que están inactivos.
  4. El sistema permite la creación sin generar conflicto.
- **Postcondición:** El código `100` ahora factura a nombre de "Pan Integral". El registro histórico del inventario del producto inactivo "Pan de Bono" no sufre alteraciones ni conflictos.

**Caso C: Búsqueda Rápida por Teclado Numérico (POS)**
- **Actor:** Cajero.
- **Flujo Principal:**
  1. El cajero digita rápidamente el código `105` en el teclado numérico y presiona la tecla de confirmación.
  2. El sistema recibe el código y localiza el producto mediante una búsqueda de coincidencia exacta.
  3. El sistema agrega el producto directamente al ticket de venta en curso sin exigir ventanas o confirmaciones adicionales.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-03-01:** El sistema rechaza la creación o modificación de un producto si el código ingresado ya pertenece a otro producto activo de la misma tienda.
- [ ] **CA-FRD-006-03-02:** El sistema autogenera y asigna un código secuencial disponible basado en la configuración de la tienda, al guardar un producto dejando el código en blanco.
- [ ] **CA-FRD-006-03-03:** El sistema mantiene íntegro el historial transaccional (ventas, movimientos) asociado al producto original, sin que este se corrompa al modificar o reutilizar su código de producto.
- [ ] **CA-FRD-006-03-04:** El sistema valida que el código ingresado cumpla con la longitud mínima y máxima configurada para la tienda.

---

## Requisitos de Datos (Para Equipo Data)
- **Atributo Código de Producto:** Campo optimizado para la digitación, con soporte para validaciones de longitud (mínima y máxima).
- **Unicidad Condicional:** Regla de persistencia que asegure la unicidad del código de producto exclusivamente entre los registros en estado activo de una misma tienda.
- **Identidad Fuerte:** El modelo debe enlazar el producto con el resto de entidades transaccionales mediante un identificador interno inmutable, desacoplando el código de producto de la integridad referencial.
- **Secuencia de Autogeneración:** Mecanismo para determinar el siguiente código numérico consecutivo a partir de un valor base configurado.
