# FRD-028: Almacenamiento Local Seguro y Caché de Aplicación

### Nombre de la Funcionalidad
Gobernanza de Almacenamiento Local (Cache, Tokens y Estado UI).

#### Descripción
El sistema POS (Single Page Application) depende fuertemente del navegador para almacenar el token de sesión (JWT), estados operativos optimistas (ej. si la caja está abierta) y caché de datos para operar rápidamente. Este documento establece los límites arquitectónicos para evitar vulnerabilidades de manipulación (Tampering), prevenir colapsos por cuota de memoria (QuotaExceededError) y definir qué tecnología de almacenamiento se debe usar para cada tipo de dato, respetando el Contrato de Interfaz donde el Backend es la única autoridad.

---

## Reglas de Negocio

### RN-CACHE-01: Prohibición de Almacenamiento Masivo en LocalStorage
Debido al límite físico de ~5MB impuesto por los navegadores modernos, `localStorage` y `sessionStorage` son altamente volátiles para sistemas escalables.
- **DEBE** prohibirse el uso de `localStorage` para almacenar colecciones (Arrays/Listas) de entidades de dominio (Productos, Clientes, Ventas, Movimientos, Gastos).
- Todas las colecciones de datos masivas que requieran caché local DEBEN utilizar `IndexedDB` (ej. vía adaptadores IDB).
- `localStorage` queda reservado **EXCLUSIVAMENTE** para:
  1. Tokens de Autenticación y Sesión (JWT).
  2. Variables escalares de estado (ej. `tienda-store-status`).
  3. Configuraciones ligeras de UI (ej. Tema oscuro, Preferencias de vista).

### RN-CACHE-02: Caché Optimista vs Autoridad del Backend
Cualquier dato guardado localmente es inherentemente inseguro, ya que puede ser modificado por el usuario mediante las Herramientas de Desarrollador (DevTools).
- El estado local (ej. bandera de `is_admin`, `caja_abierta`) se considera **Optimista**. Su único propósito es acelerar el renderizado de la UI (ej. mostrar u ocultar el botón "Pagar").
- El Frontend **NO PUEDE** utilizar el estado local como prueba de autoridad para cálculos financieros. (Apoya a *POL-FIN-01*).
- Toda escritura en base de datos (RPC) DEBE ser validada nuevamente por el servidor (Supabase RLS). Si un usuario inyecta `{"isAdmin": true}` en su `localStorage`, la UI podría mostrar un botón de administrador, pero el servidor DEBE rechazar la petición con un error 403, tras lo cual el Frontend DEBE auto-corregir su caché purgando el estado manipulado.

### RN-CACHE-03: Supervivencia de Datos Críticos ante Cierres de Sesión
El sistema actual utiliza comandos agresivos (`localStorage.clear()`) al cerrar sesión.
- El cierre de sesión DEBE purgar los tokens de autenticación y los datos sensibles (clientes, inventario en caché).
- El cierre de sesión **NO DEBE** purgar colas operativas pendientes (`sync_queue`, `dead_letter_queue` en `IndexedDB`), ya que esto implicaría pérdida de datos históricos de ventas no sincronizadas, violando la *POL-AUD-01 (Inmutabilidad Histórica)*.

### RN-CACHE-04: Resiliencia ante Corrupción de Caché Local
Si el caché local se corrompe (ej. un JSON malformado o un schema desactualizado por una nueva versión de la app):
- El sistema DEBE interceptar los errores de parseo (ej. `JSON.parse` failures).
- Ante una corrupción del caché de lectura (como el catálogo de productos o configuración), el sistema DEBE purgar automáticamente la clave afectada de `localStorage` o `IndexedDB` y forzar una re-descarga silenciosa desde el Backend, sin bloquear al usuario con una "Pantalla Blanca de la Muerte" (White Screen of Death).

---

## Casos de Uso

**Caso A: Manipulación de Estado de Caja por Usuario Malicioso**
- **Actor:** Empleado.
- **Precondición:** La caja está cerrada.
- **Flujo Principal:**
  1. El empleado abre las DevTools y cambia `tienda-store-status` a `{"status": "OPEN"}` en `localStorage`.
  2. La UI lee el nuevo estado y habilita el botón "Registrar Gasto".
  3. El empleado intenta registrar un gasto.
  4. El Frontend envía la petición al Backend.
  5. El Backend (RPC Supabase) detecta que la caja real está cerrada y rechaza la transacción.
  6. El Frontend recibe el error, revierte el `tienda-store-status` local a `CLOSED` y oculta el botón nuevamente, notificando: "Error: La caja está cerrada".

**Caso B: Crecimiento Masivo del Catálogo**
- **Actor:** Sistema.
- **Flujo Principal:**
  1. La tienda registra su producto número 10,000.
  2. El sistema guarda la caché local del catálogo en `IndexedDB`.
  3. El almacenamiento local de la app alcanza los 50MB sin generar excepciones de cuota, permitiendo al POS seguir funcionando fluidamente en búsquedas.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| `supabaseAdapter.ts` | **(Refactor Requerido):** El adaptador genérico actual usa `localStorageAdapter` como fallback automático para colecciones. DEBE migrarse para usar `IndexedDB` o lanzar una excepción de límite para entidades de dominio (Clientes, Gastos, etc). |
| `App.vue` | Modificar el logout para purgar selectivamente (`removeItem` del auth y caches de dominio) en lugar de un `clear()` destructivo ciego si llega a afectar colas futuras. |
| `useDataIntegrity.ts` | Ya implementa la purga ante corrupción (RN-CACHE-04), pero debe expandirse a las nuevas llaves de IDB. |

---

## Criterios de Aceptación
- [ ] **CA-CACHE-01:** Las colecciones de "Clientes" y "Gastos" se almacenan en `IndexedDB` (o memoria volátil), no en `localStorage`.
- [ ] **CA-CACHE-02:** Alterar manualmente una variable crítica en `localStorage` (como los permisos del usuario) resulta en un rechazo del servidor y la restauración inmediata del valor original en el cliente en la siguiente petición.
- [ ] **CA-CACHE-03:** El log-out purga la sesión pero mantiene intactas las colas locales de transacciones en `IndexedDB`.
