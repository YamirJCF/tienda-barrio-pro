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
- Se aplica **únicamente a clientes nuevos** al momento de su creación.
- Si la configuración cambia → **NO altera ni sobrescribe** los cupos de los clientes que ya existen en el sistema.

---

### Matriz de Permisos (`FRD-003-01`, `POL-SEG-03`)

| Acción | Admin | Empleado con `Fiar y cobrar abonos` (`canFiar`) | Empleado sin `Fiar y cobrar abonos` |
|--------|-------|----------|----------------------------------|
| Ver lista, detalle y estado de cuenta de clientes activos | ✅ | ✅ | ❌ |
| Seleccionar "Fiado" en POS (respetando cupo) | ✅ | ✅ (con firma individual) | ❌ |
| Registrar abono (pago con Caja Dedicada POS abierta) | ✅ | ✅ (con firma individual) | ❌ |
| Crear cliente | ✅ | ❌ | ❌ |
| Editar cliente | ✅ | ❌ | ❌ |
| **Eliminar cliente** | ✅ (solo si balance = 0, `FRD-030`) | ❌ | ❌ |
| Cambiar cupo individual | ✅ | ❌ | ❌ |
| Cambiar cupo global por defecto | ✅ | ❌ | ❌ |

---

### Eliminación de Cliente y Resguardo Contable Interno (`FRD-030`, `POL-PRIV-02`)

**Precondición:** Balance del cliente = $0 y rol **Administrador**.

| Estado del Balance | Acción |
|--------------------|--------|
| Balance > 0 (debe dinero) | ❌ Botón "Eliminar" deshabilitado. Tooltip: "El cliente tiene deuda pendiente." |
| Balance = 0 | ✅ Modal de confirmación → El servidor resuelve internamente según `FRD-030` (`POL-PRIV-02`). |

> [!IMPORTANT]
> **Política de Eliminación Protegida y Resguardo Contable Silencioso (`POL-PRIV-02`, `FRD-030`):**
> Frente al Administrador existe una única acción de eliminación y **no se expone un filtro de "Mostrar eliminados"** en las listas operativas:
> - Si el cliente eliminado **nunca tuvo movimientos históricos**, el servidor lo borra definitivamente.
> - Si el cliente **sí tuvo movimientos históricos**, el servidor conserva en silencio su nombre, cédula y transacciones pasadas como soporte contable obligatorio (limpiando su teléfono y fijando su cupo en $0, ocultándolo de toda lista activa). Si en el futuro esa misma cédula vuelve a registrarse por el Administrador, se reactiva en silencio sin duplicar el tercero (`FRD-030` RN-04 y RN-05).

---

### Navegación y Filtrado del Listado de Clientes

El módulo DEBE proveer mecanismos de filtrado para que el usuario autorizado (Administrador o empleado con permiso `Fiar y cobrar abonos`) localice clientes activos según su estado financiero sin necesidad de recorrer la lista completa.

1. **Filtro por Estado de Deuda:** El listado DEBE ofrecer un filtro para mostrar clientes activos según su estado financiero:
   - **Todos:** Muestra todos los clientes activos (estado por defecto).
   - **Con Deuda:** Muestra únicamente clientes cuyo balance es mayor a $0.
   - **Al Día:** Muestra únicamente clientes cuyo balance es igual a $0.

2. **Ausencia de Filtro de Eliminados (`FRD-030`):** En cumplimiento de `POL-PRIV-02` y `FRD-030`, las listas y búsquedas muestran exclusivamente clientes activos (sin opción ni filtro de mostrar eliminados).

3. **Ordenamiento:** El listado DEBE permitir ordenar por:
   - Nombre (A-Z / Z-A) — orden por defecto.
   - Monto de deuda (mayor a menor / menor a mayor).

4. **Combinación de Filtros:** Los filtros de estado de deuda y la búsqueda textual existente (nombre, cédula, teléfono) DEBEN poder combinarse simultáneamente. El ordenamiento se aplica sobre los resultados filtrados.

5. **Paginación del Historial de Transacciones:** El historial de transacciones (compras a crédito + abonos) dentro del detalle de un cliente individual DEBE implementar carga progresiva: mostrar inicialmente las últimas 20 transacciones (orden cronológico descendente), permitiendo al usuario cargar más manualmente. El sistema DEBE mostrar el total de transacciones del cliente.

---


## Transacciones

### Tipos de Movimiento

| Tipo | Efecto en Balance | Origen |
|------|-------------------|--------|
| **Compra a Crédito** | +Monto | Automático desde ventas cuando método = fiado |
| **Abono / Pago** | -Monto | Manual desde detalle de cliente |

> [!NOTE]
> **Canalización Monetaria de Abonos:**
> Todo Abono/Pago representa un ingreso real de liquidez. Por tanto, DEBE canalizarse obligatoriamente a través de un canal de pago (Efectivo, Nequi, Llave BRE) y registrarse en el turno de caja activo (FRD-020).

### Campos de Transacción

- Identificador único
- Relación con Cliente
- Tipo: compra o pago
- Monto (siempre positivo)
- Canal de Pago (solo para abonos)
- Turno de Caja (`session_id`) (solo para abonos)
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
- **Actor:** Admin o Empleado con permiso **`Fiar y cobrar abonos`** (`FRD-003-01`)
- **Precondición:** Cliente con balance > 0. Existe un turno de Caja Dedicada POS abierto.
- **Flujo Principal:**
    1. Usuario navega a clientes → Selecciona cliente.
    2. Sistema muestra: Balance $45,000, Cupo $100,000.
    3. Usuario selecciona "Registrar Abono".
    4. Ingresa monto $20,000 y selecciona obligatoriamente el canal de pago (**Efectivo, Nequi o Llave BRE**).
    5. Sistema valida: $20,000 ≤ $45,000 (balance actual) ✅.
    6. Sistema registra transacción tipo pago con la **firma individual** del usuario, asociada al canal seleccionado y al turno activo.
    7. Nuevo balance: $25,000.
- **Flujo Alternativo (Caja Cerrada):** Si no hay turno abierto, el sistema bloquea el abono indicando "Debe abrir caja para recibir dinero".
- **Postcondición:** Balance actualizado, transacción registrada con firma individual, dinero sumado al canal en la caja activa.

**Caso B: Venta Fiado Bloqueada por Cupo**
- **Actor:** Admin o Empleado con permiso **`Fiar y cobrar abonos`** (`FRD-003-01`)
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

**Caso E: Consultar Clientes con Deuda Pendiente**
- **Actor:** Admin o Empleado con permiso **`Fiar y cobrar abonos`** (`FRD-003-01`).
- **Precondición:** Existen clientes con balance > 0 y clientes con balance = 0.
- **Flujo Principal:**
    1. Usuario ingresa al módulo de Clientes.
    2. Sistema muestra el listado con todos los clientes activos (estado por defecto).
    3. Usuario selecciona el filtro "Con Deuda".
    4. Sistema muestra únicamente los clientes cuyo balance es mayor a $0.
    5. Usuario ordena por "Monto de deuda" de mayor a menor.
    6. Usuario identifica rápidamente a los clientes con mayor deuda pendiente.
- **Postcondición:** Vista filtrada y ordenada que permite priorizar cobros.

**Caso F: Eliminación Protegida y Resguardo Contable Silencioso (`FRD-030`, `POL-PRIV-02`)**
- **Actor:** Exclusivamente el Administrador.
- **Precondición:** Cliente activo con balance exactamente igual a `$0`.
- **Flujo Principal:**
    1. Admin selecciona "Eliminar Cliente" y confirma.
    2. El servidor verifica que el saldo es `$0`: si nunca tuvo movimientos históricos, lo borra definitivamente; si tuvo movimientos históricos, conserva en silencio su nombre, cédula y transacciones pasadas como soporte contable (limpiando teléfono y cupo, y ocultándolo de toda lista y búsqueda activa sin ofrecer un filtro de "Mostrar eliminados").
- **Postcondición:** El cliente desaparece de la cartera activa y la contabilidad histórica permanece íntegra.

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
- Fecha de creación y firma del Administrador creador
- Estado de ciclo de vida interno (`FRD-030`): Activo vs. Archivado Contablemente (transparente, sin filtro de eliminados en listas)
- Fecha y hora de eliminación en servidor (null si activo)

**Entidad Transacción de Cliente:**
- Identificador único
- Relación con Cliente
- Usuario responsable (firma individual inmutable)
- Tipo: compra o pago
- Monto
- Canal de Pago (**Efectivo, Nequi o Llave BRE**, obligatorio en abonos)
- Relación con Turno de Caja (si aplica)
- Descripción
- Fecha/hora
- Referencia a venta (si aplica)

---

## Criterios de Aceptación

### Funcionalidad
- [ ] Empleados con el permiso **`Fiar y cobrar abonos`** pueden fiar en POS, registrar abonos y consultar el estado de cuenta de clientes activos, pero **NO** crear, editar, cambiar cupos ni eliminar clientes (**100% exclusivo del Administrador**).
- [ ] Venta Fiado se bloquea si total > (cupo - balance) o si el empleado no posee el permiso `Fiar y cobrar abonos`.
- [ ] No se puede eliminar cliente con balance > 0.
- [ ] Balance nunca es negativo (validación en frontend Y backend).
- [ ] El "Cupo por Defecto" es configurable por el Admin y **se aplica únicamente a clientes nuevos al crearlos**, sin sobrescribir jamás los cupos de clientes ya existentes.
- [ ] El registro de un abono exige seleccionar obligatoriamente un canal de pago (**Efectivo, Nequi o Llave BRE**) y un turno de Caja Dedicada POS abierto.

### UX
- [ ] Botón "Eliminar" deshabilitado con tooltip cuando hay deuda.
- [ ] Mensaje claro cuando venta Fiado es bloqueada por cupo.
- [ ] Indicador visual (rojo/verde) en lista de clientes.
- [ ] Barra de progreso de cupo en detalle del cliente.

### Datos
- [ ] Cada transacción registra cliente, firma individual del usuario responsable, tipo, monto, canal y fecha.
- [ ] Transacciones tipo compra incluyen referencia a venta para trazabilidad.
- [ ] Búsqueda funciona por nombre, cédula y teléfono sobre clientes activos.
- [ ] La eliminación con saldo `$0` cumple `FRD-030` (`POL-PRIV-02`): borrado definitivo si no tiene movimientos, o resguardo contable silencioso sin filtro "Mostrar eliminados" en listas operativas (y re-alta transparente si la cédula vuelve a crearse).
- [ ] El listado de clientes ofrece filtro por estado de deuda: Todos, Con Deuda, Al Día.
- [ ] El listado de clientes permite ordenar por nombre o por monto de deuda.
- [ ] Los filtros de estado de deuda y la búsqueda textual se pueden combinar simultáneamente.
- [ ] El listado muestra por defecto todos los clientes activos ordenados por nombre.
- [ ] El historial de transacciones de un cliente individual carga las últimas 20 transacciones inicialmente con opción de cargar más.
