# Lista Completa de los 28 Micro-pasos del Protocolo PVS-A

## FASE A — Auditoría
### Bloque 1 — Identificación
- **.1** Confirmar nombre exacto y ruta del SDD objetivo (cita literal del encabezado).
- **.2** Extraer, una por una, listadas textualmente, todas las tablas que el SDD declara tocar (cita literal de la sección donde aparecen).
- **.3** CHECKPOINT — presentar la lista completa. Detenerse. Guardar en `PVS_A_SDD_XXX.md`.

### Bloque 2 — Verificación mecánica
- [x] .4 Ejecutar `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%<tabla>%'` — pegar resultado crudo completo (stdout de psql).
- [x] .5 CHECKPOINT sobre esa tabla específica. Detenerse. Guardar en `PVS_A_SDD_006_03.md`.
- [x] .6 Ejecutar `SELECT tgname FROM pg_trigger WHERE tgrelid = '<tabla>'::regclass` — pegar resultado crudo completo (stdout de psql).
- [x] .7 CHECKPOINT sobre esa tabla específica. Detenerse. Guardar en `PVS_A_SDD_006_03.md`.

### Bloque 3 — Contraste Sección 0 vs. realidad
- [x] .8 Citar textualmente (comillas, sin editar) el contenido completo de la Sección 0 del SDD.
- [x] .9 Citar textualmente los resultados crudos ya obtenidos en .4/.6.
- [x] .10 Tabla explícita campo por campo: ¿coincide .8 con .9? Sí/No por cada fila.
- [x] .11 CHECKPOINT. Detenerse. Guardar en `PVS_A_SDD_006_03.md`.

### Bloque 4 — Ciclo de vida vs. modelo de datos
- [x] .12 Listar, una por una, todas las transiciones del Diagrama de Estados (cita literal de cada flecha/estado).
- [x] .13 Listar, uno por uno, todos los campos del Modelo de Datos declarado en la Sección correspondiente.
- [x] .14 Tabla de cruce explícito: por cada transición de .12, ¿existe en .13 el campo que la soporta? Sí/No individual.
- [x] .15 CHECKPOINT. Detenerse. Guardar en `PVS_A_SDD_006_03.md`.

### Bloque 5 — Seguridad
- [x] .16 Citar textualmente cada mención de control de acceso en la Sección de Seguridad.
- [x] .17 Señalar explícitamente: ¿aparece nombrada, literal, la función `assert_store_access`/`get_current_store_id`? Sí/No.
- [x] .18 CHECKPOINT. Detenerse. Guardar en `PVS_A_SDD_006_03.md`.

### Bloque 6 — Canal de pago (condicional)
- [x] .19 Confirmar con cita textual si el SDD mueve dinero.
- [x] .20 Si .19 es sí: buscar y citar textualmente si `payment_method_id`/canal aparece en el contrato de entrada.
- [x] .21 CHECKPOINT. Detenerse. Guardar en `PVS_A_SDD_006_03.md`.

## FASE B — Análisis
- [x] .22 Compilar el veredicto (Formato: Estado, Hallazgos con sección del SDD afectada, Gates actualizados) citando el ID de cada micro-paso de la Fase A.
- [x] .23 Por cada hallazgo de .22, clasificarlo contra las condiciones de Halt del PEA-N (H-1 a H-4). Sí/No explícito por hallazgo.
- [x] .24 CHECKPOINT. Presentar el veredicto clasificado. Detenerse. Guardar en `PVS_A_SDD_006_03.md`.

## FASE C — Corrección
- **.25** Aplicar la Jerarquía de Resolución del PEA-N para decidir la corrección de cada hallazgo no-Halt.
- **.26** CHECKPOINT. Presentar el texto exacto que cambiaría en el SDD — sin aplicarlo todavía. Detenerse. Guardar en `PVS_A_SDD_XXX.md`.
- **.27** Solo tras confirmación humana de .26: aplicar la corrección al documento real.
- **.28** Si la corrección involucra un contrato cruzado con otro SDD: registrar la fila correspondiente en el RVC (`RVC_<dominio>.md`).
