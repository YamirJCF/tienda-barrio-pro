# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-007-02)

> **Componente Auditado:** `frontend/src/views/HistoryView.vue` y `frontend/src/components/history/SaleDetailModal.vue` (y repositorio `frontend/src/data/repositories/saleRepository.ts`, store `frontend/src/stores/sales.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_007_NUCLEO_VENTAS_PADRE.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_007_NUCLEO_VENTAS_PADRE.md) (y especificación de comprobante [`SDD_007_02_TICKET_DE_VENTA.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_007_02_TICKET_DE_VENTA.md))  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/HistoryView.vue`
- **Componentes Auxiliares:**
  - `frontend/src/components/history/SaleDetailModal.vue`
- **Capa de Datos y Repositorios:**
  - `frontend/src/data/repositories/saleRepository.ts`
  - `frontend/src/stores/sales.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.2 Operación: `rpc_anular_venta` (Anulación Completa de Comprobante)
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Entrada:**
  ```json
  {
    "p_sale_id": "UUID (Obligatorio)",
    "p_reason": "TEXT (Obligatorio, >= 5 caracteres)",
    "p_refund_channel": "TEXT (Opcional, canal de egreso real para ventas de contado: 'efectivo', 'nequi', 'daviplata')"
  }
  ```
- **Salida Exitosa (HTTP 200):**
  ```json
  {
    "success": true,
    "data": {
      "sale_id": "UUID",
      "ticket_number": 1045,
      "is_voided": true,
      "voided_by": "UUID",
      "void_reason": "Error de digitación en caja",
      "refunded_amount": 35000,
      "refund_channel": "efectivo",
      "voided_at": "2026-10-15T15:10:00Z"
    }
  }
  ```
- **Salida de Error:**
  ```json
  {
    "success": false,
    "error": "Mensaje técnico descriptivo",
    "code": "SALE_ALREADY_VOIDED | SALE_HAS_PARTIAL_REFUNDS | NO_OPEN_CASH_SESSION | INSUFFICIENT_FUNDS_IN_CHANNEL | UNAUTHORIZED"
  }
  ```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_anular_venta`
- **Presencia de la Invocación en UI y Repositorio:**
  - Código real: En `saleRepository.ts:339-366`, `voidSale(saleId: string, reason: string)` está implementado invocando `supabase.rpc('rpc_anular_venta', { p_sale_id: saleId, p_reason: reason })`, pero omite el parámetro obligatorio `p_refund_channel` requerido para devoluciones de ventas de contado.
  - En `SaleDetailModal.vue:1-194` y en `HistoryView.vue:1-502`, **no existe ningún botón, diálogo ni modal para anular una venta**. La función del repositorio jamás es llamada desde la UI.
  - Resultado: **Ausente en UI y Parcialmente Implementado en Repositorio**.
- **Campos `p_reason` y `p_refund_channel`:**
  - Código real: Al no existir modal ni formulario de anulación, no se captura el motivo de anulación (`p_reason`, mínimo 5 caracteres) ni el canal de egreso monetario (`p_refund_channel`).
  - Resultado: **Ausente**.

### B2.5 CHECKPOINT Bloque 2
Se comprueba que la funcionalidad de anulación de venta está completamente desprovista de interfaz de usuario y de implementación en el repositorio de datos, a pesar de estar tipada en la interfaz de TypeScript.

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 Búsqueda de Cálculos en Cliente:**
  - En `SaleDetailModal.vue`, los datos mostrados son de solo lectura consumidos mediante la RPC `get_sale_detail`.
  - No se detectan cálculos financieros client-side en este componente.
- **B2.7 CHECKPOINT Bloque 2b:**
  - Conforme en la lectura pasiva de detalles de venta.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del SDD (SDD-007 §4 CL-04 a CL-08)
1. `Venta Activa (Normal)` -> Opción de anular disponible exclusivamente para Administrador.
2. `Venta Anulada Previamente` (`SALE_ALREADY_VOIDED`) -> Banner informativo inmutable "Venta Anulada" con motivo.
3. `Caja Cerrada al Devolver Contado` (`NO_OPEN_CASH_SESSION`) -> Bloqueo con orientación a abrir turno.
4. `Fondos Insuficientes en Canal de Devolución` (`INSUFFICIENT_FUNDS_IN_CHANNEL`) -> Mensaje de liquidez insuficiente.
5. `Venta con Reembolsos Parciales` (`SALE_HAS_PARTIAL_REFUNDS`) -> Bloqueo de anulación total.

### B3.9 Búsqueda en Código
- **Estado 1:** Inexistente. `SaleDetailModal.vue` no expone acción para anular.
- **Estado 2:** `SaleDetailModal.vue:108-118` renderiza el banner de venta anulada mostrando `detail.void_reason`. **Conforme para lectura**.
- **Estados 3, 4, 5:** Al carecer de formulario de acción, ninguna de las excepciones operativas puede ser disparada ni gestionada por el usuario.
  - Resultado: **Estados de Excepción Inaccesibles en UI**.

### B3.10 Cruce Explícito
- Estado 1: No implementado en UI.
- Estado 2: Sí (renderizado pasivo).
- Estado 3: No implementado en UI.
- Estado 4: No implementado en UI.
- Estado 5: No implementado en UI.

### B3.11 CHECKPOINT Bloque 3
4 de los 5 estados operativos de la anulación carecen de soporte visual.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12 Formateo:**
  - En `SaleDetailModal.vue:10`: `import { formatCurrency } from '../../utils/currency';`
  - En `SaleDetailModal.vue:164, 165, 179, 183, 188`: `formatCurrency(...)` usado en precios unitarios, subtotales y total.
- **B4.13 CHECKPOINT Bloque 4:**
  - Cumple en presentación monetaria COP, aunque importa la utilidad manual en lugar del composable `useCurrencyFormat`.

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 Restricciones:**
  - La anulación de venta es un privilegio supremo reservado exclusivamente al Administrador (SDD-007 §3.2: "Anular Venta Completa: Botón oculto para cajeros; validación estricta en rpc_anular_venta").
- **B5.15 Implementación:**
  - Dado que no existe botón de anulación en la UI, ni cajeros ni administradores pueden anular comprobantes desde la interfaz actual.
- **B5.16 CHECKPOINT Bloque 5:**
  - Bloqueo por omisión absoluta de la funcionalidad.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | Ausencia total de componente modal o botón de anulación de venta en `HistoryView.vue` y `SaleDetailModal.vue`, impidiendo a los administradores ejecutar la acción `rpc_anular_venta` definida en SDD-007 §5.2. | Bloque 2 (B2.4) | 🔴 Alta |
| UX-2 | Implementación incompleta de `voidSale` en `saleRepository.ts:339-366`: invoca `rpc_anular_venta` pero omite el parámetro obligatorio del canal de devolución `p_refund_channel` ('efectivo', 'nequi', 'daviplata') y está 100% desconectado de la UI. | Bloque 2 (B2.4) | 🔴 Alta |
| UX-3 | Ausencia de captura del canal de devolución `p_refund_channel` y validación de longitud mínima de motivo `p_reason` (>= 5 caracteres) en componentes Vue. | Bloque 2 (B2.4) | 🔴 Alta |
| UX-4 | Visualización exclusivamente pasiva de ventas anuladas en `SaleDetailModal.vue:108-118`: el modal solo renderiza el banner informativo cuando `is_voided = true`, pero carece de controles operativos de anulación para el Administrador. | Bloque 3 (B3.9) | 🟡 Media |
| UX-5 | Importación directa de la función auxiliar `formatCurrency` desde `utils/currency` en `SaleDetailModal.vue:10` en lugar del composable centralizado `useCurrencyFormat` (SPEC-011). | Bloque 4 (B4.12) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:**
  - Al identificarse 3 hallazgos de severidad ALTA (UX-1, UX-2, UX-3), el frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. Implementar el método `voidSale(saleId, reason, refundChannel)` en `saleRepository.ts` consumiendo la RPC `rpc_anular_venta`.
2. Crear el componente modal `VoidSaleModal.vue` que capture el motivo obligatorio (>= 5 caracteres) y el canal de devolución cuando la venta original haya sido en efectivo o digital.
3. Incorporar el botón condicional "Anular Venta" en `SaleDetailModal.vue`, visible únicamente cuando `authStore.isAdmin = true` y `detail.is_voided = false`.
