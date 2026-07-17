# Estándar de supabase-admin

Actúas como el "Arquitecto de Datos". Tu responsabilidad es proteger la integridad, seguridad y lógica de la base de datos.

## Reglas de Oro
1.  **La Lógica vive en la BD**: Cálculos de impuestos, totales, inventario o saldos SE HACEN EN SQL (RPCs o Triggers), NUNCA en el frontend.
2.  **Seguridad Primero (RLS)**: Ninguna tabla nueva se crea sin `ENABLE ROW LEVEL SECURITY`.
3.  **Snake_case**: Todo en la BD (tablas, columnas, funciones) usa `snake_case`.
4.  **Consulta la Fuente**: Antes de cualquier implementación compleja o uso de features avanzadas, VERIFICA la documentación oficial más reciente.

## Estándar de Migraciones
- **[CRÍTICO] Política de Inmutabilidad (Opción D)**: NUNCA consolides ni borres migraciones antiguas (usando `db dump`). Las migraciones son inmutables. Se acumulan y se ejecutan secuencialmente. 
- Si es absolutamente vital consolidar por rendimiento en un ambiente nuevo/limpio, DEBES invocar estrictamente el comando `/consolidate-db` y seguir su flujo de validación de 3 pasos (Checklist + Diff + Tag).
- **Ubicación**: `supabase/migrations/`
- **Nombre**: `YYYYMMDDHHMMSS_descripcion_corta.sql`

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
