# Plan Maestro Frontend (Vue Client `@[/ux]`) — Adopción de los contratos SQL Olas 1–5

> **For Claude:** REQUIRED SUB-SKILL: usar `executing-plans` (sesión paralela con checkpoints) o `subagent-driven-development` para ejecutar este plan tarea por tarea.

**Goal:** Conectar el cliente Vue/Pinia a los contratos RPC ya aplicados en Supabase Cloud (`ihtjocmhzuliwwvdzfnz`), eliminando toda lógica financiera del cliente y haciendo visibles todos los errores del backend.

**Architecture:** Flujo unidireccional `Vue → Store → Repository → RPC`. El Backend es la autoridad (cálculos, validación, códigos de error); el Frontend solo pide, espera, presenta y traduce errores. Una capa compartida nueva (`rpcErrors`, `bogotaDate`, `useRpcAction`) evita repetir parseo de errores y bloqueo de doble click en cada vista.

**Tech Stack:** Vue 3 + Pinia + Vite, `decimal.js`, Vitest (`npx vitest run`), Supabase JS. Protocolos: [`/ux`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/.agent/skills/ux/SKILL.md), [`/pac-uxd`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/.agent/skills/pac-uxd/SKILL.md), [`/writing-plans`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/.agent/skills/writing-plans/SKILL.md), Reglas 2, 3, 5, 6, 7, 9 y 10 de [`AGENTS.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/.agent/AGENTS.md).

---

## 1. Diagnóstico Mecánico Previo (evidencia propia de esta sesión)

Todo lo de esta tabla se verificó ejecutando `grep`, `pg_proc`, SQL o `vitest`; nada se copió de los SDDs como si fuera evidencia (Regla 9.3).

| ID | Hallazgo | Evidencia | Sev. |
|:--:|:---|:---|:--:|
| **F-1** | **Abonos de clientes rotos hoy en producción.** El cliente llama `registrar_abono` con `p_payment_method`, pero en BD solo existe `registrar_abono(p_client_id, p_amount)`. | `stores/clients.ts:189-193` + `pg_proc` (una sola firma). Reproducido: `ERROR 42883: function public.registrar_abono(uuid, numeric, text) does not exist`. | 🔴 |
| **F-2** | **Gastos se insertan directo en `cash_movements`**, sin `payment_method`, sin validar liquidez por canal ni límite 24 h. | `expenseRepository.ts:200`: `supabase.from('cash_movements').insert(dbRow)`. Contrato RVC: «Prohibido el INSERT directo; requiere `rpc_registrar_gasto_v2`». | 🔴 |
| **F-3** | **Ventas usan `rpc_procesar_venta_v2` (sin `idempotency_key`)**. Un reintento offline puede duplicar la venta. | `saleRepository.ts:168`, `syncQueue.ts:418`. `rpc_procesar_venta_v3` acepta `p_idempotency_key uuid, p_local_id text`. | 🔴 |
| **F-4** | **Pago mixto se guarda como `efectivo` en silencio** (se pierde el canal Nequi/Daviplata/Bre). | `saleRepository.ts:163`: `'mixed' ‖ 'cash' → 'efectivo'`. Viola Regla 3 / Muro 3. | 🔴 |
| **F-5** | **El cliente calcula subtotales, total y redondeo a $50.** | `stores/cart.ts:38-39` (reduce de totales) y `cart.ts:268` (`roundToNearest50`). `SDD_007_01` L178-180: «El Frontend NO calcula importes… ni redondeos». | 🔴 |
| **F-6** | **Fecha UTC vs. fecha Bogotá.** Entre 19:00 y 23:59 (Bogotá) el admin no ve solicitudes ni dispositivos del día, porque el backend ahora usa `America/Bogota`. | `authRepository.ts:458` y `:494`: `new Date().toISOString().split('T')[0]`. | 🔴 |
| **F-7** | **Rechazar/revocar hace `UPDATE` directo a `daily_passes`**: sin validar admin, sin `audit_logs` ni `audit_seguridad`. | `authRepository.ts:536-542`. Existe `rpc_gestionar_dispositivo(p_pass_id, p_action)`. | 🔴 |
| **F-8** | **Defecto backend propio (mi Ola 5):** `crear_empleado` / `toggle_empleado_activo` cuentan al dueño (`owner_*`) dentro del tope de 5. El frontend lo excluye y afirma «alineado con el backend». | `employees.ts:19-23, 75`; BD: `YAMIR/owner_3bdfa298` es `is_active=true` y está en `admin_profiles`. Prueba Ola 5: tienda con 3 activos (incluye owner) rechazó el 6.º tras sumar 2. `SDD_013`: «1 Admin + 5 Empleados». | 🔴 |
| **F-9** | **Contrato de error cambió** (`RAISE EXCEPTION 'CODE: texto'`) y el cliente muestra `error.message` crudo o lee `result.error` (que ya no llega). | `employeeRepository.ts:140-160`, `saleRepository.ts:170-182`. | 🟡 |
| **F-10** | **Línea base de pruebas en rojo:** 7/12 archivos fallan, **18 tests rojos / 51 verdes (69)**. | `npx vitest run` (13:28). Ej.: `ClientDetailView.spec.ts:183`. Hay specs duplicados (`ClientDetailView`, `ClientFormModal` ×2). | 🟡 |
| **F-11** | **Tipos generados obsoletos**: no existen `idempotency_key`, `void_session_id`, `voucher_ref`, `reviewed_by`, ni las RPCs `rpc_*_v3`/`gestionar_dispositivo`/`gasto_v2`. | Búsqueda textual en `types/database.types.ts` y `types/supabase.ts` (0 coincidencias). | 🟡 |
| **F-12** | **10 RPCs nuevas sin consumidor:** `rpc_procesar_venta_v3`, `rpc_registrar_gasto_v2`, `rpc_registrar_abono`, `rpc_admin_get_clients`, `buscar_producto_pos`, `rpc_gestionar_dispositivo`, `rpc_obtener_empleados`, `rpc_marcar_auditoria_revisada`, `rpc_asignar_proveedor_masivo`/`rpc_bulk_assign_supplier`, `rpc_registrar_entrada_masiva`. | `grep` de `.rpc('…')` (solo detecta nombres literales; un nombre dinámico no se vería). | 🟡 |
| **F-13** | La pantalla de caja **muestra el saldo esperado y calcula la diferencia en el cliente**, lo que `SDD_020` POL-SEG-01 (arqueo ciego) prohíbe. | `CashControlView.vue:332` (`formatCurrency(summary.expected)`), `:183`; `CloseRegisterModal.vue:51,61,177`; `stores/cashRegister.ts:22-63`. No abrí la pantalla en ejecución. | 🔴 |
| **F-14** | `syncQueue.ts:441` inserta `clients` directo (alta offline). | Lectura de código. Falta contrastar con `SDD_009 §5`. | 🟡 |
| **F-15** | El cliente oculta solicitudes pendientes con >5 min; `FRD_001` Caso B no define ningún TTL (la solicitud sigue pendiente hasta 3 reintentos). | `authRepository.ts:460` vs `FRD_001` Caso B. | 🟡 |
| **F-16** | **Defecto backend propio (mi Ola 5): fecha del pase inconsistente.** Yo escribo `pass_date` con fecha de Bogotá, pero `get_current_store_id()` y `get_employee_id_from_session()` filtran `pass_date = CURRENT_DATE`, y la BD está en **UTC**. Entre 19:00 y 23:59 (Bogotá) un empleado con pase aprobado dejaría de ser reconocido. | Zona BD = `UTC` (consulta). Texto de ambas funciones en `pg_proc` (`... AND pass_date = CURRENT_DATE`). `SDD_001` §4.6 dice `CURRENT_DATE`; `SDD_015` dice Bogotá. **No lo simulé en la franja horaria** (ahora son las 13:36 y ambas fechas coinciden): es 🟡 por lectura de código. | 🔴 |

**N = 16 hallazgos.** (Regla 9.1: la conclusión final los referencia uno a uno.)

> [!IMPORTANT]
> **Lo que NO se ha hecho:** no se ha tocado ningún `.vue`/`.ts`; no se ha ejecutado ningún PAC-UXD formal aún (F-13/14/15 son lecturas, no veredictos). Ninguna tarea de este plan está probada todavía.

---

## 2. Qué responden los SDD/FRD (y dónde se contradicen)

Las "decisiones" de la versión anterior de este plan eran preguntas que **debí contrastar primero con los documentos**. Esto es lo que dicen (citas leídas en esta sesión) y de dónde nace cada inconsistencia.

| Tema | Lo que dicen los documentos | ¿Respondida? | Origen de la inconsistencia | Acción |
|:--|:--|:--:|:--|:--|
| **Pago mixto** (D-F2) | `FRD_004` Caso B: «Recepción de Pago Mixto **(Próximamente POS)**». Ningún SDD define el payload. | ✅ Sí: es futuro | La UI lo ofrece aunque el FRD lo declara «próximamente». | Quitar «mixto» de la UI; deuda registrada para Ola 6. |
| **Tope de empleados** (D-F3) | `FRD_003` RN-7/Caso A: «5 empleados activos». `FRD_013` RN-013-02: «1 sesión Admin + 5 de Empleados». `SDD_003` §2.1 pide literalmente `COUNT(*) FROM employees WHERE store_id AND is_active = true`. | ⚠️ Intención sí (admin ≠ empleado); redacción SQL no | Ningún documento menciona que el dueño **también tiene una fila en `employees`** (`owner_*`). El SQL del SDD cuenta esa fila; el FRD no. Yo copié el SQL literal y vi la fila del dueño en los datos sin cuestionarla. | Hotfix `/data` T0.1 (excluir `admin_profiles`) **y** corregir `SDD_003` §2.1 y el RVC. |
| **Total del carrito** (D-F1) | `SDD_007_01` §2.3 (L178-180): el cliente solo acumula `{product_id, quantity}`; no suma, no redondea. **Pero** `SDD_012` §4.5 L307 valida offline `balance + total <= credit_limit` en el cliente, §4.3 L296 exige respetar el precio cobrado en mostrador, y el payload de cola (L333) exige `total`. | ❌ Se contradicen | Cada SDD se certificó por separado; `SDD_012` nunca se cruzó con la regla de «cero cálculos» de `SDD_007_01`. | **Decisión de documento primero**, no de código (ver nota abajo). |
| **TTL de 5 min en solicitudes** (F-15) | `FRD_001` Caso B: la solicitud sigue pendiente; reintento tras ~2 y ~5 min; bloqueo tras el 3.º intento. No existe un TTL que la oculte. | ✅ Sí | El cliente inventó un TTL de 5 min (`authRepository.ts:460`). | Quitar el filtro. |
| **Saldo esperado visible** (F-13) | `SDD_020` POL-SEG-01 y L326: el `expected_amount` **no** se muestra antes de que el usuario declare lo contado ni se expone por API. | ✅ Sí | `CashControlView.vue:332` y `CloseRegisterModal.vue:177` muestran «Total Esperado» y calculan la diferencia en cliente (`:51`, `:61`, `:183`). | Violación por cita de línea (no abrí la pantalla en ejecución). Rediseñar a arqueo ciego. |
| **Fecha del pase** (F-6/F-16) | `SDD_015` §0.3 D-1 y `SDD_001` §0.3 D-2: `America/Bogota`. `SDD_001` §4.6 (Caso G): «`CURRENT_DATE` del servidor». Zona de la BD: **UTC** (verificado). | ❌ Se contradicen | Dos definiciones de «hoy» en el mismo módulo; yo apliqué Bogotá sin revisar las funciones auxiliares que usan `CURRENT_DATE`. | **Defecto real nuevo: ver F-16 y T0.1b.** |

> **Nota sobre D-F1.** El SDD de ventas manda *cero cálculo*; el de offline *necesita* un total y precios en el cliente. Son dos reglas válidas en contextos distintos (online vs. sin red) que nadie reconcilió. La propuesta es documental: **online** → regla de `SDD_007_01` tal cual (el total oficial lo devuelve el backend); **offline** → el cliente guarda precio y total solo como *dato de cola* para la barrera preventiva de fiados, rotulado «estimado», y el backend recalcula al sincronizar. Esto requiere enmendar `SDD_007_01` §2.3 y `SDD_012` §4.3 antes de tocar `cart.ts`. **Además no verifiqué** si `rpc_procesar_venta_v3` honra el precio offline (RN-012-04) o usa el precio actual del catálogo; es una pregunta abierta para `/data`.

### Por qué aparecen estas inconsistencias (causa raíz)

1. **Los SDD se escriben y certifican módulo por módulo.** El cruce entre vecinos es una tabla en prosa (§0.2), no una verificación mecánica; dos módulos pueden afirmar cosas incompatibles y ambos pasan.
2. **La Regla 2 valida nombres de columnas, no semántica.** No detecta que el dueño vive en `employees`, ni que las funciones auxiliares usan `CURRENT_DATE` en una BD en UTC.
3. **No existen filas «transversales» en el RVC** para reglas que cruzan módulos (zona horaria, conteo de personal, quién calcula el total). Se redefinen en cada SDD.
4. **El frontend nunca se auditó contra los SDD** (PAC-UXD no se había ejecutado), así que divergió en silencio.

> **Propuesta:** añadir 3 filas transversales al RVC (zona horaria del «día de negocio», qué cuenta como «empleado», quién calcula importes online/offline) y exigir que todo SDD las cite.

---

## 3. Protocolo inmutable por tarea (Gates)

1. **Paso 1 — Diagnóstico mecánico (Regla 10):** `node scripts/scan-impact.mjs <entidad>`; imprimir el cuadro de 4 líneas. Si toca SQL/payload: consulta de `pg_proc` (Regla 6) y firma real citada (Regla 2).
2. **Paso 2 — PAC-UXD** del componente contra la §5 de su SDD → `documentation/01_requirements/VERIFICACION/PAC_UXD_SDD_<N>.md` (B1–B5: payload, Backend Authority, matriz de estados, SPEC-011, permisos).
3. **Paso 3 — Test que falla primero** (Vitest). Ejecutarlo y ver el rojo.
4. **Paso 4 — Implementación mínima.**
5. **Paso 5 — Verificación con evidencia (Regla 5):** `npx vitest run <archivo>` verde **y** ejecución de la **rama de error** (no solo el camino feliz) contra la BD real o con el mock del código de error exacto; para flujos críticos, captura de pantalla.
6. **Paso 6 — Respuesta obligatoria (Regla 3):** *«¿Qué ve el usuario si esto falla?»* Debe ser un mensaje distinto al de éxito. Prohibido `0`, `[]`, `null` o pantalla vacía como sustituto de error.
7. **Paso 7 — Commit** (`/commit`), un commit por tarea. El hook `pre-commit` exige sello de escaneo vigente (30 min).

**Checklist de UX por pantalla (`/ux`):** ⏳ skeleton que imita el payload · 📭 empty state · ❌ error visible y diferenciado · botón de acción con spinner y **bloqueo de doble click** · dinero formateado con `SPEC-011` · mobile-first · sin actualización optimista en dinero/inventario.

---

## 4. Mapa código de error → experiencia (se implementa en T0.4)

El backend lanza `RAISE EXCEPTION 'CODIGO: texto'` → `error.message` empieza por el código. Los RPC de acceso (`request_employee_access`, `solicitar_pase_diario`) además **devuelven** `{success:false, code}` por contrato de `SDD_001 §5.5`; el mapper debe aceptar ambos canales.

| Código | Origen | Mensaje al usuario / acción |
|:---|:---|:---|
| `SHIFT_EXPIRED_24H` | Ola 1 | «El turno superó 24 h. Ciérralo para continuar.» → CTA a cierre |
| `INSUFFICIENT_CHANNEL_FUNDS` | Ola 1 | «No hay saldo suficiente en {canal}.» (no cambia canal solo) |
| `INVALID_AMOUNT` / `INVALID_PAYMENT_METHOD` / `INVALID_DESCRIPTION` / `INVALID_ACTUAL_BALANCE` | Ola 1 | Error inline en el campo |
| `NO_OPEN_CASH_SESSION` | Olas 1/3 | Banner «Caja cerrada» + POS en solo lectura (D-03) |
| `STOCK_REMAINING` | Ola 2 | «No se puede eliminar: aún hay stock.» |
| `EMPTY_ENTRIES` / `EMPTY_PRODUCT_LIST` | Olas 2/4 | Botón deshabilitado + ayuda |
| `INSUFFICIENT_STOCK` / `CREDIT_LIMIT_EXCEEDED` | SDD_007_01 | Alerta roja / toast con saldo, cupo y total (según SDD) |
| `SALE_NOT_FOUND` / `REASON_TOO_SHORT` | Ola 3 | Toast / validación ≥ 10 caracteres |
| `CLIENT_NOT_FOUND` | Ola 3 | Refrescar lista |
| `RANGE_EXCEEDS_MAX_LIMIT` | Ola 4 | Selector de fechas limitado a 366 días |
| `STORE_ACCESS_DENIED` / `UNAUTHORIZED` / `UNAUTHORIZED_ACTOR` | Olas 1–5 | Cierre de sesión seguro + mensaje |
| `SESSION_LIMIT_REACHED` | Ola 5 | «Máximo 5 terminales de empleados. Revoca una para aprobar.» |
| `EXPIRED_PASS_DATE` / `PASS_NOT_FOUND` | Ola 5 | Refrescar bandeja |
| `EMPLOYEE_LIMIT_REACHED` / `LIMIT_REACHED` | Ola 5 | «Desactiva un empleado para continuar.» |
| `USERNAME_ALREADY_EXISTS` / `INVALID_PIN_FORMAT` | Ola 5 | Error inline |
| `MAX_RETRIES` | Ola 5 | Bloquea reenvío: «Contacta a tu supervisor.» |
| *(código desconocido)* | — | **Nunca silencioso:** «Error inesperado ({CÓDIGO})» + `logger.error` |

---

## 5. Fase 0 — Cimientos y hotfixes urgentes

### Task 0.0: Congelar el trabajo de backend en Git
**Hallazgo:** `git status` (rama `draft/sdd-alignment-v1.5.8`) muestra las 5 migraciones y ~40 SDDs sin commit; mezclarlos con commits de frontend rompería la trazabilidad.
- **Paso:** usar `/commit` en 2 commits: (a) `feat(db): olas 1-5 migraciones SQL + cuarentena _archived_unapplied`, (b) `docs(sdd): certificación SDDs v2.0 + RVC`. Verificar `git status` limpio salvo `frontend/`.

### Task 0.1: Hotfix backend del tope de empleados *(F-8; ejecuta `/data`; base documental: `FRD_013` RN-013-02 separa Admin de Empleados)*
**Files:** Create `supabase/migrations/20261017140000_wave5b_employee_cap_excludes_admin.sql`
- **Paso 1:** `node scripts/scan-impact.mjs employees crear_empleado toggle_empleado_activo` + `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%employees%'` (Regla 6).
- **Paso 2:** en `crear_empleado` y en la rama de reactivación de `toggle_empleado_activo`, contar `employees e WHERE e.store_id=… AND e.is_active AND NOT EXISTS (SELECT 1 FROM admin_profiles a WHERE a.id = e.id)`.
- **Paso 3:** aplicar con `apply_migration`; **probar**: tienda con owner + 5 operativos → el 6.º operativo lanza `EMPLOYEE_LIMIT_REACHED`; owner + 4 → el 5.º entra. (Insertar temporales en transacción y verificar el conteo final, como en Ola 5.)
- **Paso 4:** actualizar `RVC` («Límite de Personal») y `SDD_003` §2.1 con la regla «admin no cuenta».

### Task 0.1b: Hotfix backend de la fecha del pase *(F-16; ejecuta `/data`; **prioridad más alta de la Fase 0**)*
**Files:** Create `supabase/migrations/20261017141000_wave5c_business_day_bogota.sql`
- **Paso 1 (reproducir primero):** en SQL, con `BEGIN…ROLLBACK`, crear un pase aprobado con `pass_date = '2026-10-17'`, simular `now() = 2026-10-18 02:30 UTC` (21:30 Bogotá) y comprobar que `get_employee_id_from_session()` devuelve `NULL`. Citar la salida. Sin esta reproducción el defecto sigue siendo 🟡.
- **Paso 2 (Regla 6):** `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%CURRENT_DATE%'` y listar **todas** las funciones afectadas antes de decidir.
- **Paso 3 — opciones (Regla 10 Fase B):**
  - **A)** Cambiar `get_current_store_id`, `get_employee_id_from_session` (y las demás del Paso 2 que filtren `daily_passes`) a `(now() AT TIME ZONE 'America/Bogota')::date`. *Quirúrgico; coherente con `SDD_015`.*
  - **B)** `ALTER DATABASE postgres SET timezone = 'America/Bogota'`. *Una línea, pero cambia `CURRENT_DATE` en todas las funciones (reportes, defaults); requiere auditar todo.*
  - **C)** Volver `pass_date` a `CURRENT_DATE` (UTC). *Contradice «válido hasta las 23:59»: el pase caducaría a las 19:00 Bogotá.*
  - **Recomendación: A.**
- **Paso 4:** aplicar, repetir la reproducción del Paso 1 (debe devolver el id del empleado) y probar también la rama de pase de ayer (debe devolver `NULL`).
- **Paso 5:** corregir `SDD_001` §4.6 y añadir al RVC la fila transversal «Día de negocio = `America/Bogota`».

### Task 0.2: Regenerar tipos *(F-11)*
**Files:** Modify `frontend/src/types/database.types.ts`; revisar importadores de `types/supabase.ts`.
- **Paso 1:** MCP `generate_typescript_types` (`ihtjocmhzuliwwvdzfnz`) → sobrescribir `database.types.ts`.
- **Paso 2:** `rg "types/supabase"` en `frontend/src`; si nadie lo importa, marcarlo para eliminación (no borrar sin tu visto bueno).
- **Paso 3:** verificar con `Select-String` que aparecen `idempotency_key`, `void_session_id`, `voucher_ref`, `reviewed_by`, `rpc_gestionar_dispositivo`, `rpc_procesar_venta_v3`.
- **Paso 4:** `npx tsc --noEmit -p frontend` (si `vue-tsc` no existe, registrar la ausencia como deuda: `build` actual es solo `vite build`, no verifica tipos).

### Task 0.3: Triage de la línea base roja *(F-10)*
**Files:** `frontend/src/__tests__/**`
- **Paso 1:** `npx vitest run --reporter=json > scratch/baseline.json`; tabla de los 18 rojos con causa: *(a)* test desactualizado, *(b)* regresión real, *(c)* duplicado.
- **Paso 2:** por cada rojo, arreglar el código **o** actualizar el test con justificación escrita. **Prohibido** borrar o `skip` sin razón (Regla 5).
- **Salida esperada:** `Tests 0 failed`. Si algún rojo depende de una tarea posterior, se anota con su tarea de cierre.

### Task 0.4: Capa compartida (TDD completo)
**Files:**
- Create: `frontend/src/utils/rpcErrors.ts`, `frontend/src/utils/bogotaDate.ts`, `frontend/src/composables/useRpcAction.ts`
- Test: `frontend/src/__tests__/utils/rpcErrors.spec.ts`, `bogotaDate.spec.ts`, `composables/useRpcAction.spec.ts`

**Step 1 — Tests que fallan**
```ts
// rpcErrors.spec.ts
import { describe, it, expect } from 'vitest';
import { parseRpcError } from '../../utils/rpcErrors';

describe('parseRpcError', () => {
  it('extrae el código de un RAISE EXCEPTION "CODE: texto"', () => {
    const r = parseRpcError({ message: 'EMPLOYEE_LIMIT_REACHED: Límite de 5 empleados' });
    expect(r.code).toBe('EMPLOYEE_LIMIT_REACHED');
    expect(r.userMessage).toContain('Desactiva');
  });
  it('acepta payload devuelto {success:false, code}', () => {
    expect(parseRpcError({ success: false, code: 'MAX_RETRIES' }).code).toBe('MAX_RETRIES');
  });
  it('código desconocido NUNCA es silencioso', () => {
    const r = parseRpcError({ message: 'ZZ_NUEVO: x' });
    expect(r.code).toBe('ZZ_NUEVO');
    expect(r.userMessage).toContain('ZZ_NUEVO');
  });
  it('error sin código (red) se clasifica NETWORK, no vacío', () => {
    expect(parseRpcError(new Error('Failed to fetch')).code).toBe('NETWORK');
  });
});
```
```ts
// bogotaDate.spec.ts
import { it, expect } from 'vitest';
import { bogotaToday } from '../../utils/bogotaDate';
it('21:30 Bogotá (02:30Z del día siguiente) sigue siendo el día anterior', () => {
  expect(bogotaToday(new Date('2026-10-18T02:30:00Z'))).toBe('2026-10-17');
});
it('09:00 Bogotá', () => {
  expect(bogotaToday(new Date('2026-10-17T14:00:00Z'))).toBe('2026-10-17');
});
```
```ts
// useRpcAction.spec.ts
import { it, expect, vi } from 'vitest';
import { useRpcAction } from '../../composables/useRpcAction';
it('bloquea doble click mientras la promesa está pendiente', async () => {
  let release!: () => void;
  const fn = vi.fn(() => new Promise<string>(r => { release = () => r('ok'); }));
  const { run, loading } = useRpcAction(fn);
  const p1 = run(); const p2 = run();
  expect(loading.value).toBe(true);
  expect(fn).toHaveBeenCalledTimes(1);
  release(); await p1; await p2;
  expect(loading.value).toBe(false);
});
it('expone el error parseado (no lo traga)', async () => {
  const { run, error } = useRpcAction(async () => { throw { message: 'STOCK_REMAINING: x' }; });
  await run();
  expect(error.value?.code).toBe('STOCK_REMAINING');
});
```
**Step 2:** `cd frontend; npx vitest run src/__tests__/utils src/__tests__/composables/useRpcAction.spec.ts` → Esperado: **FAIL** (módulos inexistentes).

**Step 3 — Implementación mínima**
```ts
// utils/rpcErrors.ts
export interface RpcErrorInfo { code: string; technical: string; userMessage: string }
const MESSAGES: Record<string, string> = {
  SHIFT_EXPIRED_24H: 'El turno superó 24 horas. Ciérralo para continuar.',
  INSUFFICIENT_CHANNEL_FUNDS: 'No hay saldo suficiente en ese canal de pago.',
  NO_OPEN_CASH_SESSION: 'La caja está cerrada. Ábrela para registrar movimientos de dinero.',
  STOCK_REMAINING: 'No se puede eliminar: aún hay stock disponible.',
  SESSION_LIMIT_REACHED: 'Máximo 5 terminales de empleados. Revoca una para aprobar otra.',
  EMPLOYEE_LIMIT_REACHED: 'Límite de 5 empleados activos. Desactiva uno para continuar.',
  LIMIT_REACHED: 'Límite de 5 empleados activos. Desactiva uno para continuar.',
  USERNAME_ALREADY_EXISTS: 'Ese alias ya está registrado.',
  INVALID_PIN_FORMAT: 'El PIN debe tener exactamente 4 dígitos.',
  MAX_RETRIES: 'Límite de intentos alcanzado. Contacta a tu supervisor.',
  RANGE_EXCEEDS_MAX_LIMIT: 'El rango máximo es de 366 días.',
  REASON_TOO_SHORT: 'El motivo debe tener al menos 10 caracteres.',
  STORE_ACCESS_DENIED: 'No tienes acceso a esta tienda.',
  // … completar con la tabla de la §4 del plan
};
const CODE_RE = /^([A-Z][A-Z0-9_]{2,})\b/;

export function parseRpcError(err: unknown): RpcErrorInfo {
  const e = err as { message?: string; code?: string; success?: boolean } | null;
  const technical = e?.message ?? '';
  const code = e?.code && /^[A-Z][A-Z0-9_]+$/.test(e.code) ? e.code
    : CODE_RE.exec(technical)?.[1]
    ?? (/fetch|network/i.test(technical) ? 'NETWORK' : 'UNKNOWN');
  const userMessage = MESSAGES[code]
    ?? (code === 'NETWORK' ? 'Sin conexión con el servidor. Reintenta.' : `Error inesperado (${code}). Si persiste, contacta soporte.`);
  return { code, technical, userMessage };
}
```
```ts
// utils/bogotaDate.ts
export function bogotaToday(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Bogota', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(now);
}
```
```ts
// composables/useRpcAction.ts
import { ref } from 'vue';
import { parseRpcError, type RpcErrorInfo } from '../utils/rpcErrors';
import { logger } from '../utils/logger';

export function useRpcAction<A extends unknown[], R>(fn: (...a: A) => Promise<R>) {
  const loading = ref(false);
  const error = ref<RpcErrorInfo | null>(null);
  async function run(...args: A): Promise<R | undefined> {
    if (loading.value) return undefined;           // bloqueo de re-entrada
    loading.value = true; error.value = null;
    try { return await fn(...args); }
    catch (e) { error.value = parseRpcError(e); logger.error('[rpc]', e); return undefined; }
    finally { loading.value = false; }
  }
  return { loading, error, run };
}
```
**Step 4:** repetir el comando del Step 2 → Esperado: **PASS** (8 tests).
**Step 5:** commit `feat(ux): capa compartida rpcErrors/bogotaDate/useRpcAction`.
**Respuesta Regla 3:** si falla un RPC el usuario ve `userMessage` + el código; nunca un estado vacío.

### Task 0.5: 🔴 Hotfix de abonos *(F-1, urgente, no depende de gates)*
**Files:** Modify `frontend/src/stores/clients.ts:184-215`; Test `frontend/src/__tests__/stores/clients.spec.ts`
- **Paso 1:** ejecutar en SQL (dentro de `BEGIN…ROLLBACK`) `rpc_registrar_abono(<cliente_test>, 1000, 'efectivo')` y **citar el payload real** (Regla 2) antes de mapearlo.
- **Paso 2 (test rojo):** el store debe llamar `rpc_registrar_abono` con `{ p_client_id, p_amount, p_payment_method, p_notes }` y **no** debe restar saldo localmente; tras éxito, refresca el cliente desde backend (`rpc_admin_get_clients`/payload).
- **Paso 3:** implementar; selector de canal (`efectivo|nequi|daviplata|bre`) en el modal de abono; `useRpcAction` para spinner y bloqueo; error → `parseRpcError`.
- **Paso 4:** probar rama de error (`INVALID_AMOUNT`, `CLIENT_NOT_FOUND`, `NO_OPEN_CASH_SESSION`) — el toast debe mostrar el mensaje, el saldo mostrado **no** cambia.
- **Nota:** `client.totalDebt.minus(amount)` (L211) es cálculo de saldo en cliente → se elimina (Muro 1).

---

## 6. Fase 1 — Caja y Gastos (Ola 1) · SDD_004, 017, 020, 022, 023, 026

### Task 1.1: Gastos vía `rpc_registrar_gasto_v2` *(F-2)*
**Files:** Modify `expenseRepository.ts:150-209`, `stores/expenses.ts`, `views/ExpensesView.vue`; Test `__tests__/repositories/expenseRepository.spec.ts` (nuevo)
- **Contrato:** `rpc_registrar_gasto_v2(p_session_id, p_amount, p_payment_method, p_category, p_description, p_voucher_ref?)`.
- **UI:** selector de canal, categoría, descripción obligatoria, `voucher_ref` opcional; skeleton de lista; empty state; botón con spinner.
- **Pruebas rojas primero:** (1) el repositorio **no** llama `.from('cash_movements').insert`; (2) mapea `INSUFFICIENT_CHANNEL_FUNDS` y `SHIFT_EXPIRED_24H` a mensajes; (3) el fallo devuelve error, no `null` mudo (hoy `return null` en L208 oculta la causa → Regla 3).
- **Evidencia:** captura del mensaje con saldo insuficiente.

### Task 1.2: Apertura/cierre multicanal y pantalla de turno
**Files:** `views/CashControlView.vue`, `components/cash/OpenRegisterModal.vue`, `CloseRegisterModal.vue`, `ForcedCloseAuditModal.vue`, `stores/cashRegister.ts`
- **Paso 2 (PAC-UXD):** `SDD_004`, `SDD_017`, `SDD_020`, `SDD_027_01` → resuelve **F-13** (¿los saldos esperados deben venir de backend?). Si hay cálculo prohibido, la tarea migra esa suma a una lectura del backend (si falta el RPC de lectura, se **solicita** a `/data`; no se inventa).
- **Comportamiento a cubrir:** arqueo ciego por canal (efectivo/Nequi/Bre/Daviplata) sin mostrar el esperado antes de contar; resultado de diferencia tras cerrar; cierre forzado 24 h con aviso; cierre bloqueado si hay registros críticos sin visar (`SDD_005/014`), con enlace a auditoría.
- **D-03 en UI:** al cerrar caja el empleado **permanece logueado**; POS en solo lectura con banner `NO_OPEN_CASH_SESSION`.

---

## 7. Fase 2 — Inventario y Compras (Ola 2) · SDD_006*, 010*, 019

| Task | Archivos | Contrato / Criterio de aceptación |
|:--|:--|:--|
| **2.1** Búsqueda POS | `POSView.vue`, `stores/inventory.ts` | `buscar_producto_pos(p_store_id, p_term, p_limit, p_offset)` → jsonb; debounce 150 ms; skeleton; sin resultados = empty state (no lista vacía muda); **medir** latencia con `performance.now()` y registrar el P95 en el informe (meta SDD: <200 ms). |
| **2.2** Baja lógica | `productRepository.ts:225`, `InventoryView.vue` | `STOCK_REMAINING` y deuda abierta en `supplier_payables` se muestran con mensaje accionable. |
| **2.3** Entradas masivas | `StockEntryView.vue`, `productRepository.ts:430` | `rpc_registrar_entrada_masiva(p_store_id, p_entries jsonb)`; `EMPTY_ENTRIES` deshabilita el botón; **ceguera financiera**: la entrada **no** toca caja ni deudas. |
| **2.4** Cuentas por pagar | `PayablesView.vue:233`, `stores/payables.ts` | PAC-UXD de `SDD_019`: `PayablesView.vue:233` resta `total_amount - amount_paid` en cliente → verificar si el backend ya entrega el pendiente; si no, solicitarlo a `/data` (Muro 1). |
| **2.5** Precios por lote | `stores/batches.ts:125`, `BatchHistoryModal.vue:174` | `rpc_actualizar_precio_lote` (dos sobrecargas en BD: confirmar cuál usa el cliente); `BatchHistoryModal:174` suma remanentes → evaluar. |

---

## 8. Fase 3 — Ventas y Clientes (Ola 3) · SDD_007*, 009, 014, 024

### Task 3.1: POS → `rpc_procesar_venta_v3` con idempotencia *(F-3)*
**Files:** `saleRepository.ts:140-183`, `data/syncQueue.ts:418`, `composables/useSaleProcessor.ts`, `stores/sales.ts`; Test `__tests__/repositories/saleRepository.spec.ts` (nuevo)
- **Diseño:** generar `idempotency_key = crypto.randomUUID()` **una vez por intención de cobro** (al abrir el checkout), conservarlo en la `syncQueue` y reutilizarlo en cada reintento. `p_local_id` = id local de cola.
- **Pruebas rojas:** (1) mismo `idempotency_key` en reintento tras fallo de red; (2) el payload **no** incluye precios ni totales (solo `product_id`, `quantity`); (3) respuesta repetida (replay) no duplica el ticket en la UI.
- **Evidencia SQL:** llamar dos veces `rpc_procesar_venta_v3` con la misma clave y comprobar **una** fila en `sales` (en `BEGIN…ROLLBACK`).

### Task 3.2: Sacar el cálculo financiero del cliente *(F-5, gate D-F1)*
**Files:** `stores/cart.ts:38-39,239-283`, `components/sales/CheckoutModal.vue:64,189`, `WeightCalculatorModal.vue`, `useSaleProcessor.ts:92`
- Según D-F1 (recomendada **B**): el carrito solo acumula `{product_id, quantity}`; cualquier suma visible se rotula «Estimado» y **nunca** se serializa; **eliminar `roundToNearest50`** del cliente; el ticket muestra `total`, `rounding_difference` y `change_given` devueltos por backend.
- **Pruebas rojas:** `cart.spec.ts` actual valida redondeo en cliente → reescribir para afirmar lo contrario (el cliente no redondea y el payload no contiene importes).
- **Dependencia:** si se elige A en D-F1, abrir pedido previo a `/data` para `rpc_calcular_carrito`.

### Task 3.3: Métodos de pago *(F-4, gate D-F2)*
- Quitar el mapeo silencioso `mixed → efectivo` (`saleRepository.ts:163`). Con D-F2 = A: retirar «mixto» de `CheckoutModal`; los canales válidos son `efectivo|nequi|daviplata|bre|fiado`. Cualquier valor fuera de la lista **lanza error visible** (no se reasigna).
- **Deuda registrada (Regla 7):** *Qué:* pago mixto fuera de alcance. *Por qué:* el RPC v3 acepta un solo método; simularlo en cliente rompería Backend Authority. *Revisar cuando:* `/data` entregue `p_payments jsonb[]` (Ola 6).

### Task 3.4: Anulación y venta forzada
**Files:** `components/history/SaleDetailModal.vue`, `saleRepository.ts:316,348`, `ForceSaleModal.vue:81`
- `rpc_anular_venta(p_sale_id, p_reason)`: motivo ≥ 10 caracteres validado **solo como formato** en cliente; errores `SALE_NOT_FOUND`, `REASON_TOO_SHORT`, `INSUFFICIENT_CHANNEL_FUNDS`, `NO_OPEN_CASH_SESSION`. Solo rol Admin (guard + `v-if`).
- `ForceSaleModal.vue:81` suma déficits en cliente → PAC-UXD `SDD_014`; el déficit debe provenir del error de stock del backend.
- `SaleDetailModal` consume `get_sale_detail` ampliado: mostrar `rounding_difference` y anulación (`void_session_id`, `voided_at`).

### Task 3.5: Clientes y fiados
**Files:** `views/ClientListView.vue`, `stores/clients.ts:21`, `syncQueue.ts:441`
- Lista paginada con `rpc_admin_get_clients(p_store_id, p_filter_debt, p_include_deleted, p_search_query, p_order_by, p_limit, p_offset)`; filtros de deuda, búsqueda y orden **en backend**.
- `clients.ts:21` suma deuda total en cliente → usar el agregado del backend (PAC-UXD `SDD_009/024`).
- **F-14:** PAC-UXD de `SDD_009 §5`: confirmar si el alta offline directa es el contrato; si no, solicitar RPC a `/data`.

---

## 9. Fase 4 — Historiales, Auditoría y Reportes (Ola 4) · SDD_005, 008, 018, 021, 027_01

| Task | Archivos | Criterio |
|:--|:--|:--|
| **4.1** Historial de caja y créditos | `composables/useHistory.ts:239-431`, `HistoryView.vue` | `get_history_caja` con desglose por canal; `get_history_creditos` (bug 42703 ya resuelto en BD) — la UI debe mostrar error visible si falla (hoy `totalAmount` se suma en cliente, `useHistory.ts:145`: revisar con PAC-UXD `SDD_021`). |
| **4.2** Auditoría forense | `SystemAuditView.vue`, `auditRepository.ts` | Botón «Marcar revisada» → `rpc_marcar_auditoria_revisada(p_audit_id, p_notes)`; estado `reviewed_by/at/notes`; sin optimismo. |
| **4.3** Abastecimiento inteligente | `components/reports/SmartSupplySection.vue:44,77` | Nuevos campos de `get_smart_supply_report` (DOI, velocidad, días saturados, umbral 15 días); `revenue_at_risk` sumado en cliente (L77) → pasa a campo de backend si existe, si no se solicita. Acción masiva `rpc_bulk_assign_supplier(p_store_id, p_supplier_id, p_product_ids)`; `EMPTY_PRODUCT_LIST` deshabilita. |
| **4.4** Reporte financiero | `stores/financial.ts:159`, `FinancialDashboardView.vue` | Selector de fechas limitado a 366 días; `RANGE_EXCEEDS_MAX_LIMIT` mostrado, no tragado. Skeleton por KPI; un KPI que falla **no** se pinta como `$0`. |

---

## 10. Fase 5 — Seguridad Diaria, Dispositivos y Equipo (Ola 5) · SDD_001, 003, 013, 015

### Task 5.1: Fecha Bogotá y bandeja de dispositivos *(F-6, F-15)*
**Files:** `authRepository.ts:456-518`, `stores/devices.ts`; Test `__tests__/repositories/authRepository.spec.ts` (nuevo)
- Reemplazar `new Date().toISOString().split('T')[0]` por `bogotaToday()` (T0.4) en `getPendingAccessRequests` y `getAuthorizedDevices`.
- **Prueba roja:** con reloj simulado a `2026-10-18T02:30:00Z`, la consulta debe pedir `pass_date = '2026-10-17'`.
- **F-15:** PAC-UXD `SDD_001`: decidir si el TTL de 5 min sigue; si contradice los 3 reintentos, retirarlo.

### Task 5.2: Aprobar / rechazar / revocar por `rpc_gestionar_dispositivo` *(F-7)*
**Files:** `authRepository.ts:525-551`, `stores/devices.ts:87+`, widget de accesos (`AdminHubView.vue`, `NotificationCenterView.vue`)
- Las tres acciones llaman `rpc_gestionar_dispositivo(p_pass_id, 'approve'|'reject'|'revoke')`; **eliminar el `UPDATE` directo**.
- `SESSION_LIMIT_REACHED` → mensaje con CTA «Revocar una terminal».
- **Pruebas rojas:** (1) ningún `.from('daily_passes').update`; (2) tras `revoke` la fila pasa a `rejected` y se registra en ambos logs (verificar en SQL).

### Task 5.3: Sala de espera y reintentos
**Files:** `views/DailyWaitingRoom.vue`, `GatekeeperPending.vue`, `authRepository.ts:571-637`
- Contador `retry_count/3`; `MAX_RETRIES` bloquea el botón y muestra contacto con supervisor; `success:false` ya no cae a `status:'none'` mudo (hoy `checkDailyPassStatus` devuelve `'none'` ante cualquier error, `authRepository.ts:625`: viola Regla 3 → distinguir error de red de «sin pase»).
- **Revocación en caliente (H15):** el canal Realtime sobre `daily_passes` debe expulsar al empleado en < 2 s. **Medir** con dos sesiones (cronómetro en captura).

### Task 5.4: Empleados *(F-8, F-9, gate D-F3)*
**Files:** `views/EmployeeManagerView.vue`, `stores/employees.ts:19-23,75`, `employeeRepository.ts`
- Directorio con `rpc_obtener_empleados(p_store_id, p_status_filter, p_search)`; filtros activos/inactivos y búsqueda (H14); `pin` llega vacío (no mostrar ni guardar).
- Eliminar la regla local de tope (`employees.ts:75`) o reducirla a una pista visual; **la decisión es del backend** (`EMPLOYEE_LIMIT_REACHED`).
- `employeeRepository` deja de leer `result.error`; usa `parseRpcError`. Desactivar muestra advertencia de expulsión inmediata.

---

## 11. Fase 6 — Verificación y cierre

1. `npx vitest run` → **0 fallos** (meta de T0.3 sostenida).
2. Un **PAC-UXD por cada SDD tocado** en `documentation/01_requirements/VERIFICACION/`; reconciliar conteo de hallazgos (Regla 9.1).
3. Recorrido manual con evidencia (capturas) de los 6 flujos críticos: venta contado, venta fiado, gasto con saldo insuficiente, cierre de caja ciego, aprobación/revocación de dispositivo, alta de empleado con tope.
4. Búsqueda final de lógica prohibida: `rg "from\('(cash_movements|sales|daily_passes|clients)'\)\.(insert|update|delete)" frontend/src` → **0** resultados salvo excepciones documentadas.
5. Actualizar el encabezado de cada SDD al estado compuesto de `/pac-uxd` (`🟢` solo con evidencia; `🟡 Backend Listo / Frontend Incompleto` si queda algo).
6. Informe final con la tabla N = 15 resuelta/diferida.

---

## 12. Alcance diferido (Regla 7)

| Qué se difiere | Por qué (trade-off) | Revisar cuando |
|:--|:--|:--|
| Pago mixto en POS | El RPC v3 admite un solo método; simularlo en cliente viola Backend Authority. | `/data` entregue `p_payments jsonb[]`. |
| `vue-tsc` en CI | `build` actual es `vite build` sin chequeo de tipos; añadirlo puede destapar cientos de errores previos y frenar el plan. | Terminada la Fase 0 (tipos regenerados). |
| Eliminar `types/supabase.ts` duplicado | Puede tener importadores ocultos. | T0.2 confirme 0 importadores. |
| Rediseño visual de pantallas | Fuera del objetivo (contratos y errores); no se aprobó cambio de UI. | Tras Fase 6, si lo pides. |

---

## 13. Reconciliación final (Regla 9.4)

Los 16 hallazgos tienen tarea asignada (F-16→T0.1b; F-13→T1.2, ahora con regla de `SDD_020` POL-SEG-01): F-1→T0.5 · F-2→T1.1 · F-3→T3.1 · F-4→T3.3 · F-5→T3.2 · F-6→T5.1 · F-7→T5.2 · F-8→T0.1/T5.4 · F-9→T0.4/T5.4 · F-10→T0.3 · F-11→T0.2 · F-12→T1.1, 2.1, 2.3, 3.1, 3.5, 4.2, 4.3, 5.2, 5.4 · F-13→T1.2 · F-14→T3.5 · F-15→T5.1.
**Estado de verificación:** ningún ítem de este plan está ejecutado; todos son 🟡/🔲 hasta tener evidencia de ejecución.
