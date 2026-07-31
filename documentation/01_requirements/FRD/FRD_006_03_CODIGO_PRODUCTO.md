# FRD-006-03: Código de Producto (PLU y Código de Barras)

### Descripción
Este documento rige la especificación del Código de Producto (PLU), que sirve como la interfaz principal entre el cajero (vía teclado numérico) y el sistema. Dado que **el sistema POS no utiliza ni utilizará escáneres de hardware**, el formato y comportamiento de este código están estrictamente diseñados para optimizar la velocidad de digitación humana y la búsqueda rápida, manteniendo el desacoplamiento estricto de la identidad contable del producto.

---

## Reglas de Negocio

1. **Unicidad Operativa:** El Código de Producto DEBE ser estrictamente único dentro de los productos activos de una misma tienda. El sistema TIENE PROHIBIDO permitir la existencia de dos productos activos con el mismo código, ya que esto causaría una colisión en el Punto de Venta (POS).
2. **Independencia de Identidad (Desacoplamiento Absoluto):** El Código de Producto **NO DEBE** usarse como llave foránea o identificador relacional en bases de datos (Tickets, Kardex, Proveedores). El sistema utilizará un UUID interno inmutable para enlazar las entidades. Esto garantiza que si un código cambia o se reutiliza, el historial contable y de auditoría no se corrompe.
3. **Optimización para Teclado Numérico (Formato):** Dado que la interacción es 100% manual, el campo de código DEBE ser puramente numérico (o alfanumérico corto) y estrictamente limitado en longitud para evitar errores de digitación. 
   - Debe cumplir con los parámetros de longitud mínima (`P_MIN_PLU_LENGTH`) y máxima (`P_MAX_PLU_LENGTH`).
   - El sistema debe procesar "001" y "1" como códigos distintos si el diseño de base de datos usa VARCHAR para preservar ceros a la izquierda.
4. **Política de Reutilización (Baja Lógica):** Si un producto es dado de baja (marcado como inactivo/eliminado lógicamente), su Código de Producto queda **LIBERADO** de inmediato y puede ser asignado a un producto completamente nuevo. Esta reutilización es contablemente segura debido a la Regla 2 (Desacoplamiento).
5. **Autogeneración Inteligente:** Si al crear un producto el usuario deja el campo de código vacío, el sistema DEBE autogenerar un código numérico secuencial corto. Este código será el número consecutivo más alto disponible que sea mayor o igual al parámetro semilla (`P_AUTO_PLU_SEED`).
6. **Búsqueda Exacta y Rápida en POS:** Cuando el cajero en el POS realiza una consulta por código (digitando el PLU en el teclado numérico + Enter), la búsqueda DEBE ser una coincidencia exacta y absoluta (`=`, no `LIKE`). El sistema no ejecutará autocompletado ni búsquedas parciales para el PLU; si el código no coincide exactamente, el producto no se agrega. Las búsquedas parciales se reservan exclusivamente para el campo "Nombre del Producto".

---

## Casos de Uso

**Caso A: Reasignación de PLU Operativo**
- **Actor:** Empleado con `canManageInventory`
- **Precondición:** El producto "Gaseosa Cola" existe con el PLU `015`. El dueño decide que ahora las gaseosas usarán la serie de los `300`.
- **Flujo Principal:**
  1. El empleado edita el producto.
  2. Borra el código `015` y digita el nuevo código `301`.
  3. El sistema valida que el nuevo código no esté en uso.
  4. Guarda el cambio.
- **Postcondición:** Las ventas futuras de ese producto responderán al digitar `301`. Los tickets pasados generados con `015` permanecen intactos y apuntando a "Gaseosa Cola" gracias al UUID.

**Caso B: Reutilización de PLU Corto**
- **Actor:** Empleado con `canManageInventory`
- **Precondición:** El PLU `100` pertenecía a "Pan de Bono" (inactivo/dado de baja).
- **Flujo Principal:**
  1. El empleado crea un nuevo producto "Pan Integral".
  2. Asigna el código `100`.
  3. El sistema valida la unicidad excluyendo los productos inactivos.
  4. El sistema permite la creación.
- **Postcondición:** El PLU `100` ahora factura "Pan Integral". El kardex histórico del "Pan de Bono" no se ve afectado.

**Caso C: Búsqueda Rápida por Teclado Numérico (POS)**
- **Actor:** Empleado Cajero.
- **Flujo Principal:**
  1. El cajero digita rápidamente `105` en el teclado numérico del POS y presiona Enter.
  2. El POS recibe el código y ejecuta una búsqueda exacta inmediata en memoria/caché.
  3. El sistema localiza el UUID asociado a `105` y agrega el producto directamente al carrito sin requerir confirmación extra.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-03-01:** La base de datos debe tener un índice único parcial que garantice que no haya dos códigos iguales en la misma tienda, aplicando SOLO a productos `is_active = true`.
- [ ] **CA-FRD-006-03-02:** Guardar un producto sin ingresar un código genera uno secuencial basado en `P_AUTO_PLU_SEED` de manera automática.
- [ ] **CA-FRD-006-03-03:** Todas las tablas dependientes (Kardex, Detalles de Ticket) deben referenciar al producto por su UUID, nunca por su Código/PLU.
- [ ] **CA-FRD-006-03-04:** El sistema permite registrar códigos de longitud controlada por `P_MAX_PLU_LENGTH` (recomendado máximo 6 caracteres para digitación humana rápida).

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| Tabla `products` | Validar restricción `UNIQUE(store_id, code) WHERE is_active = true`. Alterar tipo de columna `code` a `VARCHAR(6)` o adaptado al nuevo límite. |
| Módulo Configuración | Ajustar parámetros `P_MIN_PLU_LENGTH`, `P_MAX_PLU_LENGTH` (max 6), `P_AUTO_PLU_SEED`. |
| Frontend POS | Asegurar que el input del POS enfoque automáticamente y capture el evento Enter para agregar al carrito instantáneamente. |
