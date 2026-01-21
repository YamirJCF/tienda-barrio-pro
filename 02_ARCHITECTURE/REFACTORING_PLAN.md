# Plan de Refactorización Frontend

Este plan detalla las fases para alinear el código existente con el nuevo [Estándar de Desarrollo Frontend](./FRONTEND_STANDARDS.md).

## Fase 1: Cimientos y Configuración (Inmediato)
- [ ] **Establish Standards**: Publicar `FRONTEND_STANDARDS.md`.
- [ ] **Tooling**: Verificar configuración de ESLint y Prettier.
- [ ] **Aliases**: Asegurar que `@/` apunte a `src/` para imports limpios.

## Fase 2: Componentes Base (Atomic Design)
Objetivo: Reducir duplicación de estilos UI.

- [ ] **Botones**: Crear/Refactorizar `BaseButton.vue` con variantes (primary, secondary, danger) usando Tailwind.
- [ ] **Inputs**: Estandarizar `BaseInput.vue` con soporte de labels y errores accesibles.
- [ ] **Modales**: Unificar lógica de modales (`EmployeeFormModal`, `ProductFormModal`) bajo un componente `BaseModal` reutilizable.

## Fase 3: Extracción de Lógica (Composables)
Objetivo: Adelgazar vistas complejas ("Fat Views").

### 3.1 POSView Refactor
- [ ] **Problem**: `POSView.vue` tiene >600 líneas mezclando UI, lógica de carrito y teclado numérico.
- [ ] **Action**: Extraer lógica de entrada numérica a `useNumpad.ts`.
- [ ] **Action**: Mover lógica de selección de producto a `usePOS.ts`.

### 3.2 InventoryView Refactor
- [ ] **Problem**: Lógica de filtrado y paginación en el componente.
- [ ] **Action**: Extraer a `useInventoryFilter.ts`.

## Fase 4: Limpieza y Tipado
- [ ] **Types**: Centralizar interfaces `Product`, `Sale`, `Client` en `src/types/`.
- [ ] **Styles**: Eliminar bloques `<style scoped>` que puedan ser reemplazados por clases de Tailwind.
- [ ] **Strict Check**: Eliminar cualquier uso de `any` no justificado.

## Fase 5: Optimización
- [ ] **Lazy Loading**: Verificar que todas las rutas se carguen con `import()`.
- [ ] **Assets**: Optimizar imágenes y uso de iconos.
