# FRD-007-02: Ticket de Venta (Trazabilidad y Comprobante)

### Descripción
Este documento establece las reglas, límites y el nivel de acoplamiento del "Ticket de Venta". Actualmente concebido como un simple contador visual, el Ticket debe evolucionar para convertirse en el ancla principal de auditoría de cada transacción. Su diseño debe ser lo suficientemente robusto para garantizar el no repudio (inmutabilidad) y lo suficientemente flexible (desacoplado) para permitir la futura integración de un módulo de Facturación Electrónica sin romper la lógica del Punto de Venta (POS).

---

## Reglas de Negocio

1. **Naturaleza Operativa (No Fiscal):** El Ticket es estrictamente un comprobante de control interno y de garantía para el cliente. **NO es un documento fiscal** (factura electrónica). Su propósito primario es la trazabilidad operativa, la resolución de conflictos (devoluciones) y la auditoría de caja.
2. **Inmutabilidad y Secuencialidad Inquebrantable:** La numeración del ticket DEBE ser estrictamente secuencial, sin huecos (gaps) y generada centralizadamente por el servidor (NUNCA calculada por el cliente POS local para evitar colisiones offline). Una vez emitido un número de ticket, este TIENE PROHIBIDO ser modificado, eliminado o reutilizado, incluso si la venta es posteriormente anulada.
3. **Anclaje de Trazabilidad Universal (Aplicación de POL-AUD-02):** Todo ticket generado DEBE registrar de forma indeleble en la base de datos la siguiente huella de auditoría:
    *   El ID de la sesión de caja activa (`session_id`).
    *   El ID del empleado que realizó el cobro.
    *   El timestamp exacto generado por el servidor.
    *   El tipo de transacción (Efectivo, Fiado, Merma).
    *   La fotografía inmutable de los productos (PLU, cantidad, precio en ese instante temporal).
4. **Desacoplamiento para Futura Facturación Fiscal:** El modelo de datos del ticket DEBE construirse aislando sus propiedades operativas de las fiscales. Si en el futuro el negocio requiere expedir facturas oficiales (ej. DIAN, SAT, AFIP), el módulo de facturación se construirá como un servicio externo que "escucha" la emisión de un ticket, toma sus datos y expide la factura. El POS TIENE PROHIBIDO acoplarse directamente a validaciones fiscales o detener una venta si el servidor fiscal externo no responde.
5. **Prefijo Configurable:** Para facilitar la lectura humana, el número secuencial del ticket DEBE estar precedido por un prefijo alfanumérico configurable (ej. "TK-0001", "POS-0001").

---

## Casos de Uso

**Caso A: Generación de Ticket en Venta Regular**
- **Actor:** Sistema (Servidor Backend)
- **Precondición:** El cajero ha procesado y confirmado el checkout de un carrito en el POS.
- **Flujo Principal:**
  1. El servidor recibe el payload del carrito.
  2. El servidor genera el siguiente número secuencial asegurando integridad transaccional (evitando race conditions).
  3. El servidor ancla el `session_id`, el `cajero_id` y el timestamp.
  4. El servidor guarda la venta y retorna al POS la cabecera del ticket junto con el **desglose completo de productos (ítems, cantidades y precios fotográficos)**.
  5. El POS muestra el comprobante y la lista de productos al cliente.
- **Flujo Alternativo:** Si hay un error de conexión, el POS entra en modo offline. Al reconectar, el servidor asignará los números secuenciales definitivos en el orden en que reciba las transacciones.

**Caso B: Auditoría de Ticket Anulado**
- **Actor:** Administrador
- **Precondición:** Una venta ha sido anulada.
- **Flujo Principal:**
  1. El administrador busca el ticket `TK-1045`.
  2. El sistema muestra el ticket con su contenido original (**incluyendo la lista de productos vendidos**), pero con una marca de agua o estado visual prominente de "ANULADO".
  3. El ticket retiene y muestra el historial: quién lo emitió originalmente y quién/cuándo ejecutó la anulación.
- **Postcondición:** El número `TK-1045` y su lista de productos siguen existiendo en el sistema para fines de auditoría.

---

## Criterios de Aceptación
- [ ] **CA-FRD-007-02-01:** La base de datos debe aplicar restricciones (constraints o secuencias) que impidan la creación de dos tickets con el mismo número bajo la misma tienda.
- [ ] **CA-FRD-007-02-02:** Una operación `DELETE` sobre la tabla de tickets debe estar explícitamente bloqueada (RLS o Triggers) para cualquier rol, incluyendo administradores.
- [ ] **CA-FRD-007-02-03:** El sistema debe componer el número visual del ticket concatenando el parámetro `P_TICKET_PREFIX` con el número secuencial de la base de datos.
- [ ] **CA-FRD-007-02-04:** Todo intento de insertar un ticket sin un `session_id` válido y activo debe ser rechazado por la base de datos.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| El registro de ventas | Reemplazar generación de identificador único/aleatorio del ticket por una secuencia segura administrada centralizadamente. Asegurar regla de inmutabilidad. |
| Módulo Configuración | Agregar parámetro `P_TICKET_PREFIX` al diccionario y UI. |
| Vistas de Historial | Asegurar que los tickets anulados sigan siendo visibles con su estado correspondiente, sin desaparecer del listado secuencial. |
