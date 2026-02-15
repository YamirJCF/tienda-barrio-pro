# ⚙️ Plan de Implementación: Fase 3 - Dashboard Financiero UI

**Referencia:** `FRD_Reportes_Historiales_v1.0.md` (Sección 7.1)
**Dependencias:** Fase 1 ✅ | Fase 2 ✅ (RPCs desplegadas)
**Rama de Trabajo:** `feat/financial-dashboard-phase3`

---

## Orden de Trabajo

### Estado Git
```bash
git checkout main && git pull
git checkout -b feat/financial-dashboard-phase3
```

### Plan de Acción Atómico

| # | Tarea | Archivo | Tiempo |
|---|-------|---------|--------|
| 1 | Crear Store `useFinancialStore` | `stores/financial.ts` | 15 min |
| 2 | Crear Vista `FinancialDashboardView` | `views/FinancialDashboardView.vue` | 20 min |
| 3 | Modificar Router | `router/index.ts` | 5 min |
| 4 | Modificar AdminHub (link navegación) | `views/AdminHubView.vue` | 5 min |
| 5 | Verificación en Browser | Manual | 10 min |

---

## Tarea 1: Store (`stores/financial.ts`)

### Prompt para Antigravity

#### Contexto
- Leer `frontend/src/stores/reports.ts` para patrón de store
- Leer `frontend/src/data/supabaseClient.ts` para import de Supabase
- Leer `frontend/src/stores/auth.ts` para obtener `storeId`

#### Objetivo
Crear `frontend/src/stores/financial.ts` con:
- 3 interfaces (`FinancialSummary`, `TopProduct`, `StagnantProduct`)
- 3 acciones (`fetchFinancialSummary`, `fetchTopProducts`, `fetchStagnantProducts`)
- 1 acción coordinadora `setPeriod('today'|'week'|'month')` que calcula fechas y llama las 3

#### Restricciones
- NO calcular totales ni márgenes. Solo consumir payload del RPC
- NO usar `axios`. Solo `getSupabaseClient().rpc()`
- Usar `COALESCE` conceptual: manejar null con `?? 0` en el frontend

#### Definición de Hecho (DoD)
- Store exporta `useFinancialStore`
- Compilación TypeScript sin errores
- `setPeriod('today')` carga los 3 datasets

---

## Tarea 2: Vista (`views/FinancialDashboardView.vue`)

### Prompt para Antigravity

#### Contexto
- Leer `frontend/src/components/SmartDailySummary.vue` para patrón de UI
- Leer `frontend/src/composables/useCurrencyFormat.ts` para formateo
- Leer `FRD_Reportes_Historiales_v1.0.md` líneas 602-650 para specs

#### Objetivo
Crear `views/FinancialDashboardView.vue` con 4 secciones:
1. **Header:** Pestañas [Hoy] [Semana] [Mes]
2. **KPIs:** Ventas Totales, Costo, Ganancia Neta (verde/rojo), Margen %
3. **Dinero:** Cards Efectivo/Transferencias/Fiado + Fiado Pendiente
4. **Productos:** Sub-tabs [🔥 Top] [❄️ Estancados] con listas

#### Restricciones
- Usar Vanilla CSS (NO Tailwind custom), clases de `SmartDailySummary`
- Skeleton loading obligatorio mientras `isLoading === true`
- Banner de error con botón "Reintentar"
- Responsive: móvil primero (`max-w-md mx-auto`)

#### Definición de Hecho (DoD)
- Componente renderiza sin errores
- Skeletons visibles durante loading
- Datos financieros correctos al cargar
- Pestañas cambian el período y recargan data

---

## Tarea 3: Router (`router/index.ts`)

### Prompt para Antigravity

#### Contexto
- Leer `frontend/src/router/index.ts` líneas 74-89 (rutas admin)

#### Objetivo
1. Agregar ruta lazy-loaded después de línea 79:
```typescript
{
  path: '/admin/financial-dashboard',
  name: 'financial-dashboard',
  component: () => import('../views/FinancialDashboardView.vue'),
  meta: { requiresAuth: true }
},
```
2. Agregar guard después de línea 278:
```typescript
if (to.name === 'financial-dashboard') {
  if (!authStore.isAdmin && !authStore.canViewReports) {
    return next({ name: 'dashboard' });
  }
}
```

#### Restricciones
- NO modificar rutas existentes
- NO cambiar guards existentes

---

## Tarea 4: AdminHub Link

### Prompt para Antigravity

#### Contexto
- Leer `AdminHubView.vue` sección "Reportes"

#### Objetivo
Agregar card de navegación al Financial Dashboard en la pestaña Reportes:
```html
<div @click="navigateTo('/admin/financial-dashboard')" class="card-style">
  📊 Dashboard Financiero
</div>
```

---

## Commits
```bash
git add frontend/src/stores/financial.ts
git commit -m "feat(store): add useFinancialStore for financial RPCs"

git add frontend/src/views/FinancialDashboardView.vue
git commit -m "feat(ui): add FinancialDashboardView with KPI cards"

git add frontend/src/router/index.ts frontend/src/views/AdminHubView.vue
git commit -m "feat(router): add financial-dashboard route and AdminHub link"
```
