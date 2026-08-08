# SPEC-001: Especificación Técnica de Autoridad Exclusiva del Servidor

> **Asociado a:** [FRD-001 (Autoridad del Servidor)](../FRD/FRD_001_AUTORIDAD_DEL_SERVIDOR.md)  
> **Tipo:** Especificación Arquitectónica Transversal (SPEC)  
> **Estado:** 🟢 Normativo  
> **Última Actualización:** 2026-08-07

---

## 1. Principio Fundamental

En toda la arquitectura de *Tienda Barrio Pro*, la **única fuente de verdad** para la validación de reglas de negocio, cómputos matemáticos (totales, impuestos, márgenes FIFO), estados de cuenta y autorización de permisos es **PostgreSQL / Supabase Backend**.

La interfaz de usuario (Vue 3 / Frontend) es un consumidor pasivo de presentación. El Frontend **NO "piensa" ni calcula, solo solicita y presenta**.

---

## 2. Reglas de Implementación en Código

1. **Calculo de Totales:** 
   - Las funciones RPC (`rpc_procesar_venta_v3`, `rpc_registrar_abono`, etc.) reciben únicamente identificadores y cantidades (`product_id`, `quantity`).
   - El servidor consulta el `unit_price` vigente en la tabla `products` y realiza la multiplicación y suma en PL/pgSQL.
   - Si el Frontend envía un campo de total o precio, el Backend lo **ignora por completo**.

2. **Validación de Reglas de Negocio:**
   - La comprobación de stock disponible, cupo de crédito de clientes y estado de caja abierta se realiza **dentro de la transacción atómica de Postgres**.

3. **Manejo de Desincronización (Concurrencia):**
   - Si un precio o cantidad de stock cambia entre el momento en que el usuario ve la pantalla y el momento de la ejecución del RPC, el Backend aborta con un código de error explícito (`STOCK_INSUFFICIENT`, `PRICE_CHANGED`), forzando al Frontend a refrescar la vista.

---

## 3. Matriz de Verificación

- [x] RPC `rpc_procesar_venta_v3` calcula `total_charged` en backend.
- [x] RPC `rpc_registrar_abono` calcula `balance` resultante en backend.
- [x] Triggers FIFO consumen lotes en backend sin intervención de UI.
