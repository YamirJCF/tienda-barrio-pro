# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-007-01)

> **Componente Auditado:** `frontend/src/views/POSView.vue` (y componentes auxiliares `frontend/src/components/sales/CheckoutModal.vue`, `frontend/src/components/WeightCalculatorModal.vue`; composables `frontend/src/composables/useSaleProcessor.ts`, store `frontend/src/stores/sales.ts`, repositorios `frontend/src/data/repositories/saleRepository.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_007_01_NUCLEO_POS.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_007_01_NUCLEO_POS.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/POSView.vue`
- **Componentes Auxiliares:**
  - `frontend/src/components/sales/CheckoutModal.vue`
  - `frontend/src/components/WeightCalculatorModal.vue`
- **Capa de Control y Repositorios:**
  - `frontend/src/composables/useSaleProcessor.ts`
  - `frontend/src/stores/cart.ts`
  - `frontend/src/stores/sales.ts`
  - `frontend/src/data/repositories/saleRepository.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.1 Operación: `rpc_procesar_venta_v3` (Procesamiento de Venta Atómica)
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Entrada (Request JSON):**
  ```json
  {
    "p_store_id": "UUID (Obligatorio)",
    "p_client_id": "UUID (Opcional, obligatorio si p_payment_method = 'fiado')",
    "p_payment_method": "TEXT (Obligatorio: 'efectivo', 'nequi', 'daviplata', 'fiado'. Prohibido 'mixed')",
    "p_amount_received": "NUMERIC >= 0 (Opcional, requerido si p_payment_method = 'efectivo')",
    "p_idempotency_key": "UUID (Opcional, identificador único de transacción para reintentos seguros)",
    "p_local_id": "TEXT (Opcional, identificador local de sincronización offline)",
    "p_is_offline_sync": "BOOLEAN (Opcional, default false. Si true, el backend honra/audita precios históricos congelados)",
    "p_items": [
      {
        "product_id": "UUID (Obligatorio)",
        "quantity": "NUMERIC > 0 (Obligatorio, entero en unitarios, máx 2 decimales en pesables)",
        "unit_price": "NUMERIC > 0 (Opcional, solo transmitido en sincronización offline diferida p_is_offline_sync = true)"
      }
    ]
  }
  ```
- **Salida Exitosa (HTTP 200 - Response JSON):**
  ```json
  {
    "success": true,
    "data": {
      "sale_id": "UUID",
      "ticket_number": 1045,
      "total": 35000,
      "rounding_difference": 0,
      "amount_received": 50000,
      "change_given": 15000,
      "payment_method": "efectivo",
      "items_count": 3,
      "created_at": "2026-10-15T14:30:00Z"
    }
  }
  ```
- **Salida de Error (Excepciones Tipificadas):**
  ```json
  {
    "success": false,
    "error": "Mensaje técnico descriptivo de la falla",
    "code": "NO_OPEN_CASH_SESSION | CREDIT_LIMIT_EXCEEDED | INSUFFICIENT_STOCK | STORE_ACCESS_DENIED | INVALID_PAYMENT_METHOD | CART_LIMIT_EXCEEDED"
  }
  ```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_procesar_venta_v3`
- **Firma de la Función RPC Invocada:**
  - Código real: En `saleRepository.ts:168`:
    ```typescript
    const { data, error } = await supabase.rpc('rpc_procesar_venta_v2', rpcPayload);
    ```
  - Contrato: SDD-007-01 §5.1 exige terminantemente la invocación a `rpc_procesar_venta_v3`.
  - Resultado: **Versión Obsoleta de RPC (`v2` en lugar de `v3`)**.
- **Parámetros `p_idempotency_key`, `p_local_id`, `p_is_offline_sync`:**
  - Código real: En `saleRepository.ts:158-166`, el objeto `rpcPayload` no define ni transmite estos tres parámetros requeridos por la versión v3.
  - Resultado: **Ausentes en Payload**.
- **Parámetro `p_payment_method`:**
  - Código real: En `useSaleProcessor.ts:101-103`:
    ```typescript
    const derivePrimaryMethod = (payments: PaymentTransaction[]): string => {
        const uniqueMethods = new Set(payments.map(p => p.method));
        return uniqueMethods.size > 1 ? 'mixed' : payments[0].method;
    };
    ```
    Y en `saleRepository.ts:163`:
    ```typescript
    p_payment_method: (saleData.paymentMethod === 'mixed' || saleData.paymentMethod === 'cash') ? 'efectivo' : saleData.paymentMethod
    ```
  - Contrato: SDD-007-01 §5.1 prohíbe taxativamente `'mixed'` en el checkout online (`p_payment_method: 'TEXT (Obligatorio... Prohibido mixed)'`).
  - Resultado: **Transgresión de Regla de Negocio (Manejo de 'mixed')**.

### B2.5 CHECKPOINT Bloque 2
Se detectan fallas sustanciales en el transporte: uso de la versión v2 del RPC, omisión de llaves de idempotencia y soporte no autorizado para pagos mixtos.

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 Búsqueda de Cálculos en Cliente:**
  - En `useSaleProcessor.ts:159`, la venta se registra enviando `total: cartStore.total` y `roundingDifference: new Decimal(0)`.
  - En `saleRepository.ts:178-180`:
    ```typescript
    if (data && data.success) {
        return { success: true, id: data.sale_id, ticketNumber: data.ticket_number };
    }
    ```
    El cliente descarta el `total`, `rounding_difference` y `change_given` liquidados por el backend, manteniendo en la UI el total sumado en el cliente.
  - En `POSView.vue:169-171`, el `ticketNumber` se pre-calcula localmente mediante `nextTicketNumber` en lugar de esperar la confirmación de la base de datos.
- **B2.7 CHECKPOINT Bloque 2b:**
  - El frontend preserva totales calculados por su propio carrito y pre-asigna números de ticket en lugar de acatar plenamente la autoridad financiera del backend. Marcado como **Severidad ALTA**.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del SDD
1. `CarritoVacio` -> Teclado numérico listo / Estado neutral.
2. `EnCheckout` -> Modal de selección de método de pago.
3. `RechazoCajaCerrada` (`NO_OPEN_CASH_SESSION`) -> Bloqueo de cobro con botón de apertura.
4. `RechazoCupoExcedido` (`CREDIT_LIMIT_EXCEEDED`) -> Advertencia de límite de fiado superado.
5. `RechazoStockInsuficiente` (`INSUFFICIENT_STOCK`) -> Alerta y oferta de venta forzada si aplica.
6. `VentaExitosa` -> Notificación con ticket oficial y limpieza de carrito.

### B3.9 Búsqueda en Código
- **Estado 1 y 2:** `POSView.vue:20, 96` (`<CheckoutModal v-model="showCheckout" ... />`). **Conforme**.
- **Estado 3:** `POSView.vue:76-83` (`blockingState` detecta `!cashRegisterStore.isOpen` y redirige a `/cash-control`). **Conforme**.
- **Estado 4:** `useSaleProcessor.ts` captura el error y lo propaga a la UI. **Conforme**.
- **Estado 5:** `POSView.vue:106-110` (`showForceSaleModal`, `handleForceSale`). **Conforme**.
- **Estado 6:** `useSaleProcessor.ts:68` (`showSaleSuccess`). **Conforme**.

### B3.10 Cruce Explícito
Todos los estados operativos y excepciones tipificadas cuentan con componente visual o manejador en el ciclo de vida del POS.

### B3.11 CHECKPOINT Bloque 3
Manejo de estados reactivos y transiciones visuales completo.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12 Formateo:**
  - En `POSView.vue:49`: `const { formatWithSign: formatCurrency } = useCurrencyFormat();`
  - En `CheckoutModal.vue:36`: `const { formatCurrency } = useCurrencyFormat();`
  - En `WeightCalculatorModal.vue`: Respeta el redondeo oficial en pesables.
- **B4.13 CHECKPOINT Bloque 4:**
  - Conforme en formateo de moneda y cantidades pesables.

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 Restricciones:**
  - La acción de vender requiere `canSell = true`. El pago a crédito (fiado) exige además `canFiar = true`.
- **B5.15 Implementación:**
  - En `POSView.vue:63-64, 68-75`: `canSell` y `canFiar` validados desde `authStore`, bloqueando la pantalla con `blockingState` si el usuario carece de permiso.
- **B5.16 CHECKPOINT Bloque 5:**
  - Conforme con la política de control de acceso.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | Invocación desactualizada a `rpc_procesar_venta_v2` en lugar de `rpc_procesar_venta_v3` en `saleRepository.ts:168`, omitiendo los parámetros contractuales `p_idempotency_key`, `p_local_id` y `p_is_offline_sync` de SDD-007-01 §5.1. | Bloque 2 (B2.4) | 🔴 Alta |
| UX-2 | Derivación y soporte del método de pago `'mixed'` en `useSaleProcessor.ts:102` y mapeo improvisado a `'efectivo'` en `saleRepository.ts:163`, contraviniendo la prohibición explícita de `payment_method = 'mixed'` en SDD-007-01 §5.1. | Bloque 2 (B2.4) | 🔴 Alta |
| UX-3 | Omisión del retorno contable oficial del backend (`total`, `rounding_difference`, `change_given`) en `saleRepository.ts:178-180`, reteniendo los subtotales calculados por el cliente (`cartStore.total`) tras la confirmación de la venta. | Bloque 2b (B2.6) | 🔴 Alta |
| UX-4 | Estimación y cálculo del número de ticket (`nextTicketNumber`) en el frontend (`POSView.vue:169-171` y `salesStore.ts:201, 232`) en lugar de tomar exclusivamente el consecutivo seguro retornado por la base de datos. | Bloque 2b (B2.6) | 🟡 Media |
| UX-5 | Uso de alias `formatWithSign` como `formatCurrency` en `POSView.vue:49` en lugar de la función canónica de `useCurrencyFormat` (SPEC-011). | Bloque 4 (B4.12) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:**
  - Al identificarse 3 hallazgos de severidad ALTA (UX-1, UX-2, UX-3), el frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. Actualizar `saleRepository.ts` para invocar exclusivamente `rpc_procesar_venta_v3`, suministrando `p_idempotency_key` y la estructura formal de ítems.
2. Eliminar el soporte para pagos mixtos (`mixed`) en `useSaleProcessor.ts` y `CheckoutModal.vue`, restringiendo cada venta a una sola modalidad autorizada ('efectivo', 'nequi', 'daviplata', 'fiado').
3. Capturar y sincronizar en el store el `total`, `rounding_difference` y `change_given` devueltos en el payload exitoso del RPC.
