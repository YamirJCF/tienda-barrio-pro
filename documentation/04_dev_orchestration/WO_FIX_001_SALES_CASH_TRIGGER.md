## Orden de Trabajo - Backend Logic Fix: Sales to Cash

### Estado Git Actual
- **Rama:** `fix/sales-cash-trigger` (Ya creada)
- **Archivos:** `documentation/02_architecture/patches/logic_patch_01_sales_to_cash.sql` (Ya creado)

### Resumen Técnico
Se detectó que ventas no impactan caja. Se implementó un Trigger SQL (`trg_sales_to_cash`) que intercepta `INSERT` en `sales` y genera `INSERT` en `cash_movements`.

### Plan de Acción (Ejecutado)
1.  Creado parche SQL en `02_architecture/patches`.
2.  Desplegado en Supabase (Ambiente Producción).
3.  Commit de documentación y parche.

### Comandos de Consola (Referencia)
```bash
# Asegurar rama
git checkout -b fix/sales-cash-trigger

# Staging
git add documentation/02_architecture/patches/

# Commit
git commit -m "fix(backend): add trigger logic for sales-cash linking [skip ci]"
```
