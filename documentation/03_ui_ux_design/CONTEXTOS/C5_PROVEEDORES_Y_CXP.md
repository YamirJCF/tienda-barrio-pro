# Contexto C5 — Abastecimiento (Proveedores & CxP)

> **Estado:** Cartografía Ola 1 (`Lote 1B` — solo documentación)  
> **Marco rector:** [`UX_ARQUITECTURA_SISTEMA.md`](../UX_ARQUITECTURA_SISTEMA.md) · [`ux-manifest.json`](../ux-manifest.json) (`UX-ADR-001`)  
> **Restricción de conectividad:** **Online obligatorio** para todas las operaciones ([`PRODUCT.md`](../../../PRODUCT.md#L38)).  
> **Regla de dominio (`FRD-003-ILC`):** Independencia logística-contable respecto a `C3` — una recepción de mercancía en `/stock-entry` puede vincular proveedor sin forzar pago inmediato, y una factura CxP puede abonarse desde un canal de caja o mediante pago externo (`$0` en caja).

---

## §1. Frontera del Contexto

### 1.1 Propósito Delimitado
Centralizar el directorio de proveedores, la frecuencia de visitas/entrega, el registro de facturas por pagar (`CxP`) y los abonos contra saldo de factura o canales de caja disponibles.

### 1.2 Rutas Actuales vs. Objetivo Canónico

| Ruta | Vista (`.vue`) | Estado en `ux-manifest.json` | Arquetipo | Destino Objetivo (Ola 2) |
|---|---|---|---|---|
| `/suppliers` | [`SuppliersView.vue`](../../../frontend/src/views/SuppliersView.vue) | `canonica` | `B` (Workspace Objeto) | **Se mantiene única ruta canónica:** Workspace **Proveedores & CxP** con **2 pestañas** (`Cuentas por Pagar \| Proveedores`). |
| `/payables` | [`PayablesView.vue`](../../../frontend/src/views/PayablesView.vue) | `consolidar` | `B` (Workspace Lista) | **Consolidar en `/suppliers?tab=payables`** (redirección limpia en Ola 2 sin romper enlaces históricos). |

### 1.3 Matriz de Permisos (`SDD-003-01`)

| Capacidad / Acción | `Admin` | Empleado (cualquier permiso) | Evidencia en Código |
|---|---|---|---|
| Consultar `/suppliers` y `/payables` | ✅ | ❌ | Guards `!authStore.isAdmin` en [`router/index.ts`](../../../frontend/src/router/index.ts#L372-L379) |
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

## §5. Hotspots Contables y de Dominio Verificados para Ola 2 (`FRD/SDD/SQL` antes de UI)

| ID | Severidad | Evidencia Verificada en Código | Brecha Contable / UX | Acción Requerida en Ola 2 |
|---|---|---|---|---|
| **C5-H1** | 🔴 **CRÍTICO** | [`PayablesView.vue`](../../../frontend/src/views/PayablesView.vue#L160) y L345-355 | `totalDebt`, `totalOverdue` y el saldo pendiente (`invoice.total_amount - invoice.amount_paid`) se calculan en cliente con `.reduce()` sobre una página parcial de 50 facturas, violando `SPEC_001` (Backend Authority) y arriesgando cifras incompletas. | Exponer resumen CxP (`total_debt`, `total_overdue`, `pending_balance`) desde RPC/servidor y eliminar `.reduce()` en cliente. |
| **C5-H2** | 🟠 **ALTO** | [`PayablesView.vue`](../../../frontend/src/views/PayablesView.vue#L232-L243); [`SuppliersView.vue`](../../../frontend/src/views/SuppliersView.vue#L15) y L43 | 1) `PayablesView.vue` captura el proveedor como texto libre (`newInvoiceForm.supplierName`) propiciando proveedores duplicados y huérfanos.<br>2) `SuppliersView.vue` importa `Pencil` (L15) y declara `editingSupplierId` (L43) sin flujo de edición operativo ni manejo visual de error al fallar `fetchSuppliers` (Regla 3). | Unificar en `/suppliers` con 2 pestañas, usar selector relacional de proveedor en creación de factura, completar edición de proveedor y añadir Banner `N3` de error con Reintentar. |
| **C5-H3** | 🟠 **ALTO** | [`SuppliersView.vue`](../../../frontend/src/views/SuppliersView.vue#L105); [`PayInvoiceModal.vue`](../../../frontend/src/components/suppliers/PayInvoiceModal.vue#L166) | Deuda activa congelada en `ux-manifest.json` (`baselineDebt`): `confirm()` nativo en `SuppliersView.vue` (L105) e importación duplicada de `vue-toastification` en `PayInvoiceModal.vue` (L166). | Reemplazar `confirm()` por `BaseModal` (`N5`) y migrar toast a `ToastNotification.vue` (`N2`), reduciendo `baselineDebt`. |
| **C5-H4** | 🟡 **MEDIO** | [`SuppliersView.vue`](../../../frontend/src/views/SuppliersView.vue#L168); [`PayablesView.vue`](../../../frontend/src/views/PayablesView.vue#L135); [`PayInvoiceModal.vue`](../../../frontend/src/components/suppliers/PayInvoiceModal.vue#L20-L60) | Violaciones a `DESIGN.md`: `border-l-[6px]` en tarjetas de `SuppliersView` (L168) y `PayablesView` (L135); `border-l-4` y emojis `ℹ️`/`🚫` en `PayInvoiceModal.vue` (L20-60); modales `div.fixed` custom y ausencia de `tabular-nums` en montos. | Migrar tarjetas/banners a tokens de `DESIGN.md`, reemplazar modales manuales por `BaseModal`, usar íconos Lucide y aplicar `font-mono tabular-nums`. |
