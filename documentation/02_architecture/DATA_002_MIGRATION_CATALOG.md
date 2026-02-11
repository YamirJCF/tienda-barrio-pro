# Catálogo de Procesos a Migrar (Ref: DATA-002)

**Fecha:** 2026-02-11
**Estado:** Identificación y Justificación
**Basado en**: Auditoría `saleRepository.ts` vs `financial_core.sql`

## 1. Métodos de Pago ("Hardcoded Strings")

| Componente | Estado Actual (Problema) | Estado Objetivo (Solución) | ¿Por qué es necesario? |
| :--- | :--- | :--- | :--- |
| **Frontend** | Tipado estático `'cash' \| 'fiado'`. Lógica manual para mapear `'efectivo'` <-> `'cash'`. | Dinámico. Renderiza botones basados en respuesta de `rpc_get_system_config`. | Agregar "Nequi" o "Bonos" hoy requiere re-compilar y re-desplegar la App. |
| **Backend** | `CASE WHEN p_method = 'efectivo'` quemado en RPC para calcular cambio. | `payment_methods.allows_change`. Consulta tabla para saber si calcular cambio. | La lógica de caja está rígida. No permite métodos mixtos o nuevos tipos de moneda fácilmente. |

## 2. Validación de Stock ("Logic Duplication")

| Componente | Estado Actual (Problema) | Estado Objetivo (Solución) | ¿Por qué es necesario? |
| :--- | :--- | :--- | :--- |
| **Frontend** | Itera items y compara `store.stock < qty`. Lógica desconectada de DB. | `SalesValidator` que usa reglas versionadas y códigos de error estándar (`STOCK_INSUFFICIENT`). | Si el Backend permite "Venta en Negativo" (configuración futura), el Frontend actual seguiría bloqueando la venta erróneamente. |
| **Backend** | Trigger en `inventory_movements`. Validación implícita. | Validaciones explícitas en RPC antes de insertar, retornando error codificado. | El error actual es una excepción SQL genérica difícil de parsear por la UI para mostrar mensajes amigables. |

## 3. Crédito y Fiado ("Stale Data Risk")

| Componente | Estado Actual (Problema) | Estado Objetivo (Solución) | ¿Por qué es necesario? |
| :--- | :--- | :--- | :--- |
| **Frontend** | Valida contra el estado de Pinia (`clientsStore`). Puede estar desactualizado por segundos. | Validación optimista + Re-check en Sync. Uso de `SalesValidator` compartido. | Un cliente puede haber comprado en otra caja hace 1 segundo. El Frontend aprobaría la venta Offline, pero el Sync fallará, creando un conflicto de caja. |
| **Backend** | `FOR UPDATE` lock en tabla `clients`. Correcto pero opaco. | Mantener Locking, pero estandarizar el error `CREDIT_LIMIT_EXCEEDED`. | Consistencia financiera. |

## 4. Tipos de Transacción ("Constraint Rigidity")

| Componente | Estado Actual (Problema) | Estado Objetivo (Solución) | ¿Por qué es necesario? |
| :--- | :--- | :--- | :--- |
| **Backend** | CHECK Constraint `IN ('venta_fiado', 'abono', ...)` en `client_ledger`. | Tabla foránea `transaction_types`. | Agregar un tipo de movimiento 'ajuste_mora' requiere una migración DDL pesada (Drop Constraint) en lugar de un simple INSERT. |

## 5. Cálculo de "Devuelta" (Change)

| Componente | Estado Actual (Problema) | Estado Objetivo (Solución) | ¿Por qué es necesario? |
| :--- | :--- | :--- | :--- |
| **Lógica** | `IF efectivo THEN received - total ELSE 0`. | Propiedad `allows_change` en `payment_methods`. | Si mañana aceptamos "Bonos Integrales" que dan devuelta, el código actual no lo soporta sin cambios de ingeniería. |

---

## Resumen de Prioridad de Migración

1.  🔴 **Métodos de Pago**: Crítico. Bloquea la expansión comercial y genera deuda técnica inmediata.
2.  🟠 **Tipos de Transacción**: Alto. Necesario para mejorar la contabilidad (Ledger) sin romper la DB.
3.  🟡 **Validaciones Stock/Crédito**: Medio. Funciona "bien" ahora, pero es una bomba de tiempo para el mantenimiento.

**Siguiente Paso Recomendado**: Ejecutar `DATA_001` (Creación de tablas) para resolver el punto 1 y 4 inmediatamente.
