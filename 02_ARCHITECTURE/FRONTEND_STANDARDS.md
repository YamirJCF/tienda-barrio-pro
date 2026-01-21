# Estándar de Desarrollo Frontend (Vue 3 + TS)

Este documento define los lineamientos obligatorios para el desarrollo y mantenimiento del código frontend en "Tienda de Barrio Pro".

---

## 1. Arquitectura de Componentes

### 1.1 Estructura del Archivo (.vue)
Todo componente debe seguir rigurosamente este orden:

1. `<script setup lang="ts">`: Lógica y tipado.
2. `<template>`: Estructura HTML.
3. `<style scoped>`: Estilos específicos (minimizar uso, preferir Tailwind).

### 1.2 Reglas de Script Setup
- **Imports Agrupados**:
  1. Vue core (`ref`, `computed`, etc.)
  2. Vue Router / Pinia
  3. Composables internos
  4. Componentes hijos
  5. Tipos/Interfaces
  6. Utilidades
- **Orden de Definición**:
  1. Props & Emits
  2. Variables Reactivas (`ref`, `reactive`)
  3. Computed Properties
  4. Watchers
  5. Lifecycle Hooks (`onMounted`)
  6. Métodos / Funciones

### 1.3 Naming Conventions
- **Componentes**: PascalCase (e.g., `ProductCard.vue`, `UserProfile.vue`).
- **Archivos**: PascalCase para componentes, camelCase para utilidades/composables.
- **Eventos**: kebab-case en template (`@update-user`), camelCase en script (`emit('updateUser')`).
- **Props**: camelCase.

---

## 2. Gestión de Estado (Pinia)

- **Stores Modulares**: Un store por dominio lógico (e.g., `useCartStore`, `useAuthStore`).
- **State vs Getters vs Actions**:
  - `state`: Solo datos crudos.
  - `getters`: Computed properties derivadas del state.
  - `actions`: Lógica de negocio y mutaciones (síncronas o asíncronas).
- **Prohibido**: Modificar state directamente desde componentes (excepto `v-model` simples). Usar actions.

---

## 3. Estilos y Diseño (Tailwind CSS)

- **Mobile First**: Diseñar primero para móvil, luego usar prefijos `sm:`, `md:`, `lg:` para escritorio.
- **Utility-First**: Evitar clases CSS tradicionales. Usar utilidades de Tailwind.
- **Design System**:
  - Usar colores semánticos (`bg-primary`, `text-danger`) en lugar de arbitrarios (`bg-blue-500`) cuando sea posible.
  - Usar `gap` para espaciado en flex/grid en lugar de márgenes individuales.
- **`@apply`**: Usar SOLO para patrones altamente repetitivos (e.g., `.btn-primary`).

---

## 4. Lógica Reutilizable (Composables)

- **Regla del "Fat Component"**: Si un componente tiene más de 300 líneas de lógica, extraer en un composable (`useFeature.ts`).
- **Prefijo**: Todos los composables deben empezar con `use`.
- **Retorno**: Siempre retornar un objeto plano, no destructurar reactividad si no es necesario.

---

## 5. Accesibilidad (a11y)

- **Inputs**: Siempre deben tener `label` asociado o `aria-label`.
- **Botones**: Botones de solo icono deben tener `aria-label`.
- **Feedback**: Usar notificaciones visuales para acciones de éxito/error.

---

## 6. TypeScript

- **No `any`**: Tipar explícitamente variables y retornos de función.
- **Interfaces Compartidas**: Tipos de dominio (e.g., `Product`, `User`) deben vivir en `src/types` o exportarse desde el store correspondiente.

---
**Fecha de Aprobación**: 2026-01-21
**Versión**: 1.0
