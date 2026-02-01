## Orden de Trabajo - Refactorización de Pagos Mixtos (PO-08)

### Estado Git Actual
- Rama a crear: `feat/po-08-mixed-payments`
- Comando: `git checkout -b feat/po-08-mixed-payments`

---

### Plan de Acción Atómico

#### Tarea 1: Estructuras de Datos y Types
**Objetivo**: Definir contratos de datos para soportar pagos múltiples.
1.  Crear interfaz `PaymentTransaction` en `src/types/index.ts`.
2.  Actualizar store `cart.ts` para aceptar pagos mixtos (opcional, o manejarlo en POS).
3.  *TIEMPO ESTIMADO: 10 min*

#### Tarea 2: UX Checkout Layout (Shell)
**Objetivo**: Transformar `CheckoutModal.vue` de Tabs a Lista.
1.  Eliminar lógica de Tabs (`currentTab`).
2.  Crear sección superior "Resumen" (Total, Cubierto, Restante).
3.  Crear sección media "Lista de Pagos" (v-for `payments`).
4.  Crear sección inferior "Agregar Pago" (Selector + Input).
5.  *TIEMPO ESTIMADO: 20 min*

#### Tarea 3: Lógica de Negocio (Engine)
**Objetivo**: Implementar matemática de pagos acumulativos.
1.  Implementar `computed.remainingBalance`.
2.  Implementar `addPayment()` con validación: `amount <= remainingBalance` (excepto Efectivo).
3.  Asegurar que **Nequi/Transferencia** pida Referencia.
4.  Implementar `removePayment()`.
5.  *TIEMPO ESTIMADO: 20 min*

#### Tarea 4: Integración POS (Wiring)
**Objetivo**: Conectar el nuevo modal con `POSView.vue`.
1.  Actualizar evento `@complete` en modal para emitir `PaymentTransaction[]`.
2.  Refactorizar `POSView.vue:completeSale` para iterar sobre los pagos y registrar cada uno.
3.  *TIEMPO ESTIMADO: 15 min*

---

### Bloque de Prompt para Antigravity

#### Prompt 1: Tarea 2+3 (CheckoutModal Refactor)
```markdown
## Prompt para Refactorización de CheckoutModal (PO-08)

### Contexto
- Archivo: `src/components/sales/CheckoutModal.vue`
- Meta: Permitir Pagos Mixtos (Efectivo + Nequi + Fiado).

### Objetivo
Reemplazar la interfaz actual de "Pestañas" por una interfaz de "Lista Acumulativa".

### Cambios Requeridos
1. **Estado**:
   - Eliminar `activeMethod`.
   - Crear `payments = ref<Array<{ method: string, amount: Decimal, reference?: string }>>([])`.
   - Crear `tempAmount` y `tempMethod` para el formulario de adición.

2. **Template**:
   - **Header**: Mostrar Total Venta, Total Pagado (Suma de `payments`), y Saldo Restante.
   - **Body**: Mostrar tabla/lista de pagos agregados con botón "Eliminar".
   - **Footer**: Formulario para agregar pago.
     - Input Monto (Autocompleta con *Saldo Restante*).
     - Select Método (Efectivo, Nequi, Fiado).
     - Botón "Agregar" (Deshabilitado si monto es 0).

3. **Validaciones**:
   - No permitir completar venta si `Saldo Restante > 0`.
   - Si método es "Efectivo", permitir monto mayor al restante (Genera cambio/vueltas).
   - Si método es "Nequi"/"Fiado", bloquear monto mayor al restante.

### Definición de Hecho (DoD)
- El usuario puede agregar $20.000 Efectivo y $30.000 Nequi para una venta de $50.000.
- El botón "Finalizar Venta" emite el array `payments`.
```

#### Prompt 2: Tarea 4 (Integración POS)
```markdown
## Prompt para Integración POS (PO-08)

### Contexto
- Archivo: `src/views/POSView.vue`
- Función: `completeSale()`

### Objetivo
Adaptar `completeSale` para procesar un array de pagos en lugar de un método único.

### Cambios Requeridos
1. **Firma de Función**:
   - Cambiar `(paymentMethod: string, amountReceived?: Decimal)`
   - A `(payments: Array<{ method: string, amount: Decimal, reference?: string }>)`.

2. **Procesamiento**:
   - Calcular `amountReceived` total sumando los pagos.
   - Calcular `change` (Vueltas) tomando solo la porción de Efectivo (si aplica) o Total Pagado - Total Venta.
   - **Importante**: `salesStore.addSale` y `cashRegisterStore` deben registrar los metodos correctamente.
   - *Nota*: Si el backend actual (Supabase) solo soporta 1 método por venta, concatenar en string "MIXED: Cash($20) + Nequi($30)" temporalmente o registrar la transacción principal como "Mixta" y los detalles en notas.
```

### Comandos de Consola
```bash
# 1. Crear rama
git checkout -b feat/po-08-mixed-payments

# 2. Instalar dependencias (si hay nuevas, aquí no aplica)
# npm install ...
```
