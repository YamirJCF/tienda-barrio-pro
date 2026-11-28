# Reglas Específicas del Proyecto (Tienda Barrio Pro)

## 1. Autoridad del Backend y Flujo Unidireccional

La arquitectura separa estrictamente **Backend = Autoridad de la Verdad** (Supabase: PostgreSQL, RPCs, RLS) y **Frontend = Consumidor de Experiencia** (Vue + Pinia):

- **Cálculos y Reglas Críticas en Servidor:** Toda operación financiera (totales, impuestos, descuentos, saldos) y validación real de stock o permisos ocurre en PostgreSQL/RPC/RLS. Prohibido calcular totales de negocio o decidir permisos de seguridad en `.vue`/`.ts` (el frontend solo valida formato de entrada y aplica estilo visual, ej. pintar rojo un negativo).
- **Flujo de Una Sola Vía (`UI → Store → Supabase`):** Los Stores de Pinia son caché temporal, nunca fuente de verdad. Asume que cualquier dato en memoria puede estar obsoleto; toda escritura re-valida invariantes en el Backend.
- **Espera, Bloqueo y Cero Optimistic UI en Dinero/Stock:** Las lecturas muestran *Skeletons* acordes a la estructura real; las mutaciones (`POST`/RPC) muestran estado de carga y bloquean doble envío hasta resolver la promesa. Prohibido usar *Optimistic UI* en operaciones de dinero, caja o inventario.
- **Contrato de Esquema:** Prohibido agregar campos "mockeados" en componentes o stores que no existan previamente en el contrato de datos del Backend.

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

Ningún ítem de una checklist, plan o reporte de verificación puede marcarse como completado (✅) sin evidencia de ejecución real (output de consola, screenshot, log). "El código se ve correcto" o "debería funcionar" se marca como parcial (🟡), nunca como aprobado.

Toda funcionalidad con una rama de "caso límite" o "excepción" (remanente, error, rechazo, límite superado) debe probarse ejecutando específicamente ESA rama — no solo el camino feliz (happy path). Un bug puede sobrevivir indefinidamente si solo se prueba el caso exitoso.

## 6. Auditoría de Impacto Cruzado Antes de Modificar Esquema Compartido

Antes de introducir un nuevo valor de enum/tipo (ej. un nuevo `movement_type`, `status`, o similar) o modificar el comportamiento de una tabla usada por más de un módulo, ejecuta:

    SELECT proname FROM pg_proc WHERE prosrc ILIKE '%<nombre_tabla_o_columna>%';

Revisa cada función que aparezca en el resultado antes de aplicar el cambio. Ninguna migración que toque una tabla compartida entre módulos se considera completa sin haber listado explícitamente qué otras funciones la usan y confirmado que ninguna se rompe.

## 7. Documentación Explícita de Trade-offs y Alcance Diferido

Toda simplificación de alcance ("MVP", "por ahora", "fuera de alcance", "se difiere") debe registrarse con tres elementos explícitos: qué se decidió, por qué (el trade-off concreto), y bajo qué condición futura se debería revisar. No basta con marcar algo como "pendiente" sin esa justificación — la ausencia de razón documentada es en sí misma una señal de que la decisión no fue deliberada.

## 8. Privilegios Base en Tablas Nuevas

Toda tabla nueva creada vía migración SQL debe incluir explícitamente `GRANT ALL ON TABLE <tabla> TO anon, authenticated, service_role;` (o los roles relevantes) — Supabase Cloud NO lo asigna automáticamente fuera del dashboard, a diferencia de crear la tabla vía UI. La omisión de esto provoca errores 42501 (Permission Denied) que pueden confundirse con fallos de RLS impidiendo el paso a producción.

## 9. Principios Anti-Sesgo (Verificación y Auditoría)

Estos principios son operaciones obligatorias que el verificador debe ejecutar sobre su propio trabajo antes de cerrar cualquier conclusión, en cualquier bloque o fase de verificación.

### 9.1 Invariante de Reconciliación por Conteo
Antes de escribir cualquier conclusión, veredicto o resumen, ejecuta este conteo mecánico:
`N = número total de hallazgos, discrepancias, ausencias, contradicciones o resultados negativos producidos`
La conclusión DEBE contener exactamente N referencias explícitas — una por cada hallazgo contado. Si el número de referencias es menor a N, la conclusión está incompleta y debe reescribirse.

### 9.2 Principio de No-Fusión de Dimensiones
Cuando una tarea evalúa más de una pregunta distinta (ej. ¿existe en producción? vs ¿cumple la regla de negocio?), una respuesta positiva a una pregunta NUNCA se usa como justificación, evidencia o mitigante de una respuesta negativa a otra.
**Ejemplo prohibido:** Que un documento admita una carencia ("deuda técnica") es una propiedad del documento, no una resolución. "El documento admite que X no existe" y "X ya funciona" no deben fundirse en una sola conclusión optimista que silencie el hallazgo negativo.

### 9.3 Prohibición de Citar la Fuente Auditada Como Evidencia Propia
Si la tarea es auditar un documento X, y X contiene una afirmación (ej. "la base de datos no tiene la columna Y"), esa afirmación es **material a verificar**, nunca **evidencia ya verificada**. Solo cuenta como verificado lo que se confirmó ejecutando una consulta o prueba propia en el proceso.

### 9.4 Auto-Chequeo Obligatorio Antes de Cualquier Cierre
Como último paso antes de entregar una conclusión:
1. Aplicar 9.1 (contar N hallazgos y confirmar su inclusión).
2. Aplicar 9.2 (verificar que ninguna dimensión positiva silencie una negativa).
3. Aplicar 9.3 (confirmar que los "hallazgos verificados" no repiten lo que el documento auditado ya decía de sí mismo sin consulta propia).
4. Si cualquiera de los tres falla: DETENER. Reescribir la conclusión antes de presentarla.

## 10. Ecógrafo Estructural de Resolución (Diagnóstico Mecánico vs. Solución Creativa)

**Disparador (Modo Quirúrgico):** Obligatorio al resolver bugs, discrepancias o modificar tablas, RPCs, servicios o Stores compartidos (exento en cambios puramente visuales/cosméticos). El cumplimiento está protegido por el hook `pre-commit` (`scripts/verify-impact-hook.mjs`), que bloquea commits en capas compartidas sin un sello de escaneo activo.

### 10.1 Fase A — Diagnóstico 100% Mecánico (Cero Creatividad / Cero Suposiciones)
Antes de proponer o editar código en capas compartidas, es OBLIGATORIO ejecutar:

    node scripts/scan-impact.mjs <entidad_tabla_rpc_o_store>

Con el output real de consola (y la consulta de la Regla 6 si toca SQL), imprime este cuadro de 4 líneas antes de modificar archivos:
1. **Origen Real del Fallo:** `[Dato en BD | Contrato RPC | Estado en Store | Render en UI]`
2. **Contratos RVC Activos:** `[Filas devueltas en el Eje 1 del escáner]`
3. **Radio de Explosión:** `[Archivos .sql, .ts y .vue devueltos en los Ejes 2 y 3 que consumen el objeto]`
4. **Semáforo de Frontera (Muros Inviolables):**
   - 🚫 **Muro 1 (Autoridad):** Si el fallo es de dato o cálculo financiero/stock → Prohibido parchar en `.vue`/`.ts` (ir a SQL).
   - 🚫 **Muro 2 (Acoplamiento):** Si el cambio altera firma o payload compartido → Obligatorio actualizar todos los consumidores del punto 3.
   - 🚫 **Muro 3 (Visibilidad):** Prohibido usar valores por defecto (`0`, `null`, `[]`, `catch` vacío) para silenciar el error (Regla 3).

### 10.2 Fase B — Solución Creativa dentro de la Cancha
Una vez fijados los muros de la Fase A, aplica creatividad técnica para resolver la causa raíz sin efectos secundarios. Cuando el problema admita más de un camino arquitectónico o de experiencia de usuario, **propón 2 o 3 opciones creativas viables** que respeten estrictamente los contratos del punto 2 y la integridad de los vecinos del punto 3.

## 11. Inmutabilidad y Aislamiento de Flujos de Correo/Auth, Creación de Cuentas y Datos Iniciales (Docker vs. Cloud)

Dado que la infraestructura externa de **Correo / Auth** (despacho SMTP real, enlaces de confirmación/recuperación de Supabase Cloud) y el **estado de datos de producción** no son ejecutables de extremo a extremo dentro de Docker local, rigen tres muros obligatorios:

### 11.1 Prohibición de Modificar Comportamiento de Auth y Creación de Cuentas por Pruebas Locales
- Está **terminantemente prohibido** modificar, debilitar, agregar banderas (`if (isLocal)`, bypass de `email_confirmed_at`) o cambiar el comportamiento de registro, login, verificación de correo, recuperación de contraseña o creación atómica de tienda (`handle_new_user_atomic`, `SDD-029`, guardias de `router/index.ts`, `RegisterStoreView.vue`, `CheckEmailView.vue`) en `frontend/src/` o `supabase/migrations/` para "adaptarlos" a Docker.
- Lo que no se puede probar de extremo a extremo en local **no se toca ni se altera**.

### 11.2 Aislamiento Estricto de Creación de Cuentas y Datos Iniciales
- **Estado Inicial Canónico:** Toda cuenta y tienda nueva nace exclusivamente a través del flujo oficial de servidor con sus tablas operativas limpias (en cero) y catálogos base oficiales. Queda prohibido inyectar datos semilla, productos ficticios, saldos iniciales o atajos de onboarding dentro de migraciones productivas (`supabase/migrations/`) o código de interfaz (`frontend/src/`).
- **Frontera de Semillas de Prueba:** Cualquier confirmación manual de usuario o carga de datos para pruebas en Docker debe realizarse **únicamente por fuera del código productivo y de las migraciones** (vía ejecución SQL efímera en consola sobre `supabase_db_prueba` o scripts en `supabase/tests/` con `BEGIN; ... ROLLBACK;`), garantizando que **cero datos o parches de prueba pasen a Supabase Cloud**.

### 11.3 Compuerta de Bloqueo en Flujos Aislados
- Si durante una tarea se detecta cualquier necesidad de tocar `auth`, envío de correos, triggers de alta de cuenta o inicialización de datos de tienda, el agente debe **detenerse y pedir autorización explícita al usuario**, manteniendo esos flujos 100% blindados y separados del resto de módulos operativos (Caja, POS, Inventario, Clientes, Reportes).

## 12. Gobernanza de Arquitectura UX, Flujos y Señalización (Blindaje en 5 Anillos)

Toda modificación o adición en la interfaz, rutas, modales globales o alertas se rige por [`documentation/03_ui_ux_design/UX_ARQUITECTURA_SISTEMA.md`](../documentation/03_ui_ux_design/UX_ARQUITECTURA_SISTEMA.md) y su manifiesto ejecutable [`documentation/03_ui_ux_design/ux-manifest.json`](../documentation/03_ui_ux_design/ux-manifest.json):

### 12.1 Consulta Obligatoria y Gate UX-0
- Antes de proponer o modificar flujos, rutas o modales, es obligatorio leer `UX_ARQUITECTURA_SISTEMA.md`, `ux-manifest.json` y la ficha del Contexto correspondiente (`documentation/03_ui_ux_design/CONTEXTOS/C1..C8`, cuando exista).
- Ninguna ruta, vista nueva, overlay global en `App.vue` ni cambio a `BottomNav.vue` puede implementarse sin superar antes el **Gate UX-0** (4 preguntas obligatorias: `Contexto y Objeto ORCA`, `Verdad Contable / Read Model`, `Arquetipo A–F + Matriz N1–N5 + Top Tasks`, `Higiene de Crecimiento`) registrado en `documentation/03_ui_ux_design/UX_ADR_LOG.md`.

### 12.2 Regla de 2 Commits Separados y Prohibiciones Mecánicas
- **Separación obligatoria:** Prohibido mezclar cambios a `ux-manifest.json`, `UX_ARQUITECTURA_SISTEMA.md`, `ux-fitness.spec.ts`, `.githooks/`, `scripts/verify-*.mjs` o `.agent/` con cambios de código de producto (`frontend/src/views/**`, `components/**`, `stores/**`, `composables/**`, `data/**`, `router/**`, `App.vue`) en el mismo commit.
- **Protocolo para cambios estructurales UX:** (1) Commit arquitectónico exclusivo con nueva entrada `UX-ADR-XXX` y marcador `[UX-ARCH-APPROVED]`; (2) Commit de implementación alineado 1:1 con `ux-manifest.json`.
- **Prohibiciones absolutas:**
  - Prohibido usar `git commit --no-verify` o evadir `.githooks/pre-commit` / `.githooks/commit-msg`.
  - Prohibido debilitar `frontend/src/__tests__/architecture/ux-fitness.spec.ts` (`.skip`, `.only`, `.todo`, `xit`, `xdescribe` o eliminar aserciones).
  - Prohibido aumentar cualquier array de `baselineDebt` en `ux-manifest.json` (solo puede reducirse o mantenerse igual).
  - Prohibido introducir `alert()`, `confirm()`, `prompt()`, importaciones nuevas de `vue-toastification` o usos nuevos de `material-icons`.
- **Invariante Regla 11:** Las rutas y subvistas del Contexto `C8` marcadas como `blindada` (incluyendo `GatekeeperPending.vue`) no se modifican salvo autorización explícita del usuario.

