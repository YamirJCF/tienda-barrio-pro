# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-004)

> **Componente Auditado:** `frontend/src/views/CashControlView.vue` (y componentes auxiliares `frontend/src/components/cash/CloseRegisterModal.vue`, `frontend/src/components/cash/OpenRegisterModal.vue`; repositorios `frontend/src/data/repositories/cashRepository.ts`, store `frontend/src/stores/cashRegister.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_004_CONTROL_DE_CAJA.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_004_CONTROL_DE_CAJA.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/CashControlView.vue`
- **Componentes Auxiliares:**
  - `frontend/src/components/cash/CloseRegisterModal.vue`
  - `frontend/src/components/cash/OpenRegisterModal.vue`
- **Capa de Datos:** `frontend/src/stores/cashRegister.ts` y `frontend/src/data/repositories/cashRepository.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.1 Operación Escalar: `abrir_caja` (Capa de Compatibilidad Física)
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Entradas:**
  ```json
  {
    "p_store_id": "UUID (Obligatorio)",
    "p_opening_balance": "NUMERIC >= 0 (Obligatorio, asignado a Efectivo)"
  }
  ```
- **Salida Exitosa:**
  ```json
  {
    "success": true,
    "session_id": "UUID",
    "status": "open",
    "opening_balance": 50000.00
  }
  ```

### 5.2 Operación Escalar: `cerrar_caja` (Capa de Compatibilidad Física)
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Entradas:**
  ```json
  {
    "p_session_id": "UUID (Obligatorio)",
    "p_actual_balance": "NUMERIC >= 0 (Obligatorio, dinero real contado en mano)"
  }
  ```
- **Salida Exitosa:**
  ```json
  {
    "success": true,
    "expected_balance": 150000.00,
    "actual_balance": 148000.00,
    "difference": -2000.00
  }
  ```

### 5.3 Operación: `rpc_registrar_gasto_v2`
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Entradas:**
  ```json
  {
    "p_session_id": "UUID (Obligatorio)",
    "p_amount": "NUMERIC > 0 (Obligatorio)",
    "p_payment_method": "TEXT (Obligatorio: 'efectivo', 'nequi', 'llave_bre')",
    "p_category": "TEXT (Obligatorio: 'Servicios', 'Nomina', 'Transporte', 'Mantenimiento', 'Insumos', 'Reembolso')",
    "p_description": "TEXT (Obligatorio, longitud >= 3)"
  }
  ```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `abrir_caja`
- **Campo `p_store_id`:**
  - Código real: `cashRepository.ts:167` -> `p_store_id: event.store_id` (pasado desde `CashControlView.vue:233`).
  - Resultado: **Presente**.
- **Campo `p_opening_balance`:**
  - Código real: `cashRepository.ts:168` -> `p_opening_balance: event.amount` (pasado desde `CashControlView.vue:234` como `new Decimal(amount.value)`).
  - Resultado: **Presente**.

### Operación: `cerrar_caja`
- **Campo `p_session_id`:**
  - Código real: `cashRepository.ts:187` -> `p_session_id: event.id`.
  - Resultado: **Presente**.
- **Campo `p_actual_balance`:**
  - Código real: `cashRepository.ts:189` -> `p_actual_balance: event.amount_declared` (pasado desde `CashControlView.vue:244` como `new Decimal(amount.value)`).
  - Resultado: **Presente**.

### B2.5 CHECKPOINT Bloque 2
Los campos escalares de apertura y cierre se transmiten con los nombres requeridos por la capa de compatibilidad física.

---

## Bloque 2b — Verificación de Backend Authority (Obligatorio, sin excepción)

### B2.6 Búsqueda de Cálculos en Cliente
- En `frontend/src/views/CashControlView.vue`:
  - **Línea 183:** `difference = computed(() => amount.value - summary.value.expected);`
  - **Línea 332:** `<span class="font-bold text-lg text-gray-900 dark:text-white">{{ formatCurrency(summary.expected) }}</span>` (rotulado explícitamente como *"Debe haber en Caja"*).
  - **Líneas 350-356:** Renderizado visual en tiempo real de *"Caja Cuadrada"*, *"Sobrante"* o *"Faltante"* junto con el valor numérico `formatCurrency(Math.abs(difference))` mientras el cajero digita su conteo.
- En `frontend/src/components/cash/CloseRegisterModal.vue`:
  - **Línea 51:** `diffs[method] = physical.minus(expected);`
  - **Línea 61:** `difference = computed(() => totalPhysical.value.minus(systemExpected.value));`
  - **Línea 177:** `<span class="text-gray-900 dark:text-white text-lg">{{ formatCurrency(systemExpected) }}</span>` (rotulado como *"Total Esperado"*).
  - **Línea 187:** `<span class="text-gray-500 dark:text-gray-400">Esperado: {{ formatCurrency(expected) }}</span>` desglosado por canal.

### B2.7 CHECKPOINT Bloque 2b
🔴 **HALLAZGO DE SEVERIDAD ALTA:** Violación directa de la política de **Arqueo Ciego (`POL-SEG-01` / `POL-SEG-04`)** y del principio de Backend Authority. El frontend expone al cajero cuánto dinero espera el sistema y calcula la discrepancia en caliente antes de cerrar, abriendo la puerta a manipulación intencional de faltantes/sobrantes.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del SDD-004
1. `CajaCerrada` (Turno cerrado, disponible para apertura)
2. `ValidandoApertura` (Proceso de apertura en vuelo)
3. `CajaAbierta` (Turno activo para operaciones del POS)
4. `RegistrandoMovimiento` (Ingresos/egresos/ventas)
5. `ValidandoCierre` (Proceso de arqueo en vuelo)
6. `TurnoCaducado24H` (Turno abierto con más de 24 horas)

### B3.9 Manejo Visual en `CashControlView.vue`
- `CajaCerrada` / `CajaAbierta`:
  - Línea 150: `const isOpening = computed(() => !cashRegisterStore.isOpen);`
  - Reflejo visual: Conmuta entre formulario de apertura y resumen de cierre.
- `TurnoCaducado24H`:
  - Línea 151: `const isStale = computed(() => cashRegisterStore.isStaleSession);`
  - Línea 154: `if (isStale.value) return '⚠️ Cierre Pendiente';`
  - Reflejo visual: Banner de advertencia y botón *"CERRAR TURNO PENDIENTE"*.
- `ValidandoApertura` / `ValidandoCierre`:
  - Línea 32: `const { execute: executeAction, isLoading: isSubmitting } = useAsyncAction();`
  - Reflejo visual: Botón deshabilitado y spinner mientras la promesa de backend está en vuelo.
- **Regla anti-"$0 disfrazado":**
  - En `CashControlView.vue:91-93` (`fetchPendingForcedSessions`):
    ```typescript
    } catch (e) {
        console.error('🚫 [CashControl] Failed to fetch pending forced sessions:', e);
    }
    ```
    Si la consulta a `cash_sessions` o `cash_session_balances` falla por red o permisos, se silencia en consola y `pendingForcedSessions` queda como `[]`, simulando falsamente que no hay bloqueos de cierre forzado.

### B3.10 Cruce de Estados
| Estado SDD-004 | Reflejo en Componente | ¿Conforme? |
|---|---|:---:|
| `CajaCerrada` | Renderiza formulario de base inicial de apertura | Sí |
| `ValidandoApertura` | `isSubmitting` bloquea re-entrada | Sí |
| `CajaAbierta` | Renderiza interfaz de cierre | Sí |
| `RegistrandoMovimiento` | Delegado a POS/Gastos | Sí |
| `ValidandoCierre` | `isSubmitting` bloquea botón de confirmación | Sí |
| `TurnoCaducado24H` | Advertencia y bloqueo de operaciones regulares | Sí |

### B3.11 CHECKPOINT Bloque 3
Estados funcionales representados; detectado fallo silencioso en la carga de reconciliaciones pendientes.

---

## Bloque 4 — Verificación contra SPEC-011

### B4.12 Formateo de Moneda
- Código real: `useCurrencyFormat` (`formatCurrency`) en `CashControlView.vue:28, 320, 324, 328, 332, 355`.
- Formato emitido: `$ #.##0 COP` (sin decimales para pesos colombianos).
- Cumplimiento: **Conforme con SPEC-011**.

### B4.13 CHECKPOINT Bloque 4
Cierre de Bloque 4 conforme.

---

## Bloque 5 — Verificación de Permisos / Rol

### B5.14 Restricciones de Rol en SDD-004
- La apertura y cierre exigen rol de Administrador (`admin_profiles`) o empleado operativo con el permiso `canOpenCloseCash = true` en `employees.permissions` (`RN-9`).

### B5.15 Verificación en Código
- En `CashControlView.vue:196`: `authStore.isAdmin` se utiliza para omitir el modal de PIN.
- Para empleados operativos, se abre `PinChallengeModal` (L205).
- **Discrepancia:** No existe una guarda reactiva en la vista que verifique `authStore.currentUser?.permissions?.canOpenCloseCash`. Si un empleado sin el toggle ingresa a la vista, se le permite llenar el formulario y solo es rechazado tardíamente por el RPC en backend con `UNAUTHORIZED`.

### B5.16 CHECKPOINT Bloque 5
Cierre del Bloque 5 registrado con observación de validación preventiva de permisos.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | **Violación de Arqueo Ciego (`POL-SEG-01`):** `CashControlView.vue` (L183, L332, L350-356) expone *"Debe haber en Caja"* (`summary.expected`) y calcula en cliente la diferencia en vivo antes de someter el arqueo. | Bloque 2b (.6, .7) | 🔴 Alta |
| UX-2 | **Violación de Arqueo Ciego en Modal Secundario:** `CloseRegisterModal.vue` (L51, L61, L177, L187) muestra *"Total Esperado"* por canal y calcula diferencias en cliente en tiempo real. | Bloque 2b (.6, .7) | 🔴 Alta |
| UX-3 | **Fallo Silencioso anti-Regla 3:** `fetchPendingForcedSessions` (`CashControlView.vue:91-93`) atrapa errores de red/RLS con `console.error` sin activar bandera visual de error, aparentando que no hay cierres forzados pendientes. | Bloque 3 (.11) | 🟡 Media |
| UX-4 | **Ausencia de Guardia Preventiva de Permiso `canOpenCloseCash`:** `CashControlView.vue` no oculta los controles ni muestra overlay de "Sin Permiso" para empleados que carecen de `permissions.canOpenCloseCash = true`. | Bloque 5 (.15) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:** Frontend aporta `🔴` debido a las violaciones de Arqueo Ciego (UX-1 y UX-2).  
  *Estado resultante para SDD-004:* `🟡 Backend Listo / Frontend Incompleto`.

---

## 📌 Instrucción para el Orquestador (/orchestrator)

Tareas atómicas que deben ejecutarse en la Etapa 4 de remediación de código:
1. **Ocultamiento de Saldo Esperado en Arqueo:** Remover el bloque *"Resumen del Turno"* (`summary.expected`) y el cálculo reactivo de `difference` en `CashControlView.vue` y `CloseRegisterModal.vue`. El cajero únicamente debe declarar el monto contado (`amount.value`), sin retroalimentación visual de descuadre hasta que el backend retorne `ActionResponse`.
2. **Presentación de Descuadre Post-Cierre:** Renderizar la diferencia (`difference`, `expected_balance`) únicamente en la pantalla/modal de confirmación posterior a la resolución exitosa del RPC `cerrar_caja`.
3. **Manejo de Error en Reconciliaciones Pendientes:** Reemplazar el `console.error` de `fetchPendingForcedSessions` por un estado reactivo `fetchError = true` con banner explícito de reintento.
4. **Guardia UI para `canOpenCloseCash`:** Integrar `<NoPermissionOverlay>` o deshabilitar formulario si el usuario autenticado es empleado y `currentUser.permissions.canOpenCloseCash !== true`.
