# FRD-009: Gestión de Clientes y Cartera (Módulo Secundario)

### Nombre de la Funcionalidad
Cartera de Clientes y Control de Crédito (Fiado)

#### Descripción
Sistema de gestión de clientes que permite mantener una cartera de compradores frecuentes, controlar el crédito otorgado (fiado) y registrar abonos. Actúa como soporte al módulo de Ventas cuando el método de pago es "Fiado".

---

## Reglas de Negocio

> [!IMPORTANT]
> **Políticas Globales Obligatorias:**
> Este módulo DEBE cumplir:
> - [SPEC-011: Estándar de Decimales](../TECH_SPECS/decimal-format-standard.md)

### Políticas de Formato

- Todos los montos (balance, cupo, abonos) se muestran como enteros sin decimales.
- Formato: Separador de miles con punto (ej: $185.500).

---

### Entidad Cliente

| Campo | Obligatorio | Regla |
|-------|-------------|-------|
| Nombre | ✅ Sí | Nombre completo. Mínimo 3 caracteres. |
| Cédula | ✅ Sí | Número de identificación. **Único por tienda.** |
| Teléfono | ❌ No | Teléfono de contacto. |
| Cupo de Crédito | ✅ Sí | Cupo máximo. Valor por defecto tomado de configuración global. |
| Balance | Auto | Saldo actual. Positivo = debe dinero. **NUNCA puede ser negativo.** |

---

### Regla de Saldo No Negativo

**Invariante Crítica:** El campo balance de un cliente NUNCA puede ser menor a $0.

- Si un abono intenta reducir el balance por debajo de $0 → **Rechazar operación**.
- Mensaje: "El abono ($X) supera la deuda actual ($Y). Máximo permitido: $Y."

---

### Regla de Bloqueo por Cupo Excedido

Cuando el usuario intenta procesar una venta "Fiado" desde el POS:

| Condición | Resultado | Mensaje |
|-----------|-----------|---------|
| Total venta ≤ (Cupo - Balance) | ✅ Proceder | - |
| Total venta > (Cupo - Balance) | ❌ Bloquear | "Cupo insuficiente. Disponible: $X. Total venta: $Y." |

**El sistema NO procesa la venta.** El usuario debe:
- Reducir el monto de la venta, O
- Cambiar a otro método de pago (Efectivo/Nequi), O
- Solicitar al Admin que aumente el cupo del cliente.

---

### Configuración Global de Cupo por Defecto

| Parámetro | Descripción | Ejemplo |
|-----------|-------------|---------|
| Cupo por Defecto | Cupo inicial para nuevos clientes | $100,000 |

- Configurable por Admin en configuración de tienda.
- Se aplica a nuevos clientes al momento de creación.
- Si la configuración cambia → Se actualiza en clientes existentes automáticamente.

---

### Matriz de Permisos

| Acción | Admin | Empleado |
|--------|-------|----------|
| Ver lista de clientes | ✅ | ✅ |
| Ver detalle de cliente | ✅ | ✅ |
| Crear cliente | ✅ | ❌ |
| Editar cliente | ✅ | ❌ |
| **Eliminar cliente** | ✅ (solo si balance = 0) | ❌ |
| Registrar abono (pago) | ✅ | ✅ |
| Cambiar cupo individual | ✅ | ❌ |
| Cambiar cupo global | ✅ | ❌ |

---

### Eliminación de Cliente

**Precondición:** Balance del cliente = $0

| Estado del Balance | Acción |
|--------------------|--------|
| Balance > 0 (debe dinero) | ❌ Botón "Eliminar" deshabilitado. Tooltip: "El cliente tiene deuda pendiente." |
| Balance = 0 | ✅ Modal de confirmación → Eliminar cliente y transacciones asociadas. |

---

## Transacciones

### Tipos de Movimiento

| Tipo | Efecto en Balance | Origen |
|------|-------------------|--------|
| **Compra a Crédito** | +Monto | Automático desde ventas cuando método = fiado |
| **Abono / Pago** | -Monto | Manual desde detalle de cliente |

### Campos de Transacción

- Identificador único
- Relación con Cliente
- Tipo: compra o pago
- Monto (siempre positivo)
- Descripción (ej: "Abono efectivo", "Venta Ticket #045")
- Fecha/hora
- Referencia a venta (solo para compras)

---

## Estados de la Interfaz

### Estado Vacío (Lista de Clientes)
- Mensaje: "Sin clientes registrados"
- Instrucción: "Agrega tu primer cliente para comenzar a llevar control de sus compras a crédito."
- Botón: "Agregar Cliente" (Solo visible para Admin)

### Indicador Visual de Deuda
- **Borde izquierdo rojo** + Badge "Debe": Cliente con balance > 0.
- **Borde izquierdo verde** + Badge "Al día": Cliente con balance = 0.

### Barra de Progreso de Cupo (Detalle de Cliente)
- Muestra visualmente qué porcentaje del cupo está utilizado.
- Color: Verde (0-50%), Amarillo (51-80%), Rojo (81-100%).

---

## Casos de Uso

**Caso A: Registrar Abono**
- **Actor:** Admin o Empleado
- **Precondición:** Cliente con balance > 0.
- **Flujo Principal:**
    1. Usuario navega a clientes → Selecciona cliente.
    2. Sistema muestra: Balance $45,000, Cupo $100,000.
    3. Usuario selecciona "Registrar Abono".
    4. Ingresa monto $20,000.
    5. Sistema valida: $20,000 ≤ $45,000 (balance actual) ✅.
    6. Sistema registra transacción tipo pago.
    7. Nuevo balance: $25,000.
- **Postcondición:** Balance actualizado, transacción registrada.

**Caso B: Venta Fiado Bloqueada por Cupo**
- **Actor:** Empleado con permiso de venta
- **Precondición:** Cliente con cupo utilizado.
- **Flujo Principal:**
    1. Usuario en POS agrega items por $80,000.
    2. Selecciona "Cobrar" → "Fiado" → Busca cliente.
    3. Sistema calcula: Cupo=$100,000, Balance=$45,000, Disponible=$55,000.
    4. Sistema muestra: "Cupo insuficiente. Disponible: $55,000. Total venta: $80,000."
    5. Usuario debe reducir venta o cambiar método de pago.
- **Postcondición:** Venta no procesada hasta resolver cupo.

**Caso C: Eliminar Cliente (Bloqueado por Deuda)**
- **Actor:** Admin
- **Precondición:** Cliente con balance > 0.
- **Flujo Principal:**
    1. Admin navega a detalle de cliente.
    2. Balance actual: $15,500.
    3. Botón "Eliminar" está deshabilitado.
    4. Tooltip muestra: "El cliente tiene deuda pendiente."
- **Postcondición:** Cliente no eliminado, debe pagar primero.

**Caso D: Crear Nuevo Cliente**
- **Actor:** Admin
- **Precondición:** Usuario con rol Admin.
- **Flujo Principal:**
    1. Admin selecciona "Nuevo Cliente".
    2. Completa: Nombre, Cédula, Teléfono (opcional).
    3. Campo "Cupo de Crédito" pre-llenado con valor global ($100,000).
    4. Admin puede modificar el cupo para este cliente específico.
    5. Guarda → Cliente creado con balance = 0.
- **Postcondición:** Cliente disponible para ventas fiadas.

---

## Requisitos de Datos (Para Equipo Data)

**Entidad Cliente:**
- Identificador único
- Relación con Tienda
- Nombre completo
- Cédula (única por tienda)
- Teléfono
- Cupo de crédito
- Balance actual
- Fecha de creación

**Entidad Transacción de Cliente:**
- Identificador único
- Relación con Cliente
- Tipo: compra o pago
- Monto
- Descripción
- Fecha/hora
- Referencia a venta (si aplica)

---

## Criterios de Aceptación

### Funcionalidad
- [ ] Empleados pueden registrar abonos pero NO crear/editar/eliminar clientes.
- [ ] Venta Fiado se bloquea si total > (cupo - balance).
- [ ] No se puede eliminar cliente con balance > 0.
- [ ] Balance nunca es negativo (validación en frontend Y backend).
- [ ] Cupo por defecto configurable y se propaga a clientes existentes.

### UX
- [ ] Botón "Eliminar" deshabilitado con tooltip cuando hay deuda.
- [ ] Mensaje claro cuando venta Fiado es bloqueada por cupo.
- [ ] Indicador visual (rojo/verde) en lista de clientes.
- [ ] Barra de progreso de cupo en detalle del cliente.

### Datos
- [ ] Cada transacción registra cliente, tipo, monto, fecha.
- [ ] Transacciones tipo compra incluyen referencia a venta para trazabilidad.
- [ ] Búsqueda funciona por nombre, cédula y teléfono.
