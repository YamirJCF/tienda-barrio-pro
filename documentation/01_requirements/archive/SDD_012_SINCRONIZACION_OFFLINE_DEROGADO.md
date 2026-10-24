> [!CAUTION]
> **DOCUMENTO DEROGADO Y ARCHIVADO**
> **Estado:** 🔴 DEROGADO — Conservado exclusivamente para trazabilidad histórica y auditoría comparativa contra v3.0.0.
> **Fecha de Derogación:** 2026-10-24
> **Sustituido por:** `documentation/01_requirements/SDD/SDD_012_SINCRONIZACION_OFFLINE.md` (v3.0.0)

# SDD-012: SincronizaciÃ³n y ResoluciÃ³n de Conflictos Offline

> **Asociado a:** [FRD-012: SincronizaciÃ³n y ResoluciÃ³n de Conflictos Offline](../FRD/FRD_012_SINCRONIZACION_OFFLINE.md), [FRD-012-01: LÃ­mites Estrictos del Sistema Offline](../FRD/FRD_012_01_LIMITES_SISTEMA_OFFLINE.md), y [FRD-012-R: RemediaciÃ³n del MÃ³dulo Offline](../FRD/FRD_012_REMEDIACION_OFFLINE.md)  
> **Fase del Plan:** Ola 5: Sesiones, AutenticaciÃ³n y Offline (Ãtem 5)  
> **Estado:** ðŸŸ  Aprobado con Deuda TÃ©cnica Documentada (Protocolo PAC-SDD v2.0)
> **Ãšltima ActualizaciÃ³n:** 2026-10-16  

---

## 0. CONTROL DE VERSIONES Y TRAZABILIDAD

### 0.1 Historial de Cambios
| VersiÃ³n | Fecha | Autor | Rol | DescripciÃ³n de ModificaciÃ³n |
|---------|-------|-------|-----|-----------------------------|
| 1.0.0 | 2026-01-27 | Analista Funcional | Requisitos | EspecificaciÃ³n inicial de sincronizaciÃ³n offline con resoluciÃ³n humana interactiva de conflictos de stock. |
| 1.5.0 | 2026-02-05 | Arquitecto de Software | Arquitectura | IncorporaciÃ³n de la remediaciÃ³n "Offline Defensivo" (FRD-012-R) y lÃ­mites estrictos (FRD-012-01). |
| 2.0.0 | 2026-10-16 | Orquestador TÃ©cnico | Arquitectura & QA | **Saneamiento Integral PAC-SDD v2.0**: SubordinaciÃ³n arquitectural al modelo de "Offline Defensivo" con bloqueo en origen (IndexedDB); simplificaciÃ³n de la Dead Letter Queue (DLQ) a "Reintentar / Eliminar"; delegaciÃ³n de ajustes de stock excepcionales a `CORRECCION_SISTEMA` en servidor (SDD-014); consagraciÃ³n del soporte fÃ­sico de idempotencia en `sales.local_id` (`text`) con respuesta canÃ³nica `DUPLICATE_RESOLVED`; confirmaciÃ³n de la naturaleza exclusivamente cliente (IndexedDB) de `sales_queue` y `dead_letter_queue` sin tablas huÃ©rfanas en PostgreSQL; imputaciÃ³n contable a turnos cerrados (`cash_sessions.id`) con actualizaciÃ³n de saldo esperado y bitÃ¡cora en `audit_logs` (`LATE_SYNC_UPDATE`) sin reapertura fÃ­sica de caja; suspensiÃ³n automÃ¡tica de cola ante expiraciÃ³n de JWT (`sync:auth_required`); verificaciÃ³n de privilegios base (Regla 8) incluyendo remediaciÃ³n de `clients` y `sale_items` para `service_role`; cumplimiento estricto de las Reglas 1.1 (0% cÃ³digo SQL), 2, 4, 7 y 8; y armonizaciÃ³n transversal con POS, Inventario, Caja y AuditorÃ­a. |

### 0.2 Trazabilidad de Requisitos (FRD-012, FRD-012-01, FRD-012-R)
| Regla de Negocio / CU | DescripciÃ³n en Requisitos Fuente | ImplementaciÃ³n en este SDD |
|-----------------------|----------------------------------|----------------------------|
| **RN-012-01** | Marcado de ventas offline con indicador local y fecha de sincronizaciÃ³n | SecciÃ³n 4.3 y SecciÃ³n 3.1 (`sales.local_id`, `sales.sync_status`) |
| **RN-012-02** | ValidaciÃ³n local de stock en copia descargada en cachÃ© | SecciÃ³n 4.1 y SecciÃ³n 3.3 (`products.current_stock`) |
| **RN-012-03 / RN-012-09** | DetecciÃ³n de conflicto de stock en servidor y opciones de resoluciÃ³n humana | SecciÃ³n 4.1, SecciÃ³n 4.6 y SecciÃ³n 7 (D-2) |
| **RN-012-04** | AceptaciÃ³n de precio offline sin rechazo por cambio de tarifa | SecciÃ³n 4.3 y SecciÃ³n 5.2 |
| **RN-012-05** | Conflicto de lÃ­mite de crÃ©dito en fiados diferidos y notificaciÃ³n | SecciÃ³n 4.5 y SecciÃ³n 5.3 |
| **RN-012-06** | Ventas con caja cerrada imputadas al turno contable original sin reabrir caja | SecciÃ³n 4.4, SecciÃ³n 3.5 y SecciÃ³n 7 (D-3) |
| **RN-012-07** | Orden cronolÃ³gico de sincronizaciÃ³n (FIFO) de mÃ¡s antigua a mÃ¡s reciente | SecciÃ³n 4.3 y SecciÃ³n 2.1 |
| **RN-012-08** | Reintentos automÃ¡ticos (mÃ¡ximo 3) ante fallos tÃ©cnicos de red | SecciÃ³n 4.6 y SecciÃ³n 2.2 |
| **RN-OFF-01** | LÃ­mite transaccional estricto: Ãºnico flujo encolable es `CREATE_SALE` en POS | SecciÃ³n 1.1 y SecciÃ³n 4.1 |
| **RN-OFF-02** | Bloqueo en origen (*Offline Defensivo*): bloqueo inmediato si falta stock local | SecciÃ³n 1.1, SecciÃ³n 4.1 y SecciÃ³n 7 (D-2) |
| **RN-OFF-03** | LÃ­mite de encolamiento y suspensiÃ³n por token expirado (`sync:auth_required`) | SecciÃ³n 4.2, SecciÃ³n 4.6 y SecciÃ³n 7 (D-4) |
| **RN-OFF-04** | Inmutabilidad histÃ³rica de ventas y transferencia a DLQ tras 3 fallos tÃ©cnicos | SecciÃ³n 4.6 y SecciÃ³n 3.7 (`dead_letter_queue`) |
| **RN-OFF-05** | Resiliencia ante cambios estructurales de servidor (*Schema Drift*) hacia DLQ | SecciÃ³n 4.6 y SecciÃ³n 5.4 |
| **RN-OFF-06** | Indicador visual permanente en POS (normal, 80% alerta, 100% crÃ­tico bloqueante) | SecciÃ³n 4.2 y SecciÃ³n 2.2 |
| **RN-R01** | ValidaciÃ³n preventiva de inventario disponible antes de encolar venta offline | SecciÃ³n 4.1 y SecciÃ³n 1.1 |
| **RN-R02** | ValidaciÃ³n preventiva de cupo de crÃ©dito para fiados antes de encolar | SecciÃ³n 4.5 y SecciÃ³n 3.4 (`clients.credit_limit`) |
| **RN-R03** | SincronizaciÃ³n mediante operaciÃ³n segura de procesamiento de ventas | SecciÃ³n 4.3 y SecciÃ³n 5.2 |
| **RN-R04** | Indicador visual explÃ­cito: "Modo Offline - Ventas limitadas al stock local" | SecciÃ³n 4.2 y SecciÃ³n 2.2 |
| **RN-R05** | RecuperaciÃ³n de sesiÃ³n: solicitud de re-autenticaciÃ³n previa a la sincronizaciÃ³n | SecciÃ³n 4.6 y SecciÃ³n 6.3 |

### 0.3 Matriz de Dependencias Inter-Modulares
| Documento Vecino | Tipo de Dependencia | Flujo o RestricciÃ³n Vinculante |
|------------------|---------------------|--------------------------------|
| [SDD-007](../SDD/SDD_007_NUCLEO_VENTAS_PADRE.md) / [SDD-007.1](../SDD/SDD_007_01_NUCLEO_POS.md) | NÃºcleo Transaccional | Procesamiento de ventas; soporte fÃ­sico de idempotencia en `sales.local_id`; secuencia atÃ³mica de tickets en servidor `COALESCE(MAX(ticket_number), 0) + 1`. |
| [SDD-011](../SDD/SDD_011_MANEJO_ERRORES.md) | Resiliencia y Errores | Temporizador silencioso de 60 segundos; catÃ¡logo canÃ³nico `ActionResponse`; mitigaciÃ³n de duplicados con `DUPLICATE_RESOLVED`; respuesta `INSUFFICIENT_STOCK` con `available`. |
| [SDD-028](../SDD/SDD_028_ALMACENAMIENTO_LOCAL.md) | Persistencia Cliente | Estructura de IndexedDB (`sales_queue`, `dead_letter_queue`, catÃ¡logos locales); supervivencia obligatoria de colas ante logout (`RN-CACHE-03`). |
| [SDD-004](../SDD/SDD_004_CONTROL_DE_CAJA.md) / [SDD-017](../SDD/SDD_017_CICLO_CONTABLE_Y_SESIONES.md) / [SDD-020](../SDD/SDD_020_CAJA_MULTICANAL.md) | Control de Caja | AsignaciÃ³n contable de ventas diferidas al `session_id` histÃ³rico original; recÃ¡lculo de saldo esperado sin reabrir turnos cerrados (`POL-AUD-01`). |
| [SDD-006](../SDD/SDD_006_NUCLEO_INVENTARIO_PADRE.md) / [SDD-006.1.1](../SDD/SDD_006_01_01_MOVIMIENTOS_ENTRADA.md) / [SDD-010.16](../SDD/SDD_010_016_VALORACION_FIFO.md) / [SDD-014](../SDD/SDD_014_VENTA_FORZADA_Y_AUDITORIA.md) | GestiÃ³n de Stock | Descarga local de stock; validaciÃ³n preventiva anti-negativos (`POL-LOG-02`); consumo FIFO en servidor; resoluciÃ³n de venta forzada vÃ­a `CORRECCION_SISTEMA` (SDD-014). |
| [SDD-009](../SDD/SDD_009_CLIENTES.md) / [SDD-024](../SDD/SDD_024_POLITICA_FIADOS.md) | Cartera y Fiados | ValidaciÃ³n preventiva local y bloqueo `FOR UPDATE` en servidor para fiados (`balance + total <= credit_limit`); aislamiento de caja ($0 en efectivo). |
| [SDD-005](../SDD/SDD_005_AUDITORIA_TRAZABILIDAD.md) | AuditorÃ­a Forense | Inviolabilidad contable (`POL-AUD-01`): Registro append-only en `audit_logs` (9 columnas fÃ­sicas) ante sincronizaciÃ³n diferida o mutaciones en DLQ. |

---

## 1. RESUMEN EJECUTIVO Y ALCANCE

El documento **SDD-012** define la arquitectura integral de **SincronizaciÃ³n AsÃ­ncrona, Resiliencia Operativa y ResoluciÃ³n de Conflictos Offline** en el ecosistema **Tienda Barrio Pro**. Establece las directivas tÃ©cnicas y los contratos de datos que permiten la continuidad comercial ininterrumpida en el punto de venta durante apagones elÃ©ctricos, saturaciÃ³n de redes mÃ³viles o caÃ­das del enlace de comunicaciones.

### 1.1 Principios Rectores del Modelo "Offline Defensivo"
1. **Mecanismo de Supervivencia, no Clon Completo (`RN-OFF-01`):** El subsistema offline estÃ¡ diseÃ±ado exclusivamente para cobros en punto de venta (`CREATE_SALE`). Quedan terminantemente prohibidos en modo offline: ajustes manuales de inventario (mermas/consumos), compras a proveedores, gastos operativos de tesorerÃ­a y aperturas o cierres de caja.
2. **Bloqueo en Origen (ValidaciÃ³n Preventiva Local, `RN-OFF-02`, `RN-R01`):** Para garantizar la polÃ­tica anti-negativos de inventario (`POL-LOG-02`), la terminal POS valida el carrito contra la copia local de existencias en IndexedDB antes de autorizar la venta offline. Si el stock local es insuficiente, la transacciÃ³n se bloquea en caliente en la interfaz, prohibiendo su encolamiento.
3. **Idempotencia Estricta en Servidor (`RN-012-01`, `RN-011-03`):** Toda venta diferida viaja con un identificador criptogrÃ¡fico pre-generado por el cliente (`sales.local_id`). Ante caÃ­das de red durante la respuesta HTTP, los reintentos posteriores devuelven el registro existente con cÃ³digo canÃ³nico `DUPLICATE_RESOLVED` sin duplicar movimientos contables ni descuentos de inventario.
4. **Inviolabilidad de Turnos Cerrados (`RN-012-06`, `POL-AUD-01`):** Si una venta se realizÃ³ con caja abierta y la conexiÃ³n regresa cuando el turno ya fue cerrado (manual o forzosamente a las 24 horas), el sistema asienta la transacciÃ³n en el `session_id` histÃ³rico original, actualiza el saldo esperado y emite un asiento inmutable en `audit_logs` (`LATE_SYNC_UPDATE`), sin reabrir el turno ni vulnerar los arqueos fÃ­sicos ya realizados.
5. **Dead Letter Queue (DLQ) Simplificada y SegregaciÃ³n RBAC (`RN-OFF-04`, `RN-OFF-05`, `POL-SEC-01`):** Las ventas que sufran fallos tÃ©cnicos recurrentes (tras 3 reintentos) o incompatibilidad de esquema (*Schema Drift*) se trasladan a la cola de contingencia DLQ en IndexedDB. La gestiÃ³n de esta bandeja queda reservada exclusivamente a Administradores (`admin_profiles`), quienes pueden reintentar la transacciÃ³n o eliminarla si es espuria, descartando interfaces complejas de ajuste forzado interactivo en el cliente.
6. **Persistencia de Colas y Pausa por AutenticaciÃ³n (`RN-CACHE-03`, `RN-OFF-03`):** La cola transaccional en IndexedDB sobrevive al logout voluntario del usuario. Si el token JWT expira durante una desconexiÃ³n prolongada, la sincronizaciÃ³n se detiene con el estado `sync:auth_required` hasta que el operador se re-autentique con internet, previniendo avalanchas de errores 401.

---

## 2. ARQUITECTURA GENERAL Y DIAGRAMA DE FLUJO

### 2.1 Diagrama de Secuencia: Ciclo de Venta Offline, SincronizaciÃ³n FIFO y ResoluciÃ³n Idempotente

El siguiente diagrama detalla la interacciÃ³n entre el componente POS, la base de datos local en IndexedDB, el motor de sincronizaciÃ³n cliente y el backend transaccional de Supabase:

```mermaid
sequenceDiagram
    autonumber
    participant Vendedor as ðŸ‘¤ Vendedor / POS
    participant LocalDB as ðŸ—„ï¸ IndexedDB (sales_queue)
    participant SyncWorker as âš™ï¸ Motor SincronizaciÃ³n (Pinia)
    participant Backend as âš¡ Supabase RPC
    participant DB as ðŸ”’ PostgreSQL (ProducciÃ³n)

    Note over Vendedor, DB: 1. OPERACIÃ“N EN CONTINGENCIA OFFLINE (DEFENSIVO)
    Vendedor->>LocalDB: Validar stock local de productos del carrito
    alt Stock local insuficiente (POL-LOG-02)
        LocalDB-->>Vendedor: Bloqueo inmediato: "Stock insuficiente localmente" (Cero encolamiento)
    else Stock local suficiente
        LocalDB->>LocalDB: Encolar venta en sales_queue (status = 'pending', local_id = UUID-X)
        LocalDB->>LocalDB: Decrementar stock local optimista
        LocalDB-->>Vendedor: Venta confirmada localmente con ticket provisional
    end

    Note over SyncWorker, DB: 2. DETECCIÃ“N DE RED Y DRENADO DE COLA FIFO
    SyncWorker->>SyncWorker: Heartbeat detecta conectividad a internet restablecida
    SyncWorker->>SyncWorker: Validar vigencia de token JWT
    alt JWT caducado durante el corte
        SyncWorker->>SyncWorker: Pausar cola con estado sync:auth_required
        SyncWorker-->>Vendedor: Banner: "SesiÃ³n expirada. Inicie sesiÃ³n para sincronizar"
    else JWT vÃ¡lido
        SyncWorker->>LocalDB: Leer lote de ventas pendientes en orden FIFO
        LocalDB-->>SyncWorker: Retorna Venta (local_id = UUID-X)
        SyncWorker->>Backend: rpc_procesar_venta(..., p_local_id = UUID-X)
        Backend->>DB: assert_store_access(p_store_id)
        Backend->>DB: SELECT id FROM sales WHERE local_id = 'UUID-X'
        
        alt local_id ya existe en servidor (Reintento tras timeout previo)
            DB-->>Backend: Registro existente (id = UUID-100)
            Backend-->>SyncWorker: ActionResponse { success: true, data: { sale_id: UUID-100 }, code: 'DUPLICATE_RESOLVED' }
            SyncWorker->>LocalDB: Eliminar Venta UUID-X de sales_queue
        else local_id nuevo (Primera recepciÃ³n)
            Backend->>DB: consume_stock_fifo() + INSERT sales + Asignar session_id
            DB-->>Backend: Venta asentada exitosamente (id = UUID-101, ticket_number = 1540)
            Backend-->>SyncWorker: ActionResponse { success: true, data: { sale_id: UUID-101 } }
            SyncWorker->>LocalDB: Eliminar Venta UUID-X de sales_queue
        end
        SyncWorker-->>Vendedor: NotificaciÃ³n: "ConexiÃ³n restablecida - 1 venta sincronizada"
    end

    Note over SyncWorker, DB: 3. CONTINGENCIA TÃ‰CNICA Y TRASLADO A DLQ
    alt Falla tÃ©cnica persistente (Timeout / Error 500 / Schema Drift)
        SyncWorker->>SyncWorker: Reintentos automÃ¡ticos (1, 2, 3)
        SyncWorker->>LocalDB: Trasladar venta a dead_letter_queue tras 3 fallos
        SyncWorker-->>Vendedor: Indicador de atenciÃ³n: "1 venta en cola de revisiÃ³n tÃ©cnica (DLQ)"
    end
```

---

### 2.2 Diagrama de Estados: MÃ¡quina de Estados del Gestor de SincronizaciÃ³n y Colas Locales

```mermaid
stateDiagram-v2
    [*] --> Conectado : Inicio con conexiÃ³n a internet

    state Conectado {
        [*] --> Idle : Cola local vacÃ­a
        Idle --> Transmitiendo : Venta POS directa en servidor
        Transmitiendo --> Idle : TransacciÃ³n exitosa
    }

    Conectado --> Desconectado : Falla request / PÃ©rdida de red

    state Desconectado {
        [*] --> Temporizador_60s : Inicia contador silencioso
        Temporizador_60s --> Modo_Offline_Notificado : T=60s expirado (Alerta: "Sin internet")
        
        state Modo_Offline_Notificado {
            [*] --> Cola_Normal : Ventas encoladas < 80% capacidad
            Cola_Normal --> Cola_Alerta : Capacidad alcanza 80% (Alerta visual naranja)
            Cola_Alerta --> Cola_Bloqueada : Capacidad alcanza 100% (Bloqueo crÃ­tico rojo)
        }
    }

    Desconectado --> Sincronizando : Red reanudada y detectada

    state Sincronizando {
        [*] --> Verificando_Auth : Comprobar validez de JWT
        Verificando_Auth --> Pausa_Auth : JWT expirado (sync:auth_required)
        Pausa_Auth --> Verificando_Auth : Usuario inicia sesiÃ³n con internet
        
        Verificando_Auth --> Drenado_FIFO : JWT vÃ¡lido
        
        state Drenado_FIFO {
            [*] --> Envio_Venta : Toma venta mÃ¡s antigua
            Envio_Venta --> Exito_Deduplicado : Servidor asienta o resuelve duplicado
            Exito_Deduplicado --> Purga_Local : Elimina de sales_queue
            
            Envio_Venta --> Reintento_Tecnico : Error 500 / Timeout (< 3 intentos)
            Reintento_Tecnico --> Envio_Venta : Reintento automÃ¡tico
            
            Envio_Venta --> Traslado_DLQ : Falla persistente (3 intentos agotados)
        }
    }

    Sincronizando --> Conectado : Cola vacÃ­a / NotificaciÃ³n emitida
```

---

## 3. MODELO DE DATOS FÃSICO Y REGLAS DE PERSISTENCIA

El procesamiento de ventas sincronizadas y la prevenciÃ³n de anomalÃ­as relacionales se fundamentan en tablas verificadas en Supabase (`information_schema.columns`).

### 3.1 Estructura FÃ­sica de Ventas e Idempotencia (`sales`)
La tabla `sales` aloja las columnas requeridas para el control de sincronizaciÃ³n diferida y la prevenciÃ³n de duplicados:

| Columna | Tipo de Dato | Nulable | Restricciones / Defaults | DescripciÃ³n |
|---------|--------------|---------|--------------------------|-------------|
| `id` | `uuid` | NOT NULL | PK, default `gen_random_uuid()` | Identificador maestro de la venta en servidor. |
| `store_id` | `uuid` | NOT NULL | FK `stores(id)` | Identificador de la tienda propietaria (multi-tenant). |
| `ticket_number` | `integer` | NOT NULL | Secuencial por tienda | Correlativo asignado atÃ³micamente por el servidor. |
| `employee_id` | `uuid` | NOT NULL | FK `employees(id)` | Usuario responsable de la transacciÃ³n. |
| `client_id` | `uuid` | NULLABLE | FK `clients(id)` | Cliente asociado a la venta o crÃ©dito. |
| `total` | `numeric` | NOT NULL | CHECK `total >= 0` | Importe monetario total de la venta. |
| `rounding_difference` | `numeric` | NULLABLE | Default `0` | Diferencia por redondeo comercial en efectivo. |
| `payment_method` | `text` | NOT NULL | CHECK `IN ('efectivo', 'nequi', 'daviplata', 'fiado')` | MÃ©todo de pago liquidado. |
| `amount_received` | `numeric` | NULLABLE | Default `NULL` | Importe entregado por el comprador. |
| `change_given` | `numeric` | NULLABLE | Default `NULL` | Cambio retornado al comprador. |
| `sync_status` | `text` | NULLABLE | Default `'pending'`, CHECK `IN ('synced', 'pending', 'failed')` | **Estado de sincronizaciÃ³n en servidor**. |
| `local_id` | `text` | NULLABLE | Indexado / DeduplicaciÃ³n | **Soporte fÃ­sico de idempotencia**: UUID v4 pre-generado por el cliente para evitar duplicados en reintentos. |
| `is_voided` | `boolean` | NULLABLE | Default `false` | Bandera lÃ³gica de anulaciÃ³n. |
| `voided_by` | `uuid` | NULLABLE | FK `employees(id)` | Usuario que anulÃ³ la venta. |
| `void_reason` | `text` | NULLABLE | Motivo de anulaciÃ³n. |
| `created_at` | `timestamptz` | NOT NULL | Default `now()` | Marca temporal de inserciÃ³n. |

### 3.2 Estructura FÃ­sica de Ãtems de Venta (`sale_items`)
Desglose transaccional de artÃ­culos registrados:

| Columna | Tipo de Dato | Nulable | Restricciones / Defaults | DescripciÃ³n |
|---------|--------------|---------|--------------------------|-------------|
| `id` | `uuid` | NOT NULL | PK, default `gen_random_uuid()` | Identificador del Ã­tem. |
| `sale_id` | `uuid` | NOT NULL | FK `sales(id)` ON DELETE CASCADE | Venta asociada. |
| `product_id` | `uuid` | NOT NULL | FK `products(id)` | ArtÃ­culo vendido. |
| `quantity` | `numeric` | NOT NULL | CHECK `quantity > 0` | Cantidad despachada. |
| `unit_price` | `numeric` | NOT NULL | CHECK `unit_price >= 0` | Precio unitario cobrado. |
| `subtotal` | `numeric` | NOT NULL | CHECK `subtotal >= 0` | Subtotal monetario del renglÃ³n. |
| `created_at` | `timestamptz` | NOT NULL | Default `now()` | Fecha de registro. |
| `unit_cost` | `numeric` | NULLABLE | Default `0` | Costo unitario promedio o FIFO. |

### 3.3 Estructura FÃ­sica de Inventario y CatÃ¡logo de Productos (`products`)
La validaciÃ³n preventiva local y el consumo en servidor se apoyan en los 17 campos fÃ­sicos de `products`:

| Columna | Tipo de Dato | Nulable | Restricciones / Defaults | DescripciÃ³n |
|---------|--------------|---------|--------------------------|-------------|
| `id` | `uuid` | NOT NULL | PK, default `gen_random_uuid()` | Identificador maestro del producto. |
| `store_id` | `uuid` | NOT NULL | FK `stores(id)` | Tienda a la que pertenece el producto. |
| `name` | `text` | NOT NULL | No vacÃ­o | Nombre comercial del artÃ­culo. |
| `plu` | `text` | NULLABLE | CÃ³digo identificador | **Identificador fÃ­sico real de barras o cÃ³digo PLU** (no `barcode`). |
| `price` | `numeric` | NOT NULL | CHECK `price >= 0` | Precio unitario de venta. |
| `cost_price` | `numeric` | NULLABLE | Default `NULL` | Costo unitario de reposiciÃ³n. |
| `current_stock` | `numeric` | NULLABLE | Default `0`, CHECK `current_stock >= 0` | **Existencia fÃ­sica disponible**. Base del bloqueo preventivo en origen (`POL-LOG-02`). |
| `min_stock` | `numeric` | NULLABLE | Default `5` | Umbral de reabastecimiento mÃ­nimo. |
| `category` | `text` | NULLABLE | CategorÃ­a | ClasificaciÃ³n de producto. |
| `measurement_unit`| `text` | NULLABLE | Default `'unidad'` | Unidad de medida comercial. |
| `is_weighable` | `boolean` | NULLABLE | Default `false` | Indica si el producto requiere pesaje. |
| `low_stock_alerted`| `boolean`| NULLABLE | Default `false` | Bandera de alerta de stock bajo. |
| `created_at` | `timestamptz` | NOT NULL | Default `now()` | Fecha de creaciÃ³n. |
| `updated_at` | `timestamptz` | NOT NULL | Default `now()` | Fecha de actualizaciÃ³n. |
| `supplier_id` | `uuid` | NULLABLE | FK `suppliers(id)` | Proveedor asignado. |
| `brand` | `text` | NULLABLE | Marca | Marca comercial del producto. |
| `is_active` | `boolean` | NOT NULL | Default `true` | Estado activo del artÃ­culo. |

### 3.4 Estructura FÃ­sica de Clientes y Cartera (`clients`)
Campos requeridos para la doble barrera de crÃ©dito en fiados diferidos:

| Columna | Tipo de Dato | Nulable | Restricciones / Defaults | DescripciÃ³n |
|---------|--------------|---------|--------------------------|-------------|
| `id` | `uuid` | NOT NULL | PK, default `gen_random_uuid()` | Identificador del cliente. |
| `store_id` | `uuid` | NOT NULL | FK `stores(id)` | Tienda propietaria. |
| `name` | `text` | NOT NULL | Nombre completo | Nombre comercial o del cliente. |
| `id_number` | `text` | NOT NULL | Documento de identidad | CÃ©dula o NIT del comprador. |
| `phone` | `text` | NULLABLE | TelÃ©fono | TelÃ©fono de contacto. |
| `credit_limit` | `numeric` | NOT NULL | Default `100000` | **Cupo de crÃ©dito mÃ¡ximo autorizado**. |
| `balance` | `numeric` | NULLABLE | Default `0`, CHECK `balance >= 0` | **Saldo adeudado actual**. |
| `is_deleted` | `boolean` | NULLABLE | Default `false` | Borrado lÃ³gico de cliente. |
| `deleted_at` | `timestamptz` | NULLABLE | Default `NULL` | Fecha de borrado lÃ³gico. |
| `created_at` | `timestamptz` | NOT NULL | Default `now()` | Fecha de creaciÃ³n. |
| `updated_at` | `timestamptz` | NOT NULL | Default `now()` | Fecha de actualizaciÃ³n. |

### 3.5 Estructura FÃ­sica de Caja y AsignaciÃ³n de Turno (`cash_sessions` y `cash_movements`)
- `cash_sessions` (12 columnas fÃ­sicas): `id`, `store_id`, `opened_by`, `closed_by`, `opening_balance`, `expected_balance`, `actual_balance`, `difference`, `status`, `opened_at`, `closed_at`, `forced_close`.
- `cash_movements` (7 columnas fÃ­sicas): `id`, `session_id` (FK `cash_sessions(id)`), `movement_type`, `amount`, `description`, `sale_id`, `created_at`.
- **Regla de asignaciÃ³n histÃ³rica:** Toda venta diferida se vincula a travÃ©s de `cash_movements.session_id` al turno contable de caja que estaba abierto al momento de su creaciÃ³n fÃ­sica local (`RN-012-06`).

### 3.6 Estructura FÃ­sica de la BitÃ¡cora de AuditorÃ­a Forense (`audit_logs`)
- `audit_logs` (9 columnas fÃ­sicas): `id`, `actor_id`, `event_type`, `resource_id`, `metadata`, `created_at`, `store_id`, `severity`, `ip_address`.
- **Eventos tipados de sincronizaciÃ³n:** `OFFLINE_SYNC_SUCCESS` (severidad `'info'`), `LATE_SYNC_UPDATE` (severidad `'warning'`), `DLQ_TRANSFER` (severidad `'warning'`), `DLQ_RESOLVED` (severidad `'warning'`).

### 3.7 Persistencia Local en Navegador (IndexedDB) e Inexistencia en PostgreSQL
Se declara formalmente que las entidades `syncQueue`, `sales_queue` y `dead_letter_queue` **no existen como tablas relacionales en PostgreSQL** (la consulta en `information_schema.tables` retorna conjunto vacÃ­o `[]`). Su almacenamiento reside 100% en el cliente mediante IndexedDB bajo los siguientes stores:
- `sales_queue`: Almacena transacciones de venta pendientes de drenado en orden cronolÃ³gico (FIFO).
- `dead_letter_queue` (DLQ): Almacena ventas con 3 fallos tÃ©cnicos de red o *Schema Drift* para resoluciÃ³n por el Administrador.
- `products_cache` y `clients_cache`: Copias locales descargadas para la validaciÃ³n preventiva en origen.

---

## 4. ESPECIFICACIÃ“N DETALLADA DE REGLAS DE NEGOCIO Y CASOS DE USO

### 4.1 Bloqueo Preventivo en Origen y Acoplamiento Exclusivo a POS (`RN-OFF-01`, `RN-OFF-02`, `RN-R01`)
1. **LÃ­mite Transaccional Exclusivo a Ventas:** El subsistema offline estÃ¡ restringido estrictamente a `CREATE_SALE`. El interceptor de la cola de sincronizaciÃ³n detecta y destruye de inmediato cualquier intento de encolar movimientos de inventario (mermas), gastos de tesorerÃ­a o cierres de caja en modo desconectado.
2. **ValidaciÃ³n Preventiva contra Stock Local (*Offline Defensivo*):** Antes de autorizar una venta sin internet y encolarla en `sales_queue`, la aplicaciÃ³n valida que `current_stock >= requested_quantity` para cada producto utilizando la copia en `products_cache`.
3. **Bloqueo Inmediato:** Si el inventario local es insuficiente, el POS bloquea el cobro en origen y despliega: *"Stock insuficiente en catÃ¡logo local. No es posible vender sin conexiÃ³n"*. La transacciÃ³n no se encola, garantizando la polÃ­tica anti-negativos (`POL-LOG-02`).

### 4.2 LÃ­mite de Encolamiento, Indicador Visual y Alertas (`RN-OFF-03`, `RN-OFF-06`, `RN-R04`)
1. **Capacidad MÃ¡xima de Supervivencia:** La cola local `sales_queue` dispone de un tope mÃ¡ximo configurable (default: 50 ventas) para evitar saturaciÃ³n de memoria en terminales mÃ³viles.
2. **Indicador Visual Permanente en POS:**
   - *Estado Normal (0% a 79%):* Indicador sutil permanente "X/50 ventas pendientes".
   - *Estado Alerta Preventiva (80% a 99%):* Indicador en color amarillo/naranja con advertencia: *"Cola de sincronizaciÃ³n casi llena. Reconecta a internet pronto"*.
   - *Estado CrÃ­tico Bloqueante (100%):* Indicador en color rojo. El POS bloquea el botÃ³n de cobro mostrando: *"LÃ­mite de ventas offline alcanzado. Reconecta a internet para continuar"*.

### 4.3 SincronizaciÃ³n FIFO e Idempotencia con `local_id` (`RN-012-01`, `RN-012-07`, `RN-011-03`, `RN-R03`)
1. **GeneraciÃ³n CriptogrÃ¡fica Local:** Cada venta offline genera en el cliente un `local_id` (UUID v4) y marca temporal local de creaciÃ³n antes de persistirse en `sales_queue`.
2. **Orden CronolÃ³gico Estricto (FIFO):** Al regresar la red, el motor de sincronizaciÃ³n drena las ventas en estricto orden cronolÃ³gico ascendente (de la mÃ¡s antigua a la mÃ¡s reciente).
3. **ResoluciÃ³n Idempotente en Backend:** Al recibir `p_local_id`, el backend verifica si ya existe en `sales`. Si ya fue insertada por un reintento anterior, retorna `ActionResponse` con `code = 'DUPLICATE_RESOLVED'` y el `sale_id` existente, provocando que el cliente la purgue de `sales_queue` sin duplicar movimientos de kardex ni caja.
4. **Respeto a Precios HistÃ³ricos (`RN-012-04`):** La venta offline se procesa y asienta respetando el precio unitario con el que fue cobrada en el mostrador durante el apagÃ³n, sin importar si el catÃ¡logo cambiÃ³ en el servidor mientras tanto.

### 4.4 ImputaciÃ³n Contable a Turnos Cerrados y Fidelidad de Caja (`RN-012-06`)
1. **PreservaciÃ³n del `session_id` HistÃ³rico:** La venta offline guarda el identificador del turno de caja (`cash_sessions.id`) que estaba abierto al crearse localmente.
2. **Asentamiento en PerÃ­odo HistÃ³rico sin Reabrir Caja:** Si el Administrador cerrÃ³ la caja (manual o por el cron de 24 horas de SDD-017) antes de la reconexiÃ³n:
   - El backend asienta el registro en `cash_movements` vinculÃ¡ndolo al `session_id` histÃ³rico original.
   - El saldo esperado del turno cerrado se actualiza para reflejar el ingreso real.
   - La caja cerrada **no cambia de estado** (permanece en `status = 'closed'`).
   - Se emite un asiento en `audit_logs` con `event_type = 'LATE_SYNC_UPDATE'` notificando la actualizaciÃ³n extemporÃ¡nea.

### 4.5 Doble Barrera de CrÃ©dito en Fiados Offline (`RN-R02`, `RN-012-05`)
1. **Barrera 1 (Preventiva Local):** El cliente valida que `clients_cache.balance + total <= clients_cache.credit_limit`. Si excede, el POS bloquea la venta fiada de inmediato.
2. **Barrera 2 (Estricta en Servidor):** Al sincronizar, el backend ejecuta bloqueo `SELECT ... FOR UPDATE` sobre la fila del cliente en `clients`. Si por ventas concurrentes de otra terminal el cliente superÃ³ su cupo durante el apagÃ³n, el servidor aborta la transacciÃ³n con `CREDIT_LIMIT_EXCEEDED` y traslada la venta a DLQ para gestiÃ³n directa de cobro en efectivo o anulaciÃ³n por el personal.

### 4.6 GestiÃ³n de Fallos TÃ©cnicos, Schema Drift y Dead Letter Queue (`RN-OFF-04`, `RN-OFF-05`, `RN-012-08`, `RN-R05`)
1. **Cadencia de Reintentos:** Ante fallos tÃ©cnicos transitorios (errores 500, timeouts de red), el sistema ejecuta hasta 3 reintentos automÃ¡ticos con retroceso exponencial.
2. **Traslado a Dead Letter Queue (DLQ):** Si tras 3 intentos la venta no logra procesarse, o si el interceptor detecta incompatibilidad estructural (*Schema Drift*), la venta se mueve a la `dead_letter_queue` en IndexedDB.
3. **Acciones Administrativas en DLQ:** La interfaz de la DLQ ofrece exclusivamente dos opciones al Administrador:
   - *Reintentar:* Fuerza un reenvÃ­o una vez solucionada la contingencia de red o actualizado el sistema.
   - *Eliminar:* Descarta la transacciÃ³n Ãºnicamente si se constata que fue una prueba o registro espurio.
   - *Venta Forzada Excepcional:* Si la venta es legÃ­tima pero colisiona con discrepancias fÃ­sicas de inventario en servidor, el Administrador la regulariza desde el panel aplicando `CORRECCION_SISTEMA` bajo SDD-014.
4. **SuspensiÃ³n de Cola por AutenticaciÃ³n (`sync:auth_required`):** Si el token JWT expira durante el apagÃ³n, la cola se pausa inmediatamente, impidiendo peticiones rechazadas con 401 hasta que el usuario inicie sesiÃ³n con conectividad.

---

## 5. CONTRATOS DE INTERFAZ

Los contratos de sincronizaciÃ³n se estructuran bajo esquemas JSON canÃ³nicos que separan la persistencia en el cliente de la autoridad de datos en el servidor.

### 5.1 Esquema JSON: Registro de Venta en Cola Local (`OfflineSaleRecord`)
Estructura persistida en el store `sales_queue` de IndexedDB en el navegador:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "OfflineSaleRecord",
  "type": "object",
  "required": ["local_id", "store_id", "session_id", "employee_id", "payment_method", "total", "items", "created_at_local", "retry_count"],
  "properties": {
    "local_id": {
      "type": "string",
      "format": "uuid",
      "description": "Identificador Ãºnico pre-generado por el cliente para idempotencia."
    },
    "store_id": {
      "type": "string",
      "format": "uuid",
      "description": "Tienda en la que se originÃ³ la venta."
    },
    "session_id": {
      "type": "string",
      "format": "uuid",
      "description": "Turno de caja que estaba abierto al crear la venta en el cliente."
    },
    "employee_id": {
      "type": "string",
      "format": "uuid",
      "description": "Usuario responsable de la venta."
    },
    "client_id": {
      "type": ["string", "null"],
      "format": "uuid",
      "description": "Cliente si la venta es a crÃ©dito o fidelizada."
    },
    "payment_method": {
      "type": "string",
      "enum": ["efectivo", "nequi", "daviplata", "fiado"]
    },
    "total": {
      "type": "number",
      "minimum": 0
    },
    "amount_received": {
      "type": ["number", "null"],
      "minimum": 0
    },
    "created_at_local": {
      "type": "string",
      "format": "date-time",
      "description": "Fecha y hora exacta de la creaciÃ³n en la terminal fÃ­sica."
    },
    "retry_count": {
      "type": "integer",
      "minimum": 0,
      "maximum": 3,
      "description": "Contador de reintentos tÃ©cnicos de sincronizaciÃ³n."
    },
    "items": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["product_id", "quantity", "unit_price"],
        "properties": {
          "product_id": { "type": "string", "format": "uuid" },
          "quantity": { "type": "number", "minimum": 0.001 },
          "unit_price": { "type": "number", "minimum": 0 }
        }
      }
    }
  },
  "additionalProperties": false
}
```

### 5.2 Esquema JSON: PeticiÃ³n de SincronizaciÃ³n Diferida (`SincronizarVentaRequest`)
Payload transmitido al procedimiento transaccional de ventas en Supabase:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SincronizarVentaRequest",
  "type": "object",
  "required": ["p_store_id", "p_local_id", "p_payment_method", "p_items", "p_session_id"],
  "properties": {
    "p_store_id": {
      "type": "string",
      "format": "uuid",
      "description": "Identificador de la tienda propietaria (validado con assert_store_access)."
    },
    "p_local_id": {
      "type": "string",
      "format": "uuid",
      "description": "Clave de idempotencia para prevenciÃ³n de duplicados."
    },
    "p_session_id": {
      "type": "string",
      "format": "uuid",
      "description": "Turno de caja original para imputaciÃ³n contable histÃ³rica."
    },
    "p_client_id": {
      "type": ["string", "null"],
      "format": "uuid"
    },
    "p_payment_method": {
      "type": "string",
      "enum": ["efectivo", "nequi", "daviplata", "fiado"]
    },
    "p_amount_received": {
      "type": ["number", "null"],
      "minimum": 0
    },
    "p_items": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["product_id", "quantity", "unit_price"],
        "properties": {
          "product_id": { "type": "string", "format": "uuid" },
          "quantity": { "type": "number", "minimum": 0.001 },
          "unit_price": { "type": "number", "minimum": 0 }
        }
      }
    }
  },
  "additionalProperties": false
}
```

### 5.3 Esquema JSON: Respuesta CanÃ³nica de AcciÃ³n (`ActionResponse`)
Estructura universal retornada por el servidor tras la sincronizaciÃ³n:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "ActionResponse",
  "type": "object",
  "required": ["success"],
  "properties": {
    "success": {
      "type": "boolean",
      "description": "Indica si la venta fue procesada o resuelta como preexistente."
    },
    "data": {
      "type": "object",
      "properties": {
        "sale_id": { "type": "string", "format": "uuid" },
        "ticket_number": { "type": "integer" },
        "total": { "type": "number" },
        "change": { "type": "number" }
      },
      "additionalProperties": true
    },
    "error": {
      "type": "string",
      "description": "DescripciÃ³n amigable en espaÃ±ol del error."
    },
    "code": {
      "type": "string",
      "enum": [
        "DUPLICATE_RESOLVED",
        "INSUFFICIENT_STOCK",
        "CREDIT_LIMIT_EXCEEDED",
        "STORE_ACCESS_DENIED",
        "SHIFT_EXPIRED",
        "INTERNAL_SERVER_ERROR"
      ]
    },
    "details": {
      "type": "object",
      "additionalProperties": true
    }
  },
  "additionalProperties": false
}
```

### 5.4 Esquema JSON: Registro de Dead Letter Queue (`DLQRecord`)
Estructura persistida en el store `dead_letter_queue` de IndexedDB:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "DLQRecord",
  "type": "object",
  "required": ["sale_payload", "error_code", "error_message", "failed_at", "attempts", "status"],
  "properties": {
    "sale_payload": {
      "$ref": "#/properties/OfflineSaleRecord",
      "description": "Registro completo original de la venta offline intacta."
    },
    "error_code": {
      "type": "string",
      "description": "CÃ³digo del fallo tÃ©cnico o de negocio que causÃ³ la derivaciÃ³n."
    },
    "error_message": {
      "type": "string",
      "description": "Mensaje tÃ©cnico detallado o causa del schema drift."
    },
    "failed_at": {
      "type": "string",
      "format": "date-time"
    },
    "attempts": {
      "type": "integer",
      "minimum": 3
    },
    "status": {
      "type": "string",
      "enum": ["pending_review", "retrying", "discarded"]
    }
  },
  "additionalProperties": false
}
```

---

## 6. ANÃLISIS DE SEGURIDAD Y RESILIENCIA

### 6.1 Control de Acceso y Funciones Centralizadas (Regla 4 de AGENTS.md)
1. **Aislamiento Multi-Tenant Estricto (`assert_store_access`):** Todo procedimiento en backend invocado durante la sincronizaciÃ³n diferida ejecuta como primera instrucciÃ³n mandatoria:
   - `PERFORM public.assert_store_access(p_store_id);`
   Queda terminantemente prohibido reimplementar comparaciones directas de tienda o comprobaciones manuales del JWT.
2. **Gobernanza de RLS mediante `get_current_store_id()`:** Las polÃ­ticas de seguridad a nivel de fila en `sales`, `sale_items`, `products`, `clients`, `cash_sessions` y `cash_movements` utilizan exclusivamente `get_current_store_id()`, impidiendo la fuga de datos transaccionales entre distintos comercios.

### 6.2 Privilegios Base en Tablas (Regla 8 de AGENTS.md)
Se verificÃ³ el cumplimiento de la Regla 8 en todas las tablas vinculadas a la persistencia y sincronizaciÃ³n offline:
- **RemediaciÃ³n Ejecutada y Verificada:** Se subsanÃ³ en Supabase Cloud la ausencia previa de privilegios de `service_role` sobre `clients` y `sale_items` (`GRANT ALL ON TABLE public.clients, public.sale_items TO service_role;`), validando mediante `has_table_privilege` que ambas tablas cuenten con acceso completo (`serv_select: true`, `serv_insert: true`, `serv_update: true`, `serv_delete: true`) y `rowsecurity = true`.
- Las tablas `sales`, `products`, `cash_sessions`, `cash_movements` y `audit_logs` disponen de sus privilegios base asignados para `service_role`, `authenticated` y `anon`, erradicando el riesgo de errores 42501 (Permission Denied).

### 6.3 Resiliencia Transaccional y Superficie de Amenazas
1. **Ataques de RepeticiÃ³n (Replay Attacks):** La combinaciÃ³n de `store_id` y `local_id` indexado en `sales` neutraliza ataques de inyecciÃ³n repetida de ventas desde terminales comprometidas o redes inestables.
2. **SuspensiÃ³n AutomÃ¡tica por SesiÃ³n Expirada (`sync:auth_required`):** Si la sesiÃ³n del usuario caduca durante una desconexiÃ³n prolongada, la cola de sincronizaciÃ³n se detiene automÃ¡ticamente, evitando enviar peticiones no autorizadas y forzando la re-autenticaciÃ³n limpia al regresar la conectividad (`RN-OFF-03`, `RN-R05`).
3. **Inviolabilidad de AuditorÃ­a Forense (`POL-AUD-01`):** Las sincronizaciones en diferido, las actualizaciones de turnos cerrados y las resoluciones administrativas en DLQ generan registros inmutables append-only en `audit_logs` con `severity` tipada e `ip_address`, asegurando trazabilidad total ante inspecciones financieras.

---

## 7. REGISTRO DE DEUDAS TÃ‰CNICAS Y TRADE-OFFS (REGLA 7)

Conforme a la **Regla 7 de AGENTS.md**, se formalizan los 5 compromisos y decisiones arquitecturales de este mÃ³dulo:

### D-1: Idempotencia Operativa con `sales.local_id` y PrevenciÃ³n de Duplicados (RN-012-01, RN-011-03)
- **QuÃ© se decidiÃ³:** Adoptar `sales.local_id` (`text`, nullable) como la clave de deduplicaciÃ³n operativa en la sincronizaciÃ³n diferida de ventas, retornando `DUPLICATE_RESOLVED` con el `sale_id` existente ante reintentos.
- **Por quÃ© / Trade-off:** Evita la duplicaciÃ³n de ingresos en caja y sobre-descuentos en el inventario FIFO ante timeouts de red, sin requerir una tabla intermedia de staging en PostgreSQL.
- **CondiciÃ³n de revisiÃ³n futura:** Permanente / Invariante transaccional del mÃ³dulo de ventas.

### D-2: SubordinaciÃ³n al Modelo de Offline Defensivo y SimplificaciÃ³n de DLQ (FRD-012-01, FRD-012-R)
- **QuÃ© se decidiÃ³:** Consagrar que toda la prevenciÃ³n de conflictos de stock y cupo de fiado se ejecuta en origen antes de encolar (bloqueo preventivo en IndexedDB contra catÃ¡logo local); la DLQ se simplifica a "Reintentar / Eliminar"; y cualquier ajuste de existencias excepcional se delega a `CORRECCION_SISTEMA` en servidor bajo SDD-014.
- **Por quÃ© / Trade-off:** Elimina la necesidad de interfaces complejas y propensas a errores de "Ajuste forzado interactivo" en cliente, protegiendo el principio de no-negatividad de inventario (`POL-LOG-02`).
- **CondiciÃ³n de revisiÃ³n futura:** Permanente / Arquitectura offline consolidada.

### D-3: ImputaciÃ³n Contable a Turnos Cerrados y RecÃ¡lculo sin Re-apertura de Caja (RN-012-06)
- **QuÃ© se decidiÃ³:** Estandarizar que las ventas offline creadas durante un turno que posteriormente fue cerrado se imputan al `session_id` histÃ³rico original, actualizando el saldo esperado y documentando en `audit_logs` con `LATE_SYNC_UPDATE`, sin reabrir el turno contable.
- **Por quÃ© / Trade-off:** Preserva la inmutabilidad de los turnos cerrados (`POL-AUD-01`) mientras refleja fielmente el flujo real de dinero de la jornada.
- **CondiciÃ³n de revisiÃ³n futura:** Permanente / Principio contable fundamental.

### D-4: Persistencia de Colas en IndexedDB ante Logout y Pausa por AutenticaciÃ³n (RN-CACHE-03, RN-OFF-03)
- **QuÃ© se decidiÃ³:** Normar que el logout voluntario en cliente purga credenciales pero preserva la cola `sales_queue` en IndexedDB; si el JWT expira durante el apagÃ³n, la cola se suspende con `sync:auth_required` hasta el re-login con internet.
- **Por quÃ© / Trade-off:** Evita la pÃ©rdida irrecuperable de ventas legÃ­timas realizadas por el comerciante y previene avalanchas de errores 401 durante reconexiones inestables.
- **CondiciÃ³n de revisiÃ³n futura:** Permanente / EstÃ¡ndar offline-first.

### D-5: SegregaciÃ³n RBAC y Ceguera Contable en DLQ (POL-SEC-01)
- **QuÃ© se decidiÃ³:** Restringir la consulta y resoluciÃ³n de la Dead Letter Queue exclusivamente a usuarios con rol en `admin_profiles`, ocultando mÃ¡rgenes y costos unitarios al cajero operativo.
- **Por quÃ© / Trade-off:** Cumple el principio de ceguera contable (`POL-SEC-01`) y previene manipulaciones no autorizadas de transacciones fallidas en el mostrador.
- **CondiciÃ³n de revisiÃ³n futura:** Permanente / Invariante de seguridad y control interno.

### D-6: Soporte de Precio HistÃ³rico Desconectado en `rpc_procesar_venta_v3` (`RN-012-04`)
- **QuÃ© se decidiÃ³:** Cuando una venta se origina en modo desconectado (`p_is_offline_sync = true`), el cliente envÃ­a en `p_items` el `unit_price` histÃ³rico capturado del catÃ¡logo local al momento de la transacciÃ³n (`OfflineSaleRecord.created_at`). El backend `rpc_procesar_venta_v3` debe honrar o auditar dicho precio histÃ³rico en lugar de sobreescribirlo con el precio vigente en catÃ¡logo al momento de la sincronizaciÃ³n.
- **Por quÃ© / Trade-off:** Cumple la regla `RN-012-04` impidiendo que un cambio de precios administrativo durante un apagÃ³n modifique retroactivamente el monto cobrado al cliente en el mostrador.
- **CondiciÃ³n de revisiÃ³n futura:** Ola 6 SQL (se integrarÃ¡ soporte para `p_is_offline_sync` y `unit_price` histÃ³rico opcional en `rpc_procesar_venta_v3`).

