# Plan Maestro de Migración SQL (Supabase Backend `@[/data]`)

> **Protocolos Rectores:** [`/supabase-admin`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/.agent/skills/supabase-admin/SKILL.md), [`/writing-plans`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/.agent/skills/writing-plans/SKILL.md) y Reglas 2, 3, 4, 5, 6, 8, 9, 10 de [`AGENTS.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/.agent/AGENTS.md).  
> **Meta:** Sincronizar el esquema físico y la capa transaccional RPC de Supabase Cloud (`ihtjocmhzuliwwvdzfnz`) con los 33 SDDs activos certificados (Olas 1 a 5), cerrando todas las Deudas Técnicas documentadas en `§0.3` sin romper ninguna función existente.  
> **Estado Final:** 🟢 100% COMPLETADO (Fase 0 de Higiene + 5 Olas Atómicas Aplicadas y Probadas con Evidencia en Supabase Cloud).

---

## 📋 Resumen de Ejecución por Olas y Certificación en Base de Datos

| Ola / Tarea | Migración Local | Versión Cloud Aplicada | SDDs Certificados | Evidencia Principal Verificada |
| :--- | :--- | :--- | :--- | :--- |
| **Task 0 (Higiene)** | 7 archivos locales no aplicados de julio 2026 | N/A (Aislados) | Higiene de Git y Cloud | Cuarentena limpia en `supabase/migrations/_archived_unapplied/` |
| **Task 1 (Ola 1)** | `20261017130000_wave1_multichannel_cash_and_expenses.sql` | `20261017174708` | SDD_004, SDD_017, SDD_020, SDD_022, SDD_023, SDD_026 | `rpc_registrar_gasto_v2` con validación de liquidez multicanal, `SHIFT_EXPIRED_24H`, arqueo de 12 balances y forzado con auditoría real. |
| **Task 2 (Ola 2)** | `20261017131000_wave2_inventory_fifo_plu_and_payables.sql` | `20261017175112` | SDD_006_PADRE, SDD_006_01_01, SDD_006_02, SDD_006_03, SDD_010, SDD_010_016, SDD_019 | Índice parcial PLU activo, tabla `sale_item_batches` con RLS, `buscar_producto_pos` en <200ms, `rpc_soft_delete_product` (`STOCK_REMAINING`) y entradas masivas. |
| **Task 3 (Ola 3)** | `20261017132000_wave3_sales_pos_voids_and_clients.sql` | `20261017180059` | SDD_007_PADRE, SDD_007_01, SDD_007_02, SDD_009, SDD_014, SDD_024 | `rpc_procesar_venta_v3` (idempotencia UUID, redondeo COP $50, venta forzada `CORRECCION_SISTEMA`), `rpc_anular_venta`, `rpc_registrar_abono` y `rpc_admin_get_clients`. |
| **Task 4 (Ola 4)** | `20261017133000_wave4_histories_audit_and_smart_reports.sql` | `20261017180608` | SDD_005, SDD_008, SDD_018, SDD_021, SDD_027_01 | Corrección bug 42703 (`cl.description`), visado de auditoría `rpc_marcar_auditoria_revisada`, `get_smart_supply_report` (15 días, activos, DOI), anti-DoS en `get_financial_Summary` y asignación masiva de proveedor. |
| **Task 5 (Ola 5)** | `20261017134000_wave5_daily_security_devices_and_employees.sql` | `20261017181628` | SDD_001, SDD_002, SDD_002_1, SDD_003, SDD_011, SDD_012, SDD_013, SDD_015, SDD_028 | Decisión D-03 ejecutada (trigger de cierre eliminado), pase unificado en Bogotá con tope 3 (`MAX_RETRIES`), `rpc_gestionar_dispositivo` (tope 5, dual audit), tope 5 empleados activos (`EMPLOYEE_LIMIT_REACHED`) y `rpc_obtener_empleados` con máscara segura de PIN. |
| **Task 6 (Cierre)** | Auditoría global y RVC | N/A | Todos los 33 SDDs | 100% de contratos sincronizados en BD y RVC actualizado con cero deuda técnica pendiente. |
