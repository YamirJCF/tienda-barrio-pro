# Plan de Refactorización Frontend

Este plan detalla las fases para alinear el código existente con el nuevo [Estándar de Desarrollo Frontend](./FRONTEND_STANDARDS.md).

## Fase 1: Cimientos y Configuración (Inmediato)
- [ ] **Establish Standards**: Publicar `FRONTEND_STANDARDS.md`.
- [ ] **Tooling**: Verificar configuración de ESLint y Prettier.
- [ ] **Aliases**: Asegurar que `@/` apunte a `src/` para imports limpios.

## Fase 2: Componentes Base (Atomic Design)
Objetivo: Reducir duplicación de estilos UI.

- [x] **Botones**: Crear/Refactorizar `BaseButton.vue` con variantes (primary, secondary, danger) usando Tailwind.
- [x] **Inputs**: Estandarizar `BaseInput.vue` con soporte de labels y errores accesibles.
- [x] **Modales**: Unificar lógica de modales (`EmployeeFormModal`, `ProductFormModal`) bajo un componente `BaseModal` reutilizable.

## Fase 3: Extracción de Lógica (Composables)
Objetivo: Adelgazar vistas complejas ("Fat Views").

### 3.1 POSView Refactor
- [x] **Problem**: `POSView.vue` tiene >600 líneas mezclando UI, lógica de carrito y teclado numérico.
- [x] **Action**: Extraer lógica de entrada numérica a `useNumpad.ts` y componente `POSNumpad.vue`.
- [x] **Action**: Mover lógica de selección de producto a `usePOS.ts`.

### 3.2 InventoryView Refactor
- [x] **Problem**: Lógica de filtrado y paginación en el componente.
- [x] **Action**: Extraer a `useInventoryFilter.ts`.

## Fase 4: Limpieza y Tipado
- [x] **Types**: Centralizar interfaces `Product`, `Sale`, `Client` en `src/types/`.
- [x] **Styles**: Eliminar bloques `<style scoped>` que puedan ser reemplazados por clases de Tailwind.
- [x] **Strict Check**: Eliminar cualquier uso de `any` no justificado.

## Fase 5: Optimización
- [x] **Lazy Loading**: Verificar que todas las rutas se carguen con `import()`.
- [x] **Assets**: Optimizar imágenes y uso de iconos.
