# Metodología PAC-R: Auditoría Contextual para SDDs Ya Producidos

> **Tipo:** Protocolo Retrospectivo — Se ejecuta sobre un SDD que ya existe.  
> **Principio:** Un SDD producido sin PAC-N es una hipótesis, no un diseño. Este protocolo lo audita contra la realidad del sistema.  
> **Gemelo:** Ver `PAC-N` para SDDs nuevos.  
> **Versión:** 1.1 — Etapa 1.5 y Capa E agregadas como lección formal del SDD_007_01.

---

## Diferencia Fundamental con PAC-N

| Aspecto | PAC-N (Nuevos) | PAC-R (Existentes) |
|---------|---------------|---------------------|
| **Momento** | Antes de escribir | Después de escrito |
| **Objetivo** | Cargar contexto para no cometer errores | Detectar errores ya cometidos |
| **Entregable** | Sección 0 que alimenta el SDD | Informe de Hallazgos que corrige el SDD |
| **Postura** | Constructiva (¿qué debo incluir?) | Crítica (¿qué falta o está mal?) |
| **Acción resultante** | Escribe el SDD correctamente desde el inicio | Produce una lista priorizada de correcciones |

---

## Etapa 0: Inventario del SDD a Auditar

Antes de leer nada externo, se levanta el inventario de lo que ya existe en el SDD:

| Campo | Descripción |
|-------|-------------|
| **SDD auditado** | Nombre, número y ruta |
| **Estado actual** | ¿Aprobado? ¿En Borrador? ¿Qué fases están completas? |
| **Secciones existentes** | Lista de secciones y subsecciones que contiene |
| **Flujos modelados** | Lista de diagramas ya dibujados y qué escenario cubren |
| **Contratos definidos** | ¿Qué payloads de entrada/salida ya están especificados? |
| **Entidades mencionadas** | Qué tablas o entidades lógicas se referencian en el documento |

---

## Etapa 1: Carga del Contexto de Referencia

Se carga el mismo contexto que hubiera cargado PAC-N, pero ahora se usa como **vara de medición** contra lo que ya existe en el SDD.

| # | Documento | Qué se extrae para comparar |
|---|-----------|------------------------------|
| 1 | `ARQ_002_POLITICAS_GLOBALES_NEGOCIO.md` | Todas las políticas aplicables al dominio del SDD auditado |
| 2 | `ARQ_003_MATRIZ_TRAZABILIDAD_POLITICAS.md` | Políticas trazadas al FRD fuente |
| 3 | `SPEC-011 decimal-format-standard.md` | Si el SDD toca dinero o cantidades, verificar cumplimiento |
| 4 | FRD fuente y FRDs relacionados | Reglas del negocio que el SDD DEBIÓ haber cubierto |

> ⚠️ **No avanzar a Etapa 1.5 sin haber abierto y leído cada documento de la tabla anterior.**

---

## Etapa 1.5: Mapa de Dependencias Externas (Gate Bloqueante)

> **Este paso es la diferencia entre una auditoría interna (revisar el documento contra sí mismo) y una auditoría de integración (verificarlo contra el sistema real). No se avanza a Etapa 2 sin completarlo.**
>
> **Lección documentada — SDD_007_01:** El PAC-R inicial pasó la inspección sin haber abierto FRD-019 (Cuentas por Pagar) ni FRD-020/022 (Multicanal). Toda la información existía en el proyecto; el protocolo no obligaba a traerla. Resultado: 5 de los 8 hallazgos críticos finales solo los detectó el usuario, no la auditoría.

### Paso 1: Construir el Mapa de Módulos Interactuantes

Llenar esta tabla **antes** de leer el SDD con ojos críticos. Fuentes: ARQ-003 (Matriz Inversa) y cualquier término financiero/logístico mencionado en el SDD (AJUSTE, DEUDA, INGRESO, EGRESO).

| Módulo vecino | SDD/FRD fuente | Tipo de interacción | Campo o entidad compartida |
|---------------|---------------|---------------------|---------------------------|
| [nombre] | [SDD_XXX / FRD-YYY] | Envía / Recibe / Comparte tabla | [campo concreto] |

### Paso 2: Para cada módulo, extraer su contrato explícito

| Qué extraer | Por qué |
|-------------|--------|
| **Payload de entrada/salida** (campos, tipos, condicionalidades) | Detectar campos que el SDD auditado debe enviar pero no declara |
| **Reglas de negocio relevantes** (numeradas, ej. "Regla #7 del FRD-019") | Detectar reglas que el SDD debe respetar pero no referencia |
| **Enums y valores esperados** (ej. `movement_type` permitidos) | Detectar inconsistencias de valores entre módulos |
| **Triggers o side-effects** (ej. qué dispara un INSERT en esa tabla) | Detectar riesgo de doble ejecución entre RPC y trigger |

### Paso 3: Verificar nombres reales de tablas contra el esquema

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('tabla_a', 'tabla_b', 'tabla_c');
```

> ❌ Si el resultado difiere del nombre en el SDD → hallazgo 🟡 automático.

### Paso 4: Verificar valores de enums en columnas clave compartidas

```sql
SELECT enumlabel FROM pg_enum
JOIN pg_type ON pg_enum.enumtypid = pg_type.oid
WHERE pg_type.typname = '<nombre_del_tipo>';
```

> ❌ Un valor usado en el SDD que no existe en el enum real → hallazgo 🔴.

> ✅ **Gate superado cuando:** tabla de módulos vecinos completa (con campo concreto por fila), nombres de tablas verificados en `information_schema`, enums verificados en `pg_enum`.

---

## Etapa 2: Inspección por Capas

Se inspecciona el SDD en **cinco** capas, comparando lo que existe con lo que el contexto exige. Cada hallazgo se clasifica según su criticidad.

### Capa A: Cobertura de Ciclo de Vida
**Pregunta:** ¿El SDD modela todos los flujos del ciclo de vida de sus entidades?

| Flujo a verificar | ¿Está modelado? | Criticidad si falta |
|-------------------|-----------------|---------------------|
| Creación / entrada nominal | ✅ / ❌ | Alta |
| Modificación / salida nominal | ✅ / ❌ | Alta |
| Reversión / devolución / anulación | ✅ / ❌ | Alta |
| Error con Rollback explícito | ✅ / ❌ | Alta |
| Ajuste positivo | ✅ / ❌ | Media |
| Ajuste negativo / merma | ✅ / ❌ | Media |
| Expiración o bloqueo de entidades | ✅ / ❌ | Media |
| Flujos concurrentes (race conditions) | ✅ / ❌ | Alta si aplica |

### Capa B: Consistencia con Contratos Vecinos
**Pregunta:** ¿Los payloads y entidades del SDD son compatibles con los SDDs que ya interactúan con él?

Usar directamente el Mapa construido en Etapa 1.5. Para cada módulo vecino:
- ¿La entidad compartida tiene los mismos campos en ambos SDDs?
- ¿El contrato de error usa los mismos códigos?
- ¿El flujo de secuencia asume el mismo orden de operaciones?
- ¿El SDD auditado envía **todos** los campos que el vecino declara como obligatorios?

### Capa C: Cumplimiento de Políticas (ARQ-002)
**Pregunta:** ¿Cada política aplicable tiene un reflejo concreto en el SDD?

| Política aplicable | ¿Está reflejada en el SDD? | Dónde o por qué falta |
|--------------------|--------------------------|-----------------------|
| [POL-XXX-XX] | ✅ / ❌ | [ubicación o razón de la brecha] |

### Capa D: Robustez Interna de los Diagramas
**Pregunta:** ¿Los diagramas ya dibujados son técnicamente completos?

| Verificación | ✅ / ❌ | Detalle |
|-------------|---------|---------|
| ¿Todos los flujos tienen BEGIN TRANSACTION explícito? | | |
| ¿Todos los flujos tienen COMMIT y ROLLBACK dibujados? | | |
| ¿Los candados de concurrencia (FOR UPDATE) documentan su duración? | | |
| ¿Los movimientos en bitácora registran tipo/motivo de operación? | | |
| ¿Las validaciones de datos de entrada están antes de abrir la transacción? | | |
| ¿Existe mecanismo de idempotencia para operaciones de escritura? | | |

### Capa E: Anti-Alucinación de Nombres y Contratos (Obligatoria)
**Pregunta:** ¿Cada tabla, columna y valor de enum que este SDD menciona existe en el esquema real verificado?

Usa los resultados de la Etapa 1.5. Es la capa más frecuentemente omitida y la que produce bugs silenciosos que solo se detectan en ejecución.

| Nombre usado en el SDD | Nombre real verificado (Etapa 1.5) | ¿Coinciden? | Acción |
|------------------------|-----------------------------------|-------------|-------|
| [tabla/columna/valor] | [resultado de information_schema] | ✅ / ❌ | Corrección si no coinciden |

> ❌ **Patrón prohibido (lección BUG-001/003):** Si un nombre no se pudo verificar contra el esquema real → hallazgo 🟡. Nunca se marca como coincidente por analogía.

---

## Etapa 3: Clasificación de Hallazgos

Cada hallazgo detectado en la Etapa 2 se clasifica en una de tres categorías:

| Categoría | Definición | Acción requerida |
|-----------|-----------|------------------|
| 🔴 **Crítico** | Falta un flujo completo, un contrato es incompatible con un vecino, o una política obligatoria no tiene reflejo | Corrección inmediata antes de usar el SDD como base para otro |
| 🟡 **Mejora** | El flujo existe pero está incompleto (ej. falta COMMIT, falta tipo de movimiento) | Corrección antes de que el SDD se considere "cerrado" |
| 🔵 **Trade-off Documentado** | La brecha es conocida y se decide diferir por razones justificadas | Registrar en el SDD con la justificación del trade-off (Regla 7 del proyecto) |

---

## Etapa 4: Informe de Hallazgos

El entregable de la auditoría. Se agrega como **Sección 0** del SDD auditado.

```markdown
## 0. Auditoría Contextual PAC-R

> **Fecha de auditoría:** [fecha]  
> **Resultado:** 🔴 Requiere correcciones / 🟡 Mejoras menores / 🟢 Conforme

### 0.1 Hallazgos Críticos (🔴)
| # | Descripción del hallazgo | Sección afectada | Corrección requerida |
|---|--------------------------|-----------------|----------------------|
| 1 | [descripción] | [sección] | [acción] |

### 0.2 Hallazgos de Mejora (🟡)
| # | Descripción del hallazgo | Sección afectada | Corrección requerida |
|---|--------------------------|-----------------|----------------------|

### 0.3 Trade-offs Diferidos (🔵)
| # | Descripción | Por qué se difiere | Condición de revisión |
|---|-------------|-------------------|-----------------------|

### 0.4 Políticas Verificadas (✅)
| Política ID | Reflejo en el SDD |
|-------------|-------------------|

### 0.5 Contratos Vecinos Verificados (✅)
| SDD Vecino | Entidad | Estado de compatibilidad |
|------------|---------|--------------------------|
```

---

## Etapa 5: Gate de Cierre

La auditoría solo se marca como completa si:

| # | Condición |
|---|-----------|
| R-1 | Todos los hallazgos 🔴 han sido corregidos en el SDD |
| R-2 | Todos los hallazgos 🟡 han sido corregidos O documentados como trade-off |
| R-3 | La Sección 0 ha sido añadida al SDD auditado |
| R-4 | El SDD auditado conserva su estado (Aprobado/Borrador) + una nota de "Auditado PAC-R [fecha]" |

---

## Aplicación a los 3 SDDs Ya Producidos

| SDD | Auditoría pendiente | Prioridad |
|-----|---------------------|-----------|
| `SDD_007_01_NUCLEO_POS.md` | ✅ Auditado PAC-R — 3 iteraciones completadas (2026-08-04) | 🟢 Aprobado |
| `SDD_007_02_TICKET_DE_VENTA.md` | ✅ Auditado PAC-R — Etapa 1.5 y Capa E aplicadas (2026-08-04) | 🟢 Aprobado |
| `SDD_006_01_NUCLEO_INVENTARIO.md` | ✅ Auditado PAC-R — Etapa 1.5 y Capa E aplicadas (2026-08-04) | 🟢 Aprobado |
