# 🔍 Análisis Cruzado de Huecos Lógicos entre FRDs

**Objetivo:** Identificar vacíos funcionales donde un FRD asume, depende o implica algo que ningún otro FRD especifica explícitamente. No se proponen módulos nuevos ni funcionalidades fuera del alcance definido. Solo se buscan complementos lógicos faltantes a lo que ya existe.

**Método:** Cada hallazgo cita el FRD origen (donde se detecta el hueco) y el FRD relacionado (donde debería estar cubierto), con una descripción precisa del vacío.

---

## Resumen de Hallazgos

| # | Severidad | Dominio | Descripción corta |
|---|-----------|---------|-------------------|
| 1 | 🔴 Crítico | Inventario | Sin filtros/búsqueda en listado de inventario |
| 2 | 🔴 Crítico | Caja/Reportes | Sin filtros por fecha en historiales de caja |
| 3 | 🔴 Crítico | Cuentas por Pagar | Sin filtros para encontrar facturas en listado |
| 4 | 🔴 Crítico | Clientes | Sin filtros por estado de deuda en listado |
| 5 | 🟡 Alto | POS/Ventas | Sin especificación de búsqueda por nombre en POS |
| 6 | 🟡 Alto | Caja | Sin registro del canal de pago en apertura de caja |
| 7 | 🟡 Alto | Reembolsos | Sin multicanalidad en el Gestor de Reembolsos |
| 8 | 🟡 Alto | Auditoría | Sin filtros temporales en Evidence Hub centralizado |
| 9 | 🟡 Alto | Ventas/Historial | Sin filtros en historial de ventas del turno |
| 10 | 🟡 Alto | Clientes/Abonos | Sin selección de canal de pago en abonos de clientes |
| 11 | 🟡 Alto | Inventario/Kardex | Sin filtros en historial de movimientos (Kardex) |
| 12 | 🟡 Alto | Gastos | Sin categorización de gastos en el registro |
| 13 | 🟠 Medio | POS/Caja | Sin paginación en listados de alta cardinalidad |
| 14 | 🟠 Medio | Empleados | Sin filtros en listado de empleados |
| 15 | 🟠 Medio | Sesiones | Sin gestión de sesiones de empleado desde panel admin |
| 16 | 🟠 Medio | Venta Forzada | Sin registro del canal de pago en venta forzada |
| 17 | 🟠 Medio | Reportes/Caja | Sin filtro por empleado en reportes de caja |
| 18 | 🟠 Medio | Cuentas por Pagar | Sin búsqueda de proveedor reutilizable |
| 19 | 🟠 Medio | Clientes/Historial | Sin paginación en historial de transacciones del cliente |
| 20 | 🟠 Medio | Offline/DLQ | Sin indicador de cantidad de ventas pendientes de sincronización |

---

## Hallazgos Detallados

---

### HALLAZGO 1 — 🔴 Sin filtros ni búsqueda funcional en el listado de inventario

**FRD Origen:** [FRD_006_INVENTARIO](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_006_INVENTARIO.md)
**FRD Relacionado:** [FRD_006_03_CODIGO_PRODUCTO](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_006_03_CODIGO_PRODUCTO.md)

**El hueco:** FRD-006 establece que el inventario es el catálogo maestro de productos con campos como Nombre, Categoría, Stock, Stock Mínimo, PLU, Unidad de Medida, y estado Pesable. FRD-006-03 especifica la búsqueda exacta por PLU en el POS. Sin embargo, **ningún FRD especifica cómo el usuario administrador navega, filtra o busca productos dentro del módulo de Inventario** (fuera del POS).

Una tienda con 200-500 productos necesita capacidades mínimas de búsqueda y filtrado para:
- Encontrar un producto por **nombre** (búsqueda parcial)
- Filtrar por **categoría**
- Filtrar por **stock bajo** (productos con alerta activa)
- Filtrar por **estado activo/inactivo**
- Ordenar por **nombre, stock, precio**

FRD-006 Caso C menciona "Búsqueda Rápida por PLU" pero está enfocado en el POS, no en el módulo de gestión de inventario.

**Lo que falta en el FRD:**
- Regla de negocio que especifique las capacidades de filtrado y búsqueda en el listado de inventario
- Caso de uso: "Administrador busca producto por nombre parcial"
- Caso de uso: "Administrador filtra productos con stock bajo"
- Criterio de aceptación verificable

---

### HALLAZGO 2 — 🔴 Sin filtros temporales en historial de movimientos de caja

**FRD Origen:** [FRD_027_01_REPORTES_DE_CAJA](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_027_01_REPORTES_DE_CAJA.md)
**FRD Relacionado:** [FRD_021_HISTORIALES_MULTICANAL](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_021_HISTORIALES_MULTICANAL.md)

**El hueco:** FRD-027-01 establece la "Dicotomía del Reporte" con un reporte operativo (para el cajero) y un reporte de auditoría (para el dueño). FRD-021 añade filtros por canal de pago (Efectivo, Nequi, Daviplata). Sin embargo, **ninguno de estos FRDs especifica filtros temporales** para la consulta histórica.

FRD-027-01 Caso B menciona que "El propietario revisa el desempeño financiero de la semana pasada" y "extrae la auditoría interna del día martes", pero no especifica:
- Cómo selecciona el día martes (selector de fecha, calendario, lista de turnos)
- Cómo navega entre turnos cerrados (¿lista cronológica? ¿filtro por rango de fechas?)
- Cómo distingue entre turnos del mismo día si hubo múltiples aperturas/cierres

**Lo que falta en el FRD:**
- Mecanismo de selección temporal para reportes históricos de caja
- Criterio de aceptación sobre navegación entre turnos cerrados
- Regla sobre si la unidad de consulta es el "turno" o el "día"

---

### HALLAZGO 3 — 🔴 Sin filtros para localizar facturas en Cuentas por Pagar

**FRD Origen:** [FRD_019_CUENTAS_POR_PAGAR](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_019_CUENTAS_POR_PAGAR.md)

**El hueco:** FRD-019 es el FRD más extenso del sistema (20 reglas, 6 casos de uso). Define con extrema rigurosidad el comportamiento de registro, abono y pago. Sin embargo, **no especifica cómo el usuario localiza una factura específica** dentro de la lista de cuentas por pagar.

Con el tiempo, una tienda acumulará decenas o cientos de facturas (pendientes + pagadas). El FRD no establece:
- Búsqueda por nombre de proveedor
- Filtro por estado (Pendiente / Vencida / Pagada)
- Filtro por rango de fechas (creación o vencimiento)
- Ordenamiento (por monto, por antigüedad, por proveedor)

FRD-019, Regla 15 establece que el estado se calcula dinámicamente (PENDIENTE, VENCIDA, PAGADA), pero no hay caso de uso que permita al usuario filtrar la lista **por** ese estado calculado.

**Lo que falta en el FRD:**
- Regla de negocio sobre capacidades de filtrado del listado
- Caso de uso: "Administrador filtra facturas vencidas"
- Caso de uso: "Administrador busca facturas de un proveedor específico"

---

### HALLAZGO 4 — 🔴 Sin filtros por estado de deuda en listado de clientes

**FRD Origen:** [FRD_009_CLIENTES](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_009_CLIENTES.md)

**El hueco:** FRD-009 define indicadores visuales ricos (borde rojo/verde, badge "Debe"/"Al día", barra de progreso de cupo). También menciona que la búsqueda "funciona por nombre, cédula y teléfono" (criterio de aceptación). Sin embargo, **no especifica filtros funcionales** para el listado:

- Filtrar clientes que **deben dinero** (balance > 0) vs los que están al día
- Ordenar por **monto de deuda** (de mayor a menor)
- Filtrar clientes **eliminados** (soft-deleted) para auditoría

La búsqueda existe pero los filtros de estado no. Un tendero con 30+ clientes necesita ver rápidamente "¿quiénes me deben?" sin recorrer uno a uno.

**Lo que falta en el FRD:**
- Regla de negocio sobre filtros del listado de clientes
- Caso de uso: "Administrador consulta clientes con deuda pendiente"
- Criterio de aceptación sobre ordenamiento por deuda

---

### HALLAZGO 5 — 🟡 Sin especificación de búsqueda por nombre de producto en el POS

**FRD Origen:** [FRD_007_VENTAS](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_007_VENTAS.md)
**FRD Relacionado:** [FRD_006_03_CODIGO_PRODUCTO](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_006_03_CODIGO_PRODUCTO.md)

**El hueco:** FRD-007 Flujo de Venta dice: "Usuario en POS ingresa PLU con teclado numérico **o busca por nombre**". FRD-006-03 Regla 6 dice: "Las búsquedas parciales se reservan exclusivamente para el campo 'Nombre del Producto'". Sin embargo, **ningún FRD especifica el comportamiento detallado de la búsqueda por nombre en el POS**:

- ¿Cuántos caracteres mínimos antes de mostrar resultados?
- ¿Se muestra un listado desplegable con coincidencias?
- ¿Cuántos resultados máximos se muestran?
- ¿Qué se muestra en cada resultado? (nombre, precio, stock, PLU)
- ¿El cajero selecciona de la lista y se agrega al carrito directamente?

Este es un flujo de interacción primario (no todos los productos tendrán PLU asignado) y su ausencia de especificación puede generar implementaciones inconsistentes.

**Lo que falta en el FRD:**
- Caso de uso específico: "Cajero busca producto por nombre en POS"
- Reglas sobre el comportamiento de autocompletado
- Criterio de aceptación sobre la respuesta de búsqueda

---

### HALLAZGO 6 — 🟡 Sin registro del canal de pago en la base de apertura de caja

**FRD Origen:** [FRD_004_CONTROL_DE_CAJA](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_004_CONTROL_DE_CAJA.md)
**FRD Relacionado:** [FRD_004_CAJA_ESTRICTA_MULTICANAL](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_004_CAJA_ESTRICTA_MULTICANAL.md), [FRD_020_CAJA_MULTICANAL](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_020_CAJA_MULTICANAL.md)

**El hueco:** FRD-004 Caso A dice que al abrir el turno, el usuario "ingresa monto base (fondo de cambio)". FRD-004 Multicanal establece la Trinidad de Canales (Efectivo, Nequi, Llave BRE) con segregación estricta. FRD-020 exige arqueo desglosado al cierre.

**Pero ningún FRD especifica que la apertura de caja también debe registrar la base inicial por canal.** Si al cierre se exige un arqueo separado por canal (Efectivo real, Nequi real), entonces al abrir debe especificarse cuánto hay inicialmente en cada canal. De lo contrario, la fórmula de conciliación `Saldo Esperado = Base Inicial + Ingresos - Egresos` no puede calcularse por canal, solo globalmente.

**Lo que falta en el FRD:**
- Regla de negocio en FRD-004 o FRD-020 que especifique que la base de apertura debe ser multicanal
- Caso de uso: "Apertura con saldo inicial por canal"
- Ajuste a los requisitos de datos de la Entidad Sesión de Caja

---

### HALLAZGO 7 — 🟡 Sin multicanalidad en el Gestor de Reembolsos

**FRD Origen:** [FRD_006_02_GESTOR_REEMBOLSOS](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_006_02_GESTOR_REEMBOLSOS.md)
**FRD Relacionado:** [FRD_004_CAJA_ESTRICTA_MULTICANAL](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_004_CAJA_ESTRICTA_MULTICANAL.md)

**El hueco:** FRD-006-02 especifica que el reembolso genera un "Egreso (salida de efectivo)" en la sesión de caja activa. Pero asume un canal único. **No especifica por cuál canal se devuelve el dinero.**

Si un cliente compró con Nequi y devuelve el producto, ¿el reembolso sale de Efectivo o de Nequi? FRD-004 Multicanal prohíbe "prestar" saldo entre canales. El FRD-006-02 debería:

- Exigir la selección del canal de pago para el reembolso
- Aplicar validación de fondos suficientes en ese canal específico
- Si la caja en Nequi no tiene fondos suficientes para el reembolso, el Admin debe poder seleccionar otro canal

**Lo que falta en el FRD:**
- Regla de negocio sobre selección de canal en reembolso
- Criterio de aceptación sobre validación de fondos por canal
- Actualización del caso de uso para incluir selección de canal

---

### HALLAZGO 8 — 🟡 Sin filtros temporales en el Evidence Hub centralizado

**FRD Origen:** [FRD_005_AUDITORIA_TRAZABILIDAD](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_005_AUDITORIA_TRAZABILIDAD.md)

**El hueco:** FRD-005 Trazabilidad, Caso A dice: "Admin filtra por fecha y tipo de evento". El criterio de aceptación dice: "El filtro por fecha y tipo funciona correctamente". Sin embargo, **no se especifica la mecánica del filtro por fecha**:

- ¿Rango de fechas (desde-hasta)?
- ¿Selector de día específico?
- ¿Presets rápidos (hoy, ayer, última semana, último mes)?
- ¿Se filtra por fecha de creación del evento?

Esto es especialmente relevante porque FRD-005 menciona 6 dominios de auditoría (Ventas, Caja, Inventario, Seguridad, Precios, Créditos) y cada uno tendrá volúmenes distintos.

**Lo que falta en el FRD:**
- Regla de negocio sobre el tipo de filtro temporal (rango vs. día)
- Criterio de aceptación sobre presets de fecha

---

### HALLAZGO 9 — 🟡 Sin filtros en el historial de ventas del turno

**FRD Origen:** [FRD_007_VENTAS](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_007_VENTAS.md)

**El hueco:** FRD-007, Matriz de Permisos dice que Admin y empleados con `canSell` pueden "Ver historial de ventas (hoy)". Sin embargo, **no se especifica qué capacidades de consulta tiene este historial**:

- ¿Se puede buscar por número de ticket?
- ¿Se puede filtrar por método de pago (efectivo, nequi, fiado)?
- ¿Se puede filtrar por estado (activa, anulada)?
- ¿Se muestra la lista completa o paginada?

Un turno activo puede acumular 50-100 ventas. Sin filtro por ticket o método de pago, encontrar una venta específica para anularla se vuelve una tarea manual excesiva.

**Lo que falta en el FRD:**
- Regla de negocio sobre filtros del historial de ventas
- Caso de uso: "Admin busca venta por número de ticket para anularla"
- Criterio de aceptación sobre búsqueda y filtrado

---

### HALLAZGO 10 — 🟡 Sin selección de canal de pago en abonos de clientes

**FRD Origen:** [FRD_024_POLITICA_FIADOS_CLIENTES](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_024_POLITICA_FIADOS_CLIENTES.md)
**FRD Relacionado:** [FRD_009_CLIENTES](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_009_CLIENTES.md), [FRD_020_CAJA_MULTICANAL](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_020_CAJA_MULTICANAL.md)

**El hueco:** FRD-024 Regla 4 establece la "Transformación de Promesa a Liquidez" — al recibir un abono, se descuenta la deuda y se inyecta ingreso en caja. FRD-020 Regla 2 dice: "El abono DEBE registrarse en el canal correspondiente (ej. si pagó con Nequi, suma al esperado de Nequi)".

Sin embargo, **FRD-009 (que es donde se define el caso de uso de "Registrar Abono") no menciona la selección de canal de pago**. El Caso A de FRD-009 dice: "Ingresa monto $20,000" → "Sistema registra transacción tipo pago" sin pedir canal.

Hay una contradicción entre FRD-020 (que exige canal) y FRD-009 (que no lo pide). Este hueco genera ambigüedad: ¿el abono entra todo a Efectivo por defecto?

**Lo que falta en el FRD:**
- Actualización de FRD-009 Caso A para incluir selección de canal de pago
- Criterio de aceptación en FRD-009 sobre canal obligatorio en abonos
- Coherencia con FRD-020 Regla 2

---

### HALLAZGO 11 — 🟡 Sin filtros en el historial de movimientos de inventario (Kardex)

**FRD Origen:** [FRD_006_INVENTARIO](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_006_INVENTARIO.md)

**El hueco:** FRD-006 Matriz de Permisos dice que todos los roles con acceso pueden "Ver historial Kardex". Pero **no especifica las capacidades de consulta del Kardex**:

- ¿Se puede filtrar por tipo de movimiento (Entrada, Salida, Ajuste, Venta, Devolución)?
- ¿Se puede filtrar por rango de fechas?
- ¿Se puede filtrar por usuario responsable?
- ¿Está paginado?

Un producto con alta rotación acumulará cientos de movimientos. Sin filtros, el historial se vuelve inútil para auditoría operativa.

**Lo que falta en el FRD:**
- Regla de negocio sobre filtros del historial Kardex
- Caso de uso: "Admin audita movimientos de un producto en la última semana"
- Criterio de aceptación sobre filtrado por tipo y fecha

---

### HALLAZGO 12 — 🟡 Sin categorización de gastos en el registro

**FRD Origen:** [FRD_026_POLITICA_GASTOS_INMEDIATOS](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_026_POLITICA_GASTOS_INMEDIATOS.md)
**FRD Relacionado:** [FRD_018_CONTROL_OPERACIONAL](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_018_CONTROL_OPERACIONAL_Y_ANALISIS_FINANCIERO.md)

**El hueco:** FRD-026 define el gasto como un "egreso líquido inmediato" con monto y concepto. FRD-018 Pilar 1 menciona: "Categorización de gastos en tipos de OPEX: Servicios, Arriendo, Nómina/Personal, Transporte/Fletes, Mantenimiento, Merma/Deterioro".

Sin embargo, **FRD-026 (que es donde se registra el gasto) no incluye un campo de categoría OPEX**. FRD-004 Caso C dice: "Digita monto y motivo obligatorio" — el motivo es texto libre, no una categoría seleccionable.

Si FRD-018 necesita calcular el desglose de OPEX por categoría, pero el gasto se registra sin categoría, el cálculo es imposible. El dato se necesita **al momento del registro**, no después.

**Lo que falta en el FRD:**
- Regla en FRD-026 o FRD-004 sobre categorización obligatoria del gasto
- Lista de categorías OPEX predefinidas (vinculadas a FRD-018 Pilar 1)
- Criterio de aceptación: "Todo gasto registrado incluye categoría OPEX seleccionada"

---

### HALLAZGO 13 — 🟠 Sin paginación especificada en listados de alta cardinalidad

**FRD Origen:** Múltiples FRDs

**El hueco:** Ningún FRD especifica una estrategia de **paginación** para los listados que crecerán con el tiempo:

| Listado | FRD | Cardinalidad esperada |
|---------|-----|----------------------|
| Productos (Inventario) | FRD-006 | 200-500+ |
| Movimientos de inventario (Kardex) | FRD-006 | Miles |
| Ventas (Historial) | FRD-007 | 50-100/día |
| Clientes | FRD-009 | 30-100+ |
| Transacciones de cliente | FRD-009 | Decenas por cliente |
| Facturas por pagar | FRD-019 | Decenas a cientos |
| Movimientos de caja | FRD-004 | 20-50/turno |

Sin paginación (o scroll infinito, o "cargar más"), la interfaz se degradará con el tiempo.

**Lo que falta:** Regla transversal o en cada FRD sobre comportamiento de listados largos (paginación, límite por página).

---

### HALLAZGO 14 — 🟠 Sin filtros en el listado de empleados

**FRD Origen:** [FRD_003_GESTION_EMPLEADOS](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_003_GESTION_EMPLEADOS.md)

**El hueco:** FRD-003 define la entidad Empleado con estado activo/inactivo y un límite de empleados por tienda. Sin embargo, **no especifica cómo el Admin localiza empleados** si hay acumulación de empleados inactivos:

- ¿Se pueden filtrar por estado (activo/inactivo)?
- ¿Se puede buscar por nombre o alias?

Con el límite de `P_MAX_EMPLOYEES_PER_STORE` y la política de no-eliminación, los empleados inactivos se acumulan.

**Lo que falta:** Regla sobre visibilidad de empleados inactivos y búsqueda/filtro del listado.

---

### HALLAZGO 15 — 🟠 Sin visibilidad de sesiones activas para el Admin

**FRD Origen:** [FRD_013_GESTION_SESIONES](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_013_GESTION_SESIONES.md)
**FRD Relacionado:** [FRD_015_GESTION_DISPOSITIVOS](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_015_GESTION_DISPOSITIVOS.md)

**El hueco:** FRD-013 Regla 2 establece un límite de 6 sesiones simultáneas. Cuando se alcanza, el sistema rechaza nuevos logins. FRD-015 habla de "dispositivos con sesión activa" en el centro de notificaciones.

Sin embargo, **si el Admin necesita liberar una sesión para que un empleado entre**, el flujo no es claro:
- FRD-015 muestra dispositivos conectados con opción de revocar
- Pero FRD-015 solo menciona revocación de acceso (aprobación/rechazo de pases), no cierre forzado de sesión específica

FRD-013 RN-06 dice que al cerrar caja se invalidan los pases, pero eso requiere cerrar la caja entera. No hay mecanismo para que el Admin cierre una sesión individual de un empleado sin desactivar al empleado (FRD-003) ni cerrar la caja.

**Lo que falta:** Caso de uso: "Admin cierra remotamente la sesión de un empleado para liberar un slot de sesión".

---

### HALLAZGO 16 — 🟠 Sin canal de pago especificado en el flujo de Venta Forzada

**FRD Origen:** [FRD_014_VENTA_FORZADA_Y_AUDITORIA](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_014_VENTA_FORZADA_Y_AUDITORIA.md)
**FRD Relacionado:** [FRD_004_CAJA_ESTRICTA_MULTICANAL](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_004_CAJA_ESTRICTA_MULTICANAL.md)

**El hueco:** FRD-014 define el protocolo de excepción para venta con stock 0. Menciona el ajuste automático de inventario pero **no menciona el canal de pago** para la venta forzada. Dado que FRD-004 Multicanal exige canal en toda transacción, la venta forzada debería seguir el mismo flujo de checkout del POS (selección de canal), pero esto no está documentado.

**Lo que falta:** Confirmación explícita de que la venta forzada pasa por el checkout multicanal normal del POS.

---

### HALLAZGO 17 — 🟠 Sin filtro por empleado en reportes de caja

**FRD Origen:** [FRD_018_CONTROL_OPERACIONAL](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_018_CONTROL_OPERACIONAL_Y_ANALISIS_FINANCIERO.md)

**El hueco:** FRD-018 Pilar 4 establece métricas de "Ventas y Margen por Empleado/Turno" y "Historial de Descuadres de Arqueo atribuidos por cajero". El criterio CA-018-05 dice: "Los datos del Pilar 4 diferencian las operaciones por empleado o turno".

Sin embargo, **ningún FRD de reportes de caja (FRD-027-01) ni de ventas (FRD-007) especifica un filtro por empleado**. El dato está anclado al turno (session_id) y al empleado que registró, pero no hay caso de uso que permita al Admin consultar "todas las ventas del empleado X en los últimos 7 días".

**Lo que falta:** Caso de uso de consulta filtrada por empleado en reportes.

---

### HALLAZGO 18 — 🟠 Sin búsqueda reutilizable de proveedores

**FRD Origen:** [FRD_019_CUENTAS_POR_PAGAR](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_019_CUENTAS_POR_PAGAR.md)
**FRD Relacionado:** [FRD_006_01_01_MOVIMIENTOS_ENTRADA_INVENTARIO](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_006_01_01_MOVIMIENTOS_ENTRADA_INVENTARIO.md)

**El hueco:** FRD-019 Caso A dice: "El usuario ingresa el nombre del proveedor". FRD-006-01-01 menciona "Datos del Proveedor" como información referencial. Sin embargo, **ningún FRD especifica si los proveedores son texto libre o entidades reutilizables**.

Si el proveedor es texto libre:
- "Coca Cola", "coca cola", "CocaCola" serían 3 proveedores distintos
- No se pueden agrupar facturas por proveedor de forma confiable
- FRD-018 Pilar 2 menciona "Calendario de vencimientos de facturas" por proveedor, lo cual requiere consistencia

Si el proveedor es una entidad (mini-catálogo), ningún FRD define su creación ni gestión.

**Lo que falta:** Regla que defina si el proveedor es texto libre o una entidad seleccionable, y qué mecanismo evita duplicados.

---

### HALLAZGO 19 — 🟠 Sin paginación en historial de transacciones del cliente

**FRD Origen:** [FRD_009_CLIENTES](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_009_CLIENTES.md)

**El hueco:** FRD-009 define que cada cliente tiene transacciones (compras a crédito + abonos) visibles en su perfil. Un cliente frecuente que compra fiado semanalmente puede acumular 100+ transacciones en meses. **No se especifica paginación ni filtros para el historial del cliente individual.**

**Lo que falta:** Regla sobre límites de visualización o paginación en el historial de transacciones por cliente.

---

### HALLAZGO 20 — 🟠 Sin indicador de cantidad de ventas pendientes de sincronización

**FRD Origen:** [FRD_012_01_LIMITES_SISTEMA_OFFLINE](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_012_01_LIMITES_SISTEMA_OFFLINE.md)
**FRD Relacionado:** [FRD_011_MANEJO_ERRORES](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/FRD/FRD_011_MANEJO_ERRORES.md)

**El hueco:** FRD-012-01 establece un límite máximo de transacciones encoladas offline. Al alcanzar el límite, se bloquea el POS. FRD-011 establece indicadores de "Modo Offline". Sin embargo, **ningún FRD especifica que el usuario pueda ver cuántas ventas están pendientes de sincronización** antes de alcanzar el límite.

Sin este indicador, el usuario queda ciego hasta el bloqueo total: el sistema pasa de "todo funciona" a "bloqueado" sin transición.

**Lo que falta:**
- Regla sobre indicador visual de cola de sincronización (ej. "3/50 ventas pendientes")
- Criterio de aceptación sobre alerta preventiva al acercarse al límite

---

## Observaciones Metodológicas

> [!NOTE]
> **Criterio de inclusión:** Solo se listaron huecos donde un FRD **ya plantea una funcionalidad** pero omite un conector lógico necesario para que esa funcionalidad sea operativamente utilizable. No se incluyeron propuestas de funcionalidades nuevas.

> [!NOTE]
> **Criterio de exclusión:** No se incluyeron huecos de implementación técnica (esos pertenecen al SDD/DSD), ni mejoras de UX (esos pertenecen al UXD), ni propuestas de nuevos módulos.

> [!IMPORTANT]
> **Auto-chequeo 9.1 — Conteo de hallazgos:** Se reportan exactamente **20 hallazgos**, cada uno citado y detallado individualmente en la sección de Hallazgos Detallados.
> 
> **Auto-chequeo 9.2 — No-fusión de dimensiones:** Cada hallazgo se evalúa en su propia dimensión. Ningún hallazgo positivo (ej. "FRD-019 es muy detallado") se usó para atenuar un negativo (ej. "pero no tiene filtros").
>
> **Auto-chequeo 9.3 — No se citó la fuente auditada como evidencia:** Cada hueco se detectó por análisis cruzado entre FRDs, no porque un FRD lo admitiera de sí mismo.
