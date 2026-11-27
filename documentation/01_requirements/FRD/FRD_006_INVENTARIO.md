# FRD-006: Gestión de Inventario (Módulo Primario)

### Nombre de la Funcionalidad
Catálogo de Productos y Control de Existencias (Kardex)

#### Descripción
Sistema central de gestión de productos que permite mantener el catálogo de mercancía de la tienda, controlar el stock disponible y auditar todos los movimientos de inventario. Es la base sobre la cual opera el módulo de Ventas.


**Caso F: Auditar discrepancia de inventario vía Kardex**
- **Actor:** Admin
- **Precondición:** El Admin detecta una diferencia entre el stock físico y el digital de un producto de alta rotación.
- **Flujo Principal:**
    1. Usuario ingresa al detalle del producto y abre su historial Kardex.
    2. Sistema muestra los movimientos de los últimos 7 días.
    3. Usuario filtra el Tipo de Movimiento para mostrar únicamente "Ajuste" y "Salida".
    4. Sistema reduce la vista ocultando los cientos de ventas y mostrando solo las correcciones o mermas recientes.
    5. Usuario identifica qué empleado registró la merma sospechosa y revisa la razón anotada.
- **Postcondición:** El administrador aísla rápidamente la transacción anómala sin revisar manualmente las ventas.

---

## Reglas de Negocio

> [!IMPORTANT]
> **Políticas Globales Obligatorias:**
> Este módulo DEBE cumplir las siguientes especificaciones técnicas:
> - [SPEC-010: Política de Redondeo](../TECH_SPECS/rounding-policy.md)
> - [SPEC-011: Estándar de Decimales](../TECH_SPECS/decimal-format-standard.md)

### Políticas de Redondeo y Formato

Este módulo cumple las políticas globales de redondeo y formato decimal:

- **Precios:** Se redondean al múltiplo de $50 más cercano, con empate hacia abajo (beneficio cliente).
- **Montos:** Se muestran sin decimales, con separador de miles.
- **Cantidades unitarias:** Sin decimales (ej: 10).
- **Cantidades por peso (kg/lb):** Máximo 2 decimales (ej: 28.16).
- **Cantidades en gramos:** Sin decimales (ej: 454).

El redondeo se aplica al momento del cálculo, no solo en visualización. Los datos almacenados ya están redondeados.

---

### Entidad Producto

| Campo | Obligatorio | Regla |
|-------|-------------|-------|
| Nombre | ✅ Sí | Mínimo 2 caracteres |
| Precio | ✅ Sí | Mayor a $0. Redondeado al guardar. |
| Stock | ✅ Sí | Valor inicial: 0 o mayor. **NUNCA puede ser negativo.** |
| Stock Mínimo | ✅ Sí | Umbral para alerta de stock bajo. Default: 5. |
| PLU | ❌ No | Código rápido de máximo 4 dígitos. Único por tienda. |
| Costo | ❌ No | Visible para Admin y empleados con permiso `Inventario completo` (`FRD-003-01`). Oculto para empleados sin ese permiso. |
| Categoría | ❌ No | Categoría libre o predefinida. |
| Unidad de Medida | ✅ Sí | Valores: unidad, kg, lb, g |
| Es Pesable | ✅ Sí | Si es verdadero, el POS muestra calculadora de peso. |

---

### Matriz de Permisos (`FRD-003-01`, `POL-SEG-03`, `POL-LOG-03`)

| Acción | Admin | Empleado con `Inventario completo` (`canManageInventory`) | Empleado sin `Inventario completo` |
|--------|-------|-----------------------------------|--------------------------------|
| Ver listado de productos, stock, costo y Kardex | ✅ | ✅ | ❌ *(solo busca en POS para vender)* |
| Crear y editar producto | ✅ | ✅ (con firma individual) | ❌ |
| **Eliminar producto (baja lógica)** | ✅ | ✅ (con firma individual) | ❌ |
| Consultar catálogo de productos eliminados | ✅ | ❌ | ❌ |
| Registrar Entradas, **Ajustes por conteo físico** y **Devolución física a proveedor** ($0 en Caja POS, sin tocar CxP) | ✅ | ✅ (con motivo, firma individual y alerta al Admin en ajustes) | ❌ |
| Registrar **Mermas** y **Consumo del negocio** ($0 en Caja POS) | ✅ | ✅ (con motivo y firma individual) | ✅ (con motivo y firma individual, sin ver costo) |
| Registrar **Consumo / Retiro personal** (como venta en POS, $0 en Caja POS) | ✅ *(puede elegir a cualquier perfil)* | ✅ *(solo a su propio perfil)* | ✅ *(solo a su propio perfil)* |

---

### Movimientos de Stock (Kardex)

| Tipo | Efecto en Stock | Ejemplo / Alcance |
|------|-----------------|---------|
| Entrada | +Cantidad | Llega mercancía del proveedor (`Inventario completo` / Admin) |
| Salida por Merma | -Cantidad | Producto roto, dañado o vencido (`Cualquier usuario activo`, $0 en Caja POS) |
| Salida por Consumo del Negocio | -Cantidad | Insumos tomados del estante para uso de la tienda (`Cualquier usuario activo`, $0 en Caja POS) |
| Salida por Consumo / Retiro Personal | -Cantidad | Operado como venta en POS asignada al perfil propio (`Cualquier usuario activo`, $0 en Caja POS; solo Admin elige a otros) |
| Salida por Devolución Física a Proveedor | -Cantidad | Unidades devueltas físicamente al proveedor (`Inventario completo` / Admin, $0 en Caja POS y sin alterar CxP) |
| Ajuste por Conteo Físico | ±Cantidad | Corrección de inventario físico con alerta administrativa (`Inventario completo` / Admin) |
| Venta | -Cantidad | Registrado automáticamente por el POS |
| Reembolso de Cliente | +Cantidad (o directo a Merma si lleva etiqueta `"merma"`) | Devolución en POS: si tiene la etiqueta única `"merma"`, no pasa por stock vendible y sale como merma; si no la tiene, reingresa para otra venta (`FRD-006-02`) |

**Regla Crítica:** Si un movimiento resultaría en stock negativo → **Rechazar operación** con mensaje: "Stock insuficiente. Disponible: X [unidad]".

---

### Alertas Automáticas

- Cuando el stock cae por debajo del stock mínimo → Generar notificación: "Stock Bajo: [Producto]. Quedan X."
- La alerta se dispara **una sola vez** por producto hasta que se reponga.
- Cuando el stock vuelve a nivel normal → Se reactiva la capacidad de alertar en el futuro.

---

### Navegación y Búsqueda en el Catálogo

El módulo de inventario DEBE proveer mecanismos de búsqueda y filtrado para que el usuario localice productos dentro del catálogo sin necesidad de recorrer la lista completa.

1. **Búsqueda por Nombre (Parcial):** El sistema DEBE permitir buscar productos ingresando una porción del nombre. La búsqueda es insensible a mayúsculas/minúsculas y retorna coincidencias parciales desde 2 caracteres. Esta búsqueda se ejecuta sobre el catálogo local (caché).

2. **Filtros de Estado:** El listado DEBE ofrecer la capacidad de filtrar por:
   - **Estado activo/inactivo:** Por defecto se muestran solo los activos. El Admin puede alternar para ver también los inactivos.
   - **Stock bajo:** Mostrar únicamente productos cuyo stock actual sea menor o igual a su stock mínimo.

3. **Filtro por Categoría:** Si existen categorías asignadas, el listado DEBE ofrecer un filtro para mostrar solo los productos de una categoría específica.

4. **Ordenamiento:** El listado DEBE permitir ordenar por:
   - Nombre (A-Z / Z-A) — orden por defecto.
   - Stock (menor a mayor / mayor a menor).
   - Precio (menor a mayor / mayor a menor).

5. **Combinación de Filtros:** Los filtros de estado, categoría y la búsqueda por nombre DEBEN poder combinarse simultáneamente. El ordenamiento se aplica sobre los resultados filtrados.


### Navegación y Filtrado del Historial Kardex

Para garantizar la auditoría operativa (POL-AUD-02), la vista de movimientos (Kardex) de un producto DEBE proveer herramientas de filtrado combinables:

1. **Filtro por Rango de Fechas:** Permite aislar movimientos ocurridos entre dos fechas. Por defecto, al abrir el Kardex de un producto, el sistema muestra los movimientos de los últimos 7 días.
2. **Filtro por Tipo de Movimiento:** Permite visualizar exclusivamente ciertos tipos de transacción. Opciones: *Todos (por defecto), Entradas, Salidas (Mermas), Ajustes, Ventas, Devoluciones*.
3. **Filtro por Empleado:** Permite mostrar únicamente los movimientos ejecutados por un usuario específico (activo o inactivo).
4. **Combinación y Orden:** Los filtros DEBEN poder combinarse simultáneamente (ej. "Ajustes realizados por Juan en los últimos 3 días"). El ordenamiento es fijo: cronológico descendente (el más reciente arriba).

### Estrategia de Paginación para Listados Extensos

El catálogo de inventario y cualquier listado asociado (movimientos Kardex, historial de precios) DEBE implementar carga progresiva para manejar el crecimiento de datos con el tiempo.

1. **Carga Inicial Limitada:** Todo listado DEBE cargar inicialmente un máximo de 20 elementos, ordenados según el criterio por defecto de cada vista.
2. **Carga Bajo Demanda:** El sistema DEBE permitir al usuario cargar los siguientes 20 elementos manualmente (botón "Cargar más" o scroll al final de la lista). El sistema DEBE priorizar la fluidez de la interfaz evitando sobrecargar la pantalla.
3. **Conteo Total:** El sistema DEBE mostrar el total de elementos que coinciden con los filtros activos (ej. "Mostrando 20 de 347 productos"), para que el usuario tenga contexto de la magnitud del listado.
4. **Aplicabilidad Transversal:** Esta estrategia aplica como patrón de referencia para todos los listados del sistema que puedan crecer indefinidamente: productos, movimientos Kardex, ventas, clientes, transacciones de clientes, facturas por pagar y movimientos de caja.

---

## Casos de Uso

**Caso A: Crear Producto**
- **Actor:** Admin o Empleado con permiso de gestión de inventario
- **Precondición:** Usuario con permisos adecuados.
- **Flujo Principal:**
    1. Usuario selecciona "Nuevo Producto".
    2. Sistema muestra formulario: Nombre, Precio, Stock, Categoría, PLU, Unidad.
    3. Usuario completa campos y confirma.
    4. Sistema redondea precio al múltiplo de $50.
    5. Sistema guarda producto y lo muestra en la lista.
- **Postcondición:** Producto disponible para venta.

**Caso B: Registrar Entrada de Mercancía**
- **Actor:** Admin o Empleado con permiso de gestión de inventario
- **Precondición:** Producto existe en catálogo.
- **Flujo Principal:**
    1. Usuario selecciona la opción para registrar entrada de mercancía.
    2. Ingresa cantidad, costo unitario referencial, precio de venta y motivo (ej: compra o reposición de proveedor), sin solicitar fecha de vencimiento del producto (`SYSTEM_BOUNDARIES.md`, `POL-PROD-01`).
    3. Sistema suma cantidad al stock y registra en historial.
- **Postcondición:** Stock actualizado, movimiento auditable.

**Caso C: Búsqueda Rápida por PLU**
- **Actor:** Cualquier usuario con acceso a inventario.
- **Flujo Principal:**
    1. Usuario ingresa PLU en barra de búsqueda.
    2. Sistema filtra instantáneamente al producto coincidente.
- **Postcondición:** Producto encontrado en menos de 1 segundo.

**Caso D: Localizar Producto por Nombre en el Catálogo**
- **Actor:** Admin o Empleado con permiso de consulta o gestión de inventario.
- **Precondición:** El catálogo tiene 100+ productos.
- **Flujo Principal:**
    1. Usuario ingresa parte del nombre en el campo de búsqueda (ej: "pan").
    2. Sistema filtra la lista mostrando todos los productos cuyo nombre contenga "pan" (ej: "Pan Bimbo", "Pandebono", "Empanada").
    3. Usuario selecciona el producto deseado para ver detalle o editar.
- **Postcondición:** Producto localizado sin recorrer la lista completa.

**Caso E: Filtrar Productos con Stock Bajo**
- **Actor:** Admin o Empleado con permiso de consulta o gestión de inventario.
- **Precondición:** Existen productos cuyo stock actual es menor o igual a su stock mínimo.
- **Flujo Principal:**
    1. Usuario activa el filtro "Stock Bajo".
    2. Sistema muestra únicamente los productos que cumplen la condición stock ≤ stock mínimo.
    3. Usuario revisa la lista para decidir qué reabastecer.
- **Postcondición:** Vista filtrada que permite acción rápida de reabastecimiento.


**Caso F: Auditar discrepancia de inventario vía Kardex**
- **Actor:** Admin
- **Precondición:** El Admin detecta una diferencia entre el stock físico y el digital de un producto de alta rotación.
- **Flujo Principal:**
    1. Usuario ingresa al detalle del producto y abre su historial Kardex.
    2. Sistema muestra los movimientos de los últimos 7 días.
    3. Usuario filtra el Tipo de Movimiento para mostrar únicamente "Ajuste" y "Salida".
    4. Sistema reduce la vista ocultando los cientos de ventas y mostrando solo las correcciones o mermas recientes.
    5. Usuario identifica qué empleado registró la merma sospechosa y revisa la razón anotada.
- **Postcondición:** El administrador aísla rápidamente la transacción anómala sin revisar manualmente las ventas.


---

## Requisitos de Datos (Para Equipo Data)

**Entidad Producto:**
- Campos definidos en la tabla de Entidad Producto (arriba)
- Trazabilidad de autoría: firma individual de quién creó, editó o dio de baja lógica el producto
- Políticas de acceso: filtrar por tienda; mostrar costo únicamente a Admin y empleados con permiso `Inventario completo`

**Entidad Movimientos de Inventario:**
- Identificador único
- Relación con Producto
- Tipo de movimiento (Entrada, Merma, Consumo del negocio, Consumo/retiro personal, Devolución física a proveedor, Ajuste por conteo físico, Venta, Reembolso)
- Cantidad
- Razón / Motivo obligatorio
- Usuario responsable (firma individual inmutable con fotografía histórica de nombre y rol)
- Timestamp
- Inmutabilidad: ningún movimiento se borra ni edita; toda corrección se realiza por contra-movimiento

---

## Criterios de Aceptación

- [ ] Crear, editar, dar baja lógica ("Eliminar Producto"), ver el campo **costo**, ver Kardex y registrar Entradas, Ajustes por conteo físico y Devoluciones físicas a proveedor están habilitados para el Administrador y empleados con permiso **`Inventario completo`** (con firma individual inmutable).
- [ ] Consultar el catálogo de productos eliminados (inactivos) es exclusivo del Administrador.
- [ ] Cualquier usuario activo puede registrar Mermas, Consumo del negocio y Consumo/retiro personal (este último a su propio perfil; solo Admin elige a otros) con su firma individual y $0 en Caja POS.
- [ ] Al llegar stock a nivel bajo, aparece notificación en el centro de notificaciones.
- [ ] La búsqueda por PLU retorna resultado instantáneo (menos de 1 segundo).
- [ ] Todos los movimientos de stock y acciones sobre productos quedan registrados de forma inmutable con la firma individual del usuario responsable.
- [ ] No se permite crear movimientos que resulten en stock negativo.
- [ ] El precio siempre se guarda redondeado al múltiplo de $50.
- [ ] La búsqueda por nombre retorna coincidencias parciales desde 2 caracteres ingresados.
- [ ] El filtro "Stock Bajo" muestra solo productos con stock ≤ stock mínimo.
- [ ] El listado muestra solo productos activos por defecto; el Admin puede alternar para incluir inactivos.
- [ ] Los filtros (estado, categoría, stock bajo) y la búsqueda por nombre se pueden combinar simultáneamente.
- [ ] El listado permite ordenar por nombre, stock o precio.
- [ ] Los listados de productos, Kardex y precios implementan carga progresiva de 20 en 20 con indicador de total.
- [ ] El historial Kardex de un producto permite filtrar por rango de fechas, tipo de movimiento y empleado de forma simultánea.
- [ ] Al abrir el Kardex, se visualizan por defecto los movimientos de los últimos 7 días en orden cronológico descendente.
