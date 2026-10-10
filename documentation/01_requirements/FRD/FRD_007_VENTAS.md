# FRD-007: Sistema de Ventas (Módulo Primario)

### Nombre de la Funcionalidad
Punto de Venta (POS) y Procesamiento de Transacciones

#### Descripción
Sistema central de ventas que permite registrar transacciones comerciales, gestionar el carrito de compras, procesar múltiples métodos de pago y mantener sincronización con el servidor incluso sin conexión.

---

## Reglas de Negocio

> [!IMPORTANT]
> **Políticas Globales Obligatorias:**
> Este módulo DEBE cumplir las siguientes especificaciones técnicas:
> - [SPEC-010: Política de Redondeo](../TECH_SPECS/rounding-policy.md)
> - [SPEC-011: Estándar de Decimales](../TECH_SPECS/decimal-format-standard.md)

### Políticas de Redondeo y Formato

Este módulo cumple las políticas globales de redondeo y formato decimal:

- **Subtotal de productos pesables:** Se redondea al múltiplo de $50 al agregar al carrito.
- **Total de venta:** Es la suma de subtotales (ya redondeados).
- **Vueltas (cambio):** Se redondean con algoritmo híbrido (empate hacia abajo).
- **Montos:** Se muestran sin decimales, con separador de miles.
- **Cantidades unitarias:** Sin decimales.
- **Cantidades por peso:** Máximo 2 decimales.

**Campo de Auditoría:** Cada venta almacena la diferencia entre el total exacto y el total redondeado para trazabilidad fiscal.

---

### Precondiciones para Vender

El POS está **BLOQUEADO** y muestra mensaje si:

| Condición | Mensaje | Acción Disponible |
|-----------|---------|-------------------|
| Caja cerrada | "Para vender, primero abre la caja" | Ir a abrir caja |
| Inventario vacío | "Agrega productos antes de vender" | Crear producto |
| Sin permiso de venta | "No tienes permiso para vender" | Volver |

---

### Límites del Carrito

| Parámetro | Valor | Comportamiento al Exceder |
|-----------|-------|---------------------------|
| Máximo items por venta | 50 | Mensaje: "Máximo 50 productos. Procesa esta venta y crea una nueva." |
| Stock disponible | Según inventario | Mensaje: "Stock insuficiente. Disponible: X." (No agrega al carrito) |

---

### Métodos de Pago

| Método | Requisitos | Notas |
|--------|------------|-------|
| **Efectivo** | Monto recibido ≥ Total | Sistema calcula vueltas |
| **Nequi/Daviplata** | Ninguno (confianza) | Referencia opcional (últimos 4 dígitos) |
| **Fiado (Crédito)** | Cliente registrado en sistema | Ver FRD-009 para reglas de cupo |

---

### Matriz de Permisos

| Acción | Admin | Empleado con `canSell` | Empleado sin `canSell` |
|--------|-------|------------------------|------------------------|
| Acceder al POS | ✅ | ✅ | ❌ (Bloqueado) |
| Agregar items al carrito | ✅ | ✅ | ❌ |
| Procesar venta Efectivo/Nequi | ✅ | ✅ | ❌ |
| Procesar venta Fiado | ✅ | ✅ | ❌ |
| Ver historial de ventas del turno activo | ✅ | ✅ | ❌ |
| Consultar historial de ventas de turnos anteriores | ✅ | ❌ | ❌ |
| **Anular venta** | ✅ | ❌ | ❌ |

---

### Sincronización sin Conexión

- **Con conexión:** La venta se procesa inmediatamente en el servidor.
- **Sin conexión:** La venta se almacena localmente y se sincroniza cuando hay conexión.
- **Estado de Sincronización:** Cada venta tiene estado: sincronizado, pendiente, o fallido.

---

### Búsqueda Inteligente en el POS (Campo Unificado)

El POS DEBE ofrecer un único campo de entrada que acepte tanto el código PLU como el nombre del producto. El sistema DEBE distinguir automáticamente el tipo de entrada antes de ejecutar la consulta.

1. **Campo Único de Entrada:** El POS DEBE utilizar un solo campo de búsqueda para localizar productos. NO DEBE existir un campo separado para PLU y otro para nombre. El cajero escribe en el mismo lugar independientemente de si ingresa un código o un nombre.
2. **Detección Automática del Tipo de Entrada:** El sistema DEBE analizar el contenido ingresado para determinar la estrategia de búsqueda:
   - Si la entrada es **exclusivamente numérica**, el sistema DEBE ejecutar una búsqueda de coincidencia exacta por PLU (comportamiento definido en FRD-006-03, Regla 6).
   - Si la entrada contiene **al menos un carácter alfabético**, el sistema DEBE ejecutar una búsqueda parcial por nombre de producto (insensible a mayúsculas/minúsculas).
3. **Mínimo de Caracteres para Búsqueda por Nombre:** La búsqueda parcial por nombre DEBE activarse a partir de 2 caracteres alfabéticos ingresados. Con menos de 2 caracteres, el sistema NO DEBE ejecutar consultas ni mostrar sugerencias de nombre.
4. **Resultados Desplegables:** Cuando la búsqueda es por nombre, el sistema DEBE mostrar un listado desplegable de coincidencias. Cada resultado DEBE mostrar: nombre del producto, PLU (si existe), precio de venta vigente y stock disponible.
5. **Carga Progresiva de Resultados:** El listado desplegable DEBE mostrar inicialmente un máximo de 10 coincidencias. Si existen más resultados, el sistema DEBE permitir al usuario cargar manualmente las siguientes coincidencias (ej: botón "Cargar más" o desplazamiento al final de la lista). El sistema DEBE priorizar la fluidez de la interfaz, evitando sobrecargar la pantalla con datos innecesarios. La consulta inicial al servidor DEBE limitarse a los primeros 10 resultados, cargando los siguientes bajo demanda.
6. **Selección Directa:** Al seleccionar un producto del listado, el sistema DEBE agregarlo directamente al carrito de la venta en curso con cantidad 1, sin requerir confirmaciones adicionales — idéntico al comportamiento de ingreso por PLU (Caso A).
7. **Solo Productos Activos con Stock:** La búsqueda por nombre en el POS DEBE retornar exclusivamente productos en estado activo con stock disponible mayor a 0.

---

### Historial de Ventas: Búsqueda y Filtros

El historial de ventas corresponde al dominio Ventas del Evidence Hub (FRD-005) y DEBE permitir localizar una venta sin recorrer la lista completa.

1. **Alcance por Rol:** El empleado con permiso de venta consulta únicamente las ventas del turno activo. El Admin consulta cualquier período mediante el filtro temporal de FRD-005 (Regla 6), con los últimos 7 días por defecto.
2. **Búsqueda por Número de Ticket:** El historial DEBE permitir buscar una venta por su número de ticket con coincidencia exacta, aceptando el número con o sin el prefijo configurado (`P_TICKET_PREFIX`, FRD-007-02). Mientras haya un número de ticket ingresado, la búsqueda ignora los demás filtros, para que un filtro activo no oculte el ticket buscado.
3. **Filtro por Método de Pago:** Todos, Efectivo, Nequi, Llave BRE y Fiado. Los canales corresponden a FRD-004 Caja Estricta Multicanal.
4. **Filtro por Estado:** Todas, Activas y Anuladas. Por defecto se muestran todas; las ventas anuladas permanecen visibles con una marca de estado prominente (FRD-007-02).
5. **Contenido de Cada Fila:** Número de ticket, hora, total, método de pago, empleado que registró y cliente cuando el método es Fiado.
6. **Orden y Carga:** Orden cronológico descendente (más reciente primero), con carga progresiva según FRD-006 (Estrategia de Paginación para Listados Extensos).
7. **Combinación:** Los filtros de método de pago, estado y rango de fechas DEBEN poder combinarse simultáneamente.
8. **Resultado Vacío:** Si no hay coincidencias, el sistema DEBE indicar qué se buscó (ticket o filtros aplicados) y nunca mostrar una lista en blanco sin aviso.

---

### Anulación de Ventas: Reversión Contable y Temporalidad

La anulación de una venta es una operación correctiva excepcional reservada al Administrador. Restablece el inventario y revierte los efectos financieros sin violar la inmutabilidad histórica.

> [!NOTE]
> **Límite Funcional (Anulación vs Reembolso):**
> La *Anulación* (este caso) se usa **estrictamente para invalidar el ticket completo** (ej. errores de digitación del cajero, o el cliente se arrepiente antes de salir). Todo el stock vuelve al inventario. Si el cliente devuelve un ítem específico después de la compra (ej. producto dañado, garantía), NO se usa Anulación; se DEBE usar el **Gestor de Reembolsos** (FRD-006-02).

1. **Reversión Financiera según Método de Pago:**
   - **Ventas de Contado (Efectivo, Nequi, Llave BRE):** La anulación genera un contra-movimiento de egreso en el turno de caja activo, clasificado con el tipo `ANULACION_VENTA`. El canal de egreso sugerido por defecto es el canal original de la venta.
   - **Validación de Fondos y Canal Alternativo:** El servidor DEBE validar que el canal de egreso posea fondos suficientes en el turno activo (FRD-027, Regla 3). Si los fondos no alcanzan, el Admin DEBE poder seleccionar un canal alternativo de salida real (ej. Efectivo). El sistema registra tanto el canal de venta original como el canal de salida para trazabilidad completa.
   - **Ventas a Crédito (Fiado):** La anulación de una venta fiada TIENE PROHIBIDO generar egresos monetarios en la caja (POL-FIN-01 y POL-FIN-03). En su lugar, el sistema revierte automáticamente el valor del cargo en la cuenta del cliente (FRD-024), descontando la deuda pendiente.
2. **Inmutabilidad de Turnos Cerrados (POL-AUD-01):**
   - Si la venta anulada pertenece a un turno anterior ya cerrado, dicho turno permanece inalterable y sellado. Sus arqueos, reportes y métricas históricas NO se modifican.
   - Toda anulación de venta de contado EXIGE un turno de caja abierto y activo. El contra-movimiento de egreso se imputa al `session_id` del turno activo en el que se ejecuta la operación física de devolver el dinero.
   - Si la caja se encuentra cerrada, el sistema DEBE bloquear la anulación de ventas de contado instruyendo al usuario a abrir caja.
3. **Reversión Logística de Stock y Mermas:**
   - Cada producto contenido en el ticket anulado retorna al stock disponible del inventario mediante un movimiento de entrada por reversión atómico.
   - *Nota de Proceso:* Si la anulación obedece a un producto dañado en toda la compra, el usuario debe primero anular la venta (todo vuelve a stock) y posteriormente usar el módulo de Inventario para asentar una "Salida por Merma" (FRD-006-01-02).
4. **Metadatos y Auditoría Inviolable (POL-AUD-02):**
   - El ticket original permanece en el sistema con estado `ANULADO`.
   - Se registran de forma inmutable: fecha y hora de anulación, usuario Admin responsable, motivo obligatorio (`void_reason`), turno en que se anula (`void_session_id`), canal de egreso monetario (si aplica) y referencia al ticket original.

---

## Flujo de Venta

1. Usuario en POS ingresa PLU con teclado numérico o busca por nombre
2. Producto encontrado → Se agrega al carrito
3. Subtotales se calculan con redondeo aplicado
4. Stock se valida en cada agregado
5. Usuario pulsa "COBRAR" → Se abre modal de checkout
6. Usuario selecciona método de pago:
   - Efectivo → Ingresa monto recibido → Ve vueltas
   - Nequi → Confirma directamente
   - Fiado → Selecciona cliente → Sistema valida cupo
7. Usuario confirma → Venta procesada
8. Stock descontado, carrito limpiado
9. Mensaje: "Venta registrada. Ticket #XXX"

---

## Casos de Uso

**Caso A: Venta Rápida por PLU**
- **Actor:** Empleado con permiso de venta
- **Precondición:** Caja abierta, producto existente.
- **Flujo Principal:**
    1. Digita PLU en teclado numérico.
    2. Sistema encuentra producto.
    3. Pulsa "Agregar" → Item aparece en carrito.
    4. Pulsa "Cobrar" → Modal de checkout.
    5. Selecciona "Efectivo" → Ingresa monto recibido.
    6. Sistema calcula y muestra vueltas.
    7. Confirma → Venta procesada.
- **Postcondición:** Venta registrada, stock descontado, ticket generado.

**Caso B: Venta a Crédito (Fiado)**
- **Actor:** Empleado con permiso de venta
- **Precondición:** Caja abierta, cliente registrado.
- **Flujo Principal:**
    1. Agrega items al carrito.
    2. Pulsa "Cobrar" → Selecciona "Fiado".
    3. Busca cliente por nombre o identificación.
    4. Sistema muestra: "Crédito disponible: $X / Límite: $Y".
    5. Si hay cupo suficiente → Confirma.
    6. Sistema registra venta → Actualiza deuda del cliente.
- **Postcondición:** Venta registrada, deuda del cliente actualizada.

**Caso C: Anulación de Venta (Solo Admin)**
- **Actor:** Admin
- **Precondición:** Venta existe en el sistema en estado activa. Para ventas de contado, existe un turno de caja abierto.
- **Flujo Principal:**
    1. Admin navega a Historial → Ventas y localiza la venta por número de ticket o mediante filtros (ver Historial de Ventas: Búsqueda y Filtros).
    2. Selecciona venta a anular y pulsa "Anular" → Se abre modal de anulación.
    3. Si la venta fue de contado, el modal muestra el canal de devolución (canal original por defecto) y permite cambiarlo si no hay fondos. Si fue fiado, el modal indica "Reversión de cuenta de cliente (sin impacto en caja)".
    4. Admin ingresa razón obligatoria: "Error de digitación en caja" o "Cliente desistió de toda la compra".
    5. Admin confirma.
    6. Sistema valida fondos del canal (si contado), revierte stock atómicamente, genera contra-movimiento en el turno activo (o descuenta deuda en cliente si fiado) y marca el ticket como ANULADO con su huella de auditoría.
- **Flujo Alternativo (Caja Cerrada en Venta de Contado):** Si la venta a anular es de contado y no hay un turno de caja abierto, el sistema bloquea la acción informando de forma empática: "Para registrar la devolución de este dinero, primero debe abrir el turno de caja de hoy."
- **Flujo Alternativo (Fondos Insuficientes en Canal de Devolución):** Si el canal de egreso seleccionado no tiene saldo en el turno activo, el sistema muestra: "Fondos insuficientes en [canal]. Saldo actual: $X. Seleccione el canal por el que entregará el dinero." El Admin selecciona otro canal y confirma.
- **Flujo Alternativo (Venta ya Anulada):** El sistema impide re-anular una venta en estado ANULADO.
- **Postcondición:** Venta marcada como ANULADA, stock revertido en inventario, dinero devuelto asentado en el turno activo (o deuda descontada en cliente) y auditoría registrada.

**Caso D: Venta por Búsqueda de Nombre (Sin PLU Conocido)**
- **Actor:** Empleado con permiso de venta.
- **Precondición:** Caja abierta, producto existente sin PLU conocido por el cajero.
- **Flujo Principal:**
    1. Cajero no recuerda el PLU del producto.
    2. En el mismo campo de búsqueda del POS, escribe "pan" (el sistema detecta entrada alfabética).
    3. Sistema muestra listado desplegable con los primeros 10 resultados: "Pan Integral (PLU: 301) - $3,500 - Stock: 12", "Pan de Bono (PLU: 105) - $2,800 - Stock: 8", etc.
    4. Cajero selecciona "Pan Integral".
    5. Sistema agrega "Pan Integral" al carrito con cantidad 1.
    6. Cajero continúa agregando productos o procede a cobrar.
- **Postcondición:** Producto agregado al carrito sin necesidad de conocer el PLU. El campo de búsqueda se limpia para la siguiente entrada.

---

**Caso E: Localizar una Venta por Número de Ticket**
- **Actor:** Admin (cualquier período) o empleado con permiso de venta (solo turno activo).
- **Precondición:** El cliente presenta su ticket "TK-1045".
- **Flujo Principal:**
    1. Usuario abre Historial → Ventas.
    2. Escribe "1045" en el campo de búsqueda de ticket.
    3. El sistema muestra únicamente la venta TK-1045 con su estado, aunque haya otros filtros activos.
    4. Usuario abre el detalle de la venta.
    5. Si el usuario es Admin y desea anularla, continúa con el Caso C desde el paso 2.
- **Flujo Alternativo:** Si el ticket no existe dentro del alcance del usuario, el sistema muestra "No se encontró el ticket TK-1045" indicando el alcance consultado (turno activo o rango de fechas).
- **Postcondición:** Venta localizada sin recorrer el listado.

---

## Requisitos de Datos (Para Equipo Data)

**Entidad Venta:**
- Identificador único
- Número de ticket (secuencial para UI)
- Relación con Tienda
- Relación con Empleado
- Relación con Cliente (si fiado)
- Items (estructura con productos, cantidades, precios)
- Total
- Método de pago
- Monto recibido (si efectivo)
- Vueltas
- Diferencia de redondeo
- Estado de sincronización
- Estado de anulación
- Usuario que anuló (si aplica)
- Razón de anulación (si aplica)
- Turno de anulación (`void_session_id`) (si aplica)
- Canal de egreso por anulación (si aplica)
- Timestamps

---

## Criterios de Aceptación

- [ ] POS bloqueado si caja cerrada, inventario vacío o sin permiso.
- [ ] Validación de stock impide agregar items sin existencia.
- [ ] Límite de 50 items por venta con mensaje informativo.
- [ ] Redondeo a $50 aplicado en subtotales y total.
- [ ] Venta Fiado valida cupo disponible del cliente.
- [ ] Botón "Anular" solo visible para Admin.
- [ ] Ventas sin conexión se almacenan y sincronizan automáticamente.
- [ ] Cada venta genera número de ticket secuencial.
- [ ] La diferencia de redondeo se registra en cada venta.
- [ ] El POS utiliza un único campo de búsqueda que acepta tanto PLU (numérico, coincidencia exacta) como nombre de producto (alfabético, coincidencia parcial).
- [ ] La búsqueda por nombre muestra coincidencias parciales a partir de 2 caracteres, con nombre, PLU, precio y stock en cada resultado, cargando los primeros 10 y permitiendo cargar más bajo demanda.
- [ ] El historial de ventas permite buscar por número de ticket exacto, con o sin prefijo, y esa búsqueda ignora los demás filtros activos.
- [ ] El historial ofrece filtros por método de pago (Todos, Efectivo, Nequi, Llave BRE, Fiado) y por estado (Todas, Activas, Anuladas), combinables entre sí.
- [ ] El empleado con permiso de venta solo consulta ventas del turno activo; el Admin consulta cualquier período con el filtro temporal de FRD-005.
- [ ] Las ventas anuladas siguen visibles con marca de estado, y una búsqueda sin coincidencias informa qué se buscó.
- [ ] La anulación de una venta de contado genera un contra-movimiento de egreso tipificado como ANULACION_VENTA en el turno activo, con validación de fondos por canal y opción de canal alternativo si no alcanzan.
- [ ] La anulación de una venta a crédito (fiado) descuenta la deuda en la cuenta del cliente y PROHIBE generar egresos monetarios en la caja.
- [ ] La anulación de ventas de turnos cerrados preserva la inmutabilidad del turno cerrado, imputando el egreso monetario exclusivamente al turno activo actual.
- [ ] El sistema bloquea la anulación de ventas de contado si no existe un turno de caja activo, con un mensaje instructivo para abrir caja.
