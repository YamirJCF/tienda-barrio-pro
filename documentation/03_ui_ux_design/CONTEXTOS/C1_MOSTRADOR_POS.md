# Contexto C1 — Mostrador (POS & Cobro)

> **Estado:** Cartografía Ola 1 (`Lote 1B` — solo documentación)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-001`)  
> **Restricción de conectividad:** **Híbrida acotada** — único contexto con cola offline (`syncQueue`) para ventas en efectivo/transferencia; **Fiado y Reembolsos exigen conexión online obligatoria** ([`PRODUCT.md`](../../../PRODUCT.md#L38)).

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Atender en tiempo real la **Top Task #1** (cobrar venta en `< 3` toques en mostrador), administrando el carrito, el teclado numérico/calculadora de peso, los cobros en efectivo/transferencia/mixtos/fiado, el retiro personal (`consumo_personal` a `$0`), las devoluciones compensatorias (`RefundModal`) y la cola de sincronización offline (`syncQueue`).

### 1.2 Rutas Actuales vs. Objetivo Canónico

| Ruta | Vista (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Regla de Shell y Destino Objetivo |
|---|---|---|---|---|
| `/pos` | [`POSView.vue`](../../../frontend/src/views/POSView.vue) | `canonica` | `A` (Alta Velocidad) | **Se mantiene única ruta canónica.** Conserva **excepción arquitectónica sin `BottomNav`** para proteger el espacio vertical del teclado táctil y la velocidad de cobro en mostrador. |

### 1.3 Matriz de Permisos (`SDD-003-01`)

| Capacidad / Acción | `Admin` | Empleado con permiso | Empleado sin permiso | Evidencia en Código |
|---|---|---|---|---|
| Vender en POS (`canSell`) | ✅ | ✅ | ❌ *(bloqueo `blockingState`)* | [`POSView.vue`](../../../frontend/src/views/POSView.vue#L68-L82) |
| Vender a crédito / Fiado (`canFiar`) | ✅ | ✅ | ❌ *(oculto en cobro)* | [`POSView.vue`](../../../frontend/src/views/POSView.vue#L69), [`CheckoutModal.vue`](../../../frontend/src/components/sales/CheckoutModal.vue#L77-L79) |
| Registrar reembolso / anulación (`canManageRefunds`) | ✅ | ✅ | ❌ *(botón oculto)* | [`POSView.vue`](../../../frontend/src/views/POSView.vue#L70) (`authStore.canManageRefunds \|\| authStore.isAdmin`) |

---

## §2. Matriz ORCA (Objetos, Relaciones, CTAs y Densidad)

### 2.1 Objetos Canónicos y Relaciones `1:N`

```text
Venta / Ticket (1) ──< Línea de Carrito (N) ──> Producto / Lote FIFO [Contexto C3]
               │
               ├──< Pago / Cobro (N) [Efectivo | Nequi | Llave Bre-B | Fiado]
               │
               ├──< Reembolso (N) [compensatorio — RefundModal]
               │
               ├──> Turno de Caja [Contexto C2] (prerequisito abierto)
               └──> Cliente [Contexto C4] (enlace bidireccional ?checkoutClientId=...)
```

### 2.2 Matriz Global de CTAs (`Verbo × Objeto`)

| Verbo + Objeto | Rol autorizado | Red | Hogar Actual | Hogar Canónico Objetivo |
|---|---|---|---|---|
| **Agregar `Línea de Carrito`** | `canSell` | Online / Offline (`syncQueue`) | `POSView.vue` (PLU, búsqueda, peso) | `/pos` (Arquetipo `A`, `< 3` toques) |
| **Cobrar `Venta / Ticket`** | `canSell` *(Fiado exige `canFiar`)* | Online / Offline *(Fiado solo Online)* | [`CheckoutModal.vue`](../../../frontend/src/components/sales/CheckoutModal.vue) (869L) | `/pos` → Modal de Cobro Comercial (separado de `Retiro ($0)`) |
| **Registrar `Retiro Personal ($0)`** | `canSell` | Online | Mezclado en `activeMethods` (`CheckoutModal.vue` L85-92) | Flujo separado en POS (`consumo_personal` `$0` fuera de medios de pago) |
| **Consultar / Abonar `Cliente` desde POS** | `canFiar` | Online | Salto a `/clients/:id?from=pos` con retorno `?checkoutClientId=...` | Continuidad bidireccional `/pos` ↔ `/clients/:id` |
| **Registrar `Reembolso`** | `canManageRefunds` / `Admin` | Online | [`RefundModal.vue`](../../../frontend/src/components/sales/RefundModal.vue) (341L) | `/pos` → Hoja Transaccional Arquetipo `D` con capa FIFO visible |

### 2.3 Densidad de Atributos (Mostrador vs. Cobro)

| Superficie | Atributos Visibles | Regla de Densidad |
|---|---|---|
| **Lista del Ticket (`POSView.vue`)** | Cantidad (`xN`), Nombre producto, Precio unitario, Subtotal (`tabular-nums`), Total general del servidor. | Cero columnas extra ni metadatos administrativos en fila de ticket. |
| **Modal de Cobro (`CheckoutModal.vue`)** | Total a cobrar, Saldo restante a fiar (en mixto), Cupo disponible del cliente (Read Model), Monto recibido y Cambio. | Solo medios comerciales; el cupo se valida en vivo contra el saldo pendiente a fiar. |

---

## §3. Breadboards (Flujo Actual vs. Flujo Objetivo)

### 3.1 Breadboard Actual (Top Task #1 y Fricciones Detectadas)

```text
[/pos (POSView.vue)]
  ├── Pre-check blockingState (L74-100):
  │     └── Si inventoryStore.totalProducts === 0 ──> muestra "Sin Inventario" (incluso ante fallo de red)
  ├── Header Ticket:
  │     └── Botón [Clear Ticket] (L378-386) ──> cartStore.clearCart() en 1 toque sin confirmación/Undo
  └── Botón [Cobrar] ──> [CheckoutModal.vue (869 líneas)]
                           ├── Lista activeMethods incluye "Retiro ($0)" junto a Efectivo/Nequi/Fiado (L85-92)
                           ├── Fiado: isCreditLimitExceeded evalúa props.total completo (L69-73)
                           └── canComplete retorna true con solo !!selectedFiadoClient.value (L135-137)

[Botón Reembolso] ──> [RefundModal.vue (341 líneas)]
                        └── Muestra vendido / disponible / stock actual (L66-68), SIN capa FIFO de reingreso
```

### 3.2 Breadboard Objetivo (< 3 Toques + Resiliencia Offline/Contable)

```text
[Lugar Único: /pos (Arquetipo A)]
  ├── Pre-check real: Permiso canSell -> Caja abierta (/cash-control) -> Error de carga (Banner N3 Reintentar) -> Inventario vacío real
  ├── Captura rápida (1 toque catálogo / PLU / Peso) ──> Ticket (totales desde store/servidor sin cálculo ad-hoc)
  ├── Clear Ticket: botón con confirmación ligera o barra Undo N2 (5s)
  ├── Acción [Cobrar] (Top Task #1):
  │     └──> [CheckoutModal Comercial]
  │            ├── Medios comerciales: Efectivo | Nequi | Llave Bre-B | Fiado (online obligatorio)
  │            ├── Si Fiado o Mixto con Fiado:
  │            │     ├── Read Model: Cupo total | Deuda actual | Saldo a fiar | Nuevo saldo previsto
  │            │     └── Bloquea canComplete si (nuevoSaldo > cupo) O si está offline
  │            └── [Confirmar Cobro] (lock) ──> RPC (o syncQueue si efectivo/transf. offline) ──> Toast N2
  ├── Acción secundaria [Retiro Personal ($0)]: acceso dedicado fuera de medios comerciales
  └── Acción [Reembolsar (Arquetipo D)]: muestra capa FIFO de reingreso + confirmación compensatoria
```

---

## §4. Matriz de Señalización (`N1–N5`)

| Nivel | Evento / Condición en `C1` | Superficie y Comportamiento | Audiencia |
|---|---|---|---|
| **N1 — Inline** | Exceso de cupo sobre saldo restante a fiar, monto recibido insuficiente, bloqueo de Fiado en modo offline, cantidad de reembolso inválida | Mensaje persistente dentro de `CheckoutModal` o `RefundModal`; deshabilita botón confirmar (`canComplete`). | `canSell`, `canFiar`, `canManageRefunds` |
| **N2 — Toast Efímero** | Venta completada, venta encolada en modo offline, reembolso aplicado, acción Undo tras limpiar ticket | **Solo** `ToastNotification.vue`. | Actor en mostrador |
| **N3 — Banner Persistente** | 1) Modo offline activo con contador pendiente en `syncQueue`.<br>2) Error real al cargar inventario/catálogo en POS con botón **Reintentar** (diferenciado de inventario vacío). | Franja persistente en cabecera POS sin ocultar errores de red. | Todos |
| **N4 — Bandeja `/notifications`** | Fallo persistente al sincronizar cola offline (`syncQueue`) o reembolso relevante auditado | Notificación con deep-link hacia `/pos` o `/reports?tab=history` (Admin). | `Admin` / Cajero |
| **N5 — Compuerta (`Arquetipo F`)** | `blockingState`: sin permiso `canSell`, caja cerrada (`-> /cash-control`), inventario vacío confirmado | Overlay bloqueante con causa exacta y una sola salida accionable (`BaseModal` si aplica confirmación destructiva). | Actor en mostrador |

---

## §5. Hotspots Contables y de Dominio Verificados para Ola 2 (`FRD/SDD/SQL` antes de UI)

| ID | Severidad | Evidencia Verificada en Código | Brecha Contable / UX | Acción Requerida en Ola 2 |
|---|---|---|---|---|
| **C1-H1** | 🟠 **ALTO** | [`CheckoutModal.vue`](../../../frontend/src/components/sales/CheckoutModal.vue#L69-L73) y L131-139 | `isCreditLimitExceeded` suma `props.total` completo en lugar del **saldo restante a fiar** en pagos mixtos, y `canComplete` (L135-137) devuelve `true` con `!!selectedFiadoClient.value`, sin bloquear exceso de cupo ni Fiado offline. | Corregir ecuación contra saldo pendiente a fiar (`mixto`), bloquear exceso de cupo en `canComplete` y exigir estado online para Fiado. |
| **C1-H2** | 🟠 **ALTO** | [`CheckoutModal.vue`](../../../frontend/src/components/sales/CheckoutModal.vue#L85-L92) (869 líneas); [`POSView.vue`](../../../frontend/src/views/POSView.vue#L410) | `CheckoutModal.vue` mezcla `Retiro ($0)` (`consumo_personal`) dentro de `activeMethods` como si fuera medio de pago comercial; `POSView.vue` (L410) mantiene fallback multiplicativo en plantilla (`item.subtotal \|\| item.price.times(item.quantity)`). | Extraer `Retiro ($0)` fuera de los medios de pago comerciales, modularizar `CheckoutModal` y asegurar `item.subtotal` siempre calculado por store/RPC. |
| **C1-H3** | 🟡 **MEDIO** | [`POSView.vue`](../../../frontend/src/views/POSView.vue#L65-L98) | `blockingState` evalúa `inventoryStore.totalProducts === 0` para renderizar `"Sin Inventario"`, disfrazando un error de carga/red como inventario vacío (riesgo de fallo silencioso, Regla 3). | Separar estado `inventoryLoadError` (Banner `N3` con Reintentar) de inventario realmente vacío confirmado por servidor. |
| **C1-H4** | 🟡 **MEDIO** | [`POSView.vue`](../../../frontend/src/views/POSView.vue#L378-L386); [`RefundModal.vue`](../../../frontend/src/components/sales/RefundModal.vue#L66-L103) | Botón `Clear Ticket` (`Trash2`) vacía todo el carrito en 1 toque sin confirmación ni opción Undo; `RefundModal.vue` no expone la capa FIFO de reingreso al procesar la devolución. | Agregar confirmación ligera o Undo (`N2`) en `Clear Ticket` y mostrar lote/política FIFO de reingreso en `RefundModal` (alineado con `SDD/SQL`). |
