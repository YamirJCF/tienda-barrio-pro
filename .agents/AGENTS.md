# Reglas Específicas del Proyecto (Tienda Barrio Pro)

## 2. Verificación de Esquema Real (Anti-Alucinación de Nombres)

Antes de escribir CUALQUIER línea de SQL, RPC o migración que referencie una tabla o columna que no fue creada en esta misma tarea, es OBLIGATORIO ejecutar primero:

    SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '<tabla>';

El resultado crudo de esa consulta debe citarse explícitamente antes de escribir el código. Nunca asumas un nombre de tabla/columna por analogía con otro proyecto, otro documento, o "cómo normalmente se llamaría". Postgres NO valida referencias dentro de un bloque `plpgsql` hasta tiempo de ejecución — que una función se cree sin error NO significa que los nombres sean correctos. Si el nombre no se pudo verificar contra el esquema real, dilo explícitamente en vez de asumir.

## 3. Prohibición de Fallos Silenciosos

Ningún bloque `EXCEPTION`, `catch`, o guardia condicional puede convertir un error en un resultado que parezca válido (0, `null`, lista vacía, "$0", pantalla en blanco sin aviso).

- Prohibido usar `IF EXISTS (SELECT ... information_schema.tables ...)` para "tolerar" que una tabla o función dependiente no exista. Si la dependencia es obligatoria para la lógica de negocio, debe fallar con `RAISE EXCEPTION` explícito y describir la ausencia — nunca saltarse el paso en silencio.
- Todo `EXCEPTION WHEN OTHERS` en un RPC debe relanzar el error (`RAISE`) para que se propague al cliente como error real, nunca devolver un JSON con forma distinta al payload exitoso (`success:false` disfrazado de dato válido).
- Antes de dar por cerrada cualquier tarea, responde explícitamente: "¿qué ve el usuario en pantalla/logs si esto falla?" Si la respuesta es "lo mismo que cuando funciona correctamente", la tarea no está completa.

## 4. Reutilización Obligatoria de Funciones de Seguridad Centralizadas

Antes de escribir cualquier política RLS o validación de acceso nueva, ejecuta primero:

    SELECT proname FROM pg_proc WHERE proname ILIKE '%store_access%' OR proname ILIKE '%current_store%';

Si existe una función centralizada de validación de acceso (ej. `get_current_store_id()`, `assert_store_access()`), la política nueva DEBE usarla. Está prohibido reimplementar el `EXISTS`/`JOIN` de validación de tienda desde cero en cada tabla nueva — hacerlo introduce inconsistencias entre tablas (algunas reconocen admins, otras no) que son difíciles de detectar después.

## 5. Distinción Obligatoria entre "Código Revisado" y "Probado con Evidencia"

Ningún ítem de una checklist, plan o reporte de verificación puede marcarse como completado (✅) sin evidencia de ejecución real (output de consola, screenshot, log). "El código se ve correcto" o "debería funcionar" se marca como parcial (🟡), nunca como approved.

Toda funcionalidad con una rama de "caso límite" o "excepción" (remanente, error, rechazo, límite superado) debe probarse ejecutando específicamente ESA rama — no solo el camino feliz (happy path). Un bug puede sobrevivir indefinidamente si solo se prueba el caso exitoso.

## 6. Auditoría de Impacto Cruzado Antes de Modificar Esquema Compartido

Antes de introducir un nuevo valor de enum/tipo (ej. un nuevo `movement_type`, `status`, o similar) o modificar el comportamiento de una tabla usada por más de un módulo, ejecuta:

    SELECT proname FROM pg_proc WHERE prosrc ILIKE '%<nombre_tabla_o_columna>%';

Revisa cada función que aparezca en el resultado antes de aplicar el cambio. Ninguna migración que toque una tabla compartida entre módulos se considera completa sin haber listado explícitamente qué otras funciones la usan y confirmado que ninguna se rompe.

## 7. Documentación Explícita de Trade-offs y Alcance Diferido

Toda simplificación de alcance ("MVP", "por ahora", "fuera de alcance", "se difiere") debe registrarse con tres elementos explícitos: qué se decidió, por qué (el trade-off concreto), y bajo qué condición futura se debería revisar. No basta con marcar algo como "pendiente" sin esa justificación — la ausencia de razón documentada es en sí misma una señal de que la decisión no fue deliberada.

## 8. Privilegios Base en Tablas Nuevas

Toda tabla nueva creada vía migración SQL debe incluir explícitamente `GRANT ALL ON TABLE <tabla> TO anon, authenticated, service_role;` (o los roles relevantes) — Supabase Cloud NO lo asigna automáticamente fuera del dashboard, a diferencia de crear la tabla vía UI. La omisión de esto provoca errores 42501 (Permission Denied) que pueden confundirse con fallos de RLS impidiendo el paso a producción.
