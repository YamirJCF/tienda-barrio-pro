# FRD-012-01: Acoplamiento y Límites Estrictos del Sistema Offline

### Nombre de la Funcionalidad
Delimitación Operativa y Resolución Defensiva del Modo Offline (Dead Letter Queue).

#### Descripción
El modo "Offline" del sistema no es un clon de la aplicación completa, sino un mecanismo de supervivencia de emergencia para garantizar la continuidad comercial durante apagones o cortes de red. Este documento aterriza las expectativas teóricas de la sincronización offline a la realidad arquitectónica actual (basada en `syncQueue`, `syncInterceptor` y DLQ), estableciendo reglas claras, limitando el acoplamiento y prohibiendo operaciones complejas sin conexión.

---

## Reglas de Negocio

### RN-OFF-01: Límite Transaccional Estricto (Solo Ventas)
El sistema offline está acoplado **única y exclusivamente** al flujo del Punto de Venta (POS).
- La única operación encolable en modo offline es la creación de una venta (`CREATE_SALE`).
- **Quedan terminantemente prohibidos en modo offline:** Ajustes de inventario (Mermas/Consumos), Devoluciones a proveedores, Gastos operativos y Cierres de Caja.
- Cualquier intento de encolar una operación distinta a una venta (ej. `CREATE_MOVEMENT`) DEBE ser bloqueada y destruida por la cola de sincronización para prevenir corrupciones.

### RN-OFF-02: Bloqueo en Origen (Validación Local Preventiva)
Para cumplir con la *POL-LOG-02 (Anti-Negativos)*, el modo offline es "defensivo".
- El sistema DEBE validar el carrito contra el stock descargado localmente en caché ANTES de permitir la venta offline.
- Si el stock local es insuficiente, la venta offline SE BLOQUEA INMEDIATAMENTE. No se encola para ver si "quizás en el servidor sí hay stock".

### RN-OFF-03: Límite de Encolamiento (Sobrevivencia, no autonomía)
El sistema offline no está diseñado para operar días enteros sin internet.
- Se establece un límite máximo de transacciones encoladas. Una vez alcanzado este límite, el sistema DEBE rechazar nuevas ventas hasta que se recupere la conexión y se drene la cola.
- Si la sesión de seguridad (JWT) expira y no puede ser renovada automáticamente, la cola de sincronización se DEBE detener inmediatamente (bloqueo `sync:auth_required`) hasta que el usuario se re-autentique con internet (apoyo a *POL-SEG-02*).

### RN-OFF-04: Resolución de Conflictos Simplificada (DLQ)
Cuando la conexión vuelve, el servidor procesa la cola. Si una venta falla por razones del servidor (ej. un producto fue eliminado o el stock real sí era cero):
1. El sistema DEBE reintentar automáticamente la sincronización de esa venta fallida hasta un máximo de 3 veces.
2. Tras 3 fallos, la venta DEBE ser movida a una Cola de Letras Muertas (DLQ - Dead Letter Queue).
3. **Resolución Binaria:** Las únicas acciones permitidas sobre una venta en DLQ son **Reintentar** o **Eliminar**. No existe la funcionalidad de "editar la cantidad encolada" o "forzar ajuste"; si la venta es irremediable, se elimina del dispositivo local.

### RN-OFF-05: Resiliencia ante Cambios de Esquema (Drift Detection)
Si durante el apagón el Administrador cambió reglas en el servidor (ej. borró una columna o requirió un nuevo campo obligatorio):
- El sistema interceptor DEBE detectar la incompatibilidad (*Schema Drift*).
- La transacción incompatible no se envía (para evitar errores 500) y se mueve directamente a la bandeja de ítems corruptos, previniendo que una mala transacción atasque el resto de las ventas offline legítimas.

---

## Casos de Uso

**Caso A: Empleado intenta ajustar inventario sin internet**
- **Actor:** Empleado Operativo.
- **Precondición:** Sin conexión a internet.
- **Flujo Principal:**
  1. El empleado intenta registrar una "Merma" por ruptura de producto.
  2. El sistema detecta modo offline.
  3. El sistema aborta la operación y notifica: "Las operaciones de inventario requieren conexión a internet obligatoria".
- **Postcondición:** Nada se encola.

**Caso B: Venta atascada por fallo recurrente**
- **Actor:** Sistema / Servidor.
- **Flujo Principal:**
  1. El internet regresa. La cola envía la `Venta A`.
  2. El servidor rechaza la `Venta A` (ej. cliente eliminado).
  3. El sistema reintenta 3 veces y falla.
  4. La `Venta A` se mueve a la cola DLQ.
  5. El sistema notifica al administrador: "X ventas no pudieron sincronizarse".
  6. El administrador revisa y presiona "Eliminar" sobre la venta atascada.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| `syncQueue.ts` | Consolidación del drop de `CREATE_MOVEMENT` (ya implementado). Definición clara del límite máximo. |
| DLQ UI | Simplificación de la interfaz a "Reintentar / Eliminar", descartando requerimientos complejos de "Ajuste forzoso offline". |

---

## Criterios de Aceptación
- [ ] **CA-OFF-01:** Intentar ejecutar un ajuste manual de inventario sin internet resulta en un bloqueo UI y no genera un registro en IndexedDB.
- [ ] **CA-OFF-02:** Alcanzar el límite de la cola bloquea el botón de cobrar en el POS offline.
- [ ] **CA-OFF-03:** Las ventas fallidas van a DLQ tras 3 reintentos y solo pueden ser reintentadas o eliminadas.
