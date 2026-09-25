# FRD-006: Gestión de Inventario (Módulo Primario)

### Nombre de la Funcionalidad
Catálogo de Productos y Control de Existencias (Kardex)

#### Descripción
Sistema central de gestión de productos que permite mantener el catálogo de mercancía de la tienda, controlar el stock disponible y auditar todos los movimientos de inventario. Es la base sobre la cual opera el módulo de Ventas.

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
| Costo | ❌ No | Visible solo para Admin. Protegido por políticas de acceso. |
| Categoría | ❌ No | Categoría libre o predefinida. |
| Unidad de Medida | ✅ Sí | Valores: unidad, kg, lb, g |
| Es Pesable | ✅ Sí | Si es verdadero, el POS muestra calculadora de peso. |

---

### Matriz de Permisos

| Acción | Admin | Empleado con `canViewInventory` | Empleado con `canManageInventory` |
|--------|-------|--------------------------------|-----------------------------------|
| Ver listado de productos | ✅ | ✅ | ✅ |
| Ver campo costo | ✅ | ❌ | ❌ |
| Crear producto | ✅ | ❌ | ✅ |
| Editar producto | ✅ | ❌ | ✅ |
| **Eliminar producto** | ✅ | ❌ | ❌ |
| Registrar movimientos (Kardex) | ✅ | ❌ | ✅ |
| Ver historial Kardex | ✅ | ✅ | ✅ |

---

### Movimientos de Stock (Kardex)

| Tipo | Efecto en Stock | Ejemplo |
|------|-----------------|---------|
| Entrada | +Cantidad | Llega mercancía del proveedor |
| Salida | -Cantidad | Merma, robo, daño |
| Ajuste | ±Cantidad | Corrección de inventario físico |
| Venta | -Cantidad | Registrado automáticamente por módulo Ventas |
| Devolución | +Cantidad | Cliente devuelve producto |

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
    1. Usuario selecciona producto → "Movimientos" → "Nueva Entrada".
    2. Ingresa cantidad y razón (ej: "Proveedor XYZ").
    3. Opcionalmente ingresa fecha de vencimiento.
    4. Sistema suma cantidad al stock y registra en historial.
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

---

## Requisitos de Datos (Para Equipo Data)

**Entidad Producto:**
- Campos definidos en la tabla de Entidad Producto (arriba)
- Políticas de acceso: filtrar por tienda, ocultar costo si usuario no es Admin

**Entidad Movimientos de Inventario:**
- Identificador único
- Relación con Producto
- Tipo de movimiento
- Cantidad
- Razón
- Usuario que registró
- Timestamp
- Trigger: Al insertar, actualizar stock del producto automáticamente

---

## Criterios de Aceptación

- [ ] El botón "Eliminar Producto" está oculto para empleados (solo visible para Admin).
- [ ] El campo costo no es visible para empleados en ninguna pantalla.
- [ ] Al llegar stock a nivel bajo, aparece notificación en el centro de notificaciones.
- [ ] La búsqueda por PLU retorna resultado instantáneo (menos de 1 segundo).
- [ ] Todos los movimientos de stock quedan registrados con el usuario responsable.
- [ ] No se permite crear movimientos que resulten en stock negativo.
- [ ] El precio siempre se guarda redondeado al múltiplo de $50.
- [ ] La búsqueda por nombre retorna coincidencias parciales desde 2 caracteres ingresados.
- [ ] El filtro "Stock Bajo" muestra solo productos con stock ≤ stock mínimo.
- [ ] El listado muestra solo productos activos por defecto; el Admin puede alternar para incluir inactivos.
- [ ] Los filtros (estado, categoría, stock bajo) y la búsqueda por nombre se pueden combinar simultáneamente.
- [ ] El listado permite ordenar por nombre, stock o precio.
- [ ] Los listados de productos, Kardex y precios implementan carga progresiva de 20 en 20 con indicador de total.
