# PVS-A: Protocolo de Verificación Secuencial Aislada

> **Tipo:** Protocolo de ejecución — complementa a PAC-N y PEA-N, no los reemplaza.
> **Ámbito:** Re-verificación de SDDs ya producidos que quedaron en estado
> "Pendiente Re-verificación" tras la anulación del auto-reporte inicial.
> **Principio rector:** Unidad mínima de trabajo = 1 micro-paso = 1 artefacto
> crudo = 1 checkpoint. Nunca dos micro-pasos en el mismo turno. Nunca un
> resumen en vez de la evidencia misma.
>
> **Origen de la Sección 0 (Principios Anti-Sesgo):** Detectado en la
> verificación de `SDD_007_01` — el verificador declaró "🟢 APROBADO" un
> documento cuya propia evidencia (Fase A) mostraba una función RPC central
> inexistente en producción. No hubo alucinación ni mentira: el razonamiento
> parcial era correcto (el documento no fingía que la función existía), pero
> se convirtió, sin que nadie lo forzara a detenerse, en una conclusión
> total. Los correctivos puntuales por vocabulario ("no digas 'aprobado'
> sin evidencia") resultaron insuficientes porque son enumerables — el
> siguiente sesgo simplemente usa una palabra o una forma distinta no
> prevista en la lista. Por eso esta sección no enumera casos: define
> invariantes estructurales que no dependen de qué palabras, en qué
> idioma, ni sobre qué contenido esté razonando el verificador.

---

## 0. Principios Anti-Sesgo (aplican a TODA fase, no solo a Fase B)

Estos principios no son una lista de errores a evitar — son operaciones
que el verificador debe ejecutar sobre su propio trabajo antes de cerrar
cualquier conclusión, en cualquier bloque, de cualquier fase.

### 0.1 Invariante de Reconciliación por Conteo

Antes de escribir cualquier conclusión, veredicto o resumen — parcial o
final — se ejecuta este conteo mecánico:

```
N = número total de hallazgos, discrepancias, ausencias, contradicciones
    o resultados negativos que el verificador mismo produjo en cualquier
    micro-paso de esta tarea, sin importar cómo los llamó, en qué bloque
    aparecen, si parecían menores, o si ya fueron "explicados" por otra
    parte del documento auditado.
```

La conclusión DEBE contener exactamente N referencias explícitas — una
por cada hallazgo contado. Si el número de referencias en la conclusión
es menor a N, la conclusión está incompleta por definición, sin importar
qué tan bien redactada esté o qué vocabulario use. Esto es una propiedad
aritmética de la propia respuesta, no una cuestión de estilo — no se puede
evadir cambiando de palabras, porque no depende de las palabras.

### 0.2 Principio de No-Fusión de Dimensiones

Cuando una tarea evalúa más de una pregunta distinta (¿es coherente el
documento? ¿existe en producción? ¿cumple la regla de negocio? ¿es
seguro?), esas preguntas son lógicamente independientes. Una respuesta
positiva a una pregunta NUNCA se usa como justificación, evidencia, o
mitigante de una respuesta negativa a otra pregunta distinta — aunque
ambas suenen relacionadas.

**Caso específico que este principio prohíbe:** que un documento
*reconozca honestamente* una carencia ("esto falta", "deuda técnica")
es una propiedad del documento, no una resolución del problema que
describe. "El documento admite que X no existe" y "X ya funciona" son
dos afirmaciones distintas y permanecen como dos líneas distintas del
resultado — nunca se funden en una sola conclusión.

Este principio no depende de una lista de casos: es la razón estructural
por la que 0.1 funciona. La fusión de dimensiones es la operación exacta
que permite que un conteo de hallazgos "desaparezca" dentro de una
conclusión optimista. Si aparece un caso no cubierto por ningún bloque
específico de este protocolo, este principio sigue aplicando, porque no
depende del contenido del caso — depende de si el verificador está a
punto de dejar que una respuesta positiva silencie una negativa de otra
dimensión.

### 0.3 Prohibición de Citar la Fuente Auditada Como Evidencia Propia

Si la tarea es verificar/auditar un documento X, y X contiene una
afirmación sobre la realidad (ej. "la base de datos no tiene la columna
Y"), esa afirmación es **material a verificar**, nunca **evidencia ya
verificada** — sin importar cuán precisa o bien razonada parezca. Solo
cuenta como verificado lo que el verificador mismo confirmó ejecutando
su propia consulta o prueba en este proceso. Repetir la afirmación de X
con otras palabras, o citarla como si fuera un hallazgo propio, no
equivale a haberla verificado.

### 0.4 Auto-Chequeo Obligatorio Antes de Cualquier Cierre

Como último paso, siempre, antes de entregar una conclusión:

```
1. Aplicar 0.1 (contar N).
2. Aplicar 0.2 (¿alguna dimensión positiva está silenciando una negativa?).
3. Aplicar 0.3 (¿algún "hallazgo verificado" en realidad solo repite lo
   que el documento auditado ya decía de sí mismo, sin consulta propia?).
4. Si cualquiera de los tres falla: DETENER. Reescribir la conclusión
   antes de presentarla — nunca entregarla con el defecto conocido.
```

### 0.5 Alcance de Aplicación

Estos cuatro principios aplican a toda tarea de verificación, auditoría,
revisión de código o evaluación de completitud — dentro de PVS-A y fuera
de él. Cualquier instrucción de un bloque específico (Fase A, B, C) que
pida un "veredicto" se interpreta siempre a través de este filtro.

---

## Orden Lógico General

```
FASE A: AUDITORÍA (evidencia cruda, cero interpretación)
   ↓
FASE B: ANÁLISIS (clasificación de lo hallado, cero corrección todavía)
   ↓
FASE C: CORRECCIÓN (propuesta → confirmación → aplicación)
   ↓
FASE D: DOCUMENTACIÓN Y TRAZABILIDAD (persistencia, en paralelo a A-C, no al final)
```

La Fase D no es un paso posterior — se ejecuta *durante* A, B y C, escribiendo
cada checkpoint en el momento en que ocurre. Se describe al final de este
documento solo por claridad expositiva, no por orden de ejecución.

---

## Reglas Transversales (aplican a las 4 fases)

1. Un SDD a la vez. No se inicia `SDD_YYY.1` mientras `SDD_XXX` no cierre su
   Fase C (o quede formalmente detenido por un Halt).
2. Cada micro-paso tiene ID único: `SDD_XXX.N`.
3. Prohibido resumir, parafrasear de memoria, o encadenar automáticamente el
   siguiente micro-paso en la misma respuesta. Cada checkpoint se presenta y
   se detiene.
4. Si un micro-paso necesita un resultado de otro anterior del mismo SDD, se
   cita textual por su ID — nunca se reescribe de memoria.
5. Entre SDDs distintos: cero continuidad implícita. Cada SDD reinicia en `.1`.
6. Los Principios Anti-Sesgo (Sección 0) se aplican en cada checkpoint de
   cada bloque, no solo al cierre de Fase B.

---

## FASE A — Auditoría (Bloques 1 a 6)

Objetivo: reunir evidencia cruda. Ningún juicio de "está bien/mal" ocurre
todavía en esta fase — solo se recolecta y se contrasta contra el documento.

### Bloque 1 — Identificación
- `.1` Nombre y ruta exacta del SDD (cita literal del encabezado).
- `.2` Lista textual de todas las tablas que el SDD declara tocar.
- `.3` **CHECKPOINT.**

### Bloque 2 — Verificación mecánica (tabla por tabla, nunca en lote)
Por cada tabla de `.2`:
- `.4` `SELECT proname FROM pg_proc WHERE prosrc ILIKE '%<tabla>%'` — resultado crudo.
- `.5` **CHECKPOINT.**
- `.6` `SELECT tgname FROM pg_trigger WHERE tgrelid = '<tabla>'::regclass` — resultado crudo.
- `.7` **CHECKPOINT.**

### Bloque 3 — Contraste Sección 0 (PAC-N) vs. realidad
- `.8` Cita textual completa de la Sección 0 (PAC-N) del SDD.
- `.9` Cita textual de los resultados ya obtenidos en `.4`/`.6` (por ID).
- `.10` Tabla campo por campo: ¿coincide `.8` con `.9`? Sí/No individual.
- `.11` **CHECKPOINT.**

### Bloque 4 — Ciclo de vida vs. modelo de datos
- `.12` Lista textual de cada transición del Diagrama de Estados.
- `.13` Lista textual de cada campo del Modelo de Datos.
- `.14` Cruce explícito: ¿cada transición de `.12` tiene su campo de soporte en `.13`?
- `.15` **CHECKPOINT.**

### Bloque 5 — Seguridad
- `.16` Cita textual de cada mención de control de acceso.
- `.17` ¿Aparece nombrada, literal, `assert_store_access`/`get_current_store_id`? Sí/No.
- `.18` **CHECKPOINT.**

### Bloque 6 — Canal de pago (condicional)
- `.19` ¿El SDD mueve dinero? Cita textual que lo confirme o descarte.
- `.20` Si sí: ¿aparece `payment_method_id`/canal en el contrato de entrada?
- `.21` **CHECKPOINT.**

**Cierre de Fase A:** los micro-pasos `.1` a `.21` quedan escritos en el
archivo de trazabilidad del SDD (ver Fase D). No se avanza a la Fase B hasta
que los 6 bloques estén completos.

---

## FASE B — Análisis

Objetivo: convertir la evidencia cruda de la Fase A en un veredicto
clasificado y no fusionado. Aquí se interpreta, pero todavía no se corrige
nada. Cada sub-bloque aplica explícitamente los Principios Anti-Sesgo (0.1-0.4).

### Bloque 7a — Enumeración Exhaustiva de Afirmaciones Verificables
- `.22a` Listar, una por una, **sin omitir ninguna**, todas las afirmaciones
  fácticas del SDD (Sección 0 y cualquier otra) que sean verificables contra
  la base de datos real — no solo las que resultaron favorables en la Fase A.
  Cada afirmación recibe ID propio: `.22a.1`, `.22a.2`...
- `.22b` **CHECKPOINT.** Presentar la lista completa. Detenerse.

> Regla de completitud: si una afirmación del SDD no aparece en esta lista,
> ningún bloque posterior puede citarla como "verificada".

### Bloque 7b — Verificación Independiente (una afirmación a la vez)
Por cada ítem de `.22a`:
- `.22c.N` Ejecutar una consulta/prueba **propia y nueva** que confirme o
  refute la afirmación. Aplica 0.3: el texto del SDD nunca cuenta como su
  propia evidencia.
- `.22d.N` **CHECKPOINT** individual. Detenerse.

### Bloque 7c — Veredictos Por Dimensión (nunca fusionados)
Declarar explícitamente las dimensiones evaluables de este SDD (como
mínimo, siempre estas dos; se agregan más si el SDD lo amerita):

```markdown
**Dimensión 1 — Coherencia Documental:**
¿El SDD es internamente consistente? (Bloque 4: diagrama vs. modelo de
datos; Bloque 5: seguridad; Bloque 6: canal de pago). Se basa
exclusivamente en la Fase A, Bloques 1, 4, 5 y 6.

**Dimensión 2 — Correspondencia con Producción:**
De las afirmaciones verificadas en 7b, ¿cuántas confirman que lo descrito
por el SDD YA EXISTE en la base de datos, tal como está descrito? Un solo
🔴 aquí (ej. función central inexistente) determina 🔴 en esta dimensión
completa — no se promedia con los aciertos menores.

**Dimensión N (si aplica):** cualquier otra pregunta independiente que
haya surgido durante la Fase A y no encaje en las dos anteriores.
```

- `.22e` **CHECKPOINT.** Presentar cada dimensión por separado, con su
  tabla de soporte (ID de afirmación → resultado). Aplicar 0.1: contar N
  hallazgos negativos totales y confirmar que cada uno aparece referenciado
  en alguna dimensión. Detenerse.

### Bloque 7d — Clasificación Obligatoria contra Halt
- `.23` Por cada hallazgo 🔴 de **cualquier** dimensión de `7c`, clasificar
  contra H-1 a H-4 usando la definición exacta del PEA-N (citada
  textualmente, nunca reformulada de memoria).
- `.24` **CHECKPOINT.** Presentar la clasificación. Si algún hallazgo
  dispara Halt → bifurcar a "Manejo de Halt". El protocolo no continúa a
  un estado final para ese SDD hasta resolver el Halt.

### Bloque 7e — Estado Final Compuesto (nunca un solo color)
La combinación de dimensiones de `7c` determina el estado — nunca se
colapsa en un único símbolo:

| Dimensión 1 | Dimensión 2 | Estado Compuesto |
|---|---|---|
| 🟢 | 🟢 | 🟢 Confirmado — válido en documento y en producción |
| 🟢 | 🔴 | 🟡 Documento Válido / Implementación Bloqueada — no se marca 🟢 en el maestro |
| 🔴 | cualquiera | 🔴 Rechazado — corregir el documento antes de evaluar producción |

El documento maestro (`AUDITORIA_EJECUCION_PLAN_SDD.md`) recibe **ambas**
dimensiones por separado en la fila del SDD, nunca un color consolidado.

---

## FASE C — Corrección

Objetivo: resolver lo que la Fase B clasificó como corregible sin
intervención humana obligatoria, dejando rastro de cada decisión.

- `.25` Aplicar la Jerarquía de Resolución del PEA-N (Etapa 3, niveles 1-4)
  para decidir la corrección de cada hallazgo no-Halt. Nota: código faltante
  o función inexistente NUNCA se resuelve por esta jerarquía — eso es H-2
  obligatorio (ver Bloque 7d), no un vacío de regla de negocio.
- `.26` **CHECKPOINT.** Presentar el texto exacto que cambiaría en el SDD —
  sin aplicarlo todavía. Detenerse.
- `.27` Solo tras confirmación humana de `.26`: aplicar la corrección al
  documento real.
- `.28` Si la corrección involucra un contrato cruzado con otro SDD:
  registrar la fila correspondiente en el RVC (dominio que aplique).

**Cierre de Fase C:** el estado final del SDD es el Estado Compuesto de
`7e`, ajustado si `.27` corrigió alguna de las dimensiones a 🟢.

---

## Manejo de Halt (bifurcación desde `.24`)

- Detener el protocolo para ESE SDD por completo.
- No se ejecuta Fase C para ningún hallazgo de ese SDD, ni siquiera los que
  no dispararon Halt (se resuelven después, junto con el Halt, en una sola
  revisión humana).
- No se inicia el siguiente SDD de la cola hasta que el Halt quede resuelto
  con supervisión humana directa.
- El SDD queda marcado `🔴 Detenido por Halt [tipo]` en el documento maestro.

---

## FASE D — Documentación y Trazabilidad

### Dónde se guarda cada cosa

```
documentation/01_requirements/
├── VERIFICACION/
│   └── PVS_A_SDD_XXX.md        ← Fases A, B y C completas de ESE SDD
│                                  (todos los micro-pasos, en el orden
│                                  en que ocurrieron)
├── AUDITORIA_EJECUCION_PLAN_SDD.md   ← ya existente. Recibe el Estado
│                                        Compuesto (ambas dimensiones,
│                                        nunca fusionadas) en lotes de
│                                        3-4 SDDs
└── REGISTRO/
    └── RVC_<dominio>.md         ← ya existente. Recibe lo escrito en
                                     `.28`, en el momento en que ocurre
```

### Cuándo se escribe (incremental, no al final del proceso)

| Momento | Qué se escribe | Dónde |
|---|---|---|
| Al cerrar cada CHECKPOINT | El micro-paso completo, tal como se presentó | `PVS_A_SDD_XXX.md` |
| Al cerrar `.22e` | Veredictos por dimensión, sin fusionar | `PVS_A_SDD_XXX.md` |
| Al cerrar `.24` | Clasificación de Halt | `PVS_A_SDD_XXX.md` |
| Al cerrar `.27` | Texto de la corrección aplicada | `PVS_A_SDD_XXX.md` |
| Al cerrar `.28` | Fila nueva/actualizada | `RVC_<dominio>.md` |
| Cada 3-4 SDDs completados | Estado Compuesto de esos SDDs | `AUDITORIA_EJECUCION_PLAN_SDD.md` |
| Al completar los 22 SDDs | Reescritura de Secciones 3 y 4 del maestro | `AUDITORIA_EJECUCION_PLAN_SDD.md` |

Si el proceso se interrumpe a mitad de un SDD, `PVS_A_SDD_XXX.md` conserva
todo lo verificado hasta ese punto — la siguiente sesión retoma desde el
próximo micro-paso, no desde `.1`.

---

## Orden de Ejecución de los 22 SDDs Pendientes

(Heredado del plan de priorización ya aprobado — sin cambios)

1. `SDD_007_01`, `SDD_007_02` — máxima prioridad, mayor superficie de dependencias.
2. `SDD_027_01`, `SDD_027_02`, `SDD_004`, `SDD_024`, `SDD_025`, `SDD_019`,
   `SDD_026`, `SDD_006_01_01`, `SDD_006_01_02`, `SDD_006_02`, `SDD_006_03`,
   `SDD_010` — dinero e inventario.
3. `SDD_001`, `SDD_002`, `SDD_002_1`, `SDD_013`, `SDD_003`, `SDD_008`,
   `SDD_009`, `SDD_011`, `SDD_017` — seguridad y soporte.

---

## Criterio de Cierre del Proceso Completo

- Los 22 SDDs tienen su archivo `PVS_A_SDD_XXX.md` completo (Fases A-C cerradas).
- Cero filas en el maestro con estado "Pendiente Re-verificación".
- Ninguna fila del maestro tiene un color consolidado único — todas muestran
  el Estado Compuesto (ambas dimensiones).
- Secciones 3 y 4 del maestro reescritas reflejando el estado real acumulado.
- RVC actualizado con toda fila proveniente de `.28` en los 22 documentos.
