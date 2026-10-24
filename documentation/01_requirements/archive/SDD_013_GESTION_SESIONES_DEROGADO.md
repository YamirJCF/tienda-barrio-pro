> [!CAUTION]
> **DOCUMENTO DEROGADO Y ARCHIVADO**
> **Estado:** 🔴 DEROGADO — Conservado exclusivamente para trazabilidad histórica y auditoría comparativa contra v3.0.0.
> **Fecha de Derogación:** 2026-10-24
> **Sustituido por:** `documentation/01_requirements/SDD/SDD_013_GESTION_SESIONES.md` (v3.0.0)

# SDD-013: GestiÃ³n de Sesiones y Control de Concurrencia

> **Asociado a:** [FRD-013: GestiÃ³n de Sesiones](../FRD/FRD_013_GESTION_SESIONES.md)  
> **Fase del Plan:** Ola 5: Sesiones, AutenticaciÃ³n y Offline (Ãtem 2)  
> **Estado:** ðŸŸ  Aprobado con Deuda TÃ©cnica Documentada (Protocolo PAC-SDD v2.0)
> **Ãšltima ActualizaciÃ³n:** 2026-10-16  

---

## 0. CONTROL DE VERSIONES Y TRAZABILIDAD

### 0.1 Historial de Cambios
| VersiÃ³n | Fecha | Autor | Rol | DescripciÃ³n de ModificaciÃ³n |
|---------|-------|-------|-----|-----------------------------|
| 1.0.0 | 2026-01-28 | Arquitecto de Requisitos | Requisitos | RedacciÃ³n inicial de reglas de sesiÃ³n y concurrencia. |
| 1.5.0 | 2026-08-05 | Arquitecto de Software | Arquitectura | IncorporaciÃ³n preliminar de diagramas UML y modelo transitorio. |
| 2.0.0 | 2026-10-16 | Orquestador TÃ©cnico | Arquitectura & QA | **Saneamiento Integral PAC-SDD v2.0**: ErradicaciÃ³n de la tabla alucinada `device_sessions`, consolidaciÃ³n sobre `daily_passes.device_fingerprint`, formalizaciÃ³n del lÃ­mite de 6 sesiones en servidor, trigger reactivo `trg_expire_passes_on_cash_close`, cumplimiento de Reglas 1.1 (0% cÃ³digo SQL), 2, 4, 7 y 8, e integraciÃ³n con el protocolo Zero Trust. |

### 0.2 Trazabilidad de Requisitos (FRD-013)
| Regla de Negocio / CA | DescripciÃ³n en FRD | ImplementaciÃ³n en este SDD |
|-----------------------|--------------------|----------------------------|
| **RN-013-01** | DuraciÃ³n indefinida de la sesiÃ³n sin caducidad horaria | SecciÃ³n 4.1 y SecciÃ³n 2 (Diagrama de Estados) |
| **RN-013-02** | LÃ­mite de 6 sesiones concurrentes simultÃ¡neas por tienda | SecciÃ³n 4.2, SecciÃ³n 3.2 y SecciÃ³n 5.1 |
| **RN-013-03** | Comportamiento de Logout voluntario y retenciÃ³n de cachÃ© | SecciÃ³n 4.3, SecciÃ³n 5.2 y SecciÃ³n 7 (D-5) |
| **RN-013-04** | Sin timeout automÃ¡tico por inactividad fÃ­sica | SecciÃ³n 4.4 y SecciÃ³n 2 |
| **RN-013-05** | Cierre forzado por desactivaciÃ³n de cuenta de empleado | SecciÃ³n 4.5, SecciÃ³n 5.3 y SecciÃ³n 6.2 |
| **RN-013-06** | ExpiraciÃ³n masiva de pases por cierre de caja diaria | SecciÃ³n 4.6, SecciÃ³n 3.4 y SecciÃ³n 7 (D-4) |
| **RN-013-07** | RevocaciÃ³n remota de terminal por Administrador | SecciÃ³n 4.7, SecciÃ³n 5.4 y SecciÃ³n 7 (D-1) |
| **CA-01 a CA-11** | Criterios de AceptaciÃ³n (Concurrencia, Logout, Reactividad) | SecciÃ³n 4 y SecciÃ³n 6 |

### 0.3 Matriz de Dependencias Inter-Modulares
| Documento Vecino | Tipo de Dependencia | Flujo o RestricciÃ³n Vinculante |
|------------------|---------------------|--------------------------------|
| [SDD-001](../SDD/SDD_001_SEGURIDAD_DIARIA.md) | Proveedor de Identidad | SubordinaciÃ³n al Pase Diario Zero Trust (`daily_passes`). NingÃºn empleado opera sin pase aprobado para el dÃ­a. |
| [SDD-002](../SDD/SDD_002_REGISTRO_ADMIN.md) / [SDD-002.1](../SDD/SDD_002_1_CAMBIO_CONTRASENA.md) | Consumidor / Productor | SesiÃ³n administrativa (`admin_profiles`), reserva del slot #1 de 6, y facultad de revocaciÃ³n remota. |
| [SDD-003](../SDD/SDD_003_GESTION_EMPLEADOS.md) | Control de Personal | DesactivaciÃ³n reactiva (`is_active = false`) que expulsa inmediatamente sesiones vivas y expira pases diarios. |
| [SDD-004](../SDD/SDD_004_CONTROL_DE_CAJA.md) / [SDD-020](../SDD/SDD_020_CAJA_MULTICANAL.md) | Gobernanza Financiera | `trg_expire_passes_on_cash_close` en `cash_sessions` conmuta a `'expired'` todos los pases operativos del turno. |
| [SDD-007](../SDD/SDD_007_NUCLEO_VENTAS_PADRE.md) / [SDD-007.1](../SDD/SDD_007_01_NUCLEO_POS.md) | Consumidor Transaccional | ValidaciÃ³n transaccional de pase activo (`is_authorized_employee()`) en cada cobro POS. |
| [SDD-011](../SDD/SDD_011_MANEJO_ERRORES.md) | Manejo de Excepciones | CÃ³digos de error canÃ³nicos: `SESSION_LIMIT_REACHED`, `ACCOUNT_DISABLED`, `SESSION_REVOKED`, `DAILY_PASS_EXPIRED`. |
| [SDD-012](../SDD/SDD_012_SINCRONIZACION_OFFLINE.md) / [SDD-028](../SDD/SDD_028_ALMACENAMIENTO_LOCAL.md) | Persistencia Local | PreservaciÃ³n de catÃ¡logos maestros (`products`, `clients`) y cola `sync_queue` en logout voluntario. |
| [SDD-005](../SDD/SDD_005_AUDITORIA_TRAZABILIDAD.md) | Trazabilidad Forense | Inviolabilidad contable (`POL-AUD-01`): Registro inmutable en `audit_logs` ante inicios, cierres y revocaciones. |
| [SDD-015](../SDD/SDD_015_GESTION_DISPOSITIVOS.md) | GestiÃ³n de Terminales | Interfaz administrativa de auditorÃ­a de dispositivos y orquestaciÃ³n de revocaciÃ³n remota. |

---

## 1. RESUMEN EJECUTIVO Y ALCANCE

El mÃ³dulo de **GestiÃ³n de Sesiones y Control de Concurrencia** establece la arquitectura que gobierna el ciclo de vida, la permanencia, la seguridad perimetral y la concurrencia de terminales activas en el ecosistema **Tienda Barrio Pro**.

### 1.1 Principios Rectores de Arquitectura
1. **Zero Trust Subordinated to Daily Pass (`POL-SEC-02`):** La identidad de los empleados no concede acceso autÃ³nomo ni permanente. La vigencia operativa estÃ¡ subordinada exclusivamente a la existencia de un registro activo en `daily_passes` con estado `'approved'` para la fecha actual (`pass_date = CURRENT_DATE`).
2. **ErradicaciÃ³n de Tablas Alucinadas (`Regla 2 Anti-AlucinaciÃ³n`):** Se erradica terminantemente el concepto teÃ³rico de la tabla `device_sessions`. El estado de conexiÃ³n del terminal, la huella digital del dispositivo y el control de vigencia se sustentan sobre la columna fÃ­sica `device_fingerprint` y el ciclo de estados de la tabla real `daily_passes`.
3. **Control de Concurrencia Estricto de 6 Terminales (`RN-013-02`):** Cada tienda (`stores`) tiene una capacidad concurrente mÃ¡xima de 6 sesiones activas simultÃ¡neas: 1 slot reservado para la administraciÃ³n (`admin_profiles`) y un mÃ¡ximo de 5 slots operativos para empleados con pase diario aprobado. El intento de una 7ma sesiÃ³n es rechazado en servidor con el cÃ³digo `SESSION_LIMIT_REACHED`.
4. **SesiÃ³n Continua sin Timeout por Inactividad (`RN-013-04`):** El sistema no cierra sesiones por inactividad fÃ­sica, garantizando que el punto de venta permanezca disponible durante la jornada de atenciÃ³n del tendero.
5. **ExpiraciÃ³n Reactiva por Cierre de Caja (`POL-FIN-01 / RN-013-06`):** El cierre formal de la caja del turno desencadena a nivel de base de datos la expiraciÃ³n masiva e inmediata de los pases diarios operativos de la tienda mediante el trigger `trg_expire_passes_on_cash_close`.
6. **Logout Seguro y Resiliencia Offline (`RN-013-03 / POL-OFF-01`):** El cierre voluntario destruye tokens de acceso e invalida carritos transaccionales en memoria, pero preserva los catÃ¡logos pesados en IndexedDB para asegurar arranques instantÃ¡neos y tolerantes a fallos de conectividad.

---

## 2. ARQUITECTURA GENERAL Y DIAGRAMA DE FLUJO

### 2.1 Diagrama de Secuencia: Ciclo de Vida y Control de Concurrencia
El siguiente diagrama ilustra el flujo de autenticaciÃ³n, control de capacidad mÃ¡xima de terminales y revocaciÃ³n remota en servidor:

```mermaid
sequenceDiagram
    autonumber
    participant Terminal as ðŸ“± Terminal POS
    participant Store as ðŸ“¦ Auth / Pinia Store
    participant Server as âš¡ Supabase RPCs
    participant DB as ðŸ”’ PostgreSQL (daily_passes / admin_profiles)
    participant Admin as ðŸ’» Panel Administrador

    Note over Terminal, DB: 1. SOLICITUD DE ACCESO Y CONTROL DE CONCURRENCIA
    Terminal->>Store: Iniciar sesiÃ³n (Alias + PIN + device_fingerprint)
    Store->>Server: rpc_solicitar_acceso_empleado(p_username, p_pin, p_fingerprint)
    Server->>DB: Validar credenciales y contar sesiones activas (FOR UPDATE)
    alt Sesiones activas >= 6
        DB-->>Server: LÃ­mite de 6 dispositivos alcanzado
        Server-->>Store: Error 403 (SESSION_LIMIT_REACHED)
        Store-->>Terminal: Mostrar modal: "LÃ­mite de dispositivos alcanzado"
    else Capacidad disponible (< 6)
        Server->>DB: INSERT / UPDATE daily_passes (status = 'pending')
        DB-->>Server: Pase registrado
        Server-->>Store: Esperando aprobaciÃ³n del Administrador
        Store-->>Terminal: Pantalla de espera de aprobaciÃ³n
    end

    Note over Admin, DB: 2. APROBACIÃ“N POR ADMINISTRADOR
    Admin->>Server: aprobar_pase_diario(p_pass_id, p_admin_id)
    Server->>DB: assert_store_access(p_store_id) + UPDATE daily_passes (status = 'approved')
    DB-->>Server: Pase aprobado exitosamente
    Server-->>Admin: ConfirmaciÃ³n visual

    Note over Terminal, DB: 3. NOTIFICACIÃ“N Y ACCESO OPERATIVO
    Terminal->>Server: check_my_pass_status(p_pass_id)
    Server->>DB: Consulta status = 'approved' AND pass_date = CURRENT_DATE
    DB-->>Server: Aprobado
    Server-->>Terminal: EmisiÃ³n de token de sesiÃ³n operativo

    Note over Admin, DB: 4. REVOCACIÃ“N REMOTA DE TERMINAL (RN-013-07)
    Admin->>Server: rpc_revocar_sesion_dispositivo(p_pass_id, p_store_id)
    Server->>DB: assert_store_access(p_store_id) + UPDATE status = 'expired'
    DB-->>Server: Slot liberado inmediatamente
    Server-->>Admin: ConfirmaciÃ³n de revocaciÃ³n

    Note over Terminal, DB: 5. EXPULSIÃ“N REACTIVA EN TERMINAL
    Terminal->>Server: PeticiÃ³n transaccional POS
    Server->>DB: is_authorized_employee()
    DB-->>Server: false (Pase expirado)
    Server-->>Terminal: Error 403 (SESSION_REVOKED)
    Terminal->>Store: Limpiar credenciales y redirigir a Login
```

---

### 2.2 Diagrama de Estados: Ciclo de Vida de la SesiÃ³n

```mermaid
stateDiagram-v2
    [*] --> Inactiva : Terminal sin credenciales

    Inactiva --> Pendiente_Aprobacion : Credenciales OK + Cupo disponible (< 6)
    Inactiva --> Rechazada_Limite : Intento de 7ma sesiÃ³n (SESSION_LIMIT_REACHED)
    Rechazada_Limite --> Inactiva : Cierre de sesiÃ³n en otro dispositivo

    Pendiente_Aprobacion --> Activa : Admin aprueba pase diario (status = 'approved')
    Pendiente_Aprobacion --> Inactiva : Admin rechaza solicitud (status = 'rejected')

    Activa --> Activa : OperaciÃ³n continua / PerÃ­odo de inactividad (Sin Timeout)

    Activa --> Inactiva : Logout voluntario (Credenciales purgadas, CachÃ© intacta)

    Activa --> Expirada_Caja : Cierre de turno de caja (trg_expire_passes_on_cash_close)
    Expirada_Caja --> Inactiva : RedirecciÃ³n a Login al inicio del nuevo dÃ­a

    Activa --> Bloqueada_Desactivacion : Admin desactiva empleado (is_active = false)
    Bloqueada_Desactivacion --> Inactiva : ExpulsiÃ³n reactiva (ACCOUNT_DISABLED)

    Activa --> Revocada_Remota : Admin libera slot en FRD-015 (rpc_revocar_sesion)
    Revocada_Remota --> Inactiva : RedirecciÃ³n a Login (SESSION_REVOKED)
```

---

## 3. ESQUEMA DE DATOS Y MODELO DE DOMINIO

### 3.1 Estructura FÃ­sica Real de la Tabla Central: `daily_passes`
La entidad fÃ­sica real en Supabase ProducciÃ³n (`ihtjocmhzuliwwvdzfnz`) que almacena las sesiones y dispositivos operativos consta de 14 columnas verificadas:

| Columna | Tipo de Dato | Nulable | RestricciÃ³n / Default | DescripciÃ³n de Negocio |
|---------|--------------|---------|-----------------------|------------------------|
| `id` | `uuid` | NO | `PRIMARY KEY`, default `gen_random_uuid()` | Identificador Ãºnico del pase diario y sesiÃ³n operativa. |
| `employee_id` | `uuid` | NO | `FK employees.id ON DELETE CASCADE` | Empleado titular del pase de sesiÃ³n. |
| `pass_date` | `date` | NO | Default `CURRENT_DATE` | Fecha calendario de validez del pase diario. |
| `status` | `text` | NO | Default `'pending'`, `CHECK status IN ('pending', 'approved', 'rejected', 'expired')` | Estado del pase que determina la validez de la sesiÃ³n activa. |
| `device_fingerprint` | `text` | SÃ | `NULL` | Identificador unÃ­voco del hardware/navegador del terminal. |
| `retry_count` | `integer` | SÃ | Default `0`, `CHECK retry_count >= 0 AND retry_count <= 3` | Contador de reintentos de PIN para prevenciÃ³n de ataques. |
| `requested_at` | `timestamptz` | NO | Default `now()` | Estampa temporal en que el empleado solicitÃ³ el pase. |
| `resolved_at` | `timestamptz` | SÃ | `NULL` | Estampa temporal de resoluciÃ³n (aprobaciÃ³n, rechazo o expiraciÃ³n). |
| `resolved_by` | `uuid` | SÃ | `FK employees.id` | Identificador de auditorÃ­a del actor que resolviÃ³ la solicitud. |
| `store_id` | `uuid` | SÃ | `FK stores.id` | Tienda a la que pertenece la sesiÃ³n (aislamiento multi-tenant). |
| `auth_user_id` | `uuid` | SÃ | `FK auth.users.id` | Identificador del usuario en el subsistema de autenticaciÃ³n. |
| `approved_at` | `timestamptz` | SÃ | `NULL` | Estampa temporal de aprobaciÃ³n formal por el administrador. |
| `approved_by` | `uuid` | SÃ | `NULL` | Identificador del administrador que autorizÃ³ el pase. |
| `updated_at` | `timestamptz` | SÃ | Default `now()` | Estampa temporal de Ãºltima mutaciÃ³n del registro. |

#### Restricciones Clave de Integridad:
- **`daily_passes_employee_id_pass_date_key`:** `UNIQUE (employee_id, pass_date)`. Impide que un empleado genere mÃºltiples pases en la misma fecha calendario.
- **`daily_passes_status_check`:** Solo admite `'pending'`, `'approved'`, `'rejected'`, `'expired'`.

---

### 3.2 Estructura FÃ­sica de Tablas Vinculadas

#### Tabla `admin_profiles` (5 columnas fÃ­sicas)
Gobierna la sesiÃ³n administrativa (1 slot concurrente exclusivo del Propietario/Manager):
- `id` (`uuid`, PK, FK `auth.users.id ON DELETE CASCADE`).
- `store_id` (`uuid`, NOT NULL, FK `stores.id ON DELETE CASCADE`).
- `role` (`text`, NOT NULL, default `'owner'`, CHECK `role IN ('owner', 'manager')`).
- `is_verified` (`boolean`, default `false`).
- `created_at` (`timestamptz`, default `now()`).

#### Tabla `employees` (9 columnas fÃ­sicas)
Entidad de identidad operativa para empleados:
- `id` (`uuid`, PK), `store_id` (`uuid`, NOT NULL, FK `stores.id`).
- `name` (`text`, NOT NULL).
- `username` (`text`, NOT NULL, `UNIQUE` global).
- `pin_hash` (`text`, NOT NULL).
- `is_active` (`boolean`, default `true`).
- `permissions` (`jsonb`, default `'{"canFiar": false, "canViewReports": false, "canOpenCloseCash": false, "canViewInventory": false}'::jsonb`).
- `created_at` (`timestamptz`), `updated_at` (`timestamptz`).

#### Tabla `cash_sessions` (12 columnas fÃ­sicas)
Gobernanza del ciclo contable y disparador de expiraciÃ³n:
- `id` (`uuid`, PK), `store_id` (`uuid`, NOT NULL), `opened_by` (`uuid`), `closed_by` (`uuid`).
- `opening_balance` (`numeric`), `expected_balance` (`numeric`), `actual_balance` (`numeric`), `difference` (`numeric`).
- `status` (`text`, CHECK `status IN ('open', 'closed')`).
- `opened_at` (`timestamptz`), `closed_at` (`timestamptz`), `forced_close` (`boolean`).

---

### 3.3 Trigger Reactivo de ExpiraciÃ³n Masiva de Pases
En Supabase ProducciÃ³n, la tabla `cash_sessions` cuenta con el trigger verificado:
- **Nombre:** `trg_expire_passes_on_cash_close`
- **Evento:** `AFTER UPDATE ON public.cash_sessions`
- **CondiciÃ³n y Procedimiento:** Ejecuta la funciÃ³n de base de datos `expire_daily_passes()`.
- **Comportamiento LÃ³gico:**
  Cuando el registro transiciona de `status = 'open'` a `status = 'closed'`, actualiza de forma atÃ³mica en `public.daily_passes`:
  Conmuta `status = 'expired'` para todos los registros donde `employee_id` pertenezca a la misma tienda (`e.store_id = NEW.store_id`), con estado previo `status = 'approved'` y fecha `pass_date <= CURRENT_DATE`.

---

## 4. REGLAS DE NEGOCIO Y VALIDACIONES

### 4.1 RN-013-01: DuraciÃ³n de SesiÃ³n Indefinida
1. El sistema no implementa expiraciÃ³n automÃ¡tica por tiempo de las sesiones autenticadas.
2. Una sesiÃ³n operativa de empleado permanece activa hasta que ocurra uno de los siguientes cuatro eventos:
   - Cierre de sesiÃ³n voluntario por parte del usuario (Logout).
   - El Administrador desactiva la cuenta del empleado (`is_active = false` en `employees`).
   - Se cierra formalmente el turno de caja del dÃ­a (`cash_sessions.status = 'closed'`).
   - El Administrador revoca remotamente el terminal desde la consola de control de dispositivos (`FRD-015`).
3. Una sesiÃ³n de Administrador permanece activa hasta su cierre voluntario o cambio de contraseÃ±a maestro (`SDD-002.1`).

### 4.2 RN-013-02: LÃ­mite Estricto de 6 Sesiones Concurrentes
1. El sistema restringe la capacidad simultÃ¡nea por tienda a un **mÃ¡ximo estricto de 6 terminales activos**:
   - **1 sesiÃ³n de Administrador:** Cuenta propietaria o manager autenticada mediante email/password contra `auth.users` y `admin_profiles`.
   - **Hasta 5 sesiones de Empleados:** Cuentas autenticadas con alias numÃ©rico + PIN que posean un pase diario en estado `approved` para la fecha en curso (`pass_date = CURRENT_DATE`).
2. Si un usuario intenta iniciar una 7ma sesiÃ³n activa en la misma tienda:
   - El backend rechaza la transacciÃ³n abortando con el cÃ³digo canÃ³nico `SESSION_LIMIT_REACHED`.
   - La interfaz visual presenta el mensaje explÃ­cito al usuario: *"LÃ­mite de dispositivos alcanzado. Cierre sesiÃ³n en otro dispositivo para continuar."*
3. La validaciÃ³n se ejecuta obligatoriamente en servidor con bloqueo pesimista en las funciones de autenticaciÃ³n y aprobaciÃ³n, impidiendo condiciones de carrera concurrentes.

### 4.3 RN-013-03: Comportamiento de Logout Voluntario y PreservaciÃ³n de CachÃ©
Cuando un usuario invoca el cierre de sesiÃ³n voluntario desde la aplicaciÃ³n:

| Componente / Recurso | Comportamiento en Admin | Comportamiento en Empleado | JustificaciÃ³n Arquitectural |
|----------------------|-------------------------|----------------------------|-----------------------------|
| **Tokens y Credenciales JWT** | DestrucciÃ³n inmediata | DestrucciÃ³n inmediata | Cero persistencia de llaves de acceso en dispositivos desautenticados. |
| **Carrito POS en Vuelo** | Purga incondicional | Purga incondicional | Seguridad operativa: Evita que un tercero complete una venta pendiente ajena. |
| **Pase Diario (`daily_passes`)** | No aplica | ConmutaciÃ³n a `status = 'expired'` | LiberaciÃ³n inmediata del slot concurrente en servidor. |
| **CatÃ¡logo de Productos (IndexedDB)** | **Preservado intacto** | **Preservado intacto** | OptimizaciÃ³n de red: Previene re-descargas pesadas en re-inicios. |
| **CatÃ¡logo de Clientes (IndexedDB)** | **Preservado intacto** | **Preservado intacto** | Continuidad operativa en entornos offline / baja conectividad. |
| **Cola de SincronizaciÃ³n (`sync_queue`)** | **Preservada intacta** | **Preservada intacta** | Inviolabilidad contable: Las ventas offline pendientes no se borran jamÃ¡s. |

### 4.4 RN-013-04: Ausencia de Timeout por Inactividad
1. El sistema no implementa temporizadores de desconexiÃ³n por inactividad fÃ­sica (`idle timeout`).
2. En entornos de tienda fÃ­sica de barrio, el terminal puede permanecer desatendido durante horas mientras el tendero realiza labores de bodega o atenciÃ³n al mostrador. Forzar la re-autenticaciÃ³n constante degradarÃ­a la velocidad operativa del negocio.

### 4.5 RN-013-05: Cierre Forzado por DesactivaciÃ³n de Cuenta
1. Cuando el Administrador conmuta el perfil de un empleado a inactivo (`employees.is_active = false`):
   - El procedimiento invalida de forma inmediata todos los pases del empleado (`UPDATE daily_passes SET status = 'expired' WHERE employee_id = ... AND pass_date = CURRENT_DATE`).
   - El interceptor global en frontend detecta el rechazo en la siguiente invocaciÃ³n de red y expulsa al usuario al login.
   - El sistema despliega el mensaje informativo: *"Tu cuenta ha sido desactivada. Contacta al administrador."*

### 4.6 RN-013-06: ExpiraciÃ³n por Cierre de Caja
1. Al cerrarse el turno de caja (`cash_sessions.status = 'closed'`):
   - El trigger `trg_expire_passes_on_cash_close` invalida automÃ¡ticamente todos los pases diarios aprobados del dÃ­a (`status = 'expired'`).
   - Los empleados dependientes (sin privilegios de caja) ven su terminal bloqueado de inmediato con el mensaje *"Turno de caja finalizado"*.
   - El usuario que ejecutÃ³ el cierre de caja (Administrador o Empleado con permiso `canOpenCloseCash`) mantiene su sesiÃ³n activa para consultar el reporte final y cerrar sesiÃ³n voluntariamente.
   - Al dÃ­a siguiente calendario, **todos los empleados** deben solicitar un nuevo Pase Diario de forma obligatoria.

### 4.7 RN-013-07: RevocaciÃ³n Remota de Terminal por Administrador
1. El Administrador puede revocar la sesiÃ³n activa de un dispositivo especÃ­fico desde el mÃ³dulo de dispositivos ([FRD-015](../FRD/FRD_015_GESTION_DISPOSITIVOS.md) / [SDD-015](../SDD/SDD_015_GESTION_DISPOSITIVOS.md)) para liberar un slot de concurrencia.
2. La ejecuciÃ³n de `rpc_revocar_sesion_dispositivo`:
   - Conmuta el estado del pase correspondiente a `status = 'expired'` y registra `resolved_at = now()`.
   - Libera instantÃ¡neamente el slot dentro del cupo de 6 terminales.
   - En el dispositivo afectado, la siguiente llamada operativa recibe el cÃ³digo `403 SESSION_REVOKED`, forzando la redirecciÃ³n a la pantalla de login con el mensaje: *"Tu sesiÃ³n fue cerrada por el administrador"*.
   - El empleado revocado puede volver a solicitar acceso mediante un nuevo pase si las condiciones de cupo lo permiten.

---

## 5. CONTRATO DE INTERFAZ (PAYLOADS JSON)

Todos los contratos de interfaz se adhieren a la **Regla Global 4** (Protocolo de TransmisiÃ³n de Payloads).

### 5.1 Solicitud de Acceso y VerificaciÃ³n de Concurrencia
- **OperaciÃ³n Backend:** `rpc_solicitar_acceso_empleado`
- **MÃ©todo / RPC:** POST / Supabase RPC
- **DescripciÃ³n:** Valida credenciales locales (alias + PIN), verifica el lÃ­mite de 6 terminales concurrentes e inicia la solicitud de Pase Diario.

#### Payload de Entrada:
```json
{
  "p_username": "10203040",
  "p_pin": "1234",
  "p_device_fingerprint": "fp_chrome_win11_a9f2bc88",
  "p_device_metadata": {
    "browser": "Chrome 126.0",
    "os": "Windows 11",
    "ip": "190.14.22.105"
  }
}
```

#### Payload de Respuesta (Ã‰xito - Cupo Disponible, Esperando AprobaciÃ³n):
```json
{
  "success": true,
  "data": {
    "pass_id": "8a7c2e11-34b2-4d90-b183-f450293cb891",
    "status": "pending",
    "store_id": "3f9a7210-61b4-4e2b-a320-1a76c8901234",
    "requested_at": "2026-10-16T08:00:00Z",
    "retry_count": 0,
    "message": "Solicitud de acceso enviada al Administrador. Esperando aprobaciÃ³n."
  }
}
```

#### Payload de Respuesta (Fallo - LÃ­mite de 6 Sesiones Alcanzado):
```json
{
  "success": false,
  "error": "LÃ­mite de 6 terminales concurrentes alcanzado para esta tienda.",
  "code": "SESSION_LIMIT_REACHED"
}
```

#### Payload de Respuesta (Fallo - Cuenta Desactivada):
```json
{
  "success": false,
  "error": "La cuenta del empleado se encuentra inactiva.",
  "code": "ACCOUNT_DISABLED"
}
```

---

### 5.2 Cierre de SesiÃ³n Voluntario (Logout)
- **OperaciÃ³n Backend:** `rpc_cerrar_sesion_empleado`
- **DescripciÃ³n:** Invalida el pase diario activo liberando el slot concurrente, manteniendo catÃ¡logos locales en cachÃ©.

#### Payload de Entrada:
```json
{
  "p_pass_id": "8a7c2e11-34b2-4d90-b183-f450293cb891"
}
```

#### Payload de Respuesta (Ã‰xito):
```json
{
  "success": true,
  "data": {
    "pass_id": "8a7c2e11-34b2-4d90-b183-f450293cb891",
    "status": "expired",
    "closed_at": "2026-10-16T18:30:00Z",
    "slot_released": true
  }
}
```

---

### 5.3 Consulta de Sesiones y Dispositivos Conectados (Admin)
- **OperaciÃ³n Backend:** `rpc_obtener_sesiones_activas`
- **Requisito de Seguridad:** Exclusivo Administradores (`admin_profiles`). Ejecuta obligatoriamente `assert_store_access(p_store_id)`.
- **Formato:** Regla Global 4.1 (Respuesta de Lista `{ data, count }`).

#### Payload de Entrada:
```json
{
  "p_store_id": "3f9a7210-61b4-4e2b-a320-1a76c8901234"
}
```

#### Payload de Respuesta:
```json
{
  "data": [
    {
      "session_type": "admin",
      "session_id": "ad110022-77bb-4e99-9aa1-112233445566",
      "user_name": "Don Pedro (Propietario)",
      "user_identifier": "pedro@tiendabarrio.pro",
      "device_fingerprint": "fp_admin_laptop_office",
      "is_active": true,
      "connected_at": "2026-10-16T07:15:00Z"
    },
    {
      "session_type": "employee",
      "pass_id": "8a7c2e11-34b2-4d90-b183-f450293cb891",
      "employee_id": "6d3a82f1-28b4-4e8c-8521-72946c9812a1",
      "user_name": "Carlos Cajero",
      "user_identifier": "10203040",
      "device_fingerprint": "fp_pos_tablet_caja1",
      "status": "approved",
      "is_active": true,
      "approved_at": "2026-10-16T08:05:00Z"
    }
  ],
  "count": 2
}
```

---

### 5.4 RevocaciÃ³n Remota de Terminal por Administrador
- **OperaciÃ³n Backend:** `rpc_revocar_sesion_dispositivo`
- **Requisito de Seguridad:** Exclusivo Administradores (`admin_profiles`). Ejecuta obligatoriamente `assert_store_access(p_store_id)`.

#### Payload de Entrada:
```json
{
  "p_store_id": "3f9a7210-61b4-4e2b-a320-1a76c8901234",
  "p_pass_id": "8a7c2e11-34b2-4d90-b183-f450293cb891",
  "p_reason": "LiberaciÃ³n de slot para nuevo dependiente"
}
```

#### Payload de Respuesta (Ã‰xito):
```json
{
  "success": true,
  "data": {
    "pass_id": "8a7c2e11-34b2-4d90-b183-f450293cb891",
    "status": "expired",
    "revoked_at": "2026-10-16T14:20:00Z",
    "slot_released": true,
    "message": "SesiÃ³n revocada y slot liberado exitosamente."
  }
}
```

#### Payload de Respuesta (Fallo - Acceso Denegado por Tenant):
```json
{
  "success": false,
  "error": "Acceso denegado a los recursos de esta tienda.",
  "code": "STORE_ACCESS_DENIED"
}
```

---

## 6. SEGURIDAD, POLÃTICAS RLS Y MULTI-TENANCY

### 6.1 Aislamiento Multi-Tenant y Regla 4 de Seguridad Centralizada
1. **ReutilizaciÃ³n Obligatoria de `assert_store_access(p_store_id)` (Regla 4):**
   Todos los RPCs administrativos del mÃ³dulo (`aprobar_pase_diario`, `rpc_revocar_sesion_dispositivo`, `rpc_obtener_sesiones_activas`) ejecutan como **primera instrucciÃ³n incondicional**:
   La funciÃ³n de seguridad centralizada `public.assert_store_access(p_store_id)`.
   Si el invocador autenticado no pertenece a la tienda especificada, el sistema aborta de inmediato con la excepciÃ³n `STORE_ACCESS_DENIED`.
2. **Gobernanza RLS Centralizada mediante `get_current_store_id()`:**
   Las tablas vinculadas al ciclo de sesiÃ³n (`daily_passes`, `employees`, `stores`, `cash_sessions`) aplican aislamiento estricto en sus polÃ­ticas RLS comparando contra la funciÃ³n de resoluciÃ³n jerÃ¡rquica de tenant `public.get_current_store_id()`.

### 6.2 PolÃ­ticas de Seguridad a Nivel de Fila (RLS) en `daily_passes`
- **`daily_passes_select_store` (SELECT):**
  Permite la lectura de pases Ãºnicamente si el empleado asociado pertenece a la tienda del usuario autenticado:
  `EXISTS (SELECT 1 FROM employees e WHERE e.id = daily_passes.employee_id AND e.store_id = public.get_current_store_id())`.
- **`daily_passes_insert_own` (INSERT):**
  Restringe la creaciÃ³n de pases al propio empleado y a su tienda correspondiente.
- **`daily_passes_update_store` (UPDATE):**
  Restringe la mutaciÃ³n del estado del pase (aprobaciÃ³n/expiraciÃ³n) al contexto de la tienda autorizada.
- **ProhibiciÃ³n de DELETE (`POL-AUD-01`):**
  No existe polÃ­tica que habilite `DELETE` sobre `daily_passes`. Los pases finalizan exclusivamente conmutando su estado a `'expired'`.

### 6.3 Privilegios Base a Nivel de Tabla (Regla 8)
En cumplimiento de la **Regla 8 de AGENTS.md**, se encuentran otorgados y verificados mediante `has_table_privilege` los permisos para los roles del sistema:
- `daily_passes`: Privilegios asignados a `anon`, `authenticated`, `service_role`.
- `admin_profiles`: Privilegios asignados a `anon`, `authenticated`, `service_role`.
- `employees`: Privilegios asignados a `anon`, `authenticated`, `service_role`.
- `stores`: Privilegios asignados a `anon`, `authenticated`, `service_role`.
- `cash_sessions`: Privilegios asignados a `anon`, `authenticated`, `service_role`.
- Todas las tablas mantienen `rowsecurity = true`, garantizando inmunidad ante el error PostgreSQL `42501 (Permission Denied)`.

---

## 7. DEUDAS TÃ‰CNICAS Y DECISIONES DIFERIDAS

En estricto cumplimiento de la **Regla 7 de AGENTS.md**, se formalizan a continuaciÃ³n las decisiones tÃ©cnicas, compensaciones y condiciones de revisiÃ³n del mÃ³dulo:

### D-1: ErradicaciÃ³n Definitiva de la Tabla Alucinada `device_sessions` y ConsolidaciÃ³n en `daily_passes`
- **QuÃ© se decidiÃ³:** Consagrar que la base de datos fÃ­sica no contiene ni contendrÃ¡ una tabla anexa `device_sessions`. El control de terminales, dispositivos y sesiones activas de los empleados se sustenta Ã­ntegramente sobre las columnas `device_fingerprint` y `status` de la tabla real `daily_passes`.
- **Por quÃ© / Trade-off:** Evita una dispersiÃ³n redundante de estado entre mÃºltiples tablas efÃ­meras y sincronizaciones en caliente; apalanca el modelo de seguridad Zero Trust ya implementado y certificado en producciÃ³n.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Permanente. Invariante arquitectural del nÃºcleo de autenticaciÃ³n.

### D-2: Control de Concurrencia de 6 Sesiones en Servidor (`RN-013-02`)
- **QuÃ© se decidiÃ³:** Normar que el lÃ­mite de 6 sesiones simultÃ¡neas por tienda (1 Admin + 5 Empleados) se valida de forma pesimista en la base de datos al momento de solicitar o aprobar un pase, rechazando el 7mo intento con el cÃ³digo de error `SESSION_LIMIT_REACHED`.
- **Por quÃ© / Trade-off:** Protege la estabilidad del punto de venta mÃ³vil, previene el abuso de cuentas compartidas en terminales no autorizados y respeta el dimensionamiento de hardware del comercio.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Si el modelo de negocio introduce planes de suscripciÃ³n comerciales ("Multi-Caja Pro" o "Cadenas") que requieran ampliar el lÃ­mite de 5 empleados activos simultÃ¡neos.

### D-3: ReutilizaciÃ³n Obligatoria de `assert_store_access(p_store_id)` en RPCs Administrativos de SesiÃ³n (`Regla 4`)
- **QuÃ© se decidiÃ³:** Estandarizar que las funciones de administraciÃ³n de sesiones (`aprobar_pase_diario`, `rpc_revocar_sesion_dispositivo`, `rpc_obtener_sesiones_activas`) invoquen como primera instrucciÃ³n incondicional `PERFORM public.assert_store_access(p_store_id);`, erradicando validaciones ad-hoc.
- **Por quÃ© / Trade-off:** Asegura homogeneidad de seguridad multi-inquilino en cumplimiento estricto de la Regla 4 de AGENTS.md, eliminando riesgos de escalamiento de privilegios o acceso cruzado entre comercios.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Permanente. Invariante de seguridad del sistema.

### D-4: ExpiraciÃ³n Masiva de Pases por Cierre de Caja (`trg_expire_passes_on_cash_close`)
- **QuÃ© se decidiÃ³:** Consagrar el trigger de base de datos `trg_expire_passes_on_cash_close` sobre `cash_sessions` como el mecanismo reactivo oficial de fin de jornada para conmutar masivamente a `status = 'expired'` los pases operativos del turno, manteniendo activa la sesiÃ³n del actor que cerrÃ³ o del administrador.
- **Por quÃ© / Trade-off:** Automatiza la seguridad operativa al finalizar la jornada laboral sin depender de cron jobs externos, servidores de tareas ni intervenciones manuales del usuario.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Permanente. Invariante de sincronizaciÃ³n contable-financiera.

### D-5: Protocolo de Logout Diferenciado y PreservaciÃ³n de CachÃ© (`RN-013-03` vs `SDD-012 / SDD-028`)
- **QuÃ© se decidiÃ³:** Normar que el logout voluntario en la aplicaciÃ³n purgue exclusivamente credenciales JWT y carritos transaccionales pendientes, pero preserve intactos los catÃ¡logos maestros (productos, clientes) en IndexedDB y la cola de sincronizaciÃ³n `sync_queue`.
- **Por quÃ© / Trade-off:** Optimiza drÃ¡sticamente los tiempos de carga en aperturas subsecuentes en dispositivos con conectividad lenta o inestable, evitando re-descargas masivas sin comprometer la seguridad de datos financieros ajenos.
- **Bajo quÃ© condiciÃ³n futura se revisarÃ¡:** Permanente. EstÃ¡ndar de diseÃ±o offline-first para terminales de punto de venta.

