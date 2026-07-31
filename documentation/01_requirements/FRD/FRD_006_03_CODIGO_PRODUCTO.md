# FRD-006-03: Código de Producto (PLU y Código de Barras)

### Descripción
Este documento rige la especificación del Código de Producto, que sirve como la interfaz principal entre el operador (humano o hardware) y el sistema. Define las reglas de unicidad, el formato para soportar tanto PLUs cortos de teclado como códigos de barras (EAN/UPC), y establece el desacoplamiento estricto entre este código operativo y la identidad contable del producto en la base de datos.

---

## Reglas de Negocio

1. **Unicidad Operativa:** El Código de Producto DEBE ser estrictamente único dentro de los productos activos de una misma tienda. El sistema TIENE PROHIBIDO permitir la existencia de dos productos activos con el mismo código, ya que esto causaría una colisión en el Punto de Venta (POS).
2. **Independencia de Identidad (Desacoplamiento Absoluto):** El Código de Producto **NO DEBE** usarse como llave foránea o identificador relacional en bases de datos (Tickets, Kardex, Proveedores). El sistema utilizará un UUID interno inmutable para enlazar las entidades. Esto garantiza que si un código cambia o se reutiliza, el historial contable y de auditoría no se corrompe.
3. **Flexibilidad y Escalabilidad de Formato:** Para soportar la evolución de una tienda de barrio (teclado numérico) a un minimarket (escáner láser), el campo de código DEBE soportar valores alfanuméricos. 
   - Debe cumplir con los parámetros de longitud mínima (`P_MIN_PLU_LENGTH`) y máxima (`P_MAX_PLU_LENGTH`).
   - El sistema debe procesar "001" y "1" como códigos distintos si son ingresados como texto.
4. **Política de Reutilización (Baja Lógica):** Si un producto es dado de baja (marcado como inactivo/eliminado lógicamente), su Código de Producto queda **LIBERADO** de inmediato y puede ser asignado a un producto completamente nuevo. Esta reutilización es contablemente segura debido a la Regla 2 (Desacoplamiento).
5. **Autogeneración Inteligente:** Si al crear un producto el usuario deja el campo de código vacío, el sistema DEBE autogenerar un código numérico. Este código será el número consecutivo más alto disponible que sea mayor o igual al parámetro semilla (`P_AUTO_PLU_SEED`).
6. **Búsqueda Exacta en POS:** Cuando el POS o el módulo de Inventario realiza una consulta por código (usando escáner o teclado numérico + Enter), la búsqueda DEBE ser una coincidencia exacta, no parcial (`=`, no `LIKE`). Las búsquedas parciales se reservan exclusivamente para el campo "Nombre del Producto".

---

## Casos de Uso

**Caso A: Migración a Código de Barras**
- **Actor:** Empleado con `canManageInventory`
- **Precondición:** El producto "Gaseosa Cola" existe con el PLU `015`.
- **Flujo Principal:**
  1. El empleado edita el producto.
  2. Borra el código `015` y escanea el código de barras impreso en la botella (`7701234567890`).
  3. El sistema valida que el nuevo código no esté en uso.
  4. Guarda el cambio.
- **Postcondición:** Las ventas futuras de ese producto responderán al código `7701234567890`. Los tickets pasados generados con `015` permanecen intactos y apuntando a "Gaseosa Cola" gracias al UUID.

**Caso B: Reutilización de PLU Corto**
- **Actor:** Empleado con `canManageInventory`
- **Precondición:** El PLU `100` pertenecía a "Pan de Bono" (inactivo/dado de baja).
- **Flujo Principal:**
  1. El empleado crea un nuevo producto "Pan Integral".
  2. Asigna el código `100`.
  3. El sistema valida la unicidad excluyendo los productos inactivos.
  4. El sistema permite la creación.
- **Postcondición:** El PLU `100` ahora factura "Pan Integral". El kardex histórico del "Pan de Bono" no se ve afectado.

**Caso C: Escaneo Rápido (POS)**
- **Actor:** Empleado Cajero.
- **Flujo Principal:**
  1. El cajero dispara el escáner sobre el producto `7701234567890`.
  2. El POS recibe el código y ejecuta una búsqueda exacta inmediata.
  3. El sistema localiza el UUID del producto y lo agrega al carrito.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-03-01:** La base de datos debe tener un índice único parcial que garantice que no haya dos códigos iguales en la misma tienda, aplicando SOLO a productos `is_active = true`.
- [ ] **CA-FRD-006-03-02:** Guardar un producto sin ingresar un código genera uno secuencial basado en `P_AUTO_PLU_SEED` de manera automática.
- [ ] **CA-FRD-006-03-03:** Todas las tablas dependientes (Kardex, Detalles de Ticket) deben referenciar al producto por su UUID, nunca por su Código/PLU.
- [ ] **CA-FRD-006-03-04:** El sistema permite registrar códigos alfanuméricos de hasta 15 caracteres.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| Tabla `products` | Validar restricción `UNIQUE(store_id, code) WHERE is_active = true`. Alterar tipo de columna `code` a `VARCHAR(15)`. |
| Módulo Configuración | Agregar parámetros `P_MIN_PLU_LENGTH`, `P_MAX_PLU_LENGTH`, `P_AUTO_PLU_SEED`. |
| Frontend POS/Inventario | Ajustar inputs para permitir alfanuméricos; asegurar que la búsqueda directa no modifique/recorte ceros a la izquierda. |
