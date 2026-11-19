# SDD-026: Política de Gastos Generales (OPEX Inmediato)

> **Asociado a:** [FRD-026](../FRD/FRD_026_POLITICA_GASTOS_INMEDIATOS.md), [FRD-022](../FRD/FRD_022_GASTOS_MULTICANAL.md) y Contrato Marco [SDD-003-01](./SDD_003_01_MATRIZ_PERMISOS_EMPLEADOS.md)  
> **Fase del Plan:** Ola 1 — Cimientos de Caja y Gastos (Alineación `ARQ-002` v1.4)  
> **Estado:** 🟢 Alineado a Contrato Marco `SDD-003-01` (Pendiente migración Fase 3)  
> **Última Actualización:** 2026-11-19  

---

## 0. Contexto y Restricciones Aplicables

### 0.1 Políticas Globales Activadas (`ARQ-002` v1.4)
| Política ID | Dominio | Impacto Concreto en este SDD |
|-------------|---------|------------------------------|
| **POL-FIN-01** | Financiero | **Inmediatez Absoluta y `"pago externo / fuera de caja"`:** Prohibido registrar gastos "por pagar". Todo desembolso fuera de Caja Dedicada POS se marca **"pago externo / fuera de caja"** (100% Admin-only) con `$0` impacto en caja. |
| **POL-FIN-02** | Financiero | **Segregación Estricta (`efectivo`, `nequi`, `llave_bre`):** Se elimina `'daviplata'` y `'bre'`. **Todo gasto digital (Nequi o Llave BRE) descuenta únicamente de su respectivo canal digital y jamás afecta el efectivo físico en gaveta.** Prohibido el sobregiro (`INSUFFICIENT_CHANNEL_FUNDS`). |
| **POL-SEG-03** | Seguridad | **Acceso Abierto a Gastos Menores POS:** Todo usuario activo (Administrador o empleado con Pase Diario vigente) puede registrar gastos menores de turno con caja abierta `< 24h`. |
| **POL-AUD-01 / 02** | Auditoría | **Inmutabilidad y Fotografía de Firma (`actor_name`, `actor_role`):** Movimientos `append-only` en `cash_movements` con categoría OPEX cerrada (5 categorías, sin `'Reembolso'`), motivo obligatorio (`>= 3` chars) y firma histórica inmutable. |
| **SPEC-010 / 011** | Financiero | Enteros COP en `NUMERIC` sin coma flotante. |

### 0.2 Contratos Vecinos que Limitan el Diseño
- **`SDD_003_01` / `SDD_004` / `SDD_020`:** Gasto menor es Capacidad Base de todo usuario activo en turno `'open'` `< 24h`.
- **`SDD_022` / `SDD_019`:** Pagos a proveedores y `"pago externo / fuera de caja"` son 100% Admin-only (`movement_type = 'pago_proveedor'` o `$0` POS).
- **`SDD_006_02`:** Los reembolsos a clientes ya no pertenecen al catálogo OPEX de gastos; se procesan en el POS bajo permiso `canManageRefunds`.
- **`SDD_018` / `SDD_021`:** P&L computa `movement_type = 'gasto'` en OPEX; empleados consultan solo sus gastos propios del turno actual (`rpc_obtener_mis_movimientos_turno`).

### 0.3 Auditoría de BD contra Realidad (`SDD-003-01 §0.3`)
- En `database.types.ts` (L319–332), `cash_movements` ya dispone de `category`, `payment_method`, `voucher_ref` y `actor_id`.
- Brechas pendientes Fase 3: retirar `'daviplata'`/`'bre'` dejando `('efectivo', 'nequi', 'llave_bre')`, restringir OPEX a **5 categorías** (retirando `'Reembolso'`) y añadir snapshot `actor_name`/`actor_role`.

---

## 1. Glosario Local

- **Gasto General (OPEX Inmediato):** Desembolso de liquidez operativo corriente desde Caja Dedicada POS ejecutado por cualquier usuario activo en turno abierto `< 24h`.
- **Pago Externo / Fuera de Caja:** Desembolso exclusivo del Administrador con fondos propios ajenos al cajón POS (`$0` impacto en caja).
- **Canal de Pago (`payment_method`):** Exclusivamente `'efectivo'`, `'nequi'`, `'llave_bre'`.
- **Catálogo Cerrado de Categorías OPEX (5 categorías — sin `'Reembolso'`):**
  1. `Servicios` (Energía eléctrica, acueducto, gas, servicio de internet, telefonía).
  2. `Nomina` (Jornales diarios, sueldos de personal de turno, anticipos aprobados).
  3. `Transporte` (Acarreos menores, taxis para diligencias de la tienda, domicilios/fletes).
  4. `Mantenimiento` (Reparaciones locativas inmediatas, repuestos menores, bombillos, plomería).
  5. `Insumos` (Bolsas plásticas, papel térmico para tickets, marcadores, elementos de aseo).
- **Snapshot de Firma (`actor_name`, `actor_role`):** Fotografía histórica inmutable del autor.
- **Sobregiro de Canal:** Intento de desembolsar un monto superior a los fondos líquidos acumulados en el canal correspondiente para el turno activo (`INSUFFICIENT_CHANNEL_FUNDS`).

---

## 2. Diagramas de Secuencia

### 2.1 Flujo de Registro de Desembolso Inmediato (`rpc_registrar_gasto_v2`)

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as 👤 Cajero / Admin
    participant UI as 📱 Tienda Barrio Client
    participant RPC as ⚙️ rpc_registrar_gasto_v2
    participant Auth as 🔒 assert_store_access
    participant CS as 📦 cash_sessions
    participant CM as 💸 cash_movements

    Usuario->>UI: Ingresa Monto, Canal, Categoría OPEX y Motivo
    UI->>RPC: POST (session_id, amount, payment_method, category, description)
    
    activate RPC
    RPC->>CS: SELECT store_id, status, opened_at FROM cash_sessions WHERE id = p_session_id FOR UPDATE
    alt Sesión Inexistente
        RPC-->>UI: RAISE EXCEPTION 'NO_OPEN_SESSION'
    end

    RPC->>Auth: assert_store_access(v_session.store_id)
    Auth-->>RPC: Acceso Aprobado

    alt Sesión Cerrada
        RPC-->>UI: RAISE EXCEPTION 'NO_OPEN_SESSION'
    else Antigüedad > 24 Horas
        RPC-->>UI: RAISE EXCEPTION 'SESSION_EXPIRED'
    end

    alt Monto <= 0 o Nulo
        RPC-->>UI: RAISE EXCEPTION 'INVALID_AMOUNT'
    else Canal no válido
        RPC-->>UI: RAISE EXCEPTION 'INVALID_PAYMENT_METHOD'
    else Categoría fuera de catálogo
        RPC-->>UI: RAISE EXCEPTION 'INVALID_OPEX_CATEGORY'
    else Descripción < 3 caracteres
        RPC-->>UI: RAISE EXCEPTION 'EMPTY_DESCRIPTION'
    end

    RPC->>CM: Calcular Liquidez Disponible en Canal (Base + Ingresos - Egresos)
    alt Saldo Disponible < p_amount
        RPC-->>UI: RAISE EXCEPTION 'INSUFFICIENT_FUNDS'
    end

    RPC->>CM: INSERT INTO cash_movements (session_id, movement_type='gasto', amount=p_amount, description, created_at)
    Note right of CM: Descripción: [CATEGORIA] [CANAL:metodo] Motivo

    RPC-->>UI: 200 OK: { success: true, movement_id, session_id, amount, payment_method, category, description, movement_type: 'gasto', created_at }
    deactivate RPC
    UI-->>Usuario: Desembolso Registrado y Saldo de Canal Actualizado
```

### 2.2 Flujo Alternativo: Rechazo por Sobregiro de Fondos

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as 👤 Usuario Operativo
    participant UI as 📱 Tienda Barrio Client
    participant RPC as ⚙️ rpc_registrar_gasto_v2
    participant CM as 💸 cash_movements

    Usuario->>UI: Intenta registrar Gasto de $50.000 COP por canal Nequi
    UI->>RPC: POST (p_amount: 50000, p_payment_method: 'nequi')
    activate RPC
    RPC->>CM: Verifica fondos líquidos acumulados en Nequi
    Note over RPC,CM: Saldo real disponible en Nequi = $12.000 COP
    RPC-->>UI: RAISE EXCEPTION 'INSUFFICIENT_FUNDS'
    deactivate RPC
    Note over UI: Transacción abortada (Rollback automático)
    UI-->>Usuario: Alerta: "Fondos insuficientes en Nequi (Disponible: $12.000). Seleccione otro canal."
```

---

## 3. Diagramas de Estado

### 3.1 Ciclo de Vida del Gasto Operativo Inmediato

```mermaid
stateDiagram-v2
    [*] --> FormularioDesembolso : Usuario ingresa datos de erogación
    FormularioDesembolso --> ValidandoSeguridad : Envía solicitud con categoría OPEX
    
    ValidandoSeguridad --> RechazadoSeguridad : STORE_ACCESS_DENIED
    ValidandoSeguridad --> VerificandoSesion : Sesión de tienda comprobada
    
    VerificandoSesion --> RechazadoSesion : Caja cerrada o > 24h
    VerificandoSesion --> VerificandoParametros : Sesión 'open' y activa
    
    VerificandoParametros --> RechazadoParametro : Categoría, Monto o Motivo inválido
    VerificandoParametros --> VerificandoLiquidez : Parámetros validados
    
    VerificandoLiquidez --> RechazadoSobregiro : Fondos insuficientes (INSUFFICIENT_FUNDS)
    VerificandoLiquidez --> ErogacionAsentada : Liquidez confirmada
    
    ErogacionAsentada --> [*] : Movimiento append-only asentado; saldo reducido inmediatamente

    RechazadoSeguridad --> [*] : 403 Forbidden
    RechazadoSesion --> [*] : Rollback Transaccional
    RechazadoParametro --> [*] : Rollback Transaccional
    RechazadoSobregiro --> [*] : Rollback Transaccional
```

---

## 4. Especificación Detallada de Casos de Uso

### Caso A: Notificación de Gasto Futuro (Fuera del Sistema — FRD-026 Caso A)
- **Actor:** Usuario Operativo / Propietario de la tienda.
- **Precondición:** El encargado recibe la factura física del servicio eléctrico el día lunes, la cual tiene como fecha de vencimiento el día viernes.
- **Flujo Principal:**
  1. El encargado retiene el recibo físico en la gaveta o cartelera del local.
  2. El software permanece inalterado. El usuario no registra ningún compromiso futuro en el sistema.
  3. El control de caja diario se mantiene puro y libre de pasivos ficticios.
- **Flujo Alternativo:** El usuario intenta buscar en la interfaz una opción para "crear un gasto por pagar" o "registrar factura pendiente". El sistema no provee dicha funcionalidad por diseño normativo.
- **Postcondición:** La liquidez y los reportes financieros del negocio no sufren contaminación por deudas operativas no desembolsadas.

### Caso B: Ejecución y Registro del Desembolso en Efectivo (FRD-026 Caso B)
- **Actor:** Cajero o Administrador con sesión de caja activa.
- **Precondición:** Llega el día viernes. El encargado extrae `$65.000 COP` en efectivo del cajón físico para pagar el servicio eléctrico.
- **Flujo Principal:**
  1. El usuario accede al formulario de "Registrar Gasto".
  2. Digita el monto extraído: `$65.000 COP`.
  3. Selecciona el canal de origen: `Efectivo`.
  4. Selecciona la categoría OPEX: `Servicios`.
  5. Ingresa la descripción: `"Pago de factura de energía Codensa"`.
  6. Presiona el botón "Confirmar Gasto".
  7. El servidor recupera la sesión, verifica permisos con `assert_store_access()` y valida que la caja esté abierta (`status = 'open'`) con antigüedad `< 24h`.
  8. El servidor calcula la liquidez disponible en Efectivo para el turno en curso y comprueba que `saldo_efectivo >= 65000`.
  9. El servidor asienta el egreso en `cash_movements` con `movement_type = 'gasto'` y formatea la descripción: `[Servicios] [CANAL:efectivo] Pago de factura de energía Codensa`.
  10. El dinero esperado en efectivo reportado para el arqueo del turno actual disminuye inmediatamente en `$65.000 COP`.
- **Postcondición:** Egreso asentado de forma inmutable; arqueo físico de efectivo sincronizado en tiempo real.

### Caso C: Desembolso Digital (Nequi / Daviplata) con Segregación Multicanal
- **Actor:** Administrador o Cajero autorizado.
- **Precondición:** Se efectúa una transferencia digital desde la cuenta Nequi de la tienda por `$30.000 COP` para comprar bolsas e insumos de aseo.
- **Flujo Principal:**
  1. El usuario selecciona canal `Nequi`, categoría `Insumos`, monto `$30.000 COP` y motivo `"Compra de bolsas plásticas y cinta"`.
  2. El sistema valida la disponibilidad de saldo en el canal Nequi.
  3. Al confirmar fondos suficientes, el servidor registra el egreso en `cash_movements` vinculando la etiqueta `[CANAL:nequi]`.
  4. El saldo esperado de Nequi disminuye inmediatamente en `$30.000 COP`.
  5. El dinero físico del cajón (Efectivo) permanece estrictamente intacto.
- **Postcondición:** Gasto digital asentado; sin afectación cruzada al efectivo en gaveta.

### Caso D: Rechazo Transaccional por Sobregiro / Fondos Insuficientes
- **Actor:** Cajero o Administrador.
- **Precondición:** La tienda tiene saldo disponible en Nequi de `$5.000 COP`.
- **Flujo Principal:**
  1. El usuario intenta registrar un gasto de transporte por `$15.000 COP` por el canal `Nequi`.
  2. El servidor detecta que el saldo del canal resultaría negativo (`$5.000 - $15.000 = -$10.000 < 0`).
  3. El servidor aborta la transacción inmediatamente lanzando la excepción `INSUFFICIENT_FUNDS`.
  4. El sistema ejecuta un rollback automático: no se inserta ninguna fila en `cash_movements` ni se altera ningún saldo.
  5. La interfaz notifica al usuario: *"Fondos insuficientes en el canal Nequi (Disponible: $5.000). Seleccione el origen real de los fondos."*
- **Postcondición:** Cero asientos ficticios; principio de no-sobregiro respetado.

---

## 5. Contrato de Interfaz

### Operación: `rpc_registrar_gasto_v2`
- **Tipo:** Postgres RPC (Función Almacenada) / Acción (WRITE)
- **Modo de Ejecución:** `SECURITY DEFINER` con Search Path seguro (`SET search_path = public, pg_temp;`).
- **Firma de Entrada:**
  ```json
  {
    "p_session_id": "UUID (Obligatorio — Identificador de la sesión de caja activa)",
    "p_amount": "NUMERIC (Obligatorio — Monto entero COP estrictamente positivo > 0)",
    "p_payment_method": "TEXT (Obligatorio — Valores autorizados: 'efectivo', 'nequi', 'llave_bre')",
    "p_category": "TEXT (Obligatorio — Valores autorizados: 'Servicios', 'Nomina', 'Transporte', 'Mantenimiento', 'Insumos', 'Reembolso')",
    "p_description": "TEXT (Obligatorio — Longitud mínima 3 caracteres, sin contar prefijos)"
  }
  ```
- **Payload de Respuesta Exitosa (200 OK — 8 Atributos en Paridad con SDD_022):**
  ```json
  {
    "success": true,
    "data": {
      "movement_id": "8f3b2190-3456-4789-abcd-ef0123456789",
      "session_id": "b3e1a6c0-1234-4567-89ab-cdef01234567",
      "amount": 65000,
      "payment_method": "efectivo",
      "category": "Servicios",
      "description": "[Servicios] [CANAL:efectivo] Pago de factura de energía Codensa",
      "movement_type": "gasto",
      "created_at": "2026-10-14T15:30:00Z"
    }
  }
  ```
- **Catálogo Exhaustivo de Errores (8 Códigos Unificados):**
  | Código de Error | Causa de Negocio | Mensaje Técnico / HINT |
  |-----------------|------------------|------------------------|
  | `STORE_ACCESS_DENIED` | El usuario no pertenece a la tienda de la sesión o carece de sesión válida | El usuario no tiene acceso a esta tienda |
  | `NO_OPEN_SESSION` | La sesión indicada no existe o se encuentra en estado `'closed'` | No existe una sesión de caja activa para registrar el gasto |
  | `SESSION_EXPIRED` | La sesión de caja abierta supera las 24 horas transcurridas desde su apertura | La sesión de caja ha expirado (> 24h) y debe reconciliarse antes de operar |
  | `INVALID_AMOUNT` | El parámetro `p_amount` es menor o igual a cero o nulo | El monto del gasto debe ser un valor numérico estrictamente positivo |
  | `INVALID_PAYMENT_METHOD` | Canal monetario suministrado no válido | Canal de pago no válido. Permitidos: efectivo, nequi, llave_bre |
  | `INVALID_OPEX_CATEGORY` | La categoría no pertenece a las 6 autorizadas del catálogo cerrado | Categoría OPEX no autorizada. Permitidas: Servicios, Nomina, Transporte, Mantenimiento, Insumos, Reembolso |
  | `EMPTY_DESCRIPTION` | La descripción suministrada está vacía o tiene menos de 3 caracteres | La descripción o motivo del gasto es obligatoria (mínimo 3 caracteres) |
  | `INSUFFICIENT_FUNDS` | La liquidez disponible en el canal seleccionado es inferior al monto a desembolsar | Fondos insuficientes en el canal monetario seleccionado |

---

## 6. Análisis de Seguridad e Integridad

### 6.1 Reutilización Obligatoria de Funciones Centralizadas (Regla 4)
- **Validación Multi-Tenant y de Tienda:**
  Queda terminantemente prohibida cualquier comprobación de pertenencia o consulta ad-hoc manual (`WHERE store_id = ...`). La función `rpc_registrar_gasto_v2` debe invocar obligatoriamente `public.assert_store_access(v_session.store_id)` como primera instrucción tras recuperar la sesión de caja. La función centralizada `assert_store_access()` resuelve la pertenencia legítima evaluando en cascada el JWT (`app_metadata.store_id`), el perfil en `admin_profiles`, la vinculación en `employees` y los pases de turno aprobados en `daily_passes`. Si la comprobación falla, la transacción aborta arrojando la excepción `STORE_ACCESS_DENIED`.
- **Resolución Autoritativa del Cajero / Autor:**
  Para garantizar la autoría del desembolso y prevenir suplantaciones de identidad, la identidad del autor se resuelve mediante la función centralizada `public.get_employee_id_from_session()`. Si el usuario no está registrado en `employees` pero figura en `admin_profiles`, la función valida su acceso como administrador/propietario invocando `public.is_authorized_employee()`. Queda prohibido confiar en identificadores de cajero enviados desde el frontend o exigir PINs locales.

### 6.2 Privilegios Base en Tablas y Funciones (Regla 8)
Para prevenir errores de denegación de permisos `42501 (Permission Denied)` en Supabase Cloud, el diseño exige que las tablas base involucradas (`cash_movements`, `cash_sessions`) y la función RPC `rpc_registrar_gasto_v2` cuenten explícitamente con los privilegios otorgados (`GRANT ALL` y `GRANT EXECUTE`) a los roles `anon`, `authenticated` y `service_role`. La función opera con `SECURITY DEFINER` y `search_path = public, pg_temp` para blindar el contexto de ejecución.

### 6.3 Políticas de Seguridad a Nivel de Fila (RLS) y Aislamiento Multi-Tenant
La tabla `cash_movements` opera con políticas RLS estrictas y activas, garantizando aislamiento multi-tenant absoluto para roles autenticados. La política de seguridad condiciona el acceso a que la sesión vinculada (`session_id`) pertenezca a la tienda identificada autoritativamente mediante la función centralizada `public.get_current_store_id()`. Ningún usuario puede consultar, insertar ni visualizar movimientos pertenecientes a tiendas ajenas.

### 6.4 Concurrencia y Control de Carrera (Bloqueo Pesimista)
Toda extracción monetaria exige control de concurrencia a nivel lógico mediante bloqueo pesimista (`FOR UPDATE`) sobre la fila de la sesión en `cash_sessions` antes de computar saldos o insertar movimientos. Esto garantiza que múltiples solicitudes simultáneas de egreso, o una colisión entre un gasto operativo y un cierre de turno concurrente, se serialicen atómicamente, impidiendo condiciones de carrera y asegurando que el saldo resultante nunca sea negativo ni viole la regla de no-sobregiro (`balance >= 0`).

---

## 7. Modelo de Datos Lógico Verificado

### 7.1 Diagrama Entidad-Relación

```mermaid
erDiagram
    stores ||--o{ cash_sessions : "administra turnos"
    cash_sessions ||--o{ cash_movements : "registra erogaciones"

    stores {
        uuid id PK
        text name
        timestamptz created_at
    }

    cash_sessions {
        uuid id PK
        uuid store_id FK
        uuid opened_by FK
        uuid closed_by FK
        numeric opening_balance
        numeric expected_balance
        numeric actual_balance
        numeric difference
        text status
        timestamptz opened_at
        timestamptz closed_at
        boolean forced_close
    }

    cash_movements {
        uuid id PK
        uuid session_id FK
        text movement_type
        numeric amount
        text description
        uuid sale_id FK
        timestamptz created_at
    }
```

### 7.2 Diccionario de Datos Físico Verificado

#### Tabla: `cash_movements` (Esquema Real de Producción)
| Columna | Tipo de Dato | Nullable | Restricción / Default | Estado en BD | Propósito y Contrato |
|---------|--------------|----------|-----------------------|--------------|----------------------|
| `id` | `uuid` | NO | `gen_random_uuid()` PK | ✅ Existe | Identificador único e inmutable del egreso |
| `session_id` | `uuid` | NO | FK `cash_sessions(id)` ON DELETE CASCADE | ✅ Existe | Sesión de caja activa a la que se imputa la erogación |
| `movement_type` | `text` | NO | CHECK (`'ingreso'`, `'gasto'`, `'pago_proveedor'`) | ✅ Existe | Para gastos OPEX inmediatos es estrictamente `'gasto'` |
| `amount` | `numeric` | NO | CHECK (`amount > 0`) | ✅ Existe | Monto positivo extraído en pesos colombianos |
| `description` | `text` | NO | NOT NULL | ✅ Existe | Formato obligatorio: `[CATEGORIA] [CANAL:metodo_pago] Motivo` |
| `sale_id` | `uuid` | SÍ | FK `sales(id)` | ✅ Existe | Nulo para egresos de gastos operativos |
| `created_at` | `timestamptz` | NO | `now()` | ✅ Existe | Marca temporal del desembolso para auditoría |

#### Tabla: `cash_sessions` (Esquema Real de Producción)
| Columna | Tipo de Dato | Nullable | Restricción / Default | Estado en BD | Propósito y Contrato |
|---------|--------------|----------|-----------------------|--------------|----------------------|
| `id` | `uuid` | NO | `gen_random_uuid()` PK | ✅ Existe | Identificador único del turno de caja |
| `store_id` | `uuid` | NO | FK `stores(id)` | ✅ Existe | Tienda propietaria de la sesión |
| `opened_by` | `uuid` | NO | FK `employees(id)` / `admin_profiles` | ✅ Existe | Usuario que aperturó la caja |
| `closed_by` | `uuid` | SÍ | FK `employees(id)` / `admin_profiles` | ✅ Existe | Usuario que efectuó el cierre de turno |
| `opening_balance` | `numeric` | NO | Base >= 0 | ✅ Existe | Fondo de cambio físico asignado a Efectivo |
| `expected_balance` | `numeric` | SÍ | Saldo calculado | ✅ Existe | Balance esperado (`Base + Ingresos - Egresos`) |
| `actual_balance` | `numeric` | SÍ | Conteo real | ✅ Existe | Dinero real reportado en arqueo ciego |
| `difference` | `numeric` | SÍ | `actual - expected` | ✅ Existe | Descuadre contable registrado al cierre |
| `status` | `text` | NO | CHECK (`'open'`, `'closed'`) | ✅ Existe | Estado operativo del turno |
| `opened_at` | `timestamptz` | NO | `now()` | ✅ Existe | Inicio de la sesión para cálculo de vigencia de 24h |
| `closed_at` | `timestamptz` | SÍ | Timestamp | ✅ Existe | Fin del turno de caja |
| `forced_close` | `boolean` | NO | `false` | ✅ Existe | Marca de cierre forzado por caducidad |
