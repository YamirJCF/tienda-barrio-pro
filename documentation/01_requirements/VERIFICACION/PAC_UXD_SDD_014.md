# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-014)

> **Componente Auditado:** `frontend/src/components/ForceSaleModal.vue` (y composable `frontend/src/composables/useSaleProcessor.ts`, vista `frontend/src/views/POSView.vue`, repositorio `frontend/src/data/repositories/saleRepository.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_014_VENTA_FORZADA_Y_AUDITORIA.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_014_VENTA_FORZADA_Y_AUDITORIA.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/components/ForceSaleModal.vue`
- **Capa de Control y Orquestación:**
  - `frontend/src/composables/useSaleProcessor.ts`
  - `frontend/src/views/POSView.vue`
  - `frontend/src/data/repositories/saleRepository.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contratos de Interfaz (Payloads)

### 5.1 Procedimiento Almacenado: `rpc_force_sale`

#### 5.1.1 Payload de Solicitud (Request)
Invocado exclusivamente desde la terminal POS cuando un administrador aprueba el forzado de ítems en déficit:
```json
{
  "p_store_id": "UUID (Obligatorio)",
  "p_client_id": "UUID (Opcional)",
  "p_payment_method": "TEXT (Obligatorio: 'efectivo', 'nequi', 'daviplata', 'fiado')",
  "p_amount_received": "NUMERIC >= 0 (Opcional, requerido para efectivo)",
  "p_items": [
    {
      "product_id": "UUID (Obligatorio)",
      "quantity": "NUMERIC > 0 (Obligatorio)"
    }
  ],
  "p_justification": "TEXT (Obligatorio, >= 10 caracteres)"
}
```

#### 5.1.2 Payload de Respuesta Exitosa (Response Success)
```json
{
  "success": true,
  "data": {
    "sale_id": "UUID",
    "ticket_number": 1048,
    "total": 15000,
    "rounding_difference": 0,
    "change_given": 5000,
    "payment_method": "efectivo",
    "items_count": 1,
    "adjusted_products": [
      {
        "product_id": "UUID",
        "deficit_injected": 3,
        "cost_unit": 3500
      }
    ],
    "audit_logged": true,
    "created_at": "2026-10-15T01:45:00.000Z"
  }
}
```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_force_sale`
- **Campo `p_store_id`:**
  - Código real: `saleRepository.ts:309` pasa `storeId`. Presente.
- **Campo `p_client_id`:**
  - Código real: `saleRepository.ts:310` pasa `saleData.clientId || null`. Presente.
- **Campo `p_payment_method`:**
  - Código real: `saleRepository.ts:311` pasa método mapeado a 'efectivo' si es cash o mixed. Presente.
- **Campo `p_amount_received`:**
  - Código real: En `saleRepository.ts:308-314`, el objeto `rpcPayload` omite completamente `p_amount_received`. Si la venta forzada se cobra en efectivo, no se envía el monto entregado por el cliente, quebrando el cálculo de cambio y liquidación de gaveta.
  - Resultado: **Campo Ausente en Payload**.
- **Campo `p_items`:**
  - Código real: `saleRepository.ts:312` pasa `p_items: [{ product_id, quantity }]`. Presente.
- **Campo `p_justification`:**
  - Código real: `ForceSaleModal.vue:52, 85` valida `justification.value.length >= 10` y lo transmite como `p_justification` (`saleRepository.ts:313`). Presente.

### B2.5 CHECKPOINT Bloque 2
Se comprueba la omisión del parámetro `p_amount_received` en la llamada a `rpc_force_sale`.

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 Búsqueda de Cálculos en Cliente:**
  - En `useSaleProcessor.ts:234-237`:
    ```typescript
    // Update inventory locally (Fase 5b fix: forceSale wasn't updating local stock)
    saleItems.forEach(item => {
        inventoryStore.adjustStockLocal(item.productId, new Decimal(item.quantity).neg());
    });
    ```
    El cliente fuerza artificialmente el stock a valores negativos (`neg()`) en el store local. Sin embargo, en el modelo de base de datos de SDD-014, el backend inyecta una capa de lote de emergencia (`inventory_batches`) con `deficit_injected` para absorber la venta sin que el stock físico opere jamás en negativo.
  - En `ForceSaleModal.vue:80-82`: `totalDeficit` calculado con `.reduce()` en cliente.
- **B2.7 CHECKPOINT Bloque 2b:**
  - La alteración local de stock a números negativos en el frontend vulnera la regla de Backend Authority de inventarios no negativos. Marcado como **Severidad ALTA**.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del SDD (SDD-014 §3)
1. `DeteccionDeficit` -> Detección de falta de existencias en checkout.
2. `ModalForzadoActivo` -> Formulario con justificación obligatoria (>= 10 caracteres).
3. `EnvioOnlineObligatorio` -> Bloqueo estricto si está offline (acción exclusiva online).
4. `AsientoAuditoria` -> Registro en `audit_logs` con `severity = 'warning'`.

### B3.9 Búsqueda en Código
- **Estado 1:** `useSaleProcessor.ts:189` (`if (cartStore.hasForcedItems && authStore.isAdmin && navigator.onLine)`). **Conforme**.
- **Estado 2:** `ForceSaleModal.vue:30-38, 52` (textarea con contador y botón deshabilitado si < 10 caracteres). **Conforme**.
- **Estado 3:** `saleRepository.ts:282-288` (rechaza explícitamente en offline con mensaje descriptivo). **Conforme**.
- **Estado 4:** Informado en el modal: "🔒 Esta acción quedará registrada en el log de auditoría" (`ForceSaleModal.vue:41-43`). **Conforme**.

### B3.10 Cruce Explícito
Todos los estados del flujo de excepción cuentan con reflejo en código.

### B3.11 CHECKPOINT Bloque 3
Conforme en flujo de contención operativa y advertencia de auditoría.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12 Formateo:**
  - En `ForceSaleModal.vue:22-24`, muestra cantidades con unidad física (`item.unit`).
- **B4.13 CHECKPOINT Bloque 4:**
  - Conforme.

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 Restricciones:**
  - Autorización exclusiva de Administrador. Si opera un cajero, el SDD contempla elevación temporal mediante credencial/PIN de administrador.
- **B5.15 Implementación:**
  - En `useSaleProcessor.ts:189`, se condiciona estrictamente con `authStore.isAdmin`. Si un cajero regular encuentra stock en cero, el modal no se despliega y la venta simplemente falla sin opción de solicitar PIN de supervisor.
- **B5.16 CHECKPOINT Bloque 5:**
  - Restricción básica implementada; pendiente elevación de permisos en caliente.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | Omisión del parámetro `p_amount_received` en `saleRepository.ts:308-314` al invocar `rpc_force_sale`, impidiendo el cálculo de cambio y registro formal de efectivo en caja para ventas forzadas de contado (SDD-014 §5.1.1). | Bloque 2 (B2.4) | 🔴 Alta |
| UX-2 | Ajuste manual local de stock a valores negativos en `useSaleProcessor.ts:234-237` (`adjustStockLocal(..., neg())`), quebrantando el diseño de SDD-014 donde el backend inyecta lotes de emergencia y el stock físico jamás debe operar en negativo. | Bloque 2b (B2.6) | 🔴 Alta |
| UX-3 | Ausencia de mecanismo de elevación de privilegios (PIN o contraseña de administrador en caliente) en `useSaleProcessor.ts:189`, dejando a los cajeros regulares sin posibilidad de solicitar autorización en mostrador. | Bloque 5 (B5.15) | 🟡 Media |
| UX-4 | Suma de unidades en déficit calculada mediante acumulador client-side en `ForceSaleModal.vue:80-82` (`totalDeficit`). | Bloque 2b (B2.6) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:**
  - Al identificarse 2 hallazgos de severidad ALTA (UX-1, UX-2), el frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. Incluir `p_amount_received` en el payload de `saleRepository.forceSale` cuando el método de pago sea en efectivo.
2. Eliminar el decremento artificial a números negativos en `useSaleProcessor.ts:236` y sustituirlo por una sincronización reactiva del stock real retornado por el backend tras la inyección del lote.
3. Evaluar la incorporación de un modal de autorización con PIN de supervisor para cajeros en terminal POS.
