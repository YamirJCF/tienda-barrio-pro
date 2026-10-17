# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-006-01-01)

> **Componente Auditado:** `frontend/src/views/StockEntryView.vue` (y capas de repositorio `frontend/src/data/repositories/productRepository.ts`, store `frontend/src/stores/inventory.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_006_01_01_MOVIMIENTOS_ENTRADA.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_006_01_01_MOVIMIENTOS_ENTRADA.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/StockEntryView.vue`
- **Capa de Datos:** `frontend/src/stores/inventory.ts`, `frontend/src/stores/payables.ts`, `frontend/src/data/repositories/productRepository.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.1 Operación: `rpc_registrar_entrada`
- **Tipo:** RPC Postgres / Acción Transaccional (WRITE)
- **Firma Canónica Obligatoria:** 9 Parámetros

#### Entradas (Payload JSON):
```json
{
  "p_product_id": "UUID (Obligatorio, ID del producto en products)",
  "p_quantity": "NUMERIC > 0 (Obligatorio, cantidad física recepcionada)",
  "p_purchase_price": "NUMERIC >= 0 (Obligatorio, costo unitario de adquisición)",
  "p_sale_price": "NUMERIC >= 0 (Obligatorio, precio de venta para el lote, múltiplo de $50)",
  "p_reason": "TEXT (Opcional, Default: 'Entrada de mercancía', motivo de auditoría)",
  "p_supplier_id": "UUID (Opcional, ID del proveedor en suppliers)",
  "p_payment_type": "TEXT (Condicionalmente Obligatorio si p_supplier_id != NULL: 'contado' | 'credito')",
  "p_invoice_reference": "TEXT (Opcional, número físico de la factura de compra)",
  "p_reference_invoice_id": "UUID (Opcional, enlace a supplier_invoices si aplica)"
}
```

#### Salida Exitosa (Formato Unidireccional de Acción):
```json
{
  "success": true,
  "data": {
    "movement_id": "UUID_DEL_MOVIMIENTO_KARDEX",
    "batch_id": "UUID_DEL_LOTE_FIFO_CREADO",
    "product_id": "UUID_DEL_PRODUCTO",
    "new_stock": 75.00
  }
}
```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_registrar_entrada`
- **Parámetros del Payload:**
  - Código real: `StockEntryView.vue:436-448` y `productRepository.ts:430-440` transmiten los 9 parámetros requeridos (`p_product_id`, `p_quantity`, `p_purchase_price`, `p_sale_price`, `p_reason`, `p_supplier_id`, `p_payment_type`, `p_invoice_reference`, `p_reference_invoice_id`).
  - Resultado: **Firma de parámetros individuales conforme**.
- **Canal de Envío e Integridad de Factura:**
  - Código real: `StockEntryView.vue:432-456` ejecuta un bucle iterativo en cliente (`for (const item of entryItems.value)`) enviando llamadas RPC individuales. Si el ítem 3 de 5 falla, los ítems 1 y 2 ya impactaron Kardex y Lotes FIFO sin posibilidad de reversión atómica de la factura global.
  - Resultado: **Falla de Atomicidad Transaccional por Iteración Client-Side**.

### B2.5 CHECKPOINT Bloque 2
La firma unitaria del RPC es respetada, pero la recepción multifila se ejecuta sin transacción compuesta.

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 Búsqueda de Cálculos en Cliente:**
  - En `StockEntryView.vue:185`: `Subtotal: {{ formatCurrency(item.quantity * item.unitCost) }}` calculado en el template.
  - En `StockEntryView.vue:321-323`:
    ```typescript
    const totalInvoice = computed(() => {
      return entryItems.value.reduce((sum, item) => sum + (item.quantity * item.unitCost), 0);
    });
    ```
- **B2.7 CHECKPOINT Bloque 2b:**
  - Cálculos de subtotales y total de factura realizados en el frontend.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del Diagrama de Estados (SDD-006-01-01 §3)
1. `FormularioDiligenciado` -> Captura de líneas de entrada.
2. `ValidacionSeguridad` -> Verificación de acceso y datos positivos.
3. `RechazoTransaccion` -> Notificación de error y bloqueo de botón.
4. `RegistroKardex` -> Generación de movimiento y lote FIFO.

### B3.9 Búsqueda en Código
- **Estado 1:** `StockEntryView.vue:108-188` (Lista reactiva de ítems). **Conforme**.
- **Estado 2 y 3 (Manejo de Errores):**
  - En `StockEntryView.vue:452-454`, si un ítem falla dentro del bucle, solo hace `console.error(...)`. Si al menos un ítem tuvo éxito, el sistema salta a la línea 474 e informa: `"Entrada registrada exitosamente"`, silenciando que uno o más ítems fueron rechazados por el backend (violación de la Regla 3).
  - Resultado: **Falla de Silenciamiento de Error Parcial**.
- **Estado 4:** Gestionado reactivamente al redirigir al catálogo de inventario tras el éxito.

### B3.10 Cruce Explícito
- Estado 1: Sí.
- Estado 2: Sí.
- Estado 3: No (errores parciales silenciados).
- Estado 4: Sí.

### B3.11 CHECKPOINT Bloque 3
Se constata silenciamiento de errores cuando falla una parte del lote de entrada.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12 Formateo:**
  - En `StockEntryView.vue:400-406`:
    ```typescript
    const formatCurrency = (amount: number) => {
      return new Intl.NumberFormat('es-CO', { 
        style: 'currency', 
        currency: 'COP',
        maximumFractionDigits: 0 
      }).format(amount);
    };
    ```
  - No consume el composable oficial `useCurrencyFormat`.
- **B4.13 CHECKPOINT Bloque 4:**
  - Discrepancia menor por implementación paralela de formateador monetario.

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 Restricciones:**
  - La recepción física de mercancía está reservada para personal con `canManageInventory`.
- **B5.15 Implementación:**
  - El acceso a la ruta `/stock-entry` está resguardado por router guards y el botón FAB en `InventoryView.vue:298` está protegido por `v-if="canManageInventory"`.
- **B5.16 CHECKPOINT Bloque 5:**
  - Conforme en restricción de rol.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | Procesamiento de entrada multifila mediante bucle client-side en `StockEntryView.vue:432-456`, ejecutando llamadas atómicas aisladas que carecen de transacción unificada para toda la factura de recepción física. | Bloque 2 (B2.4) | 🔴 Alta |
| UX-2 | Silenciamiento de errores en inserciones parciales (`StockEntryView.vue:452-460`): si algunos ítems fallan pero al menos uno tiene éxito, el sistema emite notificación de éxito general y oculta el fallo de los productos no registrados (Regla 3). | Bloque 3 (B3.9) | 🔴 Alta |
| UX-3 | Conflicto de conectividad: `StockEntryView.vue:470` declara `checkConnectivity: false` permitiendo el envío en modo offline, mientras `productRepository.ts:423-425` aborta lanzando `OFFLINE_NOT_ALLOWED`. | Bloque 2 (B2.4) | 🟡 Media |
| UX-4 | Cálculo de subtotales por producto y total de entrada en el cliente (`StockEntryView.vue:185, 321-323`). | Bloque 2b (B2.6) | 🟡 Media |
| UX-5 | Uso de formateo monetario manual con `Intl.NumberFormat` en `StockEntryView.vue:400-406` en lugar de consumir `useCurrencyFormat` (SPEC-011). | Bloque 4 (B4.12) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:**
  - Al identificarse 2 hallazgos de severidad ALTA (UX-1, UX-2), el frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. Implementar reporte explícito de fallos por producto en `StockEntryView.vue` para que ningún ítem rechazado pase desapercibido.
2. Considerar el empaquetado del payload de entrada en una estructura transaccional única en backend o rollback defensivo en frontend.
3. Activar `checkConnectivity: true` en `useAsyncAction` de `StockEntryView.vue` para prevenir intentos de recepción de stock cuando el dispositivo se encuentre sin red.
4. Estandarizar la función `formatCurrency` migrándola a `useCurrencyFormat`.
