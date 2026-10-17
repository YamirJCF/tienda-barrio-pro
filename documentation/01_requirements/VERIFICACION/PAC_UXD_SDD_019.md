# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-019)

> **Componente Auditado:** `frontend/src/views/PayablesView.vue` y `frontend/src/components/suppliers/PayInvoiceModal.vue` (y store `frontend/src/stores/payables.ts`, `frontend/src/views/SuppliersView.vue`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_019_CUENTAS_POR_PAGAR.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_019_CUENTAS_POR_PAGAR.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/PayablesView.vue`
- **Componentes Auxiliares:**
  - `frontend/src/components/suppliers/PayInvoiceModal.vue`
  - `frontend/src/views/SuppliersView.vue`
- **Capa de Datos:** `frontend/src/stores/payables.ts` y `frontend/src/stores/suppliers.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contratos de Interfaz (RPC y JSON Schemas)

### 5.1 Especificación: `rpc_crear_factura_proveedor`
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Parámetros de Entrada:**
  - `p_store_id`: UUID (Not Null)
  - `p_supplier_name`: TEXT (Not Null)
  - `p_total_amount`: NUMERIC (Not Null, > 0)
  - `p_due_date`: DATE (Nullable)
  - `p_invoice_number`: TEXT (Nullable)
  - `p_reference_inventory_id`: UUID (Nullable)

### 5.2 Especificación: `rpc_pay_supplier_invoice`
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Parámetros de Entrada:**
  ```json
  {
    "p_invoice_id": "UUID (Obligatorio)",
    "p_amount": "NUMERIC > 0 (Obligatorio, <= saldo_pendiente)",
    "p_payment_method": "TEXT (Obligatorio: 'externo' | 'efectivo' | 'nequi' | 'llave_bre' | 'daviplata')",
    "p_description": "TEXT (Obligatorio para pagos internos con fondos de caja)"
  }
  ```
- **Payload de Respuesta Exitosa:**
  ```json
  {
    "success": true,
    "data": {
      "invoice_id": "UUID",
      "amount_paid": 50000.00,
      "remaining_balance": 25000.00
    }
  }
  ```
- **Catálogo de Errores:**
  | Código de Error | Causa | Mensaje Técnico |
  |-----------------|-------|-----------------|
  | `STORE_ACCESS_DENIED` | Usuario no pertenece a la tienda | Sin acceso a esta tienda |
  | `INSUFFICIENT_FUNDS` | Canal monetario sin saldo suficiente | Fondos insuficientes en el canal seleccionado |
  | `NO_OPEN_CASH_SESSION` | Intento de pago interno sin caja abierta | No existe turno de caja abierto |
  | `SHIFT_EXPIRED` | Turno de caja superó 24 horas | El turno de caja ha expirado |
  | `PAYMENT_EXCEEDS_BALANCE` | Monto superior al saldo pendiente | El abono excede el saldo pendiente |
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_pay_supplier_invoice`
- **Campo `p_invoice_id`:**
  - Código real: `PayInvoiceModal.vue:189` pasa `props.invoice.id`. Presente.
- **Campo `p_amount`:**
  - Código real: `PayInvoiceModal.vue:189` pasa `Number(amountToPay.value)`. Presente.
- **Campo `p_payment_method`:**
  - Código real: `PayInvoiceModal.vue:64-93` ofrece exclusivamente `['efectivo', 'nequi', 'daviplata']`.
  - Contrato: SDD-019 §2.3 y §5.2 define obligatoriamente la modalidad `'externo'` para abonos efectuados con fondos ajenos a la caja que no requieren turno abierto.
  - Resultado: **Modalidad `'externo'` Ausente (Falla Crítica de Contrato)**.
- **Campo `p_description`:**
  - Código real: `PayInvoiceModal.vue:189` omite el parámetro de descripción en la llamada a `payablesStore.payInvoice`.
  - Resultado: **Parámetro Ausente en Frontend**.

### B2.5 CHECKPOINT Bloque 2
Se comprueban discrepancias críticas: incapacidad de registrar abonos externos y omisión del campo de descripción requerido para la trazabilidad del egreso de caja.

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 Búsqueda de Cálculos en Cliente:**
  - En `PayablesView.vue:230-240`:
    ```typescript
    const totalDebt = computed(() => {
      return filteredInvoices.value
        .filter(inv => inv.status !== 'pagada')
        .reduce((sum, inv) => sum + (inv.total_amount - inv.amount_paid), 0);
    });

    const totalOverdue = computed(() => {
      return filteredInvoices.value
        .filter(inv => inv.status === 'vencida')
        .reduce((sum, inv) => sum + (inv.total_amount - inv.amount_paid), 0);
    });
    ```
- **B2.7 CHECKPOINT Bloque 2b:**
  - Los totales de cartera vencida y saldo global de deudas se computan mediante acumuladores JavaScript en el cliente en lugar de recibir los KPIs calculados por el backend.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del SDD
1. `Caja Cerrada / Pago Interno Bloqueado` -> Bloquea pagos internos pero DEBE permitir abonos externos (Caso C y Caso E).
2. `Fondos Insuficientes` -> Bloqueo estricto anti-sobregiro (`INSUFFICIENT_FUNDS`).
3. `Factura Pendiente / Vencida / Pagada` -> Chips de estado e indicadores de color.
4. `Cargando Facturas` -> Skeleton reactivo.
5. `Sin Facturas` -> Empty State "Todo al día".

### B3.9 Búsqueda en Código
- **Estado 1 (Caja Cerrada):**
  - En `PayInvoiceModal.vue:20-24`, si la caja está cerrada se bloquea el formulario por completo:
    ```html
    <div v-if="!cashRegisterStore.isOpen" ...>
      <p>⛔ Debes tener un turno de caja abierto para registrar un pago.</p>
    </div>
    ```
  - Contrato: Viola el flujo de Abono Externo de SDD-019 §2.3 donde el dueño puede abonar con fondos propios independientemente de si hay un turno de caja abierto.
- **Estado 2 (Sobregiro y Fondos Insuficientes):**
  - En `PayInvoiceModal.vue:52-58`, el componente incluye un "Soft Warning":
    ```html
    <div v-if="amountExceedsCash && !amountExceedsPending" ...>
      <p>Este abono dejará el saldo de la caja en negativo. Deberás justificar el faltante en el cierre.</p>
    </div>
    ```
  - Y la validación `canSubmit` (líneas 162-169) permite el envío. Esto induce al usuario al error, ya que el backend prohíbe terminantemente el saldo negativo y aborta con excepción `INSUFFICIENT_FUNDS`.
- **Estados 3, 4, 5:**
  - `PayablesView.vue:95-109` (Skeleton). **Conforme**.
  - `PayablesView.vue:117-121` (Bordes de color dinámicos según estado). **Conforme**.
  - `PayablesView.vue:171-180` (Empty State). **Conforme**.

### B3.10 Cruce Explícito
- Estado 1: No conforme (bloqueo excesivo que anula abonos externos).
- Estado 2: No conforme (soft warning induce a excepción del backend).
- Estado 3: Sí.
- Estado 4: Sí.
- Estado 5: Sí.

### B3.11 CHECKPOINT Bloque 3
Dos de los flujos de validación operativa presentan divergencias sustanciales frente a las reglas de negocio de SDD-019.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12 Formateo:**
  - En `PayablesView.vue:200` y `PayInvoiceModal.vue:123`: `import { formatCurrency } from '@/utils/currency';`
  - Utiliza la función auxiliar directa en lugar del composable oficial estandarizado `useCurrencyFormat`.
- **B4.13 CHECKPOINT Bloque 4:**
  - Discrepancia menor en importación de composable.

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 Restricciones:**
  - Registro de pagos y abonos reservado exclusivamente a Administradores (`authStore.isAdmin`) o empleados con permiso específico de cuentas por pagar.
- **B5.15 Implementación:**
  - `PayablesView.vue:160`: `v-if="invoice.status !== 'pagada' && authStore.isAdmin"`.
  - `PayInvoiceModal.vue:164`: `authStore.isAdmin` requerido en `canSubmit`.
- **B5.16 CHECKPOINT Bloque 5:**
  - Conforme con restricción de rol administrador.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | Ausencia de la modalidad de pago `externo` en `PayInvoiceModal.vue:64-93` y bloqueo absoluto ante caja cerrada (`PayInvoiceModal.vue:20-24`), contraviniendo el Caso C y §2.3 de SDD-019 que autoriza abonos externos con fondos propios sin requerir turno de caja abierto. | Bloque 2 (B2.4) | 🔴 Alta |
| UX-2 | Advertencia permisiva de sobregiro ("Soft Warning") en `PayInvoiceModal.vue:52-58` y `canSubmit:162-169`, sugiriendo que la caja puede operar en negativo, cuando `rpc_pay_supplier_invoice` aborta mandatoriamente con `INSUFFICIENT_FUNDS` sin tolerar sobregiros. | Bloque 3 (B3.9) | 🔴 Alta |
| UX-3 | Omisión del parámetro obligatorio `p_description` en la invocación de amortización de factura (`PayInvoiceModal.vue:189`), requerido por SDD-019 §5.2 para la auditoría del egreso de caja. | Bloque 2 (B2.4) | 🔴 Alta |
| UX-4 | Agregación de métricas de deuda total (`totalDebt`) y cartera vencida (`totalOverdue`) computadas en el cliente (`PayablesView.vue:230-240`). | Bloque 2b (B2.6) | 🟡 Media |
| UX-5 | Importación directa de `formatCurrency` desde `@/utils/currency` en `PayablesView.vue:200` y `PayInvoiceModal.vue:123` en lugar del composable oficial `useCurrencyFormat` (SPEC-011). | Bloque 4 (B4.12) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:**
  - Al identificarse 3 hallazgos de severidad ALTA (UX-1, UX-2, UX-3), el frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. Habilitar la opción de "Abono Externo (Fondos Propios)" en `PayInvoiceModal.vue`, permitiendo su envío aun cuando no haya un turno de caja abierto (`payment_method: 'externo'`).
2. Eliminar el soft warning de sobregiro en `PayInvoiceModal.vue` y bloquear el botón si el monto excede el saldo disponible en el canal seleccionado, alineándolo con la invariante `INSUFFICIENT_FUNDS`.
3. Agregar campo de motivo/descripción en `PayInvoiceModal.vue` y transmitirlo como `p_description` al RPC `rpc_pay_supplier_invoice`.
4. Estandarizar el uso de `useCurrencyFormat` en la vista y el modal.
