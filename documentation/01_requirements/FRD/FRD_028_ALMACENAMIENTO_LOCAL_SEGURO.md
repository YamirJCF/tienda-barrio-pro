# FRD-028: Almacenamiento Local Seguro y Caché de Aplicación

> **Versión:** 2.0 (Consolidada con Gobernanza de Memoria y Concurrencia)  
> **Fecha:** 2026-10-26  
> **Estado:** 🟢 Aprobado  
> **Módulo:** 028 — Almacenamiento Local Seguro

### Nombre de la Funcionalidad
Gobernanza de Almacenamiento Local (Caché en Memoria, Persistencia Offline, Tokens y Concurrencia).

#### Descripción
El sistema POS (Single Page Application) opera en un entorno de tienda física multi-dispositivo (hasta 6 terminales concurrentes: 1 Administrador y 5 Empleados) con conectividad variable. Este documento establece los límites arquitectónicos y las reglas de negocio para:
1. Erradicar consultas redundantes a la base de datos sin comprometer la frescura de la información en pantalla.
2. Definir la tecnología de almacenamiento adecuada para cada dato (Memoria RAM, IndexedDB y LocalStorage).
3. Gobernar la jerarquía de invalidación ante eventos de negocio y fluctuaciones de red.
4. Bloquear de forma definitiva colisiones de escritura concurrentes entre cuentas mediante blindaje por vectores independientes (Escudo 1 y Escudo 2), protegiendo la integridad del dato y auditando anomalías en seguridad.

---

## Reglas de Negocio

### RN-CACHE-01: Prohibición de Almacenamiento Masivo en LocalStorage
Debido al límite físico de ~5MB impuesto por los navegadores modernos y la naturaleza síncrona y bloqueante de su API:
- **DEBE** prohibirse el uso de `localStorage` para almacenar colecciones (Arrays/Listas) de entidades de dominio (Productos, Clientes, Ventas, Movimientos, Gastos).
- Todas las colecciones de datos masivas que requieran persistencia local para contingencia offline DEBEN utilizar `IndexedDB` (ej. `tienda-cache-db`, `tienda-sync-db`).
- `localStorage` queda reservado **EXCLUSIVAMENTE** para:
  1. Tokens de Autenticación y Sesión (JWT emitidos por Supabase GoTrue).
  2. Variables escalares de estado de UI (ej. `tienda-store-status`).
  3. Preferencias cosméticas de UI (ej. Tema oscuro, Preferencias de densidad).

### RN-CACHE-02: Caché Optimista vs Autoridad del Backend (Tampering Resistance)
Cualquier dato guardado localmente en el navegador es inherentemente inseguro e inspeccionable vía DevTools.
- El estado local en memoria o almacenamiento es estrictamente **Cosmético y Optimista**. Su único fin es acelerar la renderización de la UI.
- El Frontend **TIENE PROHIBIDO** utilizar datos del cliente o memoria como autoridad para cálculos financieros, determinación de stock legal o validación de saldos (*POL-FIN-01*).
- Toda escritura en base de datos (RPC) DEBE ser validada soberanamente por PostgreSQL en Supabase. Si un usuario manipula su almacenamiento local (ej. alterando `is_admin` o forzando `status = 'open'`), el servidor DEBE rechazar la petición (`403` / `P0001`), tras lo cual el cliente DEBE auto-corregirse purgando el dato manipulado.

### RN-CACHE-03: Supervivencia de Datos Críticos ante Cierres de Sesión
- El cierre de sesión (`logout`) DEBE purgar los tokens de autenticación JWT y las memorias volátiles de catálogo.
- El cierre de sesión **TIENE PROHIBIDO** purgar colas operativas de transacciones pendientes (`sync_queue`, `dead_letter_queue` en `IndexedDB`), ya que esto destruiría hechos económicos reales ya cobrados a clientes físicos (*POL-AUD-01*).

### RN-CACHE-04: Resiliencia ante Corrupción de Caché Local (Anti-WSOD)
Si el caché local se corrompe por cierres intempestivos, caídas de energía o cambios de esquema:
- El sistema DEBE interceptar los fallos de deserialización mediante envoltorios seguros (`safeParseJson`).
- Ante una corrupción en colecciones de lectura, el sistema DEBE purgar atómicamente la clave afectada en `localStorage` o `IndexedDB` y gatillar una re-descarga silenciosa desde Supabase, impidiendo pantallas blancas de error (White Screen of Death).

### RN-CACHE-05: Gobernanza del Caché Operacional en Memoria (RAM)
Para erradicar consultas redundantes en `onMounted` y navegaciones entre pantallas en modo online:
1. **Motor Centralizado Singleton:** Todo acceso de lectura en stores debe canalizarse a través de un gestor global en memoria (`SystemCacheManager`).
2. **Estrategia Stale-While-Revalidate (SWR):** Si el dato en memoria no ha expirado su TTL, se retorna de inmediato en 0ms. Si ha expirado, se sirve el dato stale para no bloquear la interfaz y se revalida asíncronamente en segundo plano.
3. **Deduplicación de Peticiones en Vuelo (In-Flight Deduplication):** Si múltiples componentes solicitan la misma clave mientras una petición ya viaja por la red, comparten la misma promesa singleton, emitiendo una única consulta a la base de datos.
4. **Acotamiento de Memoria (LRU Bounded):** Las consultas con filtros dinámicos y paginaciones (ej. reportes, movimientos Kardex, lotes) se almacenan bajo claves compuestas (`namespace:paramsHash`) con un límite estricto de máximo 10 entradas por namespace, aplicando desalojo LRU (Least Recently Used) al saturarse.
5. **Jerarquía de Frescura e Invalidación:**
   $$\text{Evento Local de Mutación} > \text{Reconexión de Red} > \text{Evento Supabase Realtime} > \text{Expiración TTL}$$
6. **Protección contra Carreras de Invalidación:** Cada entrada de caché mantiene un contador de generación (`generation`). Si una clave se invalida localmente mientras hay una petición en vuelo, la respuesta de la petición vieja es descartada al resolverse si su generación es inferior a la actual.

### RN-CACHE-06: Conectividad y Reconexión como Evento de Invalidación
En un entorno con hasta 6 dispositivos operando en simultáneo:
- Si el canal de Supabase Realtime o el WebSocket se desconecta, todos los datos en memoria dependientes de fuentes remotas pasan a estado **"Stale / Desconocido"**.
- Al restablecerse la conectividad, el sistema DEBE disparar un evento global de revalidación silenciosa (`invalidateAll()`), sincronizando el estado con la base de datos sin requerir que el usuario recargue el navegador (`F5`).

### RN-CACHE-07: Política de Arranque en Frío y Recarga de Página
- Los datos hidratados desde persistencia local (`pinia-plugin-persistedstate` o `IndexedDB`) al iniciar la aplicación carecen de vigencia garantizada.
- Al arrancar en frío, el sistema DEBE inicializar dichos datos con `lastFetchedAt = 0`. Esto permite mostrarlos instantáneamente para evitar pantallas vacías, pero fuerza una revalidación asíncrona inmediata contra PostgreSQL en el primer acceso.

### RN-CACHE-08: Blindaje de Integridad en Mutaciones Concurrentes (Escudos 1 y 2)
Queda estrictamente prohibida la política de "El Último Escribe Gana" (*Last-Write-Wins*) y la sobrescritura ciega entre cuentas o terminales concurrentes.
1. **Desacoplamiento Estricto por Vectores de Datos:**
   - **Vector Catálogo/Comercial:** Nombre, Precio, Costo, PLU, Categoría, Stock Mínimo.
   - **Vector Logístico/Transaccional:** Entradas, Salidas, Ventas POS, Mermas y Ajustes de Stock.
   - La edición de atributos del Vector Catálogo **NUNCA** puede enviar ni actualizar columnas del Vector Logístico (`current_stock`).
2. **Escudo 1 — Cooldown Mínimo por Vector (`< 3 segundos`):**
   - El sistema rechaza cualquier mutación sobre el mismo vector de datos si transcurrieron menos de 3 segundos desde la última modificación registrada en su historial oficial (`audit_precios` para precios/catálogo; `inventory_movements` para stock físico).
3. **Escudo 2 — Sello de Estado Base por Vector (`Vector Snapshot Seal`):**
   - Toda solicitud de edición de catálogo debe enviar el valor previo conocido que el usuario leyó al abrir la pantalla (`expected_old_price`, `expected_old_cost`, `expected_name`).
   - El servidor evalúa la mutación bajo bloqueo de fila pesimista (`SELECT ... FOR UPDATE`). Si el dato actual en la base de datos difiere del valor esperado base, la transacción se aborta.
   - **Invariante de Desacople:** El sello del Vector Catálogo **TIENE PROHIBIDO** evaluar `products.updated_at` o `current_stock`, puesto que el trigger de ventas del POS muta esas columnas en cada venta sin alterar los datos comerciales.
4. **Bloqueo Definitivo y Registro en Auditoría:**
   - La detección de una colisión concurrente se considera un error humano crítico o sospecha de alteración (*tampering*). El servidor aborta el `UPDATE` y asienta el incidente en `public.audit_seguridad` con `event_type = 'CONCURRENT_MUTATION_BLOCKED'`.
   - En el cliente, la mutación se bloquea de forma definitiva (sin opción de sobrescritura manual), se notifica al usuario y se purga el caché local para cargar el valor real vigente.
5. **Idempotencia de Red Lenta:**
   - Si una petición idéntica del mismo usuario (`actor_id`) con el mismo valor meta llega antes de 10 segundos tras un cambio ya aplicado exitosamente (reintento por parpadeo de red), el backend retorna éxito idempotente (`ALREADY_APPLIED_IDEMPOTENT`) sin duplicar registros ni registrar falsas alarmas de seguridad.

---

## Casos de Uso

**Caso A: Manipulación de Estado de Caja por Usuario Malicioso**
- **Actor:** Empleado.
- **Precondición:** La caja está cerrada.
- **Flujo:** El empleado altera `localStorage` con DevTools a `OPEN`. Al intentar registrar un gasto, el RPC de Supabase valida contra `cash_sessions`, aborta la transacción y el cliente purga su caché local revirtiendo a `CLOSED`.

**Caso B: Crecimiento Masivo del Catálogo**
- **Actor:** Sistema.
- **Flujo:** Catálogo de 10,000 productos se almacena en `IndexedDB` (`tienda-cache-db`). Las búsquedas en el POS operan en O(1) sin saturar los 5MB de `localStorage`.

**Caso C: Intento de Edición Concurrente de Precio entre Dos Empleados (Escudo 2)**
- **Actores:** Admin (Terminal 1) y Empleado (Terminal 2).
- **Precondición:** Ambos abrieron la ficha del producto "Aceite 1L" cuando costaba $10.000.
- **Flujo:**
  1. Terminal 1 sube el precio a $12.000 a las 10:00:10. Servidor valida y aplica.
  2. Terminal 2, con la ficha desactualizada abierta, intenta guardar $11.000 a las 10:00:45 enviando `expected_old_price = 10000`.
  3. El servidor compara bajo `FOR UPDATE`: precio en BD ($12.000) $\neq$ esperado ($10.000).
  4. El servidor cancela la actualización, inserta en `audit_seguridad` (`CONCURRENT_MUTATION_BLOCKED`) y retorna error de concurrencia.
  5. Terminal 2 cierra el modal, muestra alerta de colisión concurrente y purga su caché forzando la visualización de los $12.000$.

**Caso D: Cajero Vende en POS mientras Admin Actualiza Precio**
- **Actores:** Cajero (Terminal 1) y Admin (Terminal 2).
- **Flujo:**
  1. Admin abre la ficha del producto para subir precio a $12.500.
  2. Cajero vende 2 unidades en POS. El stock baja de 20 a 18 y el trigger `trg_products_updated` cambia `products.updated_at`.
  3. Admin presiona "Guardar" 1 segundo después.
  4. El RPC de catálogo evalúa exclusivamente el Vector Precio contra `audit_precios` y los valores esperados de catálogo, ignorando `current_stock` y `updated_at`.
  5. La mutación de precio se aprueba exitosamente a $12.500 y el stock físico de 18 unidades del cajero se preserva intacto.

---

## Criterios de Aceptación
- [ ] **CA-CACHE-01:** Las colecciones de dominio se almacenan en `IndexedDB` (o memoria volátil RAM), nunca en `localStorage`.
- [ ] **CA-CACHE-02:** Alterar manualmente variables de estado en `localStorage` resulta en rechazo soberano del servidor y purga inmediata en el cliente.
- [ ] **CA-CACHE-03:** El log-out purga credenciales y caché de lectura pero preserva inmutables las colas offline en `IndexedDB`.
- [ ] **CA-CACHE-04:** Peticiones concurrentes idénticas hacia Supabase se deduplican en vuelo emitiendo una sola solicitud de red.
- [ ] **CA-CACHE-05:** La reconexión tras una pérdida de red gatilla una invalidación y revalidación silenciosa global del caché operacional.
- [ ] **CA-CACHE-06:** La actualización de metadatos o precio de un producto no envía ni sobreescribe `current_stock` en la base de datos.
- [ ] **CA-CACHE-07:** Intentos de mutación sobre registros desactualizados son bloqueados definitivamente por el servidor y registrados en `audit_seguridad`.
