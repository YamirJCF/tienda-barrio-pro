# Diseño UX/UI - Refactorización Estética (WO-PHASE3-004)

Este documento detalla la estrategia de diseño para aplicar el Sistema Atómico y mejorar la UX en las vistas complejas pendientes de refactorización.

## 1. POSView (Punto de Venta)

El POS es el corazón operativo. Actualmente sufre de "Fat View" y estilos ad-hoc.

### Mapa de Componentes
- **Numpad & PLU Input**: Extraer a `POSNumpad.vue`.
  - *UX Logic*: Debe permitir entrada rápida de PLU y Cantidad (x). Feedback visual inmediato al presionar teclas.
- **Product Search**: Integrar `BaseInput` con icono de búsqueda.
  - *UX Logic*: Resultados desplegables con navegación por teclado.
- **Cart List**: Rediseñar item de lista.
  - *Visual*: Usar tarjetas más limpias, separar claramente precio unitario de subtotal.
  - *Interacción*: Swipe-to-delete en móvil (si es posible) o botón de eliminar accesible.
- **Checkout Panel**: Panel lateral fijo (desktop) o bottom sheet (mobile).
  - *Visual*: Totales grandes y legibles.

### Instrucción para Orquestador (Refactor Estético Phase 4)
1. **Limpieza de Estilos Scoped**:
   - Reemplazar clases `.ticket-scroll` con utilidades Tailwind `scrollbar-thin scrollbar-thumb-gray-200` (o plugin `no-scrollbar` si se desea ocultar).
   - Eliminar `z-index` manuales donde sea posible, usar jerarquía natural o clases `z-` estándar.
2. **Consistencia Visual**:
   - Asegurar que el `BaseButton` de "COBRAR" tenga `shadow-lg` y `active:scale-95` para feedback táctil robusto.
   - Estandarizar el padding inferior (`pb-safe`) para móviles en la sección de comandos.

---

## 2. InventoryView (Gestión de Productos)

### Detalle de Pantalla
- **Header**: Título + Botones de Acción (Nuevo Producto, Escanear).
- **Filtros**:
  - *Refactor*: Mover selects de categoría y estado a un componente `InventoryFilters.vue` o usar un `BaseSelect` (si existiera, por ahora inputs nativos estilizados uniformemente).
  - *Search*: `BaseInput` para búsqueda global.
- **Tabla/Lista**:
  - *Mobile*: Lista de tarjetas (`ProductCard.vue`?).
  - *Desktop*: Tabla responsiva.
  - *UX*: Scroll infinito o paginación clara.
- **Indicadores de Estado**:
  - *Stock Bajo*: Chip rojo/ámbar. Usar componentes de estado visual consistentes.

### Lógica de Componentes (Phase 4 Cleanup)
- **Eliminación de CSS Scoped**:
  - Reemplazar `.no-scrollbar` con utilidades globales o clases Tailwind `overflow-x-auto snap-x`.
  - Usar `gap-2` y `p-4` consistentes en lugar de márgenes ad-hoc.
- **Filtros**:
  - Convertir la lista de categorías (tags) en una fila con scroll horizontal fluido (`flex-nowrap`).
  - El input de búsqueda debe usar `BaseInput` con prop `icon="search"` (Ya implementado, verificar consistencia).

---

## 3. ClientDetailView (Detalle de Cliente)

### Detalle de Pantalla
- **Cabecera de Perfil**: Avatar con iniciales (componente `Avatar` reutilizable?), nombre grande, estado de deuda.
- **Resumen Financiero**: Tarjetas de "Deuda Total", "Cupo Disponible".
- **Historial de Transacciones**: Lista cronológica.
  - *Refactor*: Usar el mismo componente de lista que en `HistoryView` (`HistoryItemCard` o similar) para consistencia.
- **Acciones**:
  - "Abonar a Deuda" -> `BaseButton` (Action principal).
  - "Editar Datos" -> `BaseButton` (Secondary/Outline).

---

## 4. EmployeeManagerView (Gestión de Empleados)

### Detalle de Pantalla
- **Lista de Empleados**: Tarjetas con estado (Activo/Inactivo) y Rol.
- **Modal de Edición**:
  - *Refactor*: Migrar completamente a `BaseModal`.
  - *Formulario*: Usar `BaseInput` para todos los campos.
  - *Permisos*: Lista de checks estilizada.

### Instrucción para Orquestador
Priorizar la migración del Modal de Empleados a `BaseModal` para validar su reutilización en casos complejos.

---

## Estrategia de Implementación Visual

1. **Prioridad 1**: `EmployeeManagerView`. Es autocontenida y permite probar `BaseModal` a fondo.
2. **Prioridad 2**: `ClientDetailView`. Permite reutilizar componentes de lista de historial.
3. **Prioridad 3**: `InventoryView`. Alta complejidad de datos, requiere cuidado en filtros.
4. **Prioridad 4**: `POSView`. Máxima complejidad y riesgo. Dejar para el final de la fase estética para tener todos los componentes `Base` maduros.
