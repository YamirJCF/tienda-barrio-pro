# Diseño UX/UI - Módulo de Cuentas por Pagar (FRD-019)

> **Módulo:** Finanzas / Proveedores  
> **Rol:** Diseñador UX/UI (Senior Product Designer)  
> **Estado:** 🟢 Aprobado para Construcción

---

## 🗺️ Mapa de Navegación

El módulo se integra de forma orgánica en la estructura existente. No se crea un menú lateral nuevo de primer nivel para no saturar la navegación; en su lugar, se agrupa lógicamente.

1. **Dashboard Principal** ➔ (Navegación actual se mantiene)
2. **Proveedores (`SuppliersView.vue`)** ➔ Se añade una pestaña o botón de acceso a **Cuentas por Pagar** (`PayablesView.vue`).
3. **Entrada de Stock (`StockEntryView.vue`)** ➔ Se añade un campo dinámico de selector de factura, que **solo** aparece si el tipo de movimiento es "Devolución/Salida".

---

## 📱 Detalle de Pantalla (Arquitectura de Información)

### 1. Vista de Cuentas por Pagar (`PayablesView.vue`)
*Integra el estado global de la deuda y el desglose accionable por proveedor.*
- **Permisos de Acceso:** Restringido a usuarios con rol `isAdmin` o permisos financieros equivalentes, dado que la vista permite autorizar movimientos directos de salida de dinero (afectando la caja).

- **Header / Topbar (Mobile-First):**
  - Título: "Cuentas por Pagar"
  - Botón "Volver a Proveedores"
- **Cards de Resumen (Métricas Clave en Carrusel Horizontal o Grid 2x2):**
  - Card 1: **Total Deuda** (Suma de saldos pendientes, color neutro)
  - Card 2: **Vencido** (Suma de facturas vencidas, color rojo/peligro)
- **Filtros (Barra pegajosa):**
  - Selector de Proveedor (Dropdown).
  - Chips de Estado: "Todas", "Pendientes", "Vencidas".
- **Lista de Facturas (Cards verticales para scroll cómodo):**
  - Cada Card de Factura muestra:
    - `Header`: Nombre del Proveedor | Fecha de Emisión
    - `Body`: Monto Total | Saldo Pendiente (Destacado en negrita)
    - `Status Badge`: Vencida (Rojo), Pendiente (Amarillo/Naranja)
    - `Footer`: Botón primario "Abonar"
- **Empty State:**
  - Ilustración minimalista (sin emojis, SVG limpio).
  - Texto dinámico según el filtro activo: "No hay facturas {vencidas/pendientes} en este momento." (evita asumir erróneamente "cero deuda total" cuando un filtro excluyente está activo).

#### 4. Validación de Caja en Rojo (Soft Warning)
- Si el `p_amount` ingresado por el usuario es mayor que el saldo actual en efectivo de la sesión de caja abierta, el sistema **no bloqueará** la operación (por diseño de incentivos), pero mostrará un *Warning* visual claro (ej. Alert naranja) antes de habilitar el botón de confirmar:
  *"⚠️ Este abono dejará el saldo de la caja en negativo. Deberás justificar el faltante en el cierre."*

#### 5. Modal de Abono (Componente) (`PayInvoiceModal.vue`)
*Aparece al tocar el botón "Abonar" en una tarjeta de factura.*

- **Header:** "Registrar Abono a Proveedor"
- **Resumen Contextual (Solo lectura):**
  - "Factura de: [Proveedor]"
  - "Saldo Pendiente: $XX.XXX"
- **Input Principal:**
  - Input numérico grande con formato de moneda.
  - Label: "¿Cuánto deseas abonar de la caja actual?"
  - Botón rápido "Pagar Totalidad" (llena el input con el saldo exacto restante).
- **Advertencias / Validaciones Inline:**
  - Texto rojo dinámico si el monto excede el saldo pendiente: *"El abono no puede superar la deuda"*.
- **Footer:**
  - Botón Secundario: "Cancelar"
  - Botón Primario: "Confirmar Abono" (Con loading state o spinner). **Deshabilitado proactivamente** si `cashRegisterStore.isOpen` es falso, acompañado de un tooltip o texto de advertencia claro ("Debes tener un turno de caja abierto para registrar un pago"), evitando al usuario llenar el formulario para enterarse de que fallará.

### 3. Ajuste en Entrada/Devolución (`StockEntryView.vue`)
*El objetivo es no saturar la pantalla. El campo extra solo existe si hace falta.*

- En el formulario actual, si el `movementType` es `devolucion` (o `salida`) **Y** hay un proveedor seleccionado:
  - Aparece un nuevo `Select` o `ComboBox` opcional.
  - Label: "¿A qué factura corresponde esta devolución? (Opcional)"
  - Opciones: Lista de todas las facturas no pagadas (`amount_paid < total_amount`) de ese proveedor. Esto incluye obligatoriamente tanto las "pendientes" como las "vencidas".
  - Nota de ayuda sutil (Tool-tip): *"Si se deja vacío, se deducirá de la deuda más antigua."*

---

## ⚙️ Lógica de Componentes (Interacciones y Estados)

1. **Skeleton Loaders (Carga de Datos):**
   - Al entrar a `PayablesView`, mientras se obtienen las facturas de la base de datos (Supabase), se mostrarán tarjetas "fantasma" parpadeantes (`animate-pulse` de Tailwind) manteniendo la silueta de los textos. Nada de spinners centrados bloqueando la pantalla.
2. **Botón de Confirmar Abono (Optimistic vs Real):**
   - **Regla Backend Authority:** El botón "Confirmar" cambia a estado *Loading/Disabled* al hacer click. La UI **no** actualiza el saldo visualmente hasta que el RPC retorne `success`.
   - Si ocurre error (Ej: "Caja cerrada"), el modal se mantiene abierto y muestra un Toast/Alerta roja superior.
   - Si es exitoso, el modal se cierra, muestra Toast verde, y la lista principal ejecuta un refetch (`fetchInvoices`).
3. **Botón Rápido "Pagar Totalidad":**
   - Facilita la interacción en móvil (Touch & Interaction) al evitar teclear números largos. Al pulsarlo, el `v-model` del input asume exactamente el valor del saldo adeudado (`total_amount - amount_paid`).

---

## 🤖 Instrucción para el Orquestador

Para el equipo de ejecución técnica:

1. **Frontend / UI:** 
   - Necesitas crear 2 archivos visuales nuevos: `PayablesView.vue` y `PayInvoiceModal.vue`.
   - Utiliza las clases de Tailwind de tu sistema de diseño actual (evita colores hardcodeados `text-red-500`, usa las variables si las hay, o mantente dentro del esquema de la app base, ej. `bg-white`, `border-gray-200`, diseño "Glass" si aplica).
2. **StockEntryView:** 
   - No reconstruyas la vista, aplica una inyección quirúrgica (un `v-if` atado a `movementType === 'devolucion' && selectedSupplier`) para meter el `reference_invoice_id`.
3. **Flujo de Datos (Una Vía):**
   - Asegúrate de que el estado de la aplicación solo actúe como caché de lo que devuelve el RPC o la query de facturas. El frontend no debe hacer sumas ni restas locales de saldos tras un abono; delega eso a la recarga de la consulta.
