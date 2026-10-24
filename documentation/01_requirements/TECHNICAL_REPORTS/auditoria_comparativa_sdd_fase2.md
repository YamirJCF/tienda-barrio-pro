# Informe de Auditoría Comparativa: SDD Derogado vs. SDD Nuevo (v3.0.0) vs. Base de Datos Viva

> **Módulo:** Arquitectura de Datos, Sesiones, Caja y Modo Offline  
> **Fecha:** 2026-10-24  
> **Responsables:** `@[/data]` (Arquitecto de Datos) & `@[/qa]` (Auditor de Calidad y Resiliencia)  
> **Estado:** ✅ Auditoría Formalizada (Gate 2)  
> **Reglas Aplicadas:** Regla 2 (Anti-Alucinación), Regla 3 (No Fallos Silenciosos), Regla 4 (Seguridad Centralizada), Regla 6 (Auditoría Cruzada), Regla 7 (Trade-offs), Regla 9 (Anti-Sesgo: 9.1 Invariante de Conteo, 9.2 No-Fusión de Dimensiones, 9.3 Prohibición de Auto-Cita).

---

## 1. Declaración de Alcance y Metodología Anti-Sesgo

Conforme a la **Regla 9 de AGENTS.md**, este informe divide estrictamente el análisis en dos dimensiones independientes que **NUNCA se funden**:
- **Dimensión 1 (Eje B — Auditoría de Verdad Física y Cumplimiento):** ¿Lo que afirmaba el SDD anterior (`v2.0` derogado) realmente existía o funcionaba en la base de datos real (`ihtjocmhzuliwwvdzfnz`) y en el código del frontend?
- **Dimensión 2 (Eje A — Brecha Normativa y Evolución Funcional):** ¿Qué vacíos lógicos cerraron los nuevos FRDs de la Fase 1 (`FRD-012-01`, `FRD-013`, `FRD-017`) y cómo se plasmaron en los nuevos SDDs `v3.0.0`?

Se aplica el **Invariante de Reconciliación por Conteo (Regla 9.1)**:
Total de hallazgos críticos detectados y reconciliados: **N = 10 hallazgos específicos**.

---

## 2. Dimensión 1: Auditoría de Verdad Física (SDD Derogado vs. Realidad en BD y Código)

Esta auditoría contrasta lo que los documentos derogados (`SDD_012_DEROGADO`, `SDD_013_DEROGADO`, `SDD_017_DEROGADO`) decían frente a las consultas ejecutadas directamente en PostgreSQL (`pg_proc`, `pg_trigger`, `pg_constraint`, `information_schema.columns`) y los archivos del repositorio:

| # | Objeto / Contrato | Lo que decía el SDD Derogado (v2.0) | Realidad Comprobada en BD Viva / Código | Impacto Real / Severidad |
|---|---|---|---|---|
| **H-1** | **Trigger `trg_expire_passes_on_cash_close`** | `SDD_013` (§3.3, §4.6) y `SDD_017` (§1.1.4, §3.3) afirmaban que este trigger existía en `cash_sessions` y expiraba pases en caliente. | **NO EXISTE en producción (`pg_trigger`).** Solo existen `trg_audit_cash_opened` y `trg_audit_cash_closed`. | 🔴 **Fantasía Documental.** Además, el concepto contradecía la Decisión D-03 de `FRD-001` y `POL-LOG-01` (cerrar caja no debe desloguear a empleados). |
| **H-2** | **Doble Llave Foránea en `audit_logs.actor_id`** | `SDD_017` (§3.4, D-8) sostenía que los empleados no podían auditar porque `audit_logs` tenía FK a `auth.users`. | `audit_logs.actor_id` tiene **DOS FK simultáneas**: `audit_logs_actor_id_fkey` (`employees.id`) Y `fk_audit_user` (`auth.users.id`). | 🔴 **Bloqueo Crítico (Deadlock Relacional).** Los empleados solo existen en `employees.id`. Cualquier `INSERT` en `audit_logs` con un empleado falla por FK. Si un empleado abrió la caja, el cierre forzado de 24h (`rpc_check_and_force_close_shifts`) crasheaba y no cerraba. |
| **H-3** | **Nombres de RPCs en `SDD-013`** | `SDD_013` (§5.1-5.4) especificaba `rpc_solicitar_acceso_empleado`, `rpc_cerrar_sesion_empleado`, `rpc_obtener_sesiones_activas`, `rpc_revocar_sesion_dispositivo`. | **NINGUNO existe en `pg_proc`.** Los nombres reales son: `request_employee_access`, `solicitar_pase_diario`, `check_daily_pass_status`, `check_my_pass_status`, `rpc_gestionar_dispositivo`. | 🔴 **Alucinación de Nombres.** Imposible de integrar sin verificar `pg_proc`. |
| **H-4** | **Esquema de `sales`** | `SDD_012` (§3.1) listaba 16 columnas físicas terminando en `created_at`. | `sales` tiene **19 columnas reales**: omite `idempotency_key:uuid`, `void_session_id:uuid` y `voided_at:timestamptz`. | 🟡 **Omisión de Columnas.** Desalineación en auditoría y anulación de ventas. |
| **H-5** | **Esquema de `cash_movements`** | `SDD_012` (§3.5) y `SDD_017` (§3.2) listaban 7 columnas (`id, session_id, movement_type, amount, description, sale_id, created_at`). | `cash_movements` tiene **10 columnas reales**: omitía `payment_method:text`, `category:text`, `voucher_ref:text`. | 🟡 **Omisión de Columnas.** No registraba canales segregados ni categoría del gasto. |
| **H-6** | **Esquema de `audit_logs`** | `SDD_012` (§3.6) listaba 9 columnas terminando en `ip_address`. | `audit_logs` tiene **12 columnas reales**: omitía `reviewed_by:uuid`, `reviewed_at:timestamptz`, `review_notes:text`. | 🟡 **Omisión de Columnas.** No documentaba el flujo de revisión administrativa. |
| **H-7** | **Trazabilidad de Ventas Offline (`syncQueue` y `rpc_procesar_venta_v3`)** | `SDD_012` (§5.2) mostraba que el cliente enviaba `p_session_id` para imputar el turno original. | `syncQueue.ts` (L411-422) **NO enviaba** `p_session_id`, `p_sold_by` ni `p_sold_at`. En SQL, `rpc_procesar_venta_v3` no aceptaba `origin_session_id` y asignaba la venta a quien estuviese autenticado al reconectar. | 🔴 **Ruptura de Trazabilidad.** Si el empleado A vendió offline y el empleado B reconectó el teléfono, la venta quedaba registrada a nombre de B y en el turno actual. |
| **H-8** | **Falta de `assert_store_access` en RPCs de Caja** | `SDD_004` y `SDD_017` afirmaban que todo RPC de caja estaba protegido por aislamiento multi-inquilino. | `abrir_caja` y `get_active_cash_session` en `pg_proc` **NO TIENEN** `assert_store_access`. Eran ejecutables por `anon` sin validación de tienda, y `abrir_caja` retornaba `{success:false}` en vez de `RAISE`. | 🔴 **Fuga de Seguridad (Reglas 3 y 4).** Un usuario anónimo podía consultar el turno activo de cualquier tienda y abrir turnos falsos. |
| **H-9** | **Discrepancia en Validación de Fecha del Pase Diario** | `SDD_013` y `SDD_017` afirmaban consistencia en el control de acceso del pase. | `get_current_store_id()` corta estrictamente por `pass_date = v_today`. Pero `check_daily_pass_status()` consulta `requested_at > now() - 24h` y `check_my_pass_status()` no valida fecha. | 🔴 **Desincronización Front-Back.** La UI creía que el pase estaba `'approved'` (por consulta de 24h), pero cualquier llamada posterior fallaba con `STORE_ACCESS_DENIED`. |
| **H-10** | **Atrapamiento en Router ante Turno Caducado (`isStaleSession`)** | `SDD_017` (§4.2) declaraba bloqueo de operaciones monetarias. | `router/index.ts` (L268-274) redirige forzosamente a `/cash-control` a **cualquier** usuario si `isStaleSession` es true. | 🔴 **Bloqueo a No Cajeros.** Un dependiente de inventario sin permiso `canOpenCloseCash` quedaba atrapado en una vista donde no podía operar ni cerrar caja. |

---

## 3. Dimensión 2: Brecha Normativa y Evolución Funcional (SDD Derogado vs. SDD Nuevo v3.0.0)

Esta matriz detalla cómo los nuevos SDDs v3.0.0 construidos desde cero resuelven los vacíos lógicos del sistema integrando los nuevos requisitos aprobados en la Fase 1:

| Componente | SDD Derogado (v2.0) | Nuevo SDD v3.0.0 (Creado desde Cero) | Ganancia Arquitectural / Regla Protegida |
|---|---|---|---|
| **Frontera de Red vs. Seguridad** | Trataba cualquier excepción de petición como caída de red, permitiendo a la UI usar caché local ante accesos denegados. | **`SDD-012` v3.0.0 (§4.5):** Implementa `networkErrorClassifier.ts`. Separa errores de transporte de rechazos autoritativos (`STORE_ACCESS_DENIED`). Ante rechazo, purga caché y conduce a login/pase. | 🛡️ **Seguridad Estricta:** Cero falsos positivos de modo offline (`RN-OFF-07`). No se exponen datos financieros en sesiones no autorizadas. |
| **Caducidad Offline** | Permitía operar indefinidamente en modo offline mientras no se superara el límite de 50 ventas en cola. | **`SDD-012` v3.0.0 (§4.8):** Bloquea el botón de cobro en POS offline si el turno local supera `P_MAX_HORAS_TURNO` (24 horas). | ⏱️ **POL-SEG-02:** Impide que una terminal desconectada acumule ventas durante días sin conciliar efectivo con el dueño. |
| **Protección de Cola ante Pases Vencidos** | Si la venta fallaba al reconectar por pase expirado, se gastaban los 3 reintentos y se mandaba a la DLQ. | **`SDD-012` v3.0.0 (§4.6):** Ante `STORE_ACCESS_DENIED`, la cola se pausa con `sync:auth_required`. Cero incremento de `retry_count` y cero traslados erróneos a DLQ. | 📦 **POL-AUD-01:** Las ventas legítimas del comerciante no se pierden ni se consideran basura técnica (`RN-OFF-03`). |
| **Sello Inmutable de Venta Offline** | Solo guardaba productos, total y `local_id`. El cajero y turno se deducían al momento del drenado. | **`SDD-012` v3.0.0 (§5.1):** `OfflineSaleRecord` sella `{ origin_session_id, sold_by, sold_at }`. `rpc_procesar_venta_v3` los recibe como parámetros. | 🏷️ **POL-AUD-02:** Trazabilidad universal e inmutable de quién vendió y en qué turno físico ocurrió la venta (`RN-OFF-09`). |
| **Relevo de Jornada en Sesiones** | No definía qué pasaba si un empleado no cerraba sesión al irse a su casa. El router cargaba el Dashboard zombi. | **`SDD-013` v3.0.0 (§4.1):** Protocolo de arranque en frío. Si el pase es de ayer y no hay turno nocturno, transiciona a solicitar el Pase de Hoy (1 toque). | 🔄 **UX Fluida:** Elimina sesiones fantasma sin obligar a los empleados a hacer logout manual (`RN-013-01`). |
| **Desacople Caja vs. Pase Diario** | Afirmaba que el cierre de caja expiraba todos los pases de empleados mediante un trigger reactivo. | **`SDD-013` v3.0.0 (§4.5):** Erradica el trigger inexistente. El cierre de caja solo bloquea operaciones monetarias; el pase sigue vivo para tareas no monetarias. | 📦 **POL-LOG-01:** Independencia logística. Los empleados pueden hacer inventario o recibir pedidos con la caja sellada (`RN-013-06`). |
| **Continuidad en Cruce de Medianoche** | `get_current_store_id` cortaba a las 00:00:00 provocando `STORE_ACCESS_DENIED` a turnos nocturnos. | **`SDD-013` (§3.3) y `SDD-017` (§4.1):** Unifica la regla: pase `'approved'` de ayer sigue vigente si la tienda tiene caja abierta `< 24 horas`. | 🌙 **RN-017-01:** Hecho económico continuo. Turnos nocturnos legítimos atienden sin interrupciones ni cierres forzados a medianoche. |
| **Trazabilidad Multi-Actor en Caja** | La tabla `cash_movements` no tenía campo de actor. No se sabía qué empleado hacía qué gasto en la caja compartida. | **`SDD-017` v3.0.0 (§3.2):** Incorpora la columna física `actor_id UUID REFERENCES employees(id)` en `cash_movements`. | 👥 **POL-AUD-02:** En una tienda con hasta 6 dispositivos sobre 1 caja, cada gasto, ingreso o anulación queda firmado por su autor (`RN-017-04`). |
| **Solución al Deadlock de `audit_logs`** | El SDD viejo se resignaba a que los empleados no podían reconciliar porque no existían en `auth.users`. | **`SDD-017` v3.0.0 (§3.3):** Elimina `fk_audit_user` dejando `audit_logs_actor_id_fkey REFERENCES employees(id)`. | 🔓 **Desbloqueo Total:** Empleados y Administradores pueden firmar auditorías y reconciliar arqueos sin violaciones de integridad. |
| **Imputación Contable Tardía** | Las ventas rezagadas de cajas cerradas se imputaban ciegamente a cajas activas o generaban inconsistencia. | **`SDD-017` v3.0.0 (§4.4):** Imputación atómica al turno original cerrado, recálculo de saldo esperado y registro `LATE_SYNC_UPDATE`. | 💰 **POL-FIN-01:** No se distorsiona el turno nuevo; el turno de origen refleja su ingreso real con justificación forense. |

---

## 4. Reconciliación por Conteo (Regla 9.1)

Se confirman exactamente los **N = 10 hallazgos de verdad física** (H-1 a H-10) y su resolución explícita en los nuevos documentos SDD v3.0.0:
1. Trigger fantasma `trg_expire_passes_on_cash_close` erradicado (H-1) → Resuelto en `SDD-013` §0.1 y §4.5.
2. Doble FK en `audit_logs.actor_id` eliminada (H-2) → Resuelto en `SDD-017` §3.3 y D-1.
3. Nombres de RPCs reales alineados con `pg_proc` (H-3) → Resuelto en `SDD-013` §5.
4. Columnas reales de `sales` documentadas (H-4) → Resuelto en `SDD-012` §3.1.
5. Columnas reales de `cash_movements` + `actor_id` documentadas (H-5) → Resuelto en `SDD-012` §3.2 y `SDD-017` §3.2.
6. Columnas reales de `audit_logs` documentadas (H-6) → Resuelto en `SDD-012` §3.3 y `SDD-017` §3.3.
7. Sello inmutable de venta offline en cola y RPC (H-7) → Resuelto en `SDD-012` §4.3 y §5.1.
8. Blindaje de `assert_store_access` en RPCs de caja (H-8) → Resuelto en `SDD-017` §5.3.
9. Unificación de validez de pase en cruce de medianoche (H-9) → Resuelto en `SDD-013` §3.3 y `SDD-017` §4.1.
10. Router trap eliminado para no cajeros (H-10) → Resuelto en `SDD-017` §4.5 y D-3.

---

## 5. Conclusión del Gate 2

La **Fase 2** ha quedado formalizada con evidencia comprobada sobre la base de datos viva. Los documentos derogados se encuentran archivados con cabecera de trazabilidad, los nuevos documentos canónicos `SDD-012`, `SDD-013` y `SDD-017` v3.0.0 definen con precisión milimétrica la arquitectura de datos, y los contratos de la Fase 3 (migración SQL y código Vue) quedan 100% especificados y blindados.
