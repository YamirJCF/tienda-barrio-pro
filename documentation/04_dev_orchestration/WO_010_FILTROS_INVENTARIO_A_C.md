# Orden de Trabajo — Filtros de Inventario v3 (Opción A + C) (SDD-006 / UXD-006)

### Estado Git
- **Rama:** `feat/inventory-filters-governance`
- **Comando de Verificación:** `git branch --show-current` (permanecer en la rama activa)
- **Mensaje Base de Commit:** `feat(inventory): implementar filtros compactos A+C con parser de atajos internos`

---

### 🌍 Reporte de Contexto Comprobado y Reconocimiento del Terreno (Fase 0)
> **Regla 9.3 Aplicada:** Toda función y componente listado fue verificado físicamente en el código fuente.  
> **Ecógrafo Estructural (Regla 10):** Ejecutado sobre `useInventoryFilter` e `inventory`. Sello registrado en `.git/.impact_scan_stamp`.

| Función / Componente | Estado | Evidencia (Ruta Real) | Notas de Integración |
|---|---|---|---|
| `useInventoryFilter` | ✅ Reutilizar / Extender | `frontend/src/composables/useInventoryFilter.ts` ~L14 | Base reactiva in-memory. Añadir `stockRule`, `priceRule`, `brandFilter`, `pluFilter`, `urgency_asc` y búsqueda por `category` |
| `InventoryView.vue` | ✅ Modificar | `frontend/src/views/InventoryView.vue` ~L1 | Reemplazar header, Bottom Sheet y carrusel por barra A+C limpia |
| `useInventoryFilter.spec.ts` | ✅ Modificar | `frontend/src/__tests__/composables/useInventoryFilter.spec.ts` ~L19 | Adaptar `activeFiltersCount` (orden no cuenta) y añadir pruebas de nuevas reglas |
| `BaseInput.vue` | ✅ Reutilizar | `frontend/src/components/ui/BaseInput.vue` | Base de estilizado para inputs con slots prefix/suffix |
| `BaseEmptyState.vue` | ✅ Reutilizar | `frontend/src/components/ui/BaseEmptyState.vue` | Componente de estado vacío cuando no hay resultados |
| `parseShortcuts()` | 🔴 AUSENTE | `frontend/src/utils/inventoryShortcutParser.ts` | **CREAR NUEVO:** Parser puro de atajos internos sin dependencias de UI |
| `BaseDropdown.vue` | 🔴 AUSENTE | `frontend/src/components/ui/BaseDropdown.vue` | **CREAR NUEVO:** Desplegable táctil móvil anclado con teclado y accesibilidad |
| `InventorySearchBar.vue` | 🔴 AUSENTE | `frontend/src/components/inventory/InventorySearchBar.vue` | **CREAR NUEVO:** Barra de búsqueda táctil con atajos internos y error inline |
| `inventoryShortcutParser.spec.ts` | 🔴 AUSENTE | `frontend/src/__tests__/utils/inventoryShortcutParser.spec.ts` | **CREAR NUEVO:** Tests TDD del parser puro |

---

### 📋 Secuencia de Tareas Atómicas
> **Regla de Ejecución:** Cada paso debe completarse y validarse antes de avanzar al siguiente. Cero tolerancia a fallos silenciosos.

#### Paso 1 — [Lógica Pura]: Crear Tests Unitarios del Parser de Atajos (TDD)
- **Archivo:** `frontend/src/__tests__/utils/inventoryShortcutParser.spec.ts`
- **Acción:** CREAR suite de pruebas unitarias que cubra:
  1. Atajos de estado: `bajo`, `agotado`.
  2. Atajos de marca: `marca:alpina`, `marca:"aseo general"`.
  3. Atajos de PLU: `plu:1001`.
  4. Comparadores numéricos: `stock<10`, `stock<=5`, `stock>0`, `stock>=20`, `stock=0`.
  5. Comparadores de precio: `precio<5000`, `precio>=10000`, `precio<=12.000` (con punto de miles).
  6. Admin: `inactivo` (ignorado con advertencia si `isAdmin: false`, aceptado si `isAdmin: true`).
  7. Normalización: mayúsculas (`BAJO`), tildes (`marca:álpina`).
  8. **Ramas de Error Explícito:** `stok<5` (clave desconocida), `stock<abc` (no numérico), `marca:` (valor vacío), comillas sin cerrar.
  9. Texto libre combinado: `leche deslactosada bajo stock<10` extrae texto libre y aplica filtros.
- **Validación:** `cd frontend; npx vitest run src/__tests__/utils/inventoryShortcutParser.spec.ts` (debe fallar inicialmente porque el archivo de utilidad aún no existe).

#### Paso 2 — [Lógica Pura]: Implementar Parser de Atajos (`inventoryShortcutParser.ts`)
- **Archivo:** `frontend/src/utils/inventoryShortcutParser.ts`
- **Acción:** CREAR función pura `parseShortcuts(input: string, options?: { isAdmin?: boolean })`:
  - Tokenizador que respete comillas dobles.
  - Normalizador insensible a mayúsculas y acentos.
  - Extracción de filtros reconocidos (`onlyLowStock`, `stockRule`, `priceRule`, `brandFilter`, `pluFilter`, `includeInactive`).
  - Detección estricta de sintaxis con retorno de `errors: string[]` y `warnings: string[]`.
  - Retorno de `freeText: string` con los tokens que no sean atajos.
- **Validación:** `cd frontend; npx vitest run src/__tests__/utils/inventoryShortcutParser.spec.ts` (debe pasar al 100% todos los casos).

#### Paso 3 — [Capa Estado]: Extender `useInventoryFilter.ts`
- **Archivo:** `frontend/src/composables/useInventoryFilter.ts`
- **Acción:** MODIFICAR el composable:
  1. Agregar estados: `brandFilter`, `pluFilter`, `stockRule` (`{ op: '<'|'<='|'>'|'>='|'=', value: number } | null`), `priceRule`.
  2. Agregar opción de orden `'urgency_asc'` a `InventorySortOption` (ordena por `stock - minStock` ascendente).
  3. Extender búsqueda de texto libre (`searchQuery`) para incluir `p.category`.
  4. Integrar filtrado por `brandFilter`, `pluFilter`, `stockRule`, `priceRule`.
  5. Elevar `sortBy` a ámbito de módulo para persistencia en sesión, y exportar `resetInventorySortBaseline()` para aislamiento de tests.
  6. Añadir método `applyShortcutString(rawInput: string, isAdmin: boolean)` que ejecute `parseShortcuts`, aplique los filtros válidos y devuelva `{ remainingText: string, errors: string[] }`.
  7. Ajustar `activeFiltersCount` para contar categoría, stock, precio, marca, plu e inactivos (el orden NO cuenta).
  8. Añadir callback / watcher de categoría desaparecida: si `selectedCategory !== 'all'` y ya no existe en `categories.value`, restablecer a `'all'` y disparar notificación.
- **Validación:** `cd frontend; npx vitest run src/__tests__/composables/useInventoryFilter.spec.ts`

#### Paso 4 — [Capa Estado]: Actualizar Tests Unitarios de `useInventoryFilter.spec.ts`
- **Archivo:** `frontend/src/__tests__/composables/useInventoryFilter.spec.ts`
- **Acción:** MODIFICAR para incluir:
  1. Test de persistencia de `sortBy` y uso de `resetInventorySortBaseline()`.
  2. Test de que `activeFiltersCount` no cuenta el orden de clasificación.
  3. Tests de orden `'urgency_asc'` (`stock - minStock`).
  4. Tests de búsqueda por categoría en texto libre.
  5. Tests de reglas `stockRule`, `priceRule`, `brandFilter`, `pluFilter`.
  6. Test de auto-restablecimiento a `'all'` si la categoría seleccionada desaparece.
- **Validación:** `cd frontend; npx vitest run src/__tests__/composables/useInventoryFilter.spec.ts` (100% pass).

#### Paso 5 — [Componente UI]: Crear `BaseDropdown.vue`
- **Archivo:** `frontend/src/components/ui/BaseDropdown.vue`
- **Acción:** CREAR componente desplegable táctil:
  - Props: `modelValue: string`, `options: Array<{ value: string; label: string }>`, `label: string`, `searchable?: boolean`, `searchThreshold?: number` (default 8).
  - Emits: `update:modelValue`.
  - Botón táctil `rounded-full` con flecha `ChevronDown`.
  - Panel flotante `rounded-2xl` con sombra Stitch, soporte tema claro y oscuro.
  - Event listener global para clic fuera (`click-outside`) y tecla `Escape`.
  - Accesibilidad `aria-haspopup="listbox"`, `role="listbox"`, `role="option"`.
  - Mini buscador interno automático si `options.length > searchThreshold`.
- **Validación:** Verificación de tipos TypeScript con `npm run build`.

#### Paso 6 — [Componente UI]: Crear `InventorySearchBar.vue`
- **Archivo:** `frontend/src/components/inventory/InventorySearchBar.vue`
- **Acción:** CREAR barra de búsqueda móvil táctil:
  - Props: `modelValue: string`, `errors?: string[]`.
  - Emits: `update:modelValue`, `submit-shortcuts: [raw: string]`, `clear`.
  - Input con icono `Search` a la izquierda y botón `✕` a la derecha (solo visible si hay texto).
  - Atributos móviles: `enterkeyhint="search"`, `@keydown.enter`.
  - Renderizado inline en rojo de `errorMessage` si algún atajo ingresado fue inválido.
  - **Trade-off D-N1 Aplicado:** Cero indicador `⚡N`. Interfaz limpia y despejada.
- **Validación:** Verificación de tipos TypeScript con `npm run build`.

#### Paso 7 — [Vista Principal]: Integrar en `InventoryView.vue`
- **Archivo:** `frontend/src/views/InventoryView.vue`
- **Acción:** MODIFICAR:
  1. Reemplazar encabezado con `InventorySearchBar`, `BaseDropdown` (Categoría), `BaseDropdown` (Orden) y menú `⋯` (Admin).
  2. Eliminar completamente el Bottom Sheet modal de filtros (`showFilterModal`), el carrusel de categorías y los botones obsoletos.
  3. Conectar evento `@submit-shortcuts` con `applyShortcutString` de `useInventoryFilter`.
  4. Conectar callback de categoría desaparecida con `toast.info("La categoría seleccionada ya no tiene productos asociados")`.
  5. Limpiar imports de iconos no utilizados en `lucide-vue-next`.
- **Validación:** `cd frontend; npm run build` y ejecución de tests completos.

#### Paso 8 — [Documentación]: Actualizar UXD-006
- **Archivo:** `documentation/01_requirements/UXD/UXD_006_INTERFAZ_INVENTARIO.md`
- **Acción:** MODIFICAR secciones 3.1 y 3.2 para reflejar la especificación A+C final, registrando los trade-offs de la Regla 7 (ausencia de indicador `⚡N`, orden diferido por ventas a Fase 2, exclusión de `cat:`).
- **Validación:** Revisión de enlaces de archivo y coherencia de contrato.

#### Paso 9 — [Verificación Final y Cierre]:
- **Comandos:**
  ```powershell
  cd frontend; npm test
  cd frontend; npm run build
  node scripts/scan-impact.mjs inventory
  ```
- **Validación:** 100% tests aprobados, cero errores de build, sello de impacto renovado.

---

### Comandos de Consola de Inicialización
```powershell
git status
node scripts/scan-impact.mjs inventory
```
