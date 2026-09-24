---
name: consolidate-db
description: Protocolo estricto de seguridad para consolidar migraciones de Supabase sin pérdida de datos ni funciones.
---

# Workflow: Consolidación Segura de BD

Este proceso debe seguirse RIGUROSAMENTE antes de borrar cualquier migración `.sql` antigua para consolidarlas en un único `init.sql`.

## Fase 1: Snapshot del Estado Actual (ANTES)
Crea snapshots de todo lo que existe actualmente en la base de datos de producción (o ambiente equivalente al 100%).

1. Extrae funciones (RPCs):
   ```bash
   # // turbo
   supabase db execute "SELECT routine_name FROM information_schema.routines WHERE routine_schema='public' ORDER BY routine_name;" > .temp/pre_rpc.txt
   ```
2. Extrae las tablas y columnas:
   ```bash
   # // turbo
   supabase db execute "SELECT table_name || '.' || column_name FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name, column_name;" > .temp/pre_cols.txt
   ```
3. Extrae triggers:
   ```bash
   # // turbo
   supabase db execute "SELECT event_object_table || '.' || trigger_name FROM information_schema.triggers WHERE event_object_schema IN ('public', 'auth') ORDER BY event_object_table;" > .temp/pre_triggers.txt
   ```

## Fase 2: Consolidación
1. Usa la CLI para generar el archivo consolidado provisional:
   ```bash
   supabase db dump --local --data-only=false > .temp/consolidated_init.sql
   ```
2. Resetea localmente la BD (limpia) y aplica el archivo consolidado. **ESTO ES PELIGROSO LOCALMENTE, NUNCA EN PROD**.
   ```bash
   supabase db reset --skip-scripts
   ```

## Fase 3: Snapshot de Consolidación (DESPUÉS)
1. Extrae todo de nuevo:
   ```bash
   # // turbo-all
   supabase db execute "SELECT routine_name FROM information_schema.routines WHERE routine_schema='public' ORDER BY routine_name;" > .temp/post_rpc.txt
   supabase db execute "SELECT table_name || '.' || column_name FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name, column_name;" > .temp/post_cols.txt
   supabase db execute "SELECT event_object_table || '.' || trigger_name FROM information_schema.triggers WHERE event_object_schema IN ('public', 'auth') ORDER BY event_object_table;" > .temp/post_triggers.txt
   ```

## Fase 4: Matriz de Diferencias (Diff)
Compara los resultados (puedes usar comandos `diff` de git o un visualizador):
```bash
# // turbo-all
diff --strip-trailing-cr .temp/pre_rpc.txt .temp/post_rpc.txt
diff --strip-trailing-cr .temp/pre_cols.txt .temp/post_cols.txt
diff --strip-trailing-cr .temp/pre_triggers.txt .temp/post_triggers.txt
```

> [!CAUTION]  
> SI ALGO FALTA, NO CONTINÚES. Abre el `.temp/consolidated_init.sql` y agrega manualmente lo que el `db dump` haya omitido (comúnmente omiten triggers o permisos GRANT y RPCs). REPITE LA FASE 2 y 3.

## Fase 5: Commitment
Si el `diff` es limpio (idénticos), entonces:
1. Crea un Git Tag:
   ```bash
   git tag -a "pre-consolidation-$(date +%Y-%m-%d)" -m "Backup antes de borrar migraciones"
   ```
2. Reemplaza el primer `init.sql` con el consolidado.
3. Borra los archivos `.sql` antiguos que fueron consolidados.
4. Mueve todo de `.temp/` a la basura.
