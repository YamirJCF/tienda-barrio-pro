---
name: test-expert
description: Genera tests unitarios robustos para Vue 3 y TypeScript usando Vitest, siguiendo los estándares del proyecto.
---

# Instrucciones para el Experto en Testing

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
