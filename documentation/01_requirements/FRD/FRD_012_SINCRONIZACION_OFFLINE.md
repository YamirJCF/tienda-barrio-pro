 # FRD-012: Sincronización y Resolución de Conflictos Offline

> **Módulo:** Ventas / Sincronización  
> **Versión:** 1.0  
> **Fecha:** 2026-01-27  
> **Estado:** Aprobado

---

## Descripción

El sistema DEBE sincronizar las ventas realizadas en modo offline cuando se restablezca la conexión. Este documento define:
1. Cómo detectar conflictos entre el estado local y el servidor
2. Cómo resolver cada tipo de conflicto
3. Las opciones que tiene el usuario para corregir ventas rechazadas

**Principio rector:** El sistema registra todo fielmente; la resolución de conflictos es responsabilidad humana con herramientas adecuadas.

---

## Contexto

- **Dispositivos simultáneos:** Hasta 6 (5 empleados + 1 Admin)
- **Operaciones offline:** Solo ventas POS
- **Filosofía:** El sistema es un registro fiel; los conflictos de negocio los resuelve el tendero

---

## Reglas de Negocio

### RN-012-01: Marcado de Ventas Offline

Toda venta realizada sin conexión DEBE marcarse con:
1. Un indicador de "creada sin conexión" al momento de crearla localmente
2. La fecha de sincronización DEBE permanecer vacía hasta que se sincronice exitosamente
3. Al sincronizar, el sistema DEBE establecer la fecha/hora de sincronización

### RN-012-02: Validación Local de Stock

El sistema DEBE mantener una copia local del inventario para validar ventas offline:
1. Al iniciar sesión o al abrir caja, el sistema DEBE descargar el inventario actual
2. Cada venta offline DEBE decrementar el stock en la copia local
3. El sistema NO DEBE permitir ventas que excedan el stock en la copia local
4. Si al sincronizar el stock real es menor que lo vendido, la venta se marca como "conflicto de stock"

### RN-012-03: Conflicto de Stock al Sincronizar

Si una venta offline excede el stock real al sincronizar:
1. El sistema DEBE rechazar la venta inicialmente
2. El sistema NUNCA permite stock negativo automáticamente
3. El sistema DEBE marcar la venta como "pendiente de resolución"
4. El sistema DEBE alertar inmediatamente: "La venta #X tiene conflicto de stock en [producto]"
5. El usuario DEBE elegir una de las opciones de resolución (ver RN-012-09)

> **Justificación:** En un espacio de trabajo único, el control físico del inventario es visible para todos. Los conflictos requieren decisión humana, no automatización.

### RN-012-09: Opciones de Resolución de Conflictos

Cuando una venta es rechazada por conflicto de stock, el usuario DEBE tener tres opciones:

| Opción | Descripción | Cuándo usar |
|--------|-------------|------------|
| **A) Eliminar venta** | Borrar el registro local | El producto nunca se vendió realmente |
| **B) Ajustar cantidad** | Modificar la cantidad vendida | Se vendió menos de lo intentado |
| **C) Forzar con ajuste de inventario** | Aceptar venta + crear ajuste automático | La venta SÍ ocurrió, el inventario estaba mal |

**Opción C - Detalle:**
1. Solo el Admin puede ejecutar esta opción
2. Al confirmar, el sistema DEBE crear un "Ajuste de Inventario" automático
3. El ajuste DEBE tener motivo: "Corrección por venta offline #X"
4. La venta se registra con la cantidad original
5. El stock queda en cero (no negativo)

### RN-012-04: Conflicto de Precio

Si el precio de un producto cambió mientras el empleado estaba offline:
1. El sistema DEBE aceptar la venta al precio con el que se realizó
2. El sistema NO rechaza ventas por diferencia de precio
3. Es responsabilidad del Admin gestionar la diferencia si lo considera necesario

### RN-012-05: Conflicto de Límite de Crédito

Si una venta a crédito offline excede el límite del cliente al sincronizar:
1. El sistema DEBE rechazar la venta al sincronizar
2. El sistema DEBE notificar al empleado: "La venta a crédito #X fue rechazada: cliente excede límite"
3. El sistema DEBE marcar la venta como "rechazada por límite de crédito"
4. El empleado DEBE gestionar la situación con el cliente (cobrar diferencia, cancelar fiado)

### RN-012-06: Ventas con Caja Cerrada

Si el Admin cerró la caja mientras el empleado vendía offline:
1. El sistema DEBE aceptar las ventas realizadas offline
2. Las ventas se asocian al período de caja que estaba abierto cuando se crearon localmente
3. El reporte de caja DEBE actualizar sus totales con las ventas sincronizadas
4. Es responsabilidad del Admin reconciliar la diferencia

### RN-012-07: Orden de Sincronización

Al restablecerse la conexión, el sistema DEBE sincronizar en este orden:
1. Ventas completadas (de más antigua a más reciente)
2. Ajustes de inventario pendientes
3. Actualizaciones de clientes

### RN-012-08: Reintentos de Sincronización

Si una venta falla al sincronizar:
1. El sistema DEBE reintentar automáticamente hasta 3 veces
2. Si falla 3 veces, DEBE marcar la venta como "error de sincronización"
3. El sistema DEBE mostrar al usuario las ventas con error
4. El usuario puede reintentar manualmente o eliminar la venta

---

## Casos de Uso

### Caso A: Sincronización Exitosa

- **Actor:** Sistema
- **Precondición:** Conexión restablecida, ventas offline pendientes
- **Flujo Principal:**
    1. Sistema detecta conexión
    2. Sistema obtiene lista de ventas pendientes (ordenadas por fecha)
    3. Sistema envía cada venta al servidor
    4. Servidor valida y registra la venta
    5. Sistema marca la venta como sincronizada con fecha/hora
    6. Sistema notifica: "X ventas sincronizadas"
- **Postcondición:** Todas las ventas sincronizadas, fecha de sincronización registrada

### Caso B: Conflicto de Stock - Resolución

- **Actor:** Empleado / Admin
- **Precondición:** Venta offline rechazada por stock insuficiente
- **Flujo Principal:**
    1. Sistema muestra venta en "Cola de Resolución"
    2. Usuario ve detalles: producto, cantidad intentada, stock real
    3. Usuario elige opción de resolución:
       - **Opción A:** Eliminar venta → Registro borrado
       - **Opción B:** Ajustar cantidad → Venta modificada y sincronizada
       - **Opción C:** Forzar (solo Admin) → Venta aceptada + Ajuste de inventario creado
    4. Sistema procesa la opción elegida
    5. Venta sale de la cola de resolución
- **Postcondición:** Conflicto resuelto según decisión del usuario

### Caso C: Crédito Rechazado

- **Actor:** Sistema
- **Precondición:** Venta a crédito offline pendiente
- **Flujo Principal:**
    1. Sistema envía venta al servidor
    2. Servidor valida límite de crédito actual
    3. Cliente excede límite
    4. Servidor rechaza la venta
    5. Sistema marca venta como "rechazada"
    6. Sistema notifica al empleado
    7. Empleado gestiona con el cliente
- **Postcondición:** Venta NO registrada en servidor, marcada localmente como rechazada

### Caso D: Sincronización con Caja Cerrada

- **Actor:** Sistema
- **Precondición:** Ventas offline de caja ya cerrada
- **Flujo Principal:**
    1. Sistema detecta conexión
    2. Sistema envía ventas offline
    3. Servidor asocia ventas al período de caja original
    4. Servidor actualiza totales del cierre de caja
    5. Sistema notifica a Admin: "El cierre de caja X fue actualizado con ventas tardías"
- **Postcondición:** Caja reconciliada automáticamente

### Caso E: Forzar Venta con Ajuste de Inventario

- **Actor:** Admin
- **Precondición:** Venta en cola de resolución por conflicto de stock
- **Flujo Principal:**
    1. Admin revisa la venta conflictiva
    2. Admin confirma: "La venta sí ocurrió, el inventario estaba desactualizado"
    3. Admin selecciona "Forzar con ajuste"
    4. Sistema crea Ajuste de Inventario automático
    5. Sistema registra la venta con cantidad original
    6. Sistema actualiza stock a cero (no negativo)
    7. Sistema notifica: "Venta registrada, ajuste de inventario creado"
- **Postcondición:** Venta registrada, inventario corregido, auditoría limpia

---

### Marcado
- [ ] Ventas offline tienen indicador de "creada sin conexión"
- [ ] La fecha de sincronización permanece vacía hasta sincronizar
- [ ] La fecha de sincronización se registra al completar sincronización

### Validación Local
- [ ] Inventario se descarga al iniciar sesión
- [ ] Ventas offline decrementan copia local
- [ ] No se permite vender más del stock en copia local

### Conflictos y Resolución
- [ ] Stock insuficiente abre cola de resolución
- [ ] Usuario puede elegir: Eliminar / Ajustar / Forzar
- [ ] Opción "Forzar" solo disponible para Admin
- [ ] Forzar crea ajuste de inventario automático
- [ ] Precio anterior es aceptado sin notificación
- [ ] Crédito excedido es rechazado con notificación
- [ ] Ventas con caja cerrada son aceptadas

### Sincronización
- [ ] Ventas se sincronizan en orden cronológico
- [ ] Reintentos automáticos (máximo 3)
- [ ] Ventas fallidas son visibles al usuario

### Notificaciones
- [ ] Empleado recibe alerta inmediata de stock rechazado
- [ ] Empleado recibe notificación de crédito rechazado
- [ ] Admin recibe notificación de caja actualizada tardíamente

## Requisitos de Datos (Para Equipo Data)

### Campos requeridos en el registro de ventas

El sistema requiere almacenar la siguiente información en cada venta:

| Información | Descripción |
|-------------|-------------|
| Indicador de creación offline | Distinguir si la venta se creó sin conexión |
| Fecha de sincronización | Cuándo se sincronizó con el servidor (vacía si pendiente) |
| Estado de sincronización | Pendiente, sincronizada, en conflicto, rechazada, error |
| Tipo de conflicto | Stock o crédito (si aplica) |
| Tipo de resolución | Eliminada, ajustada o forzada (si aplica) |
| Usuario que resolvió | Quién tomó la decisión de resolución |
| Fecha de resolución | Cuándo se resolvió el conflicto |

### Ajuste de Inventario Automático

Cuando se usa la opción "Forzar con ajuste", el sistema DEBE crear un registro de ajuste de inventario con:
- Tipo de ajuste: corrección
- Motivo: referencia a la venta offline que lo originó
- Usuario responsable: el Admin que ejecutó la acción
- Cantidad: diferencia entre stock registrado y cantidad vendida

### Políticas de Sincronización

1. El servidor NUNCA acepta ventas que causen stock negativo automáticamente
2. Los conflictos van a cola de resolución
3. Solo Admin puede forzar ventas con ajuste
4. Toda resolución queda auditada

---

## Trazabilidad

| Documento | Referencia |
|-----------|------------|
| FRD_007 | Ventas - Proceso principal |
| FRD_009 | Clientes - Límite de crédito |
| FRD_004 | Control de Caja - Cierre y reconciliación |
| FRD_011 | Manejo de Errores - Modo offline |
| SYSTEM_BOUNDARIES | Límites de funcionalidad offline |
