> [!CAUTION]
> **DOCUMENTO DEROGADO Y ARCHIVADO**
> **Estado:** 🔴 DEROGADO — Conservado exclusivamente para trazabilidad histórica y auditoría comparativa contra v3.0.0.
> **Fecha de Derogación:** 2026-10-24
> **Sustituido por:** `documentation/01_requirements/SDD/SDD_017_CICLO_CONTABLE_Y_SESIONES.md` (v3.0.0)

# SDD-017: AlineaciÃ³n del Ciclo Contable de Caja y Ciclo de Vida de Sesiones

> **Asociado a:** [FRD-017: AlineaciÃ³n del Ciclo Contable de Caja y Ciclo de Vida de Sesiones](../FRD/FRD_017_CICLO_CONTABLE_Y_SESIONES.md)  
> **Fase del Plan:** Ola 5: Sesiones, AutenticaciÃ³n y Offline (Ãtem 3)  
> **Estado:** ðŸŸ  Aprobado con Deuda TÃ©cnica Documentada (Protocolo PAC-SDD v2.0)
> **Ãšltima ActualizaciÃ³n:** 2026-10-16  

---

## 0. CONTROL DE VERSIONES Y TRAZABILIDAD

### 0.1 Historial de Cambios
| VersiÃ³n | Fecha | Autor | Rol | DescripciÃ³n de ModificaciÃ³n |
|---------|-------|-------|-----|-----------------------------|
| 1.0.0 | 2026-07-25 | Desarrollador-Economista Senior | Requisitos | EspecificaciÃ³n aprobada de ciclo contable y lÃ­mite de 24 horas. |
| 1.5.0 | 2026-08-04 | Arquitecto de Software | Arquitectura | RedacciÃ³n preliminar con alucinaciones de cuadre en cero (`difference = 0`). |
| 2.0.0 | 2026-10-16 | Orquestador TÃ©cnico | Arquitectura & QA | **Saneamiento Integral PAC-SDD v2.0**: ErradicaciÃ³n de cuadres ficticios ($0 descuadre); consagraciÃ³n de la realidad fÃ­sica de producciÃ³n (`actual_balance = NULL`, `difference = NULL` en cierre forzado); vinculaciÃ³n reactiva con el trigger de expiraciÃ³n de pases `trg_expire_passes_on_cash_close`; formalizaciÃ³n del procedimiento de reconciliaciÃ³n administrativa a ciegas `rpc_reconciliar_cierre_forzado`; integraciÃ³n con el subsistema de notificaciones (`notifications`); cumplimiento estricto de las Reglas 1.1 (0% cÃ³digo SQL), 2, 4, 7 y 8; y armonizaciÃ³n transversal con POS, Gastos y Devengo (SDD-018). |

### 0.2 Trazabilidad de Requisitos (FRD-017)
| Regla de Negocio / CU | DescripciÃ³n en FRD | ImplementaciÃ³n en este SDD |
|-----------------------|--------------------|----------------------------|
| **RN-017-01** | Continuidad del Turno (Cruce libre de medianoche sin deslogueo) | SecciÃ³n 4.1 y SecciÃ³n 2 (Diagrama de Estados) |
| **RN-017-02** | Cierre forzado estricto al cumplir 24 horas de apertura | SecciÃ³n 4.2, SecciÃ³n 3.3 y SecciÃ³n 5.1 |
| **RN-017-03** | AuditorÃ­a y notificaciÃ³n administrativa de cierre forzado | SecciÃ³n 4.3, SecciÃ³n 3.4 y SecciÃ³n 5.2 |
| **RN-017-04** | Inmutabilidad contable de la asignaciÃ³n al turno (`session_id`) | SecciÃ³n 4.4, SecciÃ³n 3.2 y SecciÃ³n 7 (D-5) |
| **CU-017-A** | OperaciÃ³n nocturna continua a travÃ©s de medianoche | SecciÃ³n 4.1 y SecciÃ³n 2.1 |
| **CU-017-B** | Olvido de cierre de caja, ejecuciÃ³n forzada y regularizaciÃ³n | SecciÃ³n 4.2, SecciÃ³n 4.3 y SecciÃ³n 5.2 |

### 0.3 Matriz de Dependencias Inter-Modulares
| Documento Vecino | Tipo de Dependencia | Flujo o RestricciÃ³n Vinculante |
|------------------|---------------------|--------------------------------|
| [SDD-004](../SDD/SDD_004_CONTROL_DE_CAJA.md) / [SDD-020](../SDD/SDD_020_CAJA_MULTICANAL.md) | NÃºcleo Financiero | Esquema fÃ­sico de `cash_sessions` (12 columnas), `cash_movements` (7 columnas), fÃ³rmula de saldo esperado y principio de arqueo ciego (`POL-SEG-01`). |
| [SDD-013](../SDD/SDD_013_GESTION_SESIONES.md) / [SDD-001](../SDD/SDD_001_SEGURIDAD_DIARIA.md) | Gobernanza de Sesiones | SubordinaciÃ³n de pases diarios (`daily_passes`); expiraciÃ³n reactiva masiva vÃ­a trigger `trg_expire_passes_on_cash_close` al pasar la caja a `'closed'`. |
| [SDD-007](../SDD/SDD_007_NUCLEO_VENTAS_PADRE.md) / [SDD-007.1](../SDD/SDD_007_01_NUCLEO_POS.md) | Consumidor Transaccional | PrecondiciÃ³n de turno abierto con antigÃ¼edad menor a 24 horas (`opened_at >= NOW() - INTERVAL '24 hours'`) para procesar cobros de contado en POS. |
| [SDD-019](../SDD/SDD_019_CUENTAS_POR_PAGAR.md) / [SDD-022](../SDD/SDD_022_GASTOS_MULTICANAL.md) | Egresos de TesorerÃ­a | PrecondiciÃ³n de turno abierto `< 24h` para registrar pagos a proveedores y gastos OPEX, previniendo sobregiros por canal (`INSUFFICIENT_FUNDS`). |
| [SDD-023](../SDD/SDD_023_IMPACTO_CRUZADO_MULTICANAL.md) | Consistencia Transversal | Procedimiento atÃ³mico de reconciliaciÃ³n post-cierre forzado (`rpc_reconciliar_cierre_forzado`) y preservaciÃ³n de columnas escalares. |
| [SDD-018](../SDD/SDD_018_CONTROL_OPERACIONAL.md) | Inteligencia Financiera | Principio de Devengo contable: imputaciÃ³n inmutable de ingresos y egresos al `session_id` del turno original sin distorsiÃ³n por cierres forzados. |
| [SDD-005](../SDD/SDD_005_AUDITORIA_TRAZABILIDAD.md) | AuditorÃ­a Forense | Inviolabilidad contable (`POL-AUD-01`): Registro inmutable en `audit_logs` con acciones `FORCED_CLOSE_24H` y `FORCED_CLOSE_RECONCILED`. |

---

## 1. RESUMEN EJECUTIVO Y ALCANCE

El documento **SDD-017** establece la alineaciÃ³n arquitectural definitiva entre el **Ciclo Contable de Caja** y el **Ciclo de Vida de las Sesiones de Usuario** en el ecosistema **Tienda Barrio Pro**.

### 1.1 Principios Rectores EconÃ³mico-Contables
1. **Prevalencia del Hecho EconÃ³mico sobre el Reloj AstronÃ³mico (`RN-017-01`):** La unidad contable de caja es el turno continuo de trabajo del tendero. Las 00:00:00 del calendario no constituyen un corte contable ni fuerzan la expulsiÃ³n (`logout`) de los cajeros en turnos nocturnos legÃ­timos (ej. de 10:00 PM a 02:00 AM).
2. **Techo Temporal Inviolable de 24 Horas (`RN-017-02`):** Para prevenir la negligencia operativa de cajas abandonadas indefinidamente y el arrastre de descuadres desapercibidos, el sistema impone un lÃ­mite estricto de 24 horas a partir del momento exacto de apertura (`cash_sessions.opened_at`).
3. **ErradicaciÃ³n de Falsedades Contables (Cero Cuadres Ficticios):** El cierre forzado asÃ­ncrono **nunca** asume un descuadre de $0 ni inventa un dinero fÃ­sico inexistente. El sistema sella la sesiÃ³n calculando matemÃ¡ticamente el saldo esperado (`expected_balance`), fijando el saldo real fÃ­sico en `NULL` (`actual_balance = NULL`) y la diferencia en `NULL` (`difference = NULL`), documentando que el turno quedÃ³ pendiente de arqueo humano supervisado.
4. **ExpiraciÃ³n Reactiva y Cascada de Sesiones (`POL-SEC-02`):** El sellado de la caja (manual o forzado a las 24 horas) desencadena a nivel de base de datos el trigger fÃ­sico `trg_expire_passes_on_cash_close`, conmutando a `'expired'` todos los pases diarios operativos de la tienda en `daily_passes`.
5. **Alerta Bloqueante y ReconciliaciÃ³n Obligatoria (`RN-017-03`):** Un turno cerrado forzosamente bloquea la apertura de una nueva caja en la tienda hasta que un usuario autorizado (con permiso `canOpenCloseCash` o rol de Administrador) acuse recibo de la notificaciÃ³n, efectÃºe el arqueo fÃ­sico a ciegas mediante `rpc_reconciliar_cierre_forzado` y liquide la diferencia en el libro de auditorÃ­a.
6. **Defensa en Profundidad Transaccional (`Defense in Depth`):** Si un turno de caja rebasa las 24 horas y el cron job de mantenimiento aÃºn no se ha ejecutado, las funciones transaccionales de cobro en POS (`rpc_procesar_venta_v3`) y egreso de fondos (`rpc_pay_supplier_invoice`, `rpc_registrar_gasto`) evalÃºan en tiempo real la antigÃ¼edad del turno, abortando de inmediato con el cÃ³digo `SHIFT_EXPIRED`.

---

## 2. ARQUITECTURA GENERAL Y DIAGRAMA DE FLUJO

### 2.1 Diagrama de Secuencia: Ciclo de Turno Nocturno y Cierre Forzado a las 24 Horas
El siguiente diagrama detalla la interacciÃ³n entre la terminal POS, el motor transaccional de Supabase, el proceso asÃ­ncrono de cierre forzado de 24 horas, el trigger reactivo y la reconciliaciÃ³n administrativa:

```mermaid
sequenceDiagram
    autonumber
    participant Cajero as ðŸ“± Terminal POS (Cajero)
    participant POS as âš¡ Backend POS / RPCs
    participant DB as ðŸ”’ PostgreSQL (cash_sessions / daily_passes)
    participant Cron as â±ï¸ Cron / Mantenimiento
    participant Admin as ðŸ’» Panel Administrador

    Note over Cajero, DB: 1. OPERACIÃ“N NORMAL Y CRUCE DE MEDIANOCHE (RN-017-01)
    Cajero->>POS: Abrir caja a las 22:00 con base inicial
    POS->>DB: INSERT cash_sessions (status = 'open', opened_at = 22:00)
    Note over Cajero, DB: Cruce de las 00:00:00 del calendario astronÃ³mico
    Cajero->>POS: rpc_procesar_venta_v3 (01:30 AM)
    POS->>DB: Validar turno abierto y opened_at < 24h
    DB-->>POS: Turno activo vÃ¡lido (antigÃ¼edad 3.5h)
    POS-->>Cajero: Venta procesada exitosamente (Sin logout)

    Note over Cron, DB: 2. EJECUCIÃ“N ASÃNCRONA DE CIERRE FORZADO (RN-017-02)
    Note over DB: El turno no fue cerrado manualmente y cumple 24 horas abiertas
    Cron->>DB: rpc_check_and_force_close_shifts()
    DB->>DB: Sella cash_sessions (status = 'closed', forced_close = true, actual_balance = NULL)
    DB->>DB: Disparo trg_expire_passes_on_cash_close -> expire_daily_passes()
    DB->>DB: UPDATE daily_passes SET status = 'expired'
    DB->>DB: INSERT audit_logs (action = 'FORCED_CLOSE_24H')
    DB->>DB: INSERT notifications (audience = 'admin', type = 'finance')

    Note over Cajero, DB: 3. INTENTO TRANSACCIONAL SOBRE TURNO CADUCADO (DEFENSA EN PROFUNDIDAD)
    Cajero->>POS: Intentar registrar venta o egreso
    POS->>DB: Verificar turno activo
    DB-->>POS: Caja cerrada forzosamente / Pase expirado
    POS-->>Cajero: Error 403 (SHIFT_EXPIRED / CASH_SESSION_CLOSED)
    Cajero->>Cajero: Bloqueo de POS y redirecciÃ³n a pantalla informativa

    Note over Admin, DB: 4. ALERTA BLOQUEANTE Y RECONCILIACIÃ“N (RN-017-03)
    Admin->>POS: Intentar abrir nuevo turno de caja
    POS->>DB: Verificar turnos pendientes
    DB-->>POS: Existe turno cerrado forzosamente sin reconciliar (actual_balance IS NULL)
    POS-->>Admin: Error 409 (RECONCILIATION_REQUIRED)
    Admin->>POS: rpc_reconciliar_cierre_forzado(p_session_id, p_actual_balance)
    POS->>DB: assert_store_access() + Calcular difference en servidor
    DB->>DB: UPDATE cash_sessions (actual_balance = p_actual, difference = v_diff, closed_by = admin)
    DB->>DB: INSERT audit_logs (action = 'FORCED_CLOSE_RECONCILED')
    POS-->>Admin: Turno reconciliado exitosamente. Se autoriza apertura de nueva caja.
```

---

### 2.2 Diagrama de Estados: MÃ¡quina de Estados del Ciclo Contable de Caja

```mermaid
stateDiagram-v2
    [*] --> Cerrada : Inicio de operaciones / Sin caja abierta

    Cerrada --> Abierta : abrir_caja (Base inicial registrada)

    state Abierta {
        [*] --> Operando : Turno activo (< 24h)
        Operando --> Operando : Venta POS / Cruce de Medianoche sin interrupciÃ³n
        Operando --> Operando : Egresos OPEX / Pagos a Proveedores con fondos
    }

    Abierta --> Cerrada_Normal : Cierre voluntario antes de 24h (Arqueo fÃ­sico ciego)
    Cerrada_Normal --> Cerrada : Turno liquidado con difference registrada

    Abierta --> Cerrada_Forzada : Turno cumple 24h abiertas (rpc_check_and_force_close_shifts)
    
    state Cerrada_Forzada {
        [*] --> Pendiente_Reconciliacion : actual_balance = NULL, difference = NULL
        Pendiente_Reconciliacion --> Pases_Expirados : trg_expire_passes_on_cash_close
        Pases_Expirados --> Notificacion_Emitida : Alerta en notifications y audit_logs
    }

    Cerrada_Forzada --> Bloqueo_Apertura : Intento de abrir nueva sesiÃ³n de caja
    Bloqueo_Apertura --> Reconciliando : Admin ejecuta rpc_reconciliar_cierre_forzado
    Reconciliando --> Cerrada : Arqueo ciego saldado (difference calculada en servidor)
```

---

## 3. ESQUEMA DE DATOS Y MODELO DE DOMINIO

### 3.1 Estructura FÃ­sica Real de la Tabla `cash_sessions`
La entidad fÃ­sica real en Supabase ProducciÃ³n (`ihtjocmhzuliwwvdzfnz`) que gobierna el ciclo contable consta de 12 columnas verificadas:

| Columna | Tipo de Dato | Nulable | RestricciÃ³n / Default | DescripciÃ³n de Negocio |
|---------|--------------|---------|-----------------------|------------------------|
| `id` | `uuid` | NO | `PRIMARY KEY`, default `gen_random_uuid()` | Identificador Ãºnico e inmutable del turno contable. |
| `store_id` | `uuid` | NO | `FK stores.id` | Tienda propietaria del turno (aislamiento multi-tenant). |
| `opened_by` | `uuid` | NO | `FK employees.id` | Empleado o administrador que realizÃ³ la apertura fÃ­sica. |
| `closed_by` | `uuid` | SÃ | `FK employees.id` | Actor que ejecutÃ³ el cierre o la reconciliaciÃ³n del turno. |
| `opening_balance` | `numeric` | NO | Importe monetario COP entero | Saldo base inicial en efectivo al momento de la apertura. |
| `expected_balance` | `numeric` | SÃ | Calculado en backend | Saldo teÃ³rico esperado calculado por agregaciÃ³n contable. |
| `actual_balance` | `numeric` | SÃ | `NULL` en cierre forzado | Dinero fÃ­sico contado en arqueo ciego por el operador. |
| `difference` | `numeric` | SÃ | `NULL` en cierre forzado | Descuadre contable calculado exclusivamente en servidor. |
| `status` | `text` | NO | Default `'open'`, `CHECK status IN ('open', 'closed')` | Estado operativo del turno de caja. |
| `opened_at` | `timestamptz` | NO | Default `now()` | **Estampa temporal de apertura** (base del techo de 24h). |
| `closed_at` | `timestamptz` | SÃ | `NULL` mientras estÃ© abierta | Estampa temporal de cierre formal o cierre forzado. |
| `forced_close` | `boolean` | NO | Default `false` | **Bandera fÃ­sica** que identifica turnos cerrados por lÃ­mite de 24h. |

---

### 3.2 Estructura FÃ­sica de la Tabla `cash_movements`
AsignaciÃ³n contable inmutable (`session_id`) por cada hecho econÃ³mico:

| Columna | Tipo de Dato | Nulable | RestricciÃ³n / Default | DescripciÃ³n de Negocio |
|---------|--------------|---------|-----------------------|------------------------|
| `id` | `uuid` | NO | `PRIMARY KEY`, default `gen_random_uuid()` | Identificador del movimiento de tesorerÃ­a. |
| `session_id` | `uuid` | NO | `FK cash_sessions.id ON DELETE CASCADE` | **VinculaciÃ³n irrevocable al turno contable** (`RN-017-04`). |
| `movement_type` | `text` | NO | `CHECK movement_type IN ('ingreso', 'gasto', 'pago_proveedor')` | ClasificaciÃ³n contable del flujo de caja. |
| `amount` | `numeric` | NO | `CHECK amount > 0` | Importe monetario en enteros COP sin centavos. |
| `description` | `text` | NO | Texto no vacÃ­o | DescripciÃ³n del concepto (con tag de canal ej. `[Efectivo]`). |
| `sale_id` | `uuid` | SÃ | `FK sales.id` | Llave forÃ¡nea a la venta originaria (en cobros POS). |
| `created_at` | `timestamptz` | NO | Default `now()` | Estampa temporal del asiento contable. |

---

### 3.3 Procedimiento de Cierre Forzado: `rpc_check_and_force_close_shifts()`
Procedimiento almacenado en producciÃ³n ejecutado de forma asÃ­ncrona por cron job de mantenimiento:
1. **Criterio de SelecciÃ³n:** Itera sobre `cash_sessions` donde `status = 'open'` y `opened_at < (NOW() - INTERVAL '24 hours')`.
2. **CÃ¡lculo de Saldo Esperado Unificado:**
   Calcula `v_ingresos` sumando `amount` de `cash_movements` con `movement_type = 'ingreso'`.
   Calcula `v_gastos` sumando `amount` de `cash_movements` con `movement_type IN ('gasto', 'pago_proveedor')`.
   Calcula `v_expected = r.opening_balance + v_ingresos - v_gastos`.
3. **Sellado AtÃ³mico de la SesiÃ³n:**
   Actualiza la fila fijando `status = 'closed'`, `forced_close = true`, `expected_balance = v_expected`, `actual_balance = NULL`, `difference = NULL`, y `closed_at = NOW()`.
4. **Disparo Reactivo del Trigger de Pases:**
   La transiciÃ³n de `'open'` a `'closed'` acciona automÃ¡ticamente `trg_expire_passes_on_cash_close`, expirando los pases diarios aprobados de la tienda (`daily_passes.status = 'expired'`).
5. **AuditorÃ­a Forense y NotificaciÃ³n Administrativa:**
   Inserta asiento en `audit_logs` con `action = 'FORCED_CLOSE_24H'`.
   Inserta registro en `notifications` con `type = 'finance'`, `audience = 'admin'`, y tÃ­tulo `âš ï¸ Cierre Forzado de Caja (24 Horas)`.

---

### 3.4 Procedimiento de ReconciliaciÃ³n: `rpc_reconciliar_cierre_forzado()`
Procedimiento almacenado para saldar la cuenta tras un cierre forzado:
1. **Validaciones de Entrada:** Exige `p_actual_balance >= 0`.
2. **Seguridad RBAC en Servidor:** Valida que el empleado o administrador posea el permiso `canOpenCloseCash = true`.
3. **ValidaciÃ³n de Estado:** Localiza la sesiÃ³n verificando que cumpla estrictamente `id = p_session_id`, `status = 'closed'`, `forced_close = true` y `actual_balance IS NULL`.
4. **Aislamiento Multi-Tenant (Regla 4):** Valida que el invocador pertenezca a la tienda de la sesiÃ³n (`assert_store_access`).
5. **CÃ¡lculo de Diferencia en Servidor:** Computa `v_difference = p_actual_balance - v_session.expected_balance` (positivo = sobrante, negativo = faltante; misma convenciÃ³n que `cerrar_caja`, SDD-020 H-5).
6. **LiquidaciÃ³n:** Actualiza `actual_balance = p_actual_balance`, `difference = v_difference` y `closed_by = p_employee_id`.
7. **Asiento Inmutable:** Inserta en `audit_logs` el evento `FORCED_CLOSE_RECONCILED` usando las columnas reales (`actor_id`, `store_id`, `event_type`, `resource_id`, `metadata`, `severity`). Como `audit_logs.actor_id` tiene dos FK (`employees` y `auth.users`), el actor debe existir en ambas; de lo contrario aborta con `AUDIT_ACTOR_UNRESOLVABLE`.
8. **Errores como excepciones (Regla 3):** Todo rechazo de negocio se propaga con `RAISE EXCEPTION` (`INVALID_BALANCE`, `SESSION_NOT_FOUND`, `STORE_ACCESS_DENIED`, `EMPLOYEE_NOT_FOUND`, `INSUFFICIENT_PERMISSIONS`, `AUDIT_ACTOR_UNRESOLVABLE`, `SESSION_NOT_RECONCILABLE`); nunca `{success:false}` con forma de dato vÃ¡lido.

---

## 4. REGLAS DE NEGOCIO Y VALIDACIONES

### 4.1 RN-017-01: Continuidad del Turno (Cruce de Medianoche)
1. Un turno de caja activo puede cruzar libremente la medianoche astronÃ³mica (00:00:00) sin corte forzado ni pÃ©rdida de estado.
2. Las sesiones operativas de usuario y los pases diarios se mantienen activos mientras el turno de caja permanezca abierto y no se haya alcanzado el techo temporal estricto de 24 horas.
3. El frontend y el backend tienen prohibido ejecutar `logout()`, descartar tokens o invalidar pases Ãºnicamente por el cambio de fecha calendario del reloj local o del servidor.

### 4.2 RN-017-02: Cierre Forzado por Techo de 24 Horas
1. Si un turno de caja permanece abierto exactamente 24 horas despuÃ©s de su apertura (`opened_at < NOW() - INTERVAL '24 hours'`):
   - El sistema conmuta el estado de la caja a `closed` marcando `forced_close = true`.
   - El sistema sella el turno con el saldo esperado calculado matemÃ¡ticamente hasta ese instante.
   - El saldo real (`actual_balance`) y la diferencia (`difference`) se establecen obligatoriamente en `NULL`. Queda estrictamente prohibido asumir un cuadre en cero ($0 de diferencia).
   - Todos los pases diarios operativos de la tienda caducan inmediatamente por la acciÃ³n reactiva del trigger de base de datos.

### 4.3 RN-017-03: AuditorÃ­a y Alerta Bloqueante Post-Cierre Forzado
1. **AuditorÃ­a Forense:** El cierre forzado genera automÃ¡ticamente un registro inmutable en `audit_logs` documentando que la acciÃ³n fue ejecutada por el sistema debido a negligencia temporal del operador.
2. **NotificaciÃ³n Persistente:** Se genera una notificaciÃ³n en `notifications` dirigida a la audiencia `'admin'`.
3. **Alerta Bloqueante:** El sistema impide la apertura de un NUEVO turno de caja en la tienda mientras exista un turno con `forced_close = true AND actual_balance IS NULL`.
4. **ReconciliaciÃ³n Humana Obligatoria:** Antes de iniciar un nuevo ciclo contable, el Administrador o un operador con permiso `canOpenCloseCash` debe realizar el arqueo fÃ­sico a ciegas, acusar recibo de la notificaciÃ³n y ejecutar `rpc_reconciliar_cierre_forzado`. El sistema se exime de responsabilidad por el dinero fÃ­sico no supervisado durante el tiempo de abandono.

### 4.4 RN-017-04: Inmutabilidad de la AsignaciÃ³n Contable (Principio de Devengo)
1. Todas las transacciones de venta (`sales`), items y movimientos de tesorerÃ­a (`cash_movements`) registrados durante un turno quedan irrevocablemente asociados al `session_id` de ese turno.
2. Ni el cierre forzado asÃ­ncrono ni la reconciliaciÃ³n administrativa posterior mutan retrospectivamente las transacciones, las ventas devengadas ni el costo de ventas (COGS FIFO) en el estado de resultados (`SDD-018`).

### 4.5 Defensa en Profundidad Transaccional (< 24h)
1. Las funciones transaccionales de venta en POS (`rpc_procesar_venta_v3`), pago a proveedores (`rpc_pay_supplier_invoice`) y registro de gastos (`rpc_registrar_gasto`) evalÃºan en tiempo real la antigÃ¼edad del turno abierto.
2. Si un turno abierto rebasÃ³ las 24 horas y el cron job aÃºn no ha ejecutado el cierre batch, la transacciÃ³n es rechazada con el cÃ³digo canÃ³nico `SHIFT_EXPIRED`, forzando la expulsiÃ³n defensiva del punto de venta y evitando la contaminaciÃ³n de registros contables caducados.

---

## 5. CONTRATO DE INTERFAZ (PAYLOADS JSON)

Los contratos de interfaz se adhieren a la **Regla Global 4** del proyecto.

### 5.1 EjecuciÃ³n Batch de Cierre Forzado de 24 Horas
- **OperaciÃ³n Backend:** `rpc_check_and_force_close_shifts`
- **MÃ©todo / RPC:** Supabase RPC (Invocado por Cron o Servicio de Mantenimiento con rol `service_role`).

#### Payload de Entrada:
```json
{}
```

#### Payload de Respuesta (Ã‰xito):
```json
{
  "success": true,
  "closed_shifts": 1
}
```

---

### 5.2 ReconciliaciÃ³n Administrativa de Cierre Forzado
- **OperaciÃ³n Backend:** `rpc_reconciliar_cierre_forzado`
- **Requisito de Seguridad:** Exclusivo personal con permiso `canOpenCloseCash = true` o rol `admin`. Ejecuta `assert_store_access(v_session.store_id)`.

#### Payload de Entrada:
```json
{
  "p_session_id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
  "p_employee_id": "8f7e6d5c-4b3a-2109-8765-4321fedcba98",
  "p_actual_balance": 1850000
}
```

#### Payload de Respuesta (Ã‰xito - Arqueo Conciliado con Diferencia):
```json
{
  "success": true,
  "expected_balance": 1870000,
  "actual_balance": 1850000,
  "difference": 20000
}
```

#### Payload de Respuesta (Fallo - SesiÃ³n Ya Reconciliada o InvÃ¡lida):
```json
{
  "success": false,
  "error": "La sesiÃ³n no existe, no fue cerrada forzosamente, o ya fue reconciliada.",
  "code": "SESSION_NOT_RECONCILIABLE"
}
```

#### Payload de Respuesta (Fallo - Permisos Insuficientes):
```json
{
  "success": false,
  "error": "Sin permiso para reconciliar cierres de caja.",
  "code": "INSUFFICIENT_PERMISSIONS"
}
```

---

### 5.3 Consulta de Estado del Turno y ValidaciÃ³n de AntigÃ¼edad
- **OperaciÃ³n Backend:** `get_active_cash_session`
- **Formato:** Regla Global 4.1.

#### Payload de Entrada:
```json
{
  "p_store_id": "3f9a7210-61b4-4e2b-a320-1a76c8901234"
}
```

#### Payload de Respuesta (Turno Activo VÃ¡lido < 24h):
```json
{
  "isOpen": true,
  "sessionId": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
  "openingAmount": 200000,
  "openedBy": "8f7e6d5c-4b3a-2109-8765-4321fedcba98",
  "openedAt": "2026-10-16T08:00:00Z"
}
```

#### Payload de Respuesta (Sin Turno Activo):
```json
{
  "isOpen": false
}
```

---

## 6. SEGURIDAD, POLÃTICAS RLS Y MULTI-TENANCY

### 6.1 Aislamiento Multi-Tenant y Regla 4 de Seguridad Centralizada
1. **ReutilizaciÃ³n Obligatoria de `assert_store_access(p_store_id)` (Regla 4):**
   Las funciones administrativas de conciliaciÃ³n de turno ejecutan como primera instrucciÃ³n incondicional:
   `PERFORM public.assert_store_access(v_session.store_id);`
   Si el invocador autenticado no pertenece a la tienda titular de la sesiÃ³n de caja, la ejecuciÃ³n aborta con la excepciÃ³n `STORE_ACCESS_DENIED`.
2. **Gobernanza RLS Centralizada mediante `get_current_store_id()`:**
   Las tablas `cash_sessions`, `cash_movements`, `notifications` y `daily_passes` aplican aislamiento de inquilinos en sus polÃ­ticas RLS comparando estrictamente contra la funciÃ³n centralizada `public.get_current_store_id()`.

### 6.2 PolÃ­ticas de Seguridad a Nivel de Fila (RLS)
- **`cash_sessions`:**
  - `cash_sessions_select_store`: `store_id = get_current_store_id()`.
  - `cash_sessions_insert_store`: `WITH CHECK (store_id = get_current_store_id())`.
  - `cash_sessions_update_store`: `store_id = get_current_store_id()`.
- **`cash_movements`:**
  - `cash_movements_select_store` / `cash_movements_insert_store`: Delegan mediante `EXISTS` hacia `cash_sessions.store_id = get_current_store_id()`.
- **`notifications`:**
  - Lectura y actualizaciÃ³n restringidas a la tienda propia (`store_id = get_current_store_id()`) y a la audiencia correspondiente (`admin`, `employee`, `all`).
- **Inviolabilidad Contable (`POL-AUD-01`):**
  Queda prohibido cualquier `DELETE` fÃ­sico sobre `cash_sessions`, `cash_movements` y `audit_logs`.

### 6.3 Privilegios Base a Nivel de Tabla (Regla 8)
En estricto cumplimiento de la **Regla 8 de AGENTS.md**, se encuentran verificados los privilegios mediante `has_table_privilege`:
- `cash_sessions`: Otorgados para `anon`, `authenticated`, `service_role`.
- `cash_movements`: Otorgados para `anon`, `authenticated`, `service_role`.
- `daily_passes`: Otorgados para `anon`, `authenticated`, `service_role`.
- `notifications`: Otorgados para `authenticated`, `service_role`.
- `audit_logs`: Otorgados para `authenticated` (lectura) y `service_role` (escritura).
- Todas las tablas mantienen `rowsecurity = true`, garantizando inmunidad ante errores PostgreSQL `42501 (Permission Denied)`.

---

## 7. DEUDAS TÃ‰CNICAS Y DECISIONES DIFERIDAS

En estricto cumplimiento de la **Regla 7 de AGENTS.md**, se formalizan a continuaciÃ³n las decisiones tÃ©cnicas, compromisos y condiciones de revisiÃ³n del mÃ³dulo:

### D-1: Continuidad Contable del Turno vs Reloj AstronÃ³mico (`RN-017-01` vs `SDD-001 / SDD-013`)
- **QuÃ© se decidiÃ³:** Consagrar que el perÃ­odo contable de caja se rige por el Hecho EconÃ³mico continuo y el lÃ­mite temporal de 24 horas, suprimiendo deslogueos y expiraciones de pase a medianoche (00:00:00). La expiraciÃ³n de pases se supedita exclusivamente al cierre formal de caja vÃ­a trigger `trg_expire_passes_on_cash_close`.
- **Por quÃ© / Trade-off:** Otorga flexibilidad operativa para turnos nocturnos sin interrumpir las ventas en el mostrador, manteniendo intacta la disciplina de conciliaciÃ³n fÃ­sica al finalizar la jornada.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Permanente. Invariante de diseÃ±o contable-financiero.

### D-2: EjecuciÃ³n AtÃ³mica del Cierre Forzado a las 24 Horas (`rpc_check_and_force_close_shifts`)
- **QuÃ© se decidiÃ³:** Normar que el cierre forzado sella el turno fijando `status = 'closed'`, `forced_close = true`, `expected_balance = v_expected`, `actual_balance = NULL` y `difference = NULL`, disparando automÃ¡ticamente la expiraciÃ³n de pases operativos vÃ­a trigger y emitiendo auditorÃ­a y alerta administrativa.
- **Por quÃ© / Trade-off:** Protege la caja contra el abandono operativo sin generar cuadres falsos ($0 de descuadre) que oculten pÃ©rdidas de dinero real o impidan la rendiciÃ³n de cuentas.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Permanente. Invariante contable de la plataforma.

### D-3: ReconciliaciÃ³n Administrativa Obligatoria Post-Cierre Forzado (`rpc_reconciliar_cierre_forzado`)
- **QuÃ© se decidiÃ³:** Estandarizar que toda caja cerrada forzosamente bloquee la apertura de un nuevo turno en la tienda hasta que un usuario con `canOpenCloseCash` ejecute `rpc_reconciliar_cierre_forzado` ingresando el arqueo fÃ­sico real a ciegas.
- **Por quÃ© / Trade-off:** Impone responsabilidad y supervisiÃ³n humana obligatoria sobre turnos abandonados, impidiendo el arrastre de faltantes no justificados hacia nuevas jornadas.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Permanente. Invariante de control interno y auditorÃ­a.

### D-4: PrecondiciÃ³n Defensiva `< 24h` en Transacciones POS y Egresos (`SDD-007 / SDD-019 / SDD-022`)
- **QuÃ© se decidiÃ³:** Normar que las funciones transaccionales (`rpc_procesar_venta_v3`, `rpc_pay_supplier_invoice`, `rpc_registrar_gasto`) validen en tiempo real que el turno abierto tenga antigÃ¼edad menor a 24 horas, rechazando operaciones con `SHIFT_EXPIRED` si el turno rebasÃ³ el lÃ­mite temporal.
- **Por quÃ© / Trade-off:** Elimina la ventana de vulnerabilidad entre el cumplimiento de las 24 horas y la ejecuciÃ³n asÃ­ncrona del cron job de mantenimiento, asegurando defensa en profundidad.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Permanente. EstÃ¡ndar de integridad transaccional.

### D-5: Integridad Contable Inmutable y Devengo (`RN-017-04` / Devengo / `SDD-018`)
- **QuÃ© se decidiÃ³:** Consagrar que todos los movimientos de caja (`cash_movements`) permanecen inmutablemente atados a su `session_id` original; ni el cierre forzado ni la reconciliaciÃ³n administrativa mutan retrospectivamente las ventas, los cobros ni el P&L devengado en SDD-018.
- **Por quÃ© / Trade-off:** Garantiza la inviolabilidad del estado de resultados y el costo de ventas FIFO ante contingencias o negligencias operativas en el turno de caja.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Permanente. Principio contable fundamental del sistema.
### D-6: ReconciliaciÃ³n de Cierre Forzado Solo en Efectivo (correcciÃ³n 2026-10-21)
- **QuÃ© se decidiÃ³:** El modal de auditorÃ­a pide un Ãºnico conteo fÃ­sico en efectivo por sesiÃ³n pendiente y el cliente ya no consulta `cash_session_balances` ni recibe `expected_balance` (Arqueo Ciego).
- **Por quÃ© / Trade-off:** `cash_session_balances` no existe en producciÃ³n (SDD-020 Ola 4 diferida) y el backend vivo (`cerrar_caja`, `rpc_check_and_force_close_shifts`, `rpc_reconciliar_cierre_forzado`) calcula `expected_balance` solo con `payment_method = 'efectivo'`. La consulta a la tabla inexistente devolvÃ­a `PGRST205` y dejaba inalcanzable la reconciliaciÃ³n. Costo: no se concilia fÃ­sicamente Nequi/Daviplata/BRE (son saldos bancarios, no de gaveta; siguen trazables en `cash_movements.payment_method`).
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Al desplegar `rpc_cerrar_caja_multicanal` con `cash_session_balances` (SDD-020, Ola 4).

### D-7: Compuerta Servidor de Apertura (`RECONCILIATION_REQUIRED`) Diferida
- **QuÃ© se decidiÃ³:** No modificar `abrir_caja` en esta correcciÃ³n. Hoy la compuerta RN-017-03 existe solo en cliente (`CashControlView`), que ahora falla cerrado si no puede verificar turnos pendientes. Verificado: `abrir_caja` en producciÃ³n abre con un turno forzado pendiente.
- **Por quÃ© / Trade-off:** Mover la compuerta a SQL es lo correcto (Muro 1) pero bloquearÃ­a la apertura de toda tienda con cierres forzados pendientes (hoy 2 en producciÃ³n) y no se pudo validar de extremo a extremo con un empleado de pase diario en esta correcciÃ³n.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Tras confirmar la reconciliaciÃ³n en producciÃ³n con el administrador y con un empleado con `canOpenCloseCash`; entonces `abrir_caja` debe abortar con `RECONCILIATION_REQUIRED`.

### D-8: Empleados sin Identidad en `auth.users` No Pueden Reconciliar
- **QuÃ© se decidiÃ³:** `rpc_reconciliar_cierre_forzado` aborta con `AUDIT_ACTOR_UNRESOLVABLE` si `p_employee_id` no existe en `auth.users` (3 de 5 empleados en producciÃ³n).
- **Por quÃ© / Trade-off:** `audit_logs.actor_id` exige existir en `employees` y en `auth.users` (`fk_audit_user`); relajarlo afecta una tabla compartida entre mÃ³dulos (Regla 6). Un administrador puede reconciliar siempre.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Al unificar la autenticaciÃ³n de empleados en `auth.users` o al relajar `fk_audit_user` con auditorÃ­a de impacto cruzado.

