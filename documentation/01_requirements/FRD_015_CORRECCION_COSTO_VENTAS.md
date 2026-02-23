# Documento de Requisitos Funcionales (FRD)

## 015. Habilitación de Analytics (Corrección de Costos en Ventas)

### Evaluación Estratégica y Propuesta de Valor

**Contexto del Problema:**
Actualmente, el sistema Point of Sale (POS) registra todas las ventas correctamente a nivel de ingresos (precio de venta), pero el RPC central (`rpc_procesar_venta_v2`) tiene una omisión estructural: inserta las líneas de venta (`sale_items`) sin registrar el costo unitario de la mercancía (`unit_cost`), recurriendo por defecto a `0`.

**Análisis de Costo-Beneficio Económico:**
*   **El Costo de no hacer nada (Pérdida de Valor):** Si cada venta se registra con un costo de $0, el tendero recibe el mensaje: "Tus ventas fueron $500k y tu ganancia fue $500k (margen del 100%)". Esta información no solo es falsa, sino que destruye la credibilidad del módulo futuro de Analytics. El tendero no podrá confiar en informes financieros.
*   **El "Puente Roto" Financiero:** El sistema ya incurre en el alto costo computacional de ejecutar la lógica del método FIFO (restar unidades por lote). Sin embargo, al final de este proceso complejo, el costo deducido no se asocia al ítem vendido. Es un desperdicio de recursos (procesamos FIFO pero no guardamos el resultado clave).
*   **Inversión vs. Retorno:** La corrección requiere la modificación de una o dos líneas de código SQL en *un único RPC*. El esfuerzo técnico es *prácticamente nulo*, mientras que el valor generado (desbloquear el "Escenario B" y el cálculo de Ganancia Bruta real) es masivo.

**Conclusión de Arquitectura:**
Esta corrección no es una mejora ("nice to have"), es un **bloqueante estructural prioritario** antes de poder diseñar cualquier tipo de visualización analítica de ganancias.

---

### Descripción

Corrección del procedimiento almacenado de procesamiento de ventas para asegurar que el costo base del producto (`cost_price` de la tabla `products`) sea capturado e insertado en la columna `unit_cost` de la tabla `sale_items` al momento de cada transacción.

### Reglas de Negocio
1. **Inmutabilidad Histórica del Costo**: El costo insertado en `sale_items` debe reflejar el costo real conocido en el preciso instante en que se efectuó la venta, haciendo que los reportes financieros sean resistentes a futuros cambios de precios por inflación.
2. **Precedencia de FIFO (Iteración a Futuro)**: En esta primera iteración, el sistema debe registrar al menos el costo estándar (`products.cost_price`). En una segunda iteración más avanzada, el RPC debería ser reescrito para leer y fraccionar la venta, promediando con exactitud los `cost_unit` obtenidos de los lotes FIFO procesados. Por simplicidad, tomaremos temporalmente `products.cost_price` mientras refactorizamos a fondo la recursividad FIFO.

### Casos de Uso
- **Actor:** Tendero / Empleado (Manejando Punto de Venta)
- **Precondición:** El producto tiene registrado un `cost_price` mayor a cero.
- **Flujo Principal:**
  1. El empleado escanea o agrega productos al carrito.
  2. El empleado completa el proceso de pago.
  3. El POS llama a `rpc_procesar_venta_v2`.
  4. El sistema lee el campo `cost_price` de la tabla `products` para cada ítem.
  5. El sistema inserta ese valor en `sale_items.unit_cost`.
- **Flujo Alternativo:** Si el `cost_price` del producto es $0 (o nulo), el sistema inserta $0 sin interrumpir o cancelar la venta.

### Criterios de Aceptación
- [ ] Tras ejecutar una venta nueva, la base de datos registra correctamente el valor en `sale_items.unit_cost`.
- [ ] El cambio no rompe la lógica existente de validación de cajón abierto, fiado ni descuadre de inventario FIFO.

---

## Lista de Tareas de Alto Nivel
1. [ ] Crear parche/script SQL para modificar `rpc_procesar_venta_v2` e incorporar la variable `v_product_cost`.
2. [ ] Modificar el bucle de inserción en el RPC para enviar `v_product_cost` al INSERT INTO de `sale_items`.
3. [ ] Ejecutar el parche de migración a nivel de Supabase.
4. [ ] Realizar una venta de prueba (QA) para verificar integridad de datos en `sale_items`.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| Función RPC: `rpc_procesar_venta_v2` | Modificar `SELECT price INTO v_product_price...` por `SELECT price, cost_price INTO v_product_price, v_product_cost...`. <br> Modificar `INSERT INTO public.sale_items` para incluir `unit_cost`. |
