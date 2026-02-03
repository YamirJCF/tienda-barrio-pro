# Reporte de Auditoría: Consistencia del Sistema vs FRD-007

**Fecha:** 2026-02-03
**Auditores:** @[/data], @[/ux]
**Alcance:** Módulo de Ventas (POS), Esquema de Base de Datos, Repositorios Frontend

## 🚨 Hallazgos Críticos

### 1. Error de Sintaxis de Entrada "N/A" (Bloqueante)
*   **Severidad:** CRÍTICA
*   **Ubicación:** Trigger de Base de Datos `public.sync_sale_to_cash`
*   **Causa Raíz:** El trigger intenta combinar (COALESCE) un ENTERO (`NEW.ticket_number`) con un literal de TEXTO `'N/A'`, causando que Postgres falle al intentar convertir tipos durante la operación de concatenación.
*   **Impacto:** No se pueden completar las ventas.
*   **Estado de la Solución:** Existe una corrección en `supabase/migrations/20260203130000_fix_trigger_n_a.sql` pero no ha sido aplicada.
*   **Recomendación:** Aplicar la migración inmediatamente.

### 2. Corrupción de Datos en Pagos "Mixtos"
*   **Severidad:** ALTA
*   **Ubicación:** `frontend/src/data/repositories/saleRepository.ts` (Línea 191)
*   **Problema:** El Frontend permite un método de pago `'mixed'` (probablemente para pagos divididos), pero el repositorio **transforma forzosamente** esto a `'efectivo'` antes de enviarlo al backend.
    ```typescript
    p_payment_method: (saleData.paymentMethod === 'mixed' ...) ? 'efectivo' : ...
    ```
*   **La Discrepancia:**
    *   **FRD-007** NO define pagos 'Mixtos'.
    *   **Base de Datos:** El Trigger `sync_sale_to_cash` agrega el monto **TOTAL** de la venta al Cajón de Dinero si el método es `'efectivo'`.
*   **Impacto de Negocio:** Si un usuario paga $10k en Efectivo y $10k en Nequi (Mixto), el sistema registra que entraron $20k al cajón físico. **Esto garantiza descuadres de caja.**
*   **Recomendación:** Deshabilitar pago 'mixto' en Frontend hasta que el Backend soporte Pagos Divididos (Movimientos de Caja referenciando montos parciales), O validación estricta de que Mixto = 100% Efectivo (lo cual es redundante).

### 3. Deriva de Tipos y Firma RPC
*   **Severidad:** MEDIA
*   **Ubicación:** `frontend/src/types/database.types.ts`
*   **Problema:** El RPC `procesar_venta` **no existe** en las definiciones locales de TypeScript.
*   **Riesgo:** El Frontend está asegurando tipos estrictos manualmente en `saleRepository` (usando `Decimal.toNumber()`), pero sin los tipos generados, no hay garantía en tiempo de compilación de que `p_unit_price` coincida con lo que espera la base de datos.
*   **Observación:** Frontend envía `unit_price`, la tabla de BD tiene `price_at_sale`. El mapeo de variables depende de la implementación oculta del RPC.

## 📋 Mapeo Esquema v. Código

| Concepto | Término FRD | Frontend (Código) | Backend (BD) | Estado |
| :--- | :--- | :--- | :--- | :--- |
| **ID Venta** | Ticket # | `ticketNumber` | `ticket_number` | ✅ Mapeado |
| **Métodos** | Efectivo, Nequi, Fiado | `cash`, `nequi`, `fiado`, `mixed` | `efectivo`, `nequi`... | ⚠️ **Riesgo (Mixto)** |
| **Precios** | Precio Unitario | `price` | `unit_price` | ⚠️ **Ambiguo** |
| **Empleado** | - | `username` | `alias` | ✅ Mapeado |

## 🛠 Plan de Acción

1.  **Inmediato**: Ejecutar `20260203130000_fix_trigger_n_a.sql` para resolver el bloqueo.
2.  **Corrección**: Eliminar o arreglar la lógica `'mixed'` -> `'efectivo'`. Si Mixto no está en el FRD, debe eliminarse de la UX.
3.  **Mantenimiento**: Ejecutar `supabase gen types` para actualizar `database.types.ts` y exponer las firmas reales de RPC.
