# Arquitectura del Proyecto

## Estructura de Carpetas

```
src/
├── components/
│   ├── ui/                    # Componentes UI reutilizables
│   │   ├── BaseModal.vue      # Wrapper base para modales
│   │   ├── StatCard.vue       # Tarjeta de estadísticas
│   │   ├── NoPermissionOverlay.vue  # Overlay de sin permiso
│   │   ├── ListMenuItem.vue   # Item de menú para sidebars
│   │   └── index.ts
│   ├── BottomNav.vue
│   ├── CheckoutModal.vue
│   └── ...
├── composables/               # Lógica reutilizable (Vue Composition API)
│   ├── useCurrencyFormat.ts   # Formateo de moneda
│   └── useNotifications.ts
├── data/                      # Capa de datos (separada de UI)
│   ├── repositories/          # Abstracción de almacenamiento
│   │   ├── types.ts           # Interface StorageAdapter
│   │   ├── localStorageAdapter.ts
│   │   └── index.ts
│   ├── serializers/           # Serialización para Decimal.js
│   │   ├── decimalSerializer.ts
│   │   ├── salesSerializer.ts
│   │   ├── inventorySerializer.ts
│   │   ├── clientsSerializer.ts
│   │   ├── cartSerializer.ts
│   │   ├── expensesSerializer.ts
│   │   └── index.ts
│   └── sampleData.ts
├── stores/                    # Estado (Pinia)
│   ├── auth.ts
│   ├── sales.ts               # Usa salesSerializer
│   ├── inventory.ts           # Usa inventorySerializer
│   ├── clients.ts             # Usa clientsSerializer
│   ├── cart.ts                # Usa cartSerializer
│   ├── expenses.ts            # Usa expensesSerializer
│   └── storeStatus.ts
├── views/                     # Páginas/Vistas
│   ├── DashboardView.vue      # Usa StatCard, useCurrencyFormat
│   ├── POSView.vue            # Usa NoPermissionOverlay, useCurrencyFormat
│   ├── InventoryView.vue      # Usa NoPermissionOverlay, useCurrencyFormat
│   └── ...
└── router/
```

## Principios de Arquitectura

### Separación de Responsabilidades
- **UI (Views/Components)**: Solo presentación y eventos
- **Composables**: Lógica reutilizable de UI
- **Stores**: Estado de la aplicación
- **Data**: Persistencia y serialización

### Inversión de Dependencias
La interface `StorageAdapter` en `data/repositories/types.ts` permite cambiar el backend de almacenamiento sin modificar los stores:

```typescript
interface StorageAdapter {
  get<T>(key: string): T | null;
  set<T>(key: string, value: T): void;
  remove(key: string): void;
  clear(): void;
}
```

Actualmente usa `localStorage`, pero puede cambiarse a Supabase.

## Componentes UI Reutilizables

| Componente | Descripción | Props principales |
|------------|-------------|-------------------|
| `StatCard` | Tarjeta de estadística con icono | `icon`, `iconColor`, `title`, `value`, `subtitle` |
| `NoPermissionOverlay` | Overlay de acceso restringido | `title`, `message`, `@go-back` |
| `BaseModal` | Wrapper para modales | `v-model`, `title`, `maxHeight` |
| `ListMenuItem` | Item de menú en sidebars | `icon`, `label`, `@click` |

## Composables

| Composable | Descripción | Métodos |
|------------|-------------|---------|
| `useCurrencyFormat` | Formateo de moneda colombiana | `formatCurrency()`, `formatWithSign()` |
| `useNotifications` | Notificaciones toast | `showSaleSuccess()`, `showSaleOffline()` |
