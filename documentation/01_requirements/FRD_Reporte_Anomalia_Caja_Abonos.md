# Informe Arquitectónico: Evolución de la Caja y Conciliación Multicanal (Físico + Digital)

## 1. El Desafío: La Caja como Centro de Control Financiero
Históricamente, la "Caja" (tabla `cash_sessions` y `cash_movements`) fue concebida exclusivamente para auditar el cajón físico de billetes y monedas. Sin embargo, dado que el alcance del sistema ha crecido, la "Caja" ya no es solo un cajón físico, sino el **Turno Operativo de Conciliación** que debe cuadrar todo el dinero que fluye en la tienda, sea físico o digital (Nequi, Daviplata, Bancolombia).

Actualmente tenemos dos problemas críticos:
1. **Abonos Huérfanos:** Cuando un cliente paga una deuda, el abono se registra en su historial de cartera, pero no entra al flujo de caja (no se audita en el cierre de turno).
2. **Ceguera Digital:** Las ventas y pagos por medios electrónicos (Nequi, Daviplata) se registran en las `sales`, pero la "Caja" actual ignora completamente estos montos en su conciliación, impidiendo que el administrador cuadre la plata que debe haber en la cuenta de Nequi al final del día.

## 2. Análisis del Código y Estructura Actual
- La tabla `cash_sessions` solo tiene un `expected_balance` y `actual_balance` (orientado a un solo canal totalizado, presumiblemente efectivo).
- La tabla `cash_movements` carece de una columna `payment_method` para discriminar el tipo de ingreso.
- El RPC `procesar_venta` inserta un movimiento en `cash_movements` **solo** si el método de pago es `'efectivo'` (o `'cash'`). Las ventas por Nequi no generan movimiento en caja.
- El RPC `registrar_abono` actualiza el `client_ledger` pero ignora la caja (`cash_movements`) y no solicita con qué método (Nequi, efectivo) pagó el cliente.

## 3. Propuesta de Arquitectura Multicanal (Físico + Digital)

Para resolver este desafío y permitir que el turno audite todo el dinero, necesitamos una refactorización en la estructura de datos y en la experiencia de cierre de caja.

### A. Decisión Arquitectónica de Datos (Esquema)
Para mantener consistencia con los patrones del proyecto (ej. `inventory_movement_batches`) y asegurar consultas limpias y auditorables mediante SQL, la desagregación de saldos por canal se implementará mediante **una tabla anexa `cash_session_balances`**, abandonando la idea de usar JSON en `cash_sessions`.
Esto permite un RLS independiente, índices robustos, y facilita las agregaciones (SUM/GROUP BY) del motor financiero.

1. **Enriquecer `cash_movements`:** 
   - Añadir la columna `payment_method` (text) a `cash_movements` (relacionada con `payment_methods.code`).
   - Ajustar `procesar_venta` para registrar *todas* las ventas (efectivo, nequi, daviplata) en `cash_movements`, etiquetadas con su método de pago.

2. **Actualizar el Registro de Abonos (`registrar_abono`):**
   - Modificar el RPC para que reciba `payment_method` de forma obligatoria.
   - Insertar el abono en `cash_movements` asociado al turno de caja activo, permitiendo trazar si el abono entró al cajón (efectivo) o al banco (Nequi).
   - Bloquear el abono si la caja está cerrada.

3. **Evolucionar `cash_sessions` (Arqueo Multicanal):**
   - El arqueo tradicional (un solo total) queda obsoleto. Las columnas actuales de `expected_balance` y `actual_balance` perderán relevancia aislada.
   - Nueva tabla `cash_session_balances` (session_id, payment_method, expected_amount, actual_amount, difference) que registre una fila por cada canal (Efectivo, Nequi, Daviplata) operado durante el turno.

### B. Modificaciones en Interfaz (UX/UI)
1. **Modal de Abonos Actualizado:** Al registrar un abono, se obligará al usuario a seleccionar **cómo** pagó el cliente (Efectivo, Nequi, etc.).
2. **Cierre de Caja Enriquecido (Multicanal):** Durante el cierre de turno, el sistema agrupará y preguntará los saldos por separado (Efectivo físico y aplicaciones digitales), mostrando discrepancias independientes.

---

## 4. Análisis de Impacto Transversal (Sistemas Afectados)

Este cambio estructural rompe funciones existentes que deben ser reescritas:

1. **Impacto Crítico: Cierre Forzado de 24h (`rpc_check_and_force_close_shifts`)**
   - *Problema:* Actualmente asume un único saldo esperado global. Con la caja multicanal, este RPC queda obsoleto.
   - *Solución:* El RPC deberá calcular saldos esperados por cada `payment_method` y generar los registros correspondientes en la nueva tabla `cash_session_balances`.

2. **Impacto UI: `ForcedCloseAuditModal.vue`**
   - *Problema:* El modal actual solo solicita al Admin un (1) único campo `actual_balance` para reconciliar turnos expirados.
   - *Solución:* Debe rediseñarse para solicitar saldos reales por cada canal que tuvo movimientos durante ese turno expirado.

3. **Impacto en Cuentas por Pagar (`rpc_pay_supplier_invoice`)**
   - *Problema:* Actualmente el pago a proveedor genera un 'gasto' sin identificar el canal de origen, descontando por defecto del total global.
   - *Solución:* Este RPC ahora DEBE recibir un `payment_method`. Un pago a proveedor hecho por transferencia no debe restar del saldo esperado en efectivo físico del cajón.

---
> Estado: Aprobado - Visión y decisiones técnicas confirmadas. Procediendo a FRDs e Implementación.
