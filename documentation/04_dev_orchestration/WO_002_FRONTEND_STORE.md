## Orden de Trabajo - Frontend Store (Pinia)

### Estado Git Actual
- Rama: `feat/smart-summary-backend` (Continuamos en la misma rama feature por ahora, o creamos `feat/smart-summary-frontend`) -> Usar `feat/smart-summary-frontend` para limpieza.
- Comando: `git checkout -b feat/smart-summary-frontend`

### Plan de Acción Atómico
1.  Crear archivo `frontend/src/stores/reports.ts`.
2.  Definir la interfaz `DailySummary` que mapee EXACTAMENTE el JSON del RPC.
3.  Implementar el store `useReportsStore` con:
    - State: `summary` (DailySummary | null), `loading` (boolean), `error` (string | null).
    - Action: `fetchDailySummary(date?: string)` que llame a `supabase.rpc('get_daily_summary', ...)`

### Bloque de Prompt para Antigravity

```markdown
## Prompt para Antigravity

### Contexto
- `documentation/02_architecture/DATA_MODEL_RPC_REPORTES.md` (Para ver estructura JSON salida).
- `frontend/src/stores/auth.ts` (Referencia para uso de Supabase client).

### Objetivo
Crear `frontend/src/stores/reports.ts` que maneje el estado del resumen diario.

### Requisitos Técnicos
1.  **Iterface:** Define `DailySummary` y sus sub-interfaces (`TrafficLight`, `MoneyBreakdown`, `Alert`, `Reminder`).
2.  **State:**
    - `data`: De tipo `DailySummary | null`.
    - `isLoading`: boolean.
    - `error`: string | null.
3.  **Action `fetchDailySummary`:**
    - Recibe `date` (Date object o string YYYY-MM-DD). Default a hoy.
    - Usa `supabase.rpc('get_daily_summary', { p_store_id: authStore.user.storeId, p_date: ... })`.
    - Maneja estados de carga y error.

### Definición de Hecho (DoD)
- El archivo `stores/reports.ts` compila sin errores de TS.
```

### Comandos de Consola
```bash
git checkout -b feat/smart-summary-frontend
# Crear archivo
```
