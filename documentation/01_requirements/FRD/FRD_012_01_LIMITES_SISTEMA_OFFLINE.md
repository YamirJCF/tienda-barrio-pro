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

### RN-OFF-04: Inmutabilidad Histórica y Fallos Técnicos (DLQ)
Una venta realizada offline bajo las reglas locales de ese momento es un **hecho histórico inmutable** (*POL-AUD-01*). 
- El servidor **TIENE PROHIBIDO** rechazar la sincronización de una venta offline por motivos de lógica de negocio que hayan cambiado durante el apagón (ej. si el Administrador "eliminó" el producto o si el stock en el servidor llegó a cero). El POS ya hizo su validación de seguridad local en el momento de la venta.
- Si una venta falla al sincronizarse, **DEBE** ser estrictamente por **fallos técnicos** (ej. timeout de red persistente, error 500 del servidor, fallos criptográficos).
- El sistema reintentará 3 veces ante fallos técnicos. Tras 3 fallos, la venta se mueve a la Cola de Letras Muertas (DLQ).
- En la DLQ, el administrador puede **Reintentar** o **Eliminar** (solo en caso de pruebas o ventas fantasma comprobadas), pero el sistema asume que la venta es legítima.

### RN-OFF-05: Resiliencia ante Cambios de Esquema (Bandeja de Intervención)
Si durante el apagón el Administrador cambió reglas estructurales en el servidor (ej. borró una columna obligatoria o cambió el tipo de dato) provocando incompatibilidad (*Schema Drift*):
- El sistema interceptor DEBE detectar la incompatibilidad antes de enviarla para evitar errores de base de datos.
- La transacción incompatible **NO SE INVALIDA ni se considera "errónea"** (la información de la venta sigue siendo un hecho real). 
- En lugar de rechazarla, el sistema la mueve a una "Bandeja de Intervención Técnica" (DLQ). Allí esperará hasta que el sistema se actualice o un administrador resuelva la incompatibilidad estructural, garantizando que el historial de la venta no se pierda.

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

**Caso B: Venta atascada por fallo técnico o de esquema**
- **Actor:** Sistema / Servidor.
- **Flujo Principal:**
  1. El internet regresa. La cola envía la `Venta A`.
  2. El servidor responde con un Error 500 temporal o el Interceptor detecta *Schema Drift*.
  3. El sistema reintenta 3 veces (si es error de red) y falla.
  4. La `Venta A` se mueve a la cola DLQ (Bandeja de Intervención).
  5. El sistema notifica al administrador: "X ventas requieren revisión técnica para sincronizarse".
  6. El administrador revisa la DLQ. La información de la venta sigue intacta. Tras solucionar el problema de red o esquema, presiona "Reintentar".

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| Gestor de cola de sincronización | Consolidación de descarte de movimientos de inventario (ya implementado). Definición clara del límite máximo. |
| DLQ UI | Simplificación de la interfaz a "Reintentar / Eliminar", descartando requerimientos complejos de "Ajuste forzoso offline". |

---

## Criterios de Aceptación
- [ ] **CA-OFF-01:** Intentar ejecutar un ajuste manual de inventario sin internet resulta en un bloqueo UI y no genera un registro en IndexedDB.
- [ ] **CA-OFF-02:** Alcanzar el límite de la cola bloquea el botón de cobrar en el POS offline.
- [ ] **CA-OFF-03:** Las ventas fallidas van a DLQ tras 3 reintentos y solo pueden ser reintentadas o eliminadas.
