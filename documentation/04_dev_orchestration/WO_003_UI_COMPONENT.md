## Orden de Trabajo - Frontend UI (Smart Component)

### Estado Git Actual
- Rama: `feat/smart-summary-frontend`

### Plan de Acción Atómico
1.  Crear `frontend/src/components/SmartDailySummary.vue`.
2.  Implementar la estructura HTML/Tailwind basada en `UX_008_SMART_DAILY_SUMMARY_V2.md`.
3.  Usar `useReportsStore` para obtener datos.
4.  NO incluir lógica de cálculo. Solo renderizar.

### Bloque de Prompt para Antigravity

```markdown
## Prompt para Antigravity

### Contexto
- `documentation/03_ui_ux_design/UX_008_SMART_DAILY_SUMMARY_V2.md` (Referencia visual).
- `frontend/src/stores/reports.ts` (Store de datos).

### Objetivo
Construir el componente `SmartDailySummary.vue`.

### Requisitos Visuales (Tailwind)
1.  **Semáforo (Header):**
    - Verde: `bg-emerald-50 text-emerald-700`
    - Rojo: `bg-rose-50 text-rose-700`
    - Gris: `bg-slate-50 text-slate-700`
2.  **Hero:** Texto muy grande (`text-5xl font-bold`).
3.  **Breakdown:** Grid de 3 columnas. Cards minimalistas.
    - Iconos sugeridos (Lucide): `Banknote` (Cash), `Smartphone` (Transfer), `BookOpen` (Credit).
4.  **Alertas:** Lista vertical. Items con icono de alerta roja si es crítico.
5.  **Skeleton:** Crear un estado `v-if="reportsStore.isLoading"` con divs animados `animate-pulse`.

### Lógica TS
- `onMounted` -> `reportsStore.fetchDailySummary()`.
- Usar `computed` solo para mapear datos del store a la vista si es necesario, pero NO para recalcular valores.
```

### Comandos de Consola
```bash
# Crear archivo
```
