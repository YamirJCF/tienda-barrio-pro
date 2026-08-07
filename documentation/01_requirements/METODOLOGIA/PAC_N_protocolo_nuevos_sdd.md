# Metodología PAC-N: Pre-Análisis Contextual para SDDs Nuevos

> **Tipo:** Protocolo Preventivo — Se ejecuta ANTES de escribir el SDD.  
> **Principio:** Ningún SDD puede comenzar su Fase 1 sin haber completado este protocolo.  
> **Gemelo:** Ver `PAC-R` para auditoría de SDDs ya producidos.

---

## Objetivo

Evitar la visión de túnel cargando todo el contexto relevante **antes** de abrir el FRD. Un módulo analizado en aislamiento produce diagramas incompletos. Este protocolo fuerza el entrelazo de información entre el FRD fuente, las Políticas Globales, los Estándares Transversales y los SDDs vecinos ya aprobados.

---

## Etapa 0: Declaración del Alcance

Antes de leer cualquier documento, se declara:

| Campo | Descripción |
|-------|-------------|
| **SDD a producir** | Nombre y número (ej. `SDD_006_01_NUCLEO_INVENTARIO`) |
| **FRD fuente** | Ruta exacta al documento padre |
| **Fase del plan maestro** | Ej. "Fase 1 — Núcleo Transaccional" |
| **SDDs ya aprobados vecinos** | Lista de SDDs con los que este módulo tiene interacción directa |
| **FRDs padre/hijo relacionados** | FRDs que comparten dominio y cuyas reglas también aplican |

---

## Etapa 1: Carga del Contexto Global

Se leen los siguientes documentos en orden. Lo extraído se registra en la Ficha de Restricciones (Etapa 3).

| # | Documento | Qué se extrae | Condición |
|---|-----------|---------------|-----------|
| 1 | `ARQ_002_POLITICAS_GLOBALES_NEGOCIO.md` | Qué dominios de política (Financiero, Logístico, Seguridad, Auditoría) aplican al módulo y cuáles son sus reglas concretas | **Siempre** |
| 2 | `ARQ_003_MATRIZ_TRAZABILIDAD_POLITICAS.md` | Qué políticas específicas tienen trazabilidad registrada con el FRD fuente | **Siempre** |
| 3 | `SPEC-011 decimal-format-standard.md` | Reglas de formato para presentación de dinero y cantidades físicas | **Si el módulo toca precios, costos, stock o totales** |
| 4 | `FRD_023_IMPACTO_CRUZADO_MULTICANAL.md` | Reglas de conciliación, partición de saldos y transacciones inter-canal | **Si el módulo involucra dinero, métodos de pago o movimientos de caja** |
| 5 | SDDs vecinos ya aprobados | Contratos de interfaz ya definidos, entidades compartidas, errores ya catalogados | **Si existen SDDs vecinos** |
| 6 | FRDs padre/hijo del mismo dominio | Reglas heredadas o complementarias que el FRD fuente no repite pero asume como conocidas | **Si existen FRDs relacionados** |
| 7 | Esquema real de base de datos (`information_schema`, `pg_proc`, `pg_trigger`) | Nombres reales de tablas/columnas que el módulo tocará, y toda función o trigger que ya opere sobre ellas | **Siempre, para cada tabla declarada en la Etapa 0** |

> [!CAUTION]
> **Prohibición:** No se puede escribir el Glosario ni el primer diagrama hasta completar esta etapa. Un módulo puede no tocar dinero directamente pero producir datos que otro sí usa financieramente — ese enlace debe detectarse aquí.

> [!CAUTION]
> **Prohibición adicional:** Ningún nombre de tabla o columna puede aparecer en el Glosario, los diagramas, ni la Ficha de Restricciones sin haber sido verificado contra `information_schema.columns` en esta etapa. Un nombre "recordado por convención" (ej. `caja_diaria` en vez de `daily_cash_movements`) es una alucinación de esquema y se trata con la misma severidad que una entidad compartida no detectada.

---

## Etapa 2: Mapa de Dependencias

Se construye explícitamente el mapa relacional del FRD:

### 2.1 Dependencias Ascendentes
¿Qué entidades, sesiones o estados deben existir como precondición para que este módulo opere?

### 2.2 Dependencias Descendentes
¿Qué otros módulos consumen los datos o eventos que este módulo produce?

### 2.3 Entidades Lógicas Compartidas (Verificación Mecánica Obligatoria)

Esta sección NO se completa por reconocimiento narrativo ("recuerdo que Cuentas por Pagar toca esto"). Se completa ejecutando, para **cada tabla** declarada en la Etapa 0 como tocada por este módulo, las siguientes consultas y adjuntando su resultado crudo:

```sql
-- ¿Qué funciones/RPCs ya existentes referencian esta tabla?
SELECT proname FROM pg_proc WHERE prosrc ILIKE '%<nombre_tabla>%';

-- ¿Qué triggers ya existen sobre esta tabla?
SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgrelid = '<nombre_tabla>'::regclass;
```

Cada función o trigger que aparezca en el resultado es una **entidad lógica compartida por definición**, exista o no un SDD que la documente narrativamente como "vecino". Si el trigger encontrado tiene lógica condicional (un `CASE`, un `IF` por tipo/estado), esa lógica interna debe copiarse o referenciarse aquí — no basta con anotar que el trigger existe.

> [!WARNING]
> Toda entidad compartida identificada aquí — por consulta, no por memoria — es un **punto de riesgo de inconsistencia**. Los flujos del SDD en producción DEBEN ser compatibles con los contratos ya definidos en los SDDs vecinos para esas entidades, y con la lógica interna de cualquier trigger detectado.

---

## Etapa 3: Ficha de Restricciones Aplicables

Es el entregable principal de este protocolo. Se genera UNA VEZ y se incluye como **Sección 0** del SDD nuevo.

```markdown
## 0. Contexto y Restricciones Aplicables (PAC-N)

### 0.1 Políticas Globales Activadas (ARQ-002)
| Política ID | Dominio | Impacto Concreto en este SDD |
|-------------|---------|------------------------------|
| POL-XXX-XX | [Dominio] | [Cómo restringe el diseño de este módulo específicamente] |

### 0.2 Estándares Transversales Activos
| Estándar | Aplica porque... |
|----------|-----------------|
| SPEC-011  | [Razón concreta: ej. "El módulo expone precios de lote al POS"] |

### 0.3 Contratos Vecinos que Limitan el Diseño
| SDD Vecino | Entidad Compartida | Restricción que impone al diseño de este SDD | Evidencia (consulta que lo detectó) |
|------------|-------------------|----------------------------------------------|-------------------------------------|
| SDD_XXX_YY | [tabla/entidad] | [Qué espera ese SDD de esta entidad] | [Resultado crudo de la consulta de Etapa 2.3, o "N/A — declarado en Etapa 0" si se conocía de antemano] |

> [!CAUTION]
> Una fila sin evidencia adjunta en la última columna se considera **no verificada** y no cuenta para satisfacer el Gate G-7.

### 0.3b Campos Heredados de Reglas de Negocio Aprobadas
Para cada entidad de negocio que el SDD involucre (proveedor, cliente, venta, devolución), declarar explícitamente si existe una Regla de Negocio ya aprobada que defina campos obligatorios:

| Campo heredado | FRD/Regla de origen | Obligatorio en este SDD porque... |
|---------------|---------------------|------------------------------------|
| [campo] | [FRD-XXX Regla #Y] | [razón concreta] |

> [!CAUTION]
> Si esta tabla queda vacía, la afirmación **"no aplica ningún campo heredado"** debe justificarse explícitamente — no simplemente omitirse.

### 0.4 Mapa de Dependencias
**Ascendentes (este módulo necesita de):**
- [Entidad/módulo]: [razón]

**Descendentes (estos módulos necesitan de este):**
- [Entidad/módulo]: [razón]

### 0.5 Flujos Obligatorios por Cobertura de Ciclo de Vida
Lista de flujos que DEBEN modelarse para cubrir el ciclo de vida completo de las entidades del módulo:
- [ ] Flujo de creación / entrada nominal
- [ ] Flujo de modificación / salida nominal
- [ ] Flujo de reversión / devolución
- [ ] Flujo de error y excepción (con Rollback explícito)
- [ ] Flujo de ajuste (positivo y negativo si aplica)
- [ ] Flujo de expiración o bloqueo (si el módulo maneja entidades con vida útil)
- [ ] Flujos concurrentes (si el módulo puede recibir múltiples llamadas simultáneas)
```

---

## Etapa 4: Gate de Calidad

Seis preguntas de bloqueo. Si alguna queda sin respuesta, el PAC-N no está completo y no puede iniciarse la Fase 1.

| # | Pregunta | Respuesta requerida |
|---|----------|---------------------|
| G-1 | ¿Qué políticas de ARQ-002 restringen el diseño de este módulo? | Lista no vacía |
| G-2 | ¿Qué módulos ya aprobados consumen datos de este módulo? | Lista (puede ser vacía solo si es el primer módulo de la cadena) |
| G-3 | ¿Qué módulos ya aprobados producen datos que ESTE módulo consume? | Lista no vacía si tiene antecesores |
| G-4 | ¿Cuáles son las entidades lógicas compartidas con otros SDDs? | Lista no vacía si tiene vecinos |
| G-5 | ¿Se han identificado TODOS los flujos del ciclo de vida? | Lista completa incluyendo flujos de reversión y error |
| G-6 | ¿El módulo toca dinero, costos o cantidades? Si sí, ¿SPEC-011 está activado? | Sí/No explícito |
| G-7 | ¿Se ejecutaron las consultas de `pg_proc`/`pg_trigger`/`information_schema` para CADA tabla declarada en la Etapa 0, y su resultado crudo quedó adjunto en la Ficha de Restricciones (0.3)? | Resultado de consulta pegado por cada tabla — una respuesta narrativa ("sí, se revisó") no satisface este ítem |
