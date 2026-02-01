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
