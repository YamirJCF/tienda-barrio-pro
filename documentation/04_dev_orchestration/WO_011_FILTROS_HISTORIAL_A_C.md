# Orden de Trabajo — Filtros de Historial y Auditoría v3 (Opción A + C, Admin-Only) (FRD-005 / FRD-021 / UXD-005)

### Estado Git
- **Rama:** `feat/history-filters-governance`
- **Comando de Verificación:** `git branch --show-current`
- **Mensaje Base de Commit:** `feat(history): implementar filtros compactos A+C con parser de atajos y proteccion admin`

---

### 🌍 Reporte de Contexto Comprobado y Reconocimiento del Terreno (Fase 0)
> **Regla 9.3 Aplicada:** Toda función y componente listado fue verificado físicamente en el código fuente.  
> **Ecógrafo Estructural (Regla 10):** Ejecutado sobre `useHistory`. Sello registrado en `.git/.impact_scan_stamp`.

| Función / Componente | Estado | Evidencia (Ruta Real) | Notas de Integración |
|---|---|---|---|
| `router/index.ts` | ✅ Modificado | `frontend/src/router/index.ts` ~L280 | Guardia de seguridad: `/reports` y `/history` restringidos a `authStore.isAdmin` |
| `useHistory` | ✅ Modificado | `frontend/src/composables/useHistory.ts` ~L75 | Default `dateFilter = 'week'`, multicanal, contextual type filter, resetFilters, applyShortcutQuery, eliminación de `totalAmount` reduce |
| `useHistory.spec.ts` | ✅ Modificado | `frontend/src/__tests__/useHistory.spec.ts` | Pruebas de caja, turnos, atajos y filtros multicanal pasando al 100% |
| `historyShortcutParser.ts` | ✅ Creado | `frontend/src/utils/historyShortcutParser.ts` | Parser puro de atajos: dominio, período, pago, tipo, empleado |
| `historyShortcutParser.spec.ts` | ✅ Creado | `frontend/src/__tests__/utils/historyShortcutParser.spec.ts` | 9 pruebas unitarias cubriendo todas las ramas |
| `BaseDropdown.vue` | ✅ Reutilizado | `frontend/src/components/ui/BaseDropdown.vue` | Desplegables compactos para Dominio, Período, Pago, Tipo y Empleado |
| `HistoryView.vue` | ✅ Modificado | `frontend/src/views/HistoryView.vue` | Reemplazo de torre de 5 filas por 2 filas limpias (A+C) + estado vacío con contexto y ampliación de rango |

---

### 📋 Secuencia de Tareas Atómicas Ejecutadas y Verificadas

- [x] **Paso 1 — [Seguridad]: Blindaje Admin en Router**
  - **Archivo:** `frontend/src/router/index.ts`
  - **Acción:** Guardia explícita para `/reports` y `/history`: redirige a `/` si `!authStore.isAdmin`.
  - **Validación:** `git diff frontend/src/router/index.ts`

- [x] **Paso 2 — [Lógica Pura]: Parser de Atajos de Historial (TDD)**
  - **Archivos:** `frontend/src/utils/historyShortcutParser.ts` y `frontend/src/__tests__/utils/historyShortcutParser.spec.ts`
  - **Acción:** Función pura que tokeniza entradas, identifica dominios, fechas, métodos de pago, tipos y empleados, dejando el texto libre.
  - **Validación:** `npx vitest run src/__tests__/utils/historyShortcutParser.spec.ts` (9/9 pasaron).

- [x] **Paso 3 — [Capa Estado]: Refactorización de `useHistory.ts`**
  - **Archivo:** `frontend/src/composables/useHistory.ts`
  - **Acción:**
    1. Default `dateFilter = 'week'` (FRD-005 Regla 6).
    2. Multicanal unificado y extensible (FRD-021).
    3. Retiro del cálculo prohibido `.reduce()` financiero en cliente (`SPEC-010/011`).
    4. Métodos `applyShortcutQuery`, `resetFilters`, computadas `hasActiveFilters` y `activeDateLabel`.
  - **Validación:** `npx vitest run src/__tests__/useHistory.spec.ts` (6/6 pasaron).

- [x] **Paso 4 — [Capa UI]: Rediseño de `HistoryView.vue` (Opción A + C)**
  - **Archivo:** `frontend/src/views/HistoryView.vue`
  - **Acción:**
    1. Fila 1: Buscador táctil con atajos en Enter (`@keydown.enter="handleSearchCommit"`).
    2. Fila 2: Desplegables compactos `BaseDropdown` para Dominio, Período, Pago, Tipo y Empleado + Botón Limpiar.
    3. Panel de rango personalizado Desde–Hasta cuando `dateFilter === 'custom'`.
    4. Estado vacío contextual con período y botón de ampliación a 30 días (`FRD-005` Regla 6).
  - **Validación:** `npm --prefix frontend test` (19 suites, 132 tests pasaron) y `npm --prefix frontend run build` (0 errores).

- [x] **Paso 5 — [Documentación]: UXD y dev orchestration**
  - **Archivos:** `documentation/01_requirements/UXD/UXD_005_INTERFAZ_HISTORIAL_AUDITORIA.md` y `documentation/04_dev_orchestration/WO_011_FILTROS_HISTORIAL_A_C.md`
