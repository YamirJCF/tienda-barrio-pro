---
description: Protocolo de Pre-Análisis Contextual (PAC) - Secuencia inmutable de verificación antes de redactar cualquier SDD. Cada bloque es un gate obligatorio. No se puede avanzar al siguiente bloque sin declarar la evidencia real del bloque anterior.
---

# 🔒 Workflow: PAC-SDD — Protocolo de Verificación Previo a Redacción de SDD

> **REGLA DE ORO:** Este workflow es una secuencia de bloques inmutables. Cada bloque produce una **DECLARACIÓN DE CIERRE** con evidencia real. Sin esa declaración, el siguiente bloque está bloqueado. Asumir que un paso se realizó sin mostrar su output es una violación del protocolo equivalente a omitirlo.

> **PROHIBICIÓN ABSOLUTA:** Ningún resumen narrativo ("Se verificó que...", "La auditoría confirmó que...") reemplaza el output real (resultado de consulta, cita textual, lista de nombres). Si el output no puede mostrarse, el bloque falla y se debe declarar el fallo explícitamente.

> **AUTO-CORRECCIÓN AUTÓNOMA (CERO DEPENDENCIA DEL USUARIO):** El usuario NO validará sus pasos. Usted DEBE auto-validarse. Al final de la recolección de datos de cada bloque (antes de emitir la Declaración de Cierre), el Agente Principal **DEBE invocar un subagente independiente** (ej. usando `invoke_subagent` con rol de "Auditor QA") pasándole la evidencia recolectada. El subagente verificará independientemente la base de datos o los documentos y responderá APROBADO o RECHAZADO con las correcciones. Solo con el APROBADO del subagente, el Agente Principal puede imprimir la Declaración de Cierre del bloque y avanzar.

---

## ⚡ ACTIVACIÓN

Este workflow se activa antes de comenzar CUALQUIER SDD nuevo. Invocarlo con:

```
/pac-sdd [NÚMERO] [NOMBRE_DEL_SDD]
Ejemplo: /pac-sdd 008 REPORTES
```

---

## BLOQUE 0 — DECLARACIÓN DE ALCANCE
> **Propósito:** Establecer el contrato de trabajo antes de tocar cualquier archivo.  
> **GATE:** No se puede abrir el FRD ni ningún archivo hasta que este bloque esté completo.

### Pasos obligatorios (todos, en orden):

**B0.1** — Declarar el SDD objetivo:
- Número de SDD
- Nombre completo
- Ruta exacta del FRD fuente

**B0.2** — Declarar la Fase del Plan Maestro:
- Leer `implementation_plan.md` y citar el ítem exacto que corresponde a este SDD.

**B0.3** — Declarar SDDs vecinos conocidos:
- Listar los SDDs ya completados que tienen relación directa con el módulo (consultando `task.md`).

**B0.4 [VERIFICACIÓN INDEPENDIENTE]** — Invocar subagente:
- El Orquestador lanza un subagente para que lea el `implementation_plan.md` y `task.md` y confirme que el SDD objetivo y sus vecinos son correctos y que la fase corresponde.
- Si el subagente rechaza, el Orquestador se auto-corrige.

### 📋 DECLARACIÓN DE CIERRE BLOQUE 0:
```
✅ BLOQUE 0 CERRADO
SDD Objetivo: SDD-[NNN] [NOMBRE]
FRD Fuente: [ruta exacta]
Fase del Plan: [nombre de la fase]
SDDs Vecinos Declarados: [lista]
PROCEDO AL BLOQUE 1.
```

---

## BLOQUE 1 — LECTURA Y CITA DEL FRD
> **Propósito:** Leer el FRD completo y extraer las restricciones de negocio antes de tocar el código.  
> **GATE:** No se puede abrir ningún archivo de código (.sql, .ts, .vue) hasta que este bloque esté completo.

### Pasos obligatorios (todos, en orden):

**B1.1** — Abrir y leer el FRD fuente completo (no un resumen, el archivo).

**B1.2** — Extraer y CITAR LITERALMENTE (copiar el texto, no parafrasear):
- Todas las Reglas de Negocio (con su número exacto: RN-XXX-NN)
- Todos los Casos de Uso (con sus pre y postcondiciones)
- Todos los Criterios de Aceptación

**B1.3** — Identificar y declarar qué datos cruzan a otros módulos (entidades compartidas mencionadas en el FRD).

**B1.4 [VERIFICACIÓN INDEPENDIENTE]** — Invocar subagente:
- El Orquestador delega al subagente la lectura del archivo FRD original y le pide que valide si las Reglas, Casos de Uso y Entidades extraídas por el Orquestador están 100% completas y sin paráfrasis.
- Si el subagente detecta omisiones, el Orquestador corrige la extracción.

### 📋 DECLARACIÓN DE CIERRE BLOQUE 1:
```
✅ BLOQUE 1 CERRADO
Reglas de Negocio extraídas: [N] reglas. (Citar todas por nombre)
Casos de Uso identificados: [N] casos. (Citar todos por nombre)
Criterios de Aceptación: [N] criterios.
Entidades compartidas detectadas en FRD: [lista]
PROCEDO AL BLOQUE 2.
```

---

## BLOQUE 2 — VERIFICACIÓN DE ESQUEMA REAL (Anti-Alucinación)
> **Propósito:** Verificar contra la base de datos real cada tabla que el SDD referenciará.  
> **GATE:** Ninguna tabla o columna puede aparecer en el SDD sin haber sido verificada en este bloque. Si una tabla no se verificó aquí, no puede usarse en el SDD.

### Pasos obligatorios (todos, en orden):

**B2.1** — Para CADA tabla que el SDD mencionará, ejecutar la consulta:
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = '<nombre_tabla>'
ORDER BY ordinal_position;
```
El resultado RAW de cada consulta debe pegarse aquí, en este bloque. No se admite "la tabla tiene columnas X, Y, Z" sin el output de la consulta.

**B2.2** — Para cada tabla verificada, declarar explícitamente:
- Nombre real de columnas vs. nombre funcional que el FRD usa (ej: `username` = "Alias Numérico")
- Columnas que el FRD menciona pero que NO EXISTEN en la base de datos (esto es una BRECHA, se declara, no se ignora)

**B2.3** — Si alguna tabla mencionada en el FRD no existe en la base de datos, declararlo como **BRECHA CRÍTICA**.

**B2.4 [VERIFICACIÓN INDEPENDIENTE]** — Invocar subagente:
- El Orquestador envía el output RAW de las consultas al subagente. El subagente ejecuta sus propias consultas `SELECT ... FROM information_schema.columns` para confirmar que el Orquestador no alucinó los resultados ni omitió columnas críticas.
- Si el subagente detecta discrepancias, el Orquestador rectifica el modelo.

### 📋 DECLARACIÓN DE CIERRE BLOQUE 2:
```
✅ BLOQUE 2 CERRADO
Tablas verificadas: [lista con nombre]
Brechas de nomenclatura detectadas: [lista o "ninguna"]
Brechas críticas (tablas inexistentes): [lista o "ninguna"]
PROCEDO AL BLOQUE 3.
```

---

## BLOQUE 3 — AUDITORÍA DE FUNCIONES DE SEGURIDAD CENTRALIZADAS
> **Propósito:** Identificar las funciones de acceso centralizadas que DEBEN usarse.  
> **GATE:** Ninguna política RLS ni validación de acceso puede diseñarse en el SDD sin haber ejecutado este bloque.

### Pasos obligatorios (todos, en orden):

**B3.1** — Ejecutar la consulta de funciones de seguridad centralizadas:
```sql
SELECT proname, prosrc
FROM pg_proc
WHERE proname ILIKE '%store_access%'
   OR proname ILIKE '%current_store%'
   OR proname ILIKE '%assert%';
```
El output RAW debe pegarse aquí.

**B3.2** — Para cada función encontrada en B3.1, declarar:
- Si aplica a este SDD (sí/no, con justificación de una línea)
- Si aplica: declarar en qué contrato del SDD se usará obligatoriamente

**B3.3** — Confirmar explícitamente: ¿El SDD en preparación propone alguna validación de acceso nueva que NO use las funciones centralizadas del B3.1?

**B3.4 [VERIFICACIÓN INDEPENDIENTE]** — Invocar subagente:
- El subagente revisa el código fuente de las funciones de seguridad propuestas y el output de `pg_proc` para asegurar que no hay falsos positivos ni se omitieron funciones vitales como `assert_store_access`.

### 📋 DECLARACIÓN DE CIERRE BLOQUE 3:
```
✅ BLOQUE 3 CERRADO
Funciones centralizadas encontradas: [lista]
Funciones que aplican a este SDD: [lista]
Validaciones nuevas propuestas fuera de las centralizadas: [lista o "ninguna"]
PROCEDO AL BLOQUE 4.
```

---

## BLOQUE 4 — AUDITORÍA DE IMPACTO CRUZADO
> **Propósito:** Detectar todas las funciones del backend que ya usan las tablas que este SDD tocará.  
> **GATE:** Ningún contrato de escritura o mutación puede diseñarse sin haber ejecutado este bloque. Este bloque previene romper silenciosamente otras funciones al modificar entidades compartidas.

### Pasos obligatorios (todos, en orden):

**B4.1** — Para CADA tabla identificada en el Bloque 2, ejecutar:
```sql
SELECT proname
FROM pg_proc
WHERE prosrc ILIKE '%<nombre_tabla>%';
```
El output RAW de cada consulta debe pegarse aquí.

**B4.2** — Leer el body de cada función encontrada y declarar si el SDD propone algún cambio que la afecte (nueva columna, nuevo tipo de dato, nuevo constraint).

**B4.3** — Si se detecta una función que podría romperse, declararlo como **RIESGO DE IMPACTO CRUZADO**.

**B4.4 [VERIFICACIÓN INDEPENDIENTE]** — Invocar subagente:
- El subagente realiza una inspección profunda (`grep` o consultas adicionales en `pg_proc`) para buscar referencias ocultas a las tablas compartidas que el Orquestador pudo haber pasado por alto.

### 📋 DECLARACIÓN DE CIERRE BLOQUE 4:
```
✅ BLOQUE 4 CERRADO
Funciones impactadas por tabla [X]: [lista]
Riesgos de impacto cruzado detectados: [lista o "ninguno"]
PROCEDO AL BLOQUE 5.
```

---

## BLOQUE 5 — LECTURA DE CONTRATOS VECINOS
> **Propósito:** Leer los contratos de interfaz de los SDDs ya aprobados que limitan el diseño del SDD nuevo.  
> **GATE:** No se puede diseñar el contrato de salida del SDD sin haber verificado este bloque.

### Pasos obligatorios (todos, en orden):

**B5.1** — Para CADA SDD vecino declarado en el Bloque 0, abrir el archivo y leer su Sección 5 (Contrato de Interfaz).

**B5.2** — Citar LITERALMENTE (no parafrasear) el contrato de salida de cada SDD vecino que define restricciones sobre las entidades compartidas.

**B5.3** — Declarar explícitamente: ¿El contrato de salida propuesto para el SDD nuevo es compatible con los contratos citados en B5.2? Si hay incompatibilidad, declararla como **CONFLICTO DE CONTRATOS**.

**B5.4 [VERIFICACIÓN INDEPENDIENTE]** — Invocar subagente:
- El subagente lee el Registro Vivo de Contratos (`RVC_registro_vivo_contratos.md`) y los SDDs vecinos, asegurando que las citas son literales y las interpretaciones de compatibilidad son estrictas.

### 📋 DECLARACIÓN DE CIERRE BLOQUE 5:
```
✅ BLOQUE 5 CERRADO
SDDs vecinos leídos: [lista con sección citada]
Conflictos de contratos detectados: [lista o "ninguno"]
PROCEDO AL BLOQUE 6.
```

---

## BLOQUE 6 — GATE DE CALIDAD FINAL (PAC Completo)
> **Propósito:** Responder las preguntas de bloqueo del PAC con referencias cruzadas a los bloques anteriores.  
> **GATE:** Este es el último bloque antes de autorizar la redacción del SDD. Ninguna pregunta puede quedar "en blanco" o respondida con una narración sin referencia a evidencia de los bloques anteriores.

### Preguntas obligatorias (todas, con referencia explícita):

| # | Pregunta | Respuesta (con referencia al Bloque donde se verificó) |
|---|----------|--------------------------------------------------------|
| G-1 | ¿Qué políticas de ARQ-002 aplican? | [Respuesta] → Ver Bloque 1, RN [lista] |
| G-2 | ¿Qué SDDs ya aprobados consumen datos de este módulo? | [Respuesta] → Ver Bloque 5 |
| G-3 | ¿Qué SDDs ya aprobados producen datos que este módulo consume? | [Respuesta] → Ver Bloque 0 / Bloque 5 |
| G-4 | ¿Cuáles son las entidades lógicas compartidas? | [Respuesta] → Ver Bloque 2 |
| G-5 | ¿Se identificaron todos los flujos del ciclo de vida? | [Lista completa de flujos] |
| G-6 | ¿Este módulo toca dinero, costos o cantidades físicas? | [Sí/No] + ¿SPEC-011 activado? |
| G-7 | ¿Multi-tenant validado? ¿Se usará `assert_store_access`? | [Sí/No] → Ver Bloque 3 |
| G-8 | ¿Existen condiciones de carrera posibles sobre entidades compartidas? | [Sí/No] → Ver Bloque 4 |

### 📋 DECLARACIÓN DE CIERRE BLOQUE 6 — AUTORIZACIÓN DE REDACCIÓN:

**[VERIFICACIÓN INDEPENDIENTE FINAL ANTES DEL SDD]**
- El Orquestador invoca al subagente de Auditoría final pasándole las respuestas G-1 a G-8. El subagente emite su veredicto final. Si aprueba, se imprime:

```
✅ BLOQUE 6 CERRADO — PAC COMPLETO VERIFICADO POR AUDITOR
Todas las preguntas G-1 a G-8 respondidas con evidencia referenciada y auditada autónomamente.
Brechas Críticas auto-resueltas / registradas: [lista o "ninguna"]
Riesgos de Impacto Cruzado auto-resueltos / registrados: [lista o "ninguno"]
Conflictos de Contratos auto-resueltos / registrados: [lista o "ninguno"]

🟢 AUTORIZADO: Proceder a la redacción del SDD-[NNN] sin depender del usuario.
```

> **⚠️ BLOQUEO:** Si alguna Brecha Crítica, Riesgo de Impacto Cruzado o Conflicto de Contratos queda abierto, la redacción del SDD queda **BLOQUEADA** hasta que el usuario autorice explícitamente continuar con ese hallazgo documentado como deuda técnica pendiente.

---

## BLOQUE 7 — REDACCIÓN DEL SDD
> **Propósito:** Producir el documento SDD usando exclusivamente la evidencia recolectada en los bloques anteriores.
> **GATE:** Este bloque solo es accesible si el Bloque 6 emitió el texto "🟢 AUTORIZADO".

### Reglas de redacción:

1. **La Sección 0 del SDD** se construye copiando los hallazgos de los Bloques 2, 3, 4 y 5. No se redacta desde cero.
2. **El Glosario** solo puede incluir términos cuyas definiciones tienen respaldo en el Bloque 1 o Bloque 2.
3. **Los contratos de interfaz (Sección 5)** deben ser compatibles con lo declarado en el Bloque 5.
4. **El Modelo de Datos (Sección 7)** solo puede referenciar columnas cuya existencia fue verificada en el Bloque 2.
5. **La Sección de Seguridad (Sección 6)** debe incluir explícitamente las funciones identificadas en el Bloque 3.
6. **Prohibición absoluta:** Ninguna columna, tabla o función puede aparecer en el SDD si no fue verificada en los bloques anteriores.

### 📋 DECLARACIÓN DE CIERRE BLOQUE 7:
```
✅ BLOQUE 7 CERRADO — SDD REDACTADO
Archivo creado: [ruta exacta]
Sección 0 construida desde: Bloques 2, 3, 4, 5
Todas las entidades del Modelo de Datos verificadas en: Bloque 2
Todas las restricciones de seguridad citan funciones del: Bloque 3
WORKFLOW PAC-SDD COMPLETO PARA SDD-[NNN].
```

---

## 🚨 PROTOCOLO DE VIOLACIÓN

Si en cualquier punto del workflow se detecta que un paso fue omitido o respondido sin evidencia real, se debe:

1. **DETENER** la secuencia inmediatamente.
2. **DECLARAR** el paso violado con su número de Bloque y Paso.
3. **REGRESAR** al paso violado y ejecutarlo con evidencia real.
4. **NO** continuar desde donde se detuvo hasta que el paso violado esté cerrado correctamente.

El texto de declaración es:
```
🔴 VIOLACIÓN DETECTADA
Bloque [N], Paso [B_N.X] no ejecutado con evidencia.
Regresando al Bloque [N] para ejecutarlo correctamente.
```
