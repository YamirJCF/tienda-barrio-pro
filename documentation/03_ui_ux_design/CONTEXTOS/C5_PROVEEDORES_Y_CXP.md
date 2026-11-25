# Contexto C5 — Abastecimiento (Proveedores & CxP)

> **Estado:** Consolidado en Ola 2 (`UX-ADR-005`, `WO-OLA2-C5-001`)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-005`)  
> **Restricción de conectividad:** **Online obligatorio** para todas las operaciones ([`PRODUCT.md`](../../../PRODUCT.md#L38)).  
> **Regla de dominio (`FRD-003-ILC`):** Independencia logística-contable respecto a `C3` — una recepción de mercancía en `/stock-entry` puede vincular proveedor sin forzar pago inmediato, y una factura CxP puede abonarse desde un canal de caja o mediante pago externo (`$0` en caja).

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Centralizar el directorio de proveedores, la frecuencia de visitas/entrega, el registro de facturas por pagar (`CxP`) y los abonos contra saldo de factura o canales de caja disponibles.

### 1.2 Rutas Actuales vs. Objetivo Canónico

| Ruta | Vista (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Estado Consolidado (`UX-ADR-005`) |
|---|---|---|---|---|
| `/suppliers` *(alias `/payables`)* | [`SuppliersView.vue`](../../../frontend/src/views/SuppliersView.vue) | `canonica` | `B/D` (Workspace + Hoja Transaccional) | **Única ruta canónica:** Workspace **Proveedores y Cuentas por Pagar** con 2 pestañas (`?tab=suppliers\|payables`), KPIs/FK en servidor y `/payables` como alias compatible. `PayablesView.vue` eliminada. |

### 1.3 Matriz de Permisos (`SDD-003-01`)

| Capacidad / Acción | `Admin` | Empleado (cualquier permiso) | Evidencia en Código |
|---|---|---|---|
| Consultar `/suppliers` *(y alias `/payables`)* | ✅ | ❌ | Guard `!authStore.isAdmin` en [`router/index.ts`](../../../frontend/src/router/index.ts#L348-L351) |
| Crear / editar / eliminar Proveedor | ✅ | ❌ | 100% `isAdmin` |
| Crear Factura CxP / Registrar Abono (`PayInvoiceModal`) | ✅ | ❌ | 100% `isAdmin` |

---

## §2. Matriz ORCA (Objetos, Relaciones, CTAs y Densidad)

### 2.1 Objetos Canónicos y Relaciones `1:N`

```text
Proveedor (1) ──< Factura CxP (N) ──< Abono a Proveedor (N)
          │
          ├──> Recepción Masiva [Contexto C3: /stock-entry]
          └──> Canal de Caja [Contexto C2] (verificación de saldo disponible si pago es interno)
```

### 2.2 Matriz Global de CTAs (`Verbo × Objeto`)

| Verbo + Objeto | Rol autorizado | Red | Hogar Actual (Partido) | Hogar Canónico Objetivo |
|---|---|---|---|---|
| **Listar / Crear / Editar / Eliminar `Proveedor`** | `Admin` | Online | `/suppliers` (`SuppliersView.vue`, edición inconclusa, `confirm()` nativo) | `/suppliers?tab=suppliers` (CRUD completo con `BaseModal`) |
| **Listar `Factura CxP` y ver Deuda Total** | `Admin` | Online | `/payables` (`PayablesView.vue`, totales calculados en cliente) | `/suppliers?tab=payables` (KPIs calculados en backend) |
| **Crear `Factura CxP`** | `Admin` | Online | Modal inline en `PayablesView.vue` (L232-243, texto libre) | `/suppliers?tab=payables` → `BaseModal` con **selector real de `Proveedor`** |
| **Abonar `Factura CxP`** | `Admin` | Online | [`PayInvoiceModal.vue`](../../../frontend/src/components/suppliers/PayInvoiceModal.vue) | `/suppliers?tab=payables` (o detalle de proveedor) → Hoja Transaccional Arquetipo `D` (`BaseModal`) |

### 2.3 Densidad de Atributos (Tarjetas y Modal de Abono)

| Superficie | Atributos Visibles | Regla de Densidad |
|---|---|---|
| **Tarjeta `Factura CxP`** | Proveedor, Número de factura (`F-...`), Estado (`vencida` / `pendiente` / `pagada`), Monto original y Saldo pendiente (`tabular-nums`). | Sin `border-l-[6px]` ni cálculos en cliente (`invoice.total_amount - invoice.amount_paid` debe venir calculado por backend/store). |
| **Tarjeta `Proveedor`** | Nombre (+ badge `Por defecto`), Día de entrega, Frecuencia y Lead Time, Deuda CxP asociada. | Permite saltar directo a sus facturas CxP o editar en `BaseModal`. |

---

## §3. Breadboards (Flujo Actual vs. Flujo Objetivo)

### 3.1 Breadboard Actual (2 Rutas Desconectadas + Deuda Técnica)

```text
[/suppliers (SuppliersView.vue)]
  ├── Header / navegación separada de /payables
  ├── onMounted: si falla fetchSuppliers -> sin manejo visual de error (Regla 3)
  ├── Botón Editar: importa Pencil (L15) y declara editingSupplierId (L43), sin flujo de edición en UI
  └── Botón Eliminar ──> window.confirm(...) nativo (L105)

[/payables (PayablesView.vue)]
  ├── Botón regresar ──> router.push('/suppliers') (L340, "Volver a Proveedores")
  ├── KPIs totalDebt y totalOverdue: .reduce() en cliente sobre página parcial de 50 facturas (L345-355)
  ├── Modal Crear Factura: input texto libre newInvoiceForm.supplierName (L232-243)
  └── Botón Abonar ──> [PayInvoiceModal.vue]
                         ├── Usa vue-toastification (L166)
                         └── Banner border-l-4 + emojis ℹ️ / 🚫 (L20-60)
```

### 3.2 Breadboard Objetivo (Workspace Único `/suppliers`)

```text
[Lugar Único: /suppliers (Admin Only — 2 Pestañas)]
  ├── Tab 1 [Cuentas por Pagar (CxP)]:
  │     ├── Read Model servidor: Deuda total CxP + Total vencido (calculados en backend, tabular-nums)
  │     ├── Filtros por estado / proveedor + lista con saldo pendiente del servidor
  │     ├── Acción [+ Nueva Factura] ──> [BaseModal] con selector relacional de Proveedor (FK)
  │     └── Acción [Abonar] sobre Factura ──> [PayInvoiceModal (BaseModal Arquetipo D)]
  │                                            ├── Read Model: Saldo pendiente + saldo disponible por canal [C2]
  │                                            ├── Si caja cerrada/+24h: Banner N3 limpio (sin emoji/border-l-4) habilita "Pago externo ($0)"
  │                                            ├── Validación N1 inline: exceso de saldo o sobregiro de canal
  │                                            └── [Confirmar Abono] (lock) ──> RPC ──> Toast N2 único
  │
  └── Tab 2 [Proveedores]:
        ├── Estado de carga (BaseListSkeleton) y error (Banner N3 con Reintentar)
        ├── Acción [Crear / Editar Proveedor] ──> [BaseModal] completo
        └── Acción [Eliminar Proveedor] ──> [BaseModal confirmación N5] (cero confirm() nativo)
```

---

## §4. Matriz de Señalización (`N1–N5`)

| Nivel | Evento / Condición en `C5` | Superficie y Comportamiento | Audiencia |
|---|---|---|---|
| **N1 — Inline** | Abono supera saldo pendiente (`amountExceedsPending`), saldo insuficiente en canal seleccionado sin sobregiros (`amountExceedsChannel`), campos obligatorios en factura/proveedor | Alerta persistente dentro del modal con ícono Lucide (retirar emoji `🚫` de `PayInvoiceModal.vue` L60); bloquea envío. | `Admin` |
| **N2 — Toast Efímero** | Proveedor guardado/eliminado, factura CxP creada, abono a proveedor registrado | **Solo** `ToastNotification.vue` (retirar `vue-toastification` de `PayInvoiceModal.vue` L166). | `Admin` |
| **N3 — Banner Persistente** | 1) Turno de caja cerrado o `+24h` habilitando pago externo (`$0` en caja) sin `border-l-4` ni emoji `ℹ️`.<br>2) Error al cargar proveedores o facturas CxP con botón **Reintentar** (Regla 3). | Franja persistente en la pestaña o modal mientras persista la condición. | `Admin` |
| **N4 — Bandeja `/notifications`** | Factura CxP próxima a vencer o vencida | Notificación persistente para Admin con **deep-link**: `/suppliers?tab=payables&invoice=<id>`. | `Admin` |
| **N5 — Compuerta (`BaseModal`)** | Confirmación de eliminación segura de proveedor | Reemplazar `confirm()` nativo en `SuppliersView.vue` (L105) por `BaseModal` de confirmación. | `Admin` |

---

## §5. Hotspots Contables y de Dominio Cerrados en Ola 2 (`WO-OLA2-C5-001` / `UX-ADR-005`)

| ID | Severidad | Evidencia Original Auditada | Estado en Ola 2 | Resolución Implementada (`WO-OLA2-C5-001`) |
|---|---|---|---|---|
| **C5-H1** | ✅ **CERRADO** | `PayablesView.vue` *(retirada)* calculaba `totalDebt`, `totalOverdue` y `total_amount - amount_paid` con `.reduce()` sobre página parcial de 50 facturas | **Resuelto en SQL + Store + UI** | `rpc_obtener_cuentas_por_pagar` entrega `summary` global y `pending_balance` por factura; [`SupplierPayablesTab.vue`](../../../frontend/src/components/suppliers/SupplierPayablesTab.vue) y [`PayInvoiceModal.vue`](../../../frontend/src/components/suppliers/PayInvoiceModal.vue) consumen 100% la verdad del servidor. |
| **C5-H2** | ✅ **CERRADO** | `PayablesView.vue` *(retirada)* capturaba proveedor en texto libre; [`SuppliersView.vue`](../../../frontend/src/views/SuppliersView.vue) carecía de edición y manejo `N3` | **Resuelto en SQL + Workspace `/suppliers`** | Ruta `/payables` consolidada en [`SuppliersView.vue`](../../../frontend/src/views/SuppliersView.vue) (`?tab=suppliers\|payables`); `rpc_crear_factura_proveedor` prioriza FK `p_supplier_id`; [`SupplierDirectoryTab.vue`](../../../frontend/src/components/suppliers/SupplierDirectoryTab.vue) completa edición en `BaseModal` y banner `N3` fail-closed. |
| **C5-H3** | ✅ **CERRADO** | `confirm()` nativo en [`SuppliersView.vue`](../../../frontend/src/views/SuppliersView.vue) e importación de `vue-toastification` en [`PayInvoiceModal.vue`](../../../frontend/src/components/suppliers/PayInvoiceModal.vue) | **Resuelto + `baselineDebt` reducido** | Confirmación `N5` vía `BaseModal` (cero `confirm()`), notificaciones `N2` vía `useNotifications()`, `nativeDialogsAllowed` `3→2` y `legacyToastImportsAllowed` `5→4` en [`ux-manifest.json`](../ux-manifest.json). |
| **C5-H4** | ✅ **CERRADO** | `border-l-[6px]`, `border-l-4`, emojis `ℹ️`/`🚫`, modales `div.fixed` custom y ausencia de `tabular-nums` | **Alineado a `DESIGN.md`** | Tarjetas con borde `1px`, banners con íconos Lucide (`Info`, `Ban`, `AlertTriangle`), modales sobre `BaseModal`, montos en `font-mono tabular-nums` y sincronización fail-closed de caja en [`PayInvoiceModal.vue`](../../../frontend/src/components/suppliers/PayInvoiceModal.vue). |
