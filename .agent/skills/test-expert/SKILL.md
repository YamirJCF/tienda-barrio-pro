---
name: test-expert
description: Genera tests unitarios robustos para Vue 3 y TypeScript usando Vitest, siguiendo los estándares del proyecto.
---

# Instrucciones para el Experto en Testing

## 🧭 Control de Flujo (Pipeline)
- **Nivel:** 4 — Pruebas Unitarias, de Regresión y de Caracterización (Rutas B, C y E)
- **Rama permitida:** `feat/*`, `fix/*`, `refactor/*` (**PROHIBIDO** en `master`).
- **Entrada requerida (Gate In):**
  - En Rutas B/C: Código implementado o corregido en stores, repositorios, composables o componentes Vue.
  - En Ruta E (`refactor` — Fase 1): Código existente *antes* de ser refactorizado para tomar la "Foto Antes" (Prueba de Caracterización).
- **Límite estricto:** Crea y ejecuta tests con Vitest (`cd frontend && npm run test`); **PROHIBIDO** deshabilitar, saltar (`.skip`) o debilitar un test existente para hacerlo pasar, prohibido editar `.spec.ts` durante la Fase 2 de `refactor`, y prohibido comparar dinero contra strings formateados en vez de `Decimal`.
- **🛑 Freno de Emergencia (Hard Stop):** Si un test revela un bug en la lógica de negocio o un fallo en el contrato RPC → DETENERSE y regresar a `systematic-debugging` / `data`.
- **➡️ Siguiente eslabón:**
  - En Rutas B y C (o Fase 3 de `refactor`): `code-reviewer`
  - En Ruta E (`refactor` — Fase 1 Foto Antes): Retorna a `refactor` (Fase 2: Cirugía con `.spec.ts` congelados).
  - **En Modo AUTO:** Con todos los tests en verde (`✅`), ejecuta el siguiente eslabón de inmediato sin preguntar.
  - **En Modo PAUSADO:** Muestra el output real de Vitest en consola, indica el siguiente eslabón y espera confirmación.

---

Cuando el usuario solicite crear o arreglar tests, sigue estrictamente estas reglas basadas en la arquitectura del proyecto.

## Stack Tecnológico
- **Framework**: Vitest (compatible con Jest)
- **Utils**: `@vue/test-utils` (para componentes)
- **Mocking**: `vi` (de vitest)
- **Entorno**: `happy-dom`
- **Gestión de Estado**: Pinia
- **Matemáticas**: `decimal.js` (OBLIGATORIO para dinero/stock)

## Reglas Generales

1.  **Imports**:
    - Usa `import { describe, it, expect, beforeEach, vi } from 'vitest';`
    - Para stores: `import { setActivePinia, createPinia } from 'pinia';`
    - Para números: `import { Decimal } from 'decimal.js';`

2.  **Configuración (Setup)**:
    - Siempre usa `beforeEach` para reiniciar Pinia:
      ```typescript
      beforeEach(() => {
        setActivePinia(createPinia());
      });
      ```

3.  **Mocking**:
    - Mockea cualquier dependencia externa (API, Supabase, otros Stores).
    - Ejemplo de mock de Store:
      ```typescript
      vi.mock('@/stores/inventory', () => ({
        useInventoryStore: vi.fn(() => ({
          products: [],
          checkStock: vi.fn().mockReturnValue(true)
        }))
      }));
      ```

4.  **Manejo de Decimales (CRÍTICO)**:
    - **Lógica de Negocio (Stores/Repos)**: NUNCA pruebes contra strings formateados de dinero ($). Pruebas SIEMPRE contra instancias de `Decimal`.
      - *Incorrecto*: `expect(store.total).toBe('$5,000');`
      - *Correcto*: `expect(store.total.equals(new Decimal(5000))).toBe(true);`
    - **Capa Visual (Componentes)**: Si pruebas el *renderizado*, verifica que `useQuantityFormat` se esté usando o que el output coincida con `spec-011` (Dinero: 0 decimales, Peso: max 2).
    - **Reglas de Formato (Referencia SPEC-011)**:
        - Dinero: Enteros (0 decimales).
        - Stock (Unidad/Gramos): Enteros.
        - Stock (Kg/Lb): Max 2 decimales (ej. 28.16).


## Estructura de Archivos
- Los tests deben ubicarse en `src/__tests__/` replicando la estructura de carpetas de `src/` o ser colocados al lado del archivo con extensión `.spec.ts` (revisar configuración `vitest.config.ts`).
- Preferencia actual detectada: `src/__tests__/`

## Ejemplo de Test de Store (Referencia)

```typescript
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useMyStore } from '@/stores/myStore';
import { Decimal } from 'decimal.js';

describe('My Store Logic', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('should calculate total with decimals', () => {
    const store = useMyStore();
    store.addItem({ price: new Decimal(100), qty: 2 });
    expect(store.total.toNumber()).toBe(200);
  });
});
```

## Ejemplo de Test de Componente

```typescript
import { mount } from '@vue/test-utils';
import MyComponent from '@/views/MyComponent.vue';
import { createTestingPinia } from '@pinia/testing';

describe('MyComponent', () => {
  it('renders correctly', () => {
    const wrapper = mount(MyComponent, {
      global: {
        plugins: [createTestingPinia({ createSpy: vi.fn })]
      }
    });
    expect(wrapper.text()).toContain('Hola Mundo');
  });
});
```
