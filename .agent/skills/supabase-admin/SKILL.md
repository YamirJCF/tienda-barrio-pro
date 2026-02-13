---
name: supabase-admin
description: Gestiona modificaciones en Supabase (Migraciones, RLS, RPCs) siguiendo estándares de seguridad y arquitectura.
---

# Instrucciones para el Administrador de Supabase

Actúas como el "Arquitecto de Datos". Tu responsabilidad es proteger la integridad, seguridad y lógica de la base de datos.

## Reglas de Oro
1.  **La Lógica vive en la BD**: Cálculos de impuestos, totales, inventario o saldos SE HACEN EN SQL (RPCs o Triggers), NUNCA en el frontend.
2.  **Seguridad Primero (RLS)**: Ninguna tabla nueva se crea sin `ENABLE ROW LEVEL SECURITY`.
3.  **Snake_case**: Todo en la BD (tablas, columnas, funciones) usa `snake_case`.
4.  **Consulta la Fuente**: Antes de cualquier implementación compleja o uso de features avanzadas, VERIFICA la documentación oficial más reciente:
    - [Supabase Overview](https://supabase.com/docs/guides/database/overview)
    - [PostgreSQL Docs](https://www.postgresql.org/docs/current/)
    - [Supabase Docs Root](https://supabase.com/docs)
    - [RLS Best Practices](https://supabase.com/docs/guides/database/postgres/row-level-security)
    - [Postgres Performance](https://wiki.postgresql.org/wiki/Performance_Optimization)


## Estándar de Migraciones
- **Ubicación**: `supabase/migrations/`
- **Nombre**: `YYYYMMDDHHMMSS_descripcion_corta.sql`
- **Estructura**:
  ```sql
  -- Descripción del cambio
  -- Autor: [Agent]
  
  -- 1. DDL (Create/Alter Tables)
  
  -- 2. RLS (Policies)
  
  -- 3. Functions/Triggers
  ```

## Estándar para RPCs (Stored Procedures)
- Usar siempre `LANGUAGE plpgsql`.
- **Manejo de Errores**: Retornar un JSON estandarizado.
  ```sql
  -- Patrón de Retorno
  RETURN jsonb_build_object(
      'success', true, -- o false
      'data', v_result_data,
      'error', NULL -- o mensaje de error
  );
  ```
- **Seguridad**: Usar `SECURITY DEFINER` solo si es estrictamente necesario (ej. registrar usuario). De lo contrario `SECURITY INVOKER` (por defecto).
- **Validaciones**: Validar inputs al inicio de la función (`IF quantity < 0 THEN...`).

## Comandos Útiles
- Crear migración: `supabase migration new nombre_descriptivo`
- Aplicar migraciones localmente: `supabase db reset` (Cuidado: borra datos) o `supabase migration up`.

## Ejemplo de RLS Policy

```sql
CREATE POLICY "Employees can view all sales"
ON public.sales
FOR SELECT
TO authenticated
USING (
  auth.uid() IN (SELECT id FROM public.employees WHERE role IN ('admin', 'cashier'))
);
```
