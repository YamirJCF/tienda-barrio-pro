# 📜 WO-012: Aislamiento Multi-Tenant de Caché Local, Protocolo de Autodestrucción Total y Guardia Offline

> **Estado:** 🟢 COMPLETADO & VERIFICADO
> **Base Contractual:** ARQ-001 (Backend Authority), RVC_registro_vivo_contratos.md (Persistencia Segura L47)
> **Fecha:** 2026-10-31
> **Líder Técnico:** Orquestador Técnico (Tech Lead)

---

## 1. Diagnóstico Estructural y Causa Raíz (Fase 0)

### 1.1 El Problema Detectado
Al registrar una nueva cuenta o cambiar de cuenta en el mismo dispositivo, la interfaz cargaba los productos (27 productos) y transacciones de la tienda anterior (`maria`), a pesar de que la base de datos Supabase arrojaba 0 productos para la nueva tienda (`PRUEBA1`, UUID: `8ef75cf6-f98c-44dd-b0d4-1a92860c27a3`). Además, existía el riesgo de remanencia de datos en memoria RAM viva de los stores de Pinia tras un cierre de sesión, y la posibilidad de pérdida de ventas offline si se cerraba sesión sin sincronizar.

### 1.2 Radio de Explosión & Hallazgos Verificados
1. **`supabaseAdapter.ts` (L120-L140):** Existía un bloque condicional defensivo que, si Supabase devolvía 0 registros pero el almacenamiento local tenía elementos, abortaba la sobreescritura bajo la sospecha de *"Possible RLS issue. NOT overwriting localStorage"*.
2. **`productRepository.ts` (L215-L225):** Evaluaba `if (results.length === 0)` y automáticamente consultaba la caché de IndexedDB, asumiendo que 0 productos equivalía a una falla de red.
3. **`IndexedDBDataSource.ts` (L207):** La función `saveBulk(items)` tenía una guardia `if (items.length === 0) return;`, lo que impedía que una lista vacía limpiara el almacén IndexedDB (`store.clear()`).
4. **`auth.ts` (L393-L408):** La función `logout()` no purgaba de forma exhaustiva las colecciones de negocio (`tienda-inventory`, `products`, `clients`, `sales`, etc.) ni reseteaba los módulos en memoria RAM.
5. **`inventory.ts` (L160-L170):** El store en memoria mantenía los productos en `products.value` sin reiniciarlos cuando cambiaba la tienda activa.
6. **`sales.ts` (L174-L186):** El store de ventas acumulaba ventas (`sales.value.push(s)`) sobre las ventas de la sesión anterior en lugar de reemplazarlas autoritativamente con la respuesta del servidor.
7. **`RegisterStoreView.vue` & `WaitingRoomView.vue`:** El flujo de verificación de correo no propagaba el email hacia la sala de espera ni validaba formatos de dominios comunes, provocando rebotes y pantallas de error.
8. **`router/index.ts`:** La ruta `'/'` carecía del alias `'/dashboard'`, haciendo que URLs con hash como `#/dashboard` cayeran en el catch-all `/:pathMatch(.*)*` (`AuthCallbackView.vue`), mostrando "Enlace Inválido".
9. **`UserProfileSidebar.vue`:** El botón de "Cerrar Sesión" permitía cerrar sesión aun cuando no había internet o existían ventas encoladas en `syncQueue`, arriesgando pérdida de datos.

---

## 2. Reporte de Contexto Comprobado (Regla 9.3)

| Componente / Archivo | Estado | Acción Ejecutada | Evidencia |
|---|---|---|---|
| `frontend/src/data/repositories/supabaseAdapter.ts` | ✅ Corregido | Eliminado bloqueo de 0 items; Supabase es la autoridad. | [supabaseAdapter.ts](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/data/repositories/supabaseAdapter.ts#L115-L125) |
| `frontend/src/data/repositories/productRepository.ts` | ✅ Corregido | Fallback a IndexedDB solo en caso de falla real de red (`!fetchedOnline`), indexado por `by_store`. | [productRepository.ts](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/data/repositories/productRepository.ts#L200-L230) |
| `frontend/src/data/sources/IndexedDBDataSource.ts` | ✅ Corregido | Eliminado `if (items.length === 0) return;` en `saveBulk` para permitir limpieza de almacén. | [IndexedDBDataSource.ts](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/data/sources/IndexedDBDataSource.ts#L204-L215) |
| `frontend/src/stores/auth.ts` | ✅ Corregido | Implementado `destroyAllLocalData()` (RAM + Disco) y guardia offline/cola en `logout()`. Eliminado `checkTenantSwitch` redundante. | [auth.ts](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/stores/auth.ts#L45-L120) |
| `frontend/src/stores/sales.ts` | ✅ Corregido | Reemplazo autoritativo `sales.value = [...remoteSales]` en lugar de merge acumulativo. | [sales.ts](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/stores/sales.ts#L170-L185) |
| `frontend/src/stores/inventory.ts` | ✅ Corregido | Reseteo inmediato de `products.value = []` cuando cambia `loadedStoreId`. | [inventory.ts](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/stores/inventory.ts#L160-L170) |
| `frontend/src/components/UserProfileSidebar.vue` | ✅ Corregido | Bloqueo silencioso del botón "Cerrar Sesión" si `!isOnline || pendingSyncCount > 0`. | [UserProfileSidebar.vue](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/components/UserProfileSidebar.vue#L425-L435) |
| `frontend/src/router/index.ts` | ✅ Corregido | Añadido `alias: ['/dashboard']` y manejo seguro del resultado de `logout()`. | [router/index.ts](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/router/index.ts#L16-L20) |
| `frontend/src/views/RegisterStoreView.vue` | ✅ Corregido | Validación estricta TLD, detección de typos (`@gmail.co`), envío de `email` vía query y session. | [RegisterStoreView.vue](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/views/RegisterStoreView.vue#L45-L90) |
| `frontend/src/views/auth/WaitingRoomView.vue` | ✅ Corregido | Detección robusta de email desde query/session y llamadas a `authRepository.resendConfirmationEmail`. | [WaitingRoomView.vue](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/views/auth/WaitingRoomView.vue#L85-L160) |
| `frontend/src/views/auth/AuthCallbackView.vue` | ✅ Corregido | Verificación de sesión activa antes de emitir "Enlace Inválido". | [AuthCallbackView.vue](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/frontend/src/views/auth/AuthCallbackView.vue#L75-L115) |

---

## 3. Secuencia de Tareas Atómicas Ejecutadas

- [x] **Paso 1 — Capa Repositorio Base:** Desbloquear la autoridad de Supabase cuando devuelve 0 registros.
  - **Archivo:** `frontend/src/data/repositories/supabaseAdapter.ts`
  - **Acción:** MODIFICAR — Reemplazar el bloque de advertencia RLS por persistencia directa de lo recibido de Supabase.
  - **Validación:** Pasó prueba unitaria de integridad de tríada.

- [x] **Paso 2 — Capa IndexedDB:** Permitir que listas vacías limpien el store local.
  - **Archivo:** `frontend/src/data/sources/IndexedDBDataSource.ts`
  - **Acción:** MODIFICAR — Eliminar la guardia `if (items.length === 0) return;` en `saveBulk()`.
  - **Validación:** Operación de borrado atómico confirmada.

- [x] **Paso 3 — Capa Repositorio Productos:** Distinguir entre tienda vacía y offline real.
  - **Archivo:** `frontend/src/data/repositories/productRepository.ts`
  - **Acción:** MODIFICAR — Reemplazar la condición `if (results.length === 0)` por bandera de fallo de red (`!fetchedOnline`) y filtrar por índice `by_store`.
  - **Validación:** Pruebas unitarias de productos aprobadas.

- [x] **Paso 4 — Capa Pinia Store de Inventario:** Vaciar productos en memoria al cambiar de tienda.
  - **Archivo:** `frontend/src/stores/inventory.ts`
  - **Acción:** MODIFICAR — Resetear `products.value = []` si `loadedStoreId !== effectiveStoreId`.
  - **Validación:** Compilación reactiva validada.

- [x] **Paso 5 — Capa Pinia Store de Ventas:** Reemplazo autoritativo desde Supabase.
  - **Archivo:** `frontend/src/stores/sales.ts`
  - **Acción:** MODIFICAR — Eliminar merge acumulativo y sustituir por `sales.value = [...remoteSales]`.
  - **Validación:** Pruebas de mapeo de ventas aprobadas.

- [x] **Paso 6 — Capa Auth Store: Autodestrucción Total (Scorched Earth Teardown) y Guardia Offline:**
  - **Archivo:** `frontend/src/stores/auth.ts`
  - **Acción:** CREAR `destroyAllLocalData()` (reseteo en RAM de stores + `localStorage.clear()` + `sessionStorage.clear()` + `IndexedDB.clear()` + `systemCacheManager.reset()`). Proteger `logout()` con guardia offline y cola de pendientes.
  - **Validación:** Suite de seguridad y guardias aprobada.

- [x] **Paso 7 — Capa UI (Sidebar de Perfil): Bloqueo Silencioso del Cierre:**
  - **Archivo:** `frontend/src/components/UserProfileSidebar.vue`
  - **Acción:** MODIFICAR — Deshabilitar botón "Cerrar Sesión" si `!isOnline || pendingSyncCount > 0`.
  - **Validación:** Compilación de componentes validada.

- [x] **Paso 8 — Capa Router y Vistas de Autenticación:** Estabilizar confirmación, sala de espera y registro.
  - **Archivos:**
    - `frontend/src/router/index.ts`
    - `frontend/src/views/RegisterStoreView.vue`
    - `frontend/src/views/auth/WaitingRoomView.vue`
    - `frontend/src/views/auth/AuthCallbackView.vue`
    - `frontend/src/views/DashboardView.vue`
    - `frontend/src/views/DailyWaitingRoom.vue`
    - `frontend/src/views/GatekeeperPending.vue`
  - **Acción:** MODIFICAR — Añadir alias `/dashboard`, propagar email, validar formato y coordinar logout sin duplicación.
  - **Validación:** `npm run build` y vitest aprobados al 100%.

---

## 4. Evidencia de Verificación Técnica (Regla 5)

1. **Pruebas Unitarias Automatizadas (Vitest):**
   - 22 archivos de prueba ejecutados.
   - 146 tests aprobados (`146 passed (146)`).
   - Cero fallos de regresión en stores, repositorios y componentes.
2. **Compilación de Producción (Vite):**
   - `✓ built in 6.73s`
   - Bundling de PWA y Service Worker generados correctamente (`dist/sw.js`).
3. **Escáner Estructural de Impacto (Regla 10):**
   - Ejecutado `node scripts/scan-impact.mjs logout syncQueue`.
   - Cero violaciones a los Muros 1, 2 y 3.
