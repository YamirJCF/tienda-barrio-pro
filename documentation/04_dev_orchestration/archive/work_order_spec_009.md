## Orden de Trabajo - Implementación Sistema de Historiales (SPEC-009)

### Estado Git Actual
- **Rama Base:** `main`
- **Rama a crear:** `feat/history-system`
- **Comando:** `git checkout -b feat/history-system`

---

### Fase 1: Backend & Data (Prioridad Alta)
**Objetivo:** Crear tablas de auditoría y políticas de seguridad.

#### Bloque de Prompt para Antigravity (Backend):
```markdown
# Tarea: Implementar Esquema de Historiales (Backend)

## Contexto
Revisa el archivo de arquitectura: [history_schema.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/02_ARCHITECTURE/data_models/history_schema.md)

## Objetivo
1.  Aplicar el script SQL definido en `history_schema.md` para crear las tablas `system_audit_logs` y `price_change_logs`.
2.  **IMPORTANTE:** Asegurar que la política RLS de inserción en `system_audit_logs` incluya la validación de tienda corregida en el QA Plan:
    `WITH CHECK (store_id IN (SELECT store_id FROM public.store_members WHERE profile_id = auth.uid()))`
3.  Actualizar el archivo de tipos de TypeScript para Supabase (`src/types/supabase.ts` o equivalente) para reflejar las nuevas tablas.

## Restricciones
-   NO borrar tablas existentes.
-   Respetar la nomenclatura `snake_case` para la base de datos.
```

---

### Fase 2: Frontend UI (Prioridad Media)
**Objetivo:** Crear la vista unificada y la navegación.

#### Bloque de Prompt para Antigravity (Frontend):
```markdown
# Tarea: Implementar UI de Historiales

## Contexto
-   Diseño UX: [history_ui.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/03_UI_UX_DESIGN/history_ui.md)
-   Componente actual de Reportes: `src/components/ReportsContent.vue`

## Objetivo
1.  Crear la vista `src/views/HistoryView.vue`.
2.  Implementar el sistema de Chips de filtro (Ventas, Caja, Auditoría, etc.).
3.  Crear componente reutilizable `HistoryItemCard.vue`.
4.  Modificar `src/router/index.ts` para agregar la ruta `/history` (protegida).
5.  Agregar el botón de acceso en `ReportsContent.vue`.
6.  **Requisito QA:** El filtro de empleados debe validar que solo se listen empleados de la tienda actual.

## Definición de Hecho
-   Navegación fluida desde Reportes -> Historial.
-   Chips cambian el estado de la lista (aunque por ahora muestren datos mock o vacíos si no hay backend conectado aún).
```

---

### Fase 3: Integración y Lógica (Prioridad Alta)
**Objetivo:** Conectar UI con Supabase.

#### Bloque de Prompt para Antigravity (Lógica):
```markdown
# Tarea: Integración Lógica de Historiales

## Contexto
-   Tablas creadas en Fase 1.
-   Vista creada en Fase 2.

## Objetivo
1.  Crear composable `src/composables/useHistory.ts`.
2.  Implementar la lógica para consultar `tickets`, `cash_cuts`, `system_audit_logs` según el filtro seleccionado.
3.  Implementar paginación o "Load More" (limitar a 20 items).
4.  Manejar estados de carga y error (Graceful Degradation).

## Restricciones
-   Usar `supabase-js` client existente.
-   No exponer datos de otras tiendas (el RLS debe proteger, pero el frontend debe filtrar también por `store_id`).
```

---

### Fase 4: Verificación QA (Final)
**Objetivo:** Ejecutar plan de pruebas.

#### Bloque de Prompt para Antigravity (QA):
```markdown
# Tarea: Ejecución de QA

## Contexto
-   Plan QA: [historiales_qa_plan.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/01_REQUIREMENTS/historiales_qa_plan.md)

## Objetivo
1.  Intentar realizar una inserción ilegal en `system_audit_logs` para probar RLS.
2.  Verificar que el filtro de empleados no muestre usuarios de otras tiendas.
3.  Simular fallo de red y verificar manejo de error en UI.
```
