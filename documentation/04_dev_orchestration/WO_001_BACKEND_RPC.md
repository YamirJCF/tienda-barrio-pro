## Orden de Trabajo - Backend Logic (RPC)

### Estado Git Actual
- Rama sugerida: `feat/smart-summary-backend`
- Comando: `git checkout -b feat/smart-summary-backend`

### Plan de Acción Atómico
1.  Crear archivo de migración SQL `supabase/migrations/20260204_get_daily_summary.sql`.
2.  Copiar el contenido SQL validado en `DOCUMENTATION/02_ARCHITECTURE/DATA_MODEL_RPC_REPORTES.md`.
3.  Aplicar migración usando `supabase migration up` (o equivalente manual si no hay CLI configurado).
4.  Verificar que el RPC existe y devolver un JSON válido.

### Bloque de Prompt para Antigravity

```markdown
## Prompt para Antigravity

### Contexto
- `documentation/02_architecture/DATA_MODEL_RPC_REPORTES.md` (Contiene el código fuente SQL aprobado).

### Objetivo
1.  Crear el archivo `supabase/migrations/20260204120000_get_daily_summary.sql`.
2.  El contenido debe ser EXACTAMENTE el bloque SQL definido en el documento de arquitectura.
3.  No intentes modificar la lógica "traffic_light" ni "alerts". Úsala tal cual.

### Restricciones
- NO modifiques tablas existentes. Solo crea la función `get_daily_summary`.
- El nombre del archivo debe seguir el timestamp actual para evitar conflictos.

### Definición de Hecho (DoD)
- El archivo `.sql` existe en la carpeta migrations.
```

### Comandos de Consola
```bash
git checkout -b feat/smart-summary-backend
# Crear archivo (el agente lo hará)
```
