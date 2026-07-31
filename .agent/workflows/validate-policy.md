---
description: Validar un FRD nuevo contra las Políticas Globales (ARQ-002) y sincronizar la Matriz de Trazabilidad (ARQ-003) y el Diccionario de Parámetros (ARQ-004)
---

# Workflow: Validación y Sincronización de Políticas (/validate-policy)

> [!CAUTION]
> **OBLIGATORIO:** Este workflow debe ejecutarse SIEMPRE que se redacte o modifique un documento FRD en `01_REQUIREMENTS/FRD/`.
> Debe ejecutarse ANTES de hacer commit del FRD. Si el FRD viola una Política existente, el commit DEBE ser abortado.

---

## Propósito

Garantizar que ningún FRD nuevo o modificado contradiga las Políticas Globales de Negocio ya establecidas, y que los documentos de trazabilidad se mantengan sincronizados automáticamente.

---

## Documentos Gobernados por este Flujo

| Documento | Ruta | Rol |
|-----------|------|-----|
| Políticas Globales | `STANDARDS/ARQ_002_POLITICAS_GLOBALES_NEGOCIO.md` | Fuente de verdad de las normas estratégicas |
| Matriz de Trazabilidad | `STANDARDS/ARQ_003_MATRIZ_TRAZABILIDAD_POLITICAS.md` | Mapa bidireccional Política ↔ FRD |
| Diccionario de Parámetros | `STANDARDS/ARQ_004_DICCIONARIO_PARAMETROS_SISTEMA.md` | Valores configurables extraídos de las reglas |

---

## Pasos OBLIGATORIOS

### Paso 1: LEER las Políticas Vigentes (Carga de Contexto)

Antes de evaluar el FRD, el agente DEBE leer íntegramente:

```
documentation/01_requirements/STANDARDS/ARQ_002_POLITICAS_GLOBALES_NEGOCIO.md
```

Si no se leen las 15 políticas antes de evaluar, la validación es inválida.

---

### Paso 2: AUDITORÍA DE CONFORMIDAD (Gate de Aprobación)

> [!WARNING]
> **Este paso es un GATE (compuerta).** Si el FRD no pasa esta auditoría, TODO el proceso se detiene aquí. No se crea el FRD, no se hace commit, no se actualizan los documentos de trazabilidad.

Para cada regla de negocio del FRD nuevo o modificado, responder explícitamente:

```
┌─────────────────────────────────────────────────────────────┐
│  AUDITORÍA DE CONFORMIDAD - FRD-XXX                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Regla del FRD: "[Texto de la regla]"                       │
│                                                             │
│  ¿Contradice alguna Política de ARQ-002?                    │
│    → SÍ: ❌ BLOQUEO. Citar POL-XXX-XX violada.             │
│    → NO: ✅ Conforme.                                       │
│                                                             │
│  ¿Es una instancia nueva de una Política existente?         │
│    → SÍ: Anotar para actualizar ARQ-003 (Paso 4).          │
│    → NO: Evaluar si requiere una Política nueva (Paso 3).  │
│                                                             │
│  ¿Contiene un valor numérico configurable?                  │
│    → SÍ: Anotar para extraer a ARQ-004 (Paso 5).           │
│    → NO: Continuar.                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Resultado de la auditoría:**

| Resultado | Acción |
|-----------|--------|
| ❌ **BLOQUEO** (al menos una regla viola una Política) | DETENER inmediatamente. Informar al usuario cuál regla del FRD viola cuál Política, citando ambos textos literales. El FRD NO se crea ni se guarda hasta que el usuario resuelva la contradicción (modificando el FRD o solicitando una enmienda a la Política). |
| ✅ **CONFORME** (todas las reglas pasan) | Continuar al Paso 3. |

---

### Paso 3: EVALUACIÓN DE POLÍTICAS NUEVAS

Si alguna regla del FRD no es trazable a ninguna Política existente en ARQ-002, evaluar:

| Pregunta | Acción |
|----------|--------|
| ¿La regla es transversal (afecta a más de un módulo)? | **SÍ →** Proponer al usuario la creación de una nueva Política (POL-XXX-XX) en ARQ-002. No crearla automáticamente; la Política requiere aprobación del Arquitecto. |
| ¿La regla es específica de este módulo solamente? | **NO requiere Política.** Documentarla normalmente en el FRD sin escalarla a ARQ-002. |

---

### Paso 4: ACTUALIZAR MATRIZ DE TRAZABILIDAD (ARQ-003)

Editar `STANDARDS/ARQ_003_MATRIZ_TRAZABILIDAD_POLITICAS.md`:

1. **Matriz Política → FRDs:** Agregar el nuevo FRD-XXX en la columna "FRDs que Gobierna" de cada Política que lo cubra.
2. **Matriz Inversa FRD → Políticas:** Agregar una fila nueva con el FRD y las Políticas que lo gobiernan.

**Formato de la fila nueva (Matriz Inversa):**

```markdown
| FRD-XXX (Nombre) | POL-FIN-XX, POL-LOG-XX, ... |
```

---

### Paso 5: EXTRAER PARÁMETROS CONFIGURABLES (ARQ-004)

Revisar todas las reglas del FRD buscando valores numéricos (límites, umbrales, porcentajes, cantidades).

Para cada valor encontrado, responder:

| Pregunta | Resultado |
|----------|-----------|
| ¿Este número podría cambiar por decisión del dueño del negocio sin alterar la lógica del software? | **SÍ →** Extraerlo a ARQ-004. |
| ¿Es un valor inherente a la lógica (ej. "mayor que cero", "no negativo")? | **NO →** No es un parámetro, es una constante lógica. Dejarlo en el FRD. |

Si hay parámetros nuevos, agregar fila(s) en la tabla de `ARQ_004_DICCIONARIO_PARAMETROS_SISTEMA.md`:

```markdown
| `P_NUEVO_PARAM` | Nombre descriptivo | Valor | Unidad | POL-XXX | FRD-XXX | Rango |
```

---

### Paso 6: PROCEDER CON /add-doc

Solo después de que los Pasos 2-5 se completen exitosamente, ejecutar el workflow `/add-doc` para:
- Crear o guardar el FRD
- Actualizar `MAPA_LOGICA_GLOBAL.md`
- Hacer commit
- Push a GitHub

---

## Checklist Final de Validación

Antes de notificar al usuario que el FRD fue aprobado:

- [ ] ✅ Todas las reglas del FRD fueron auditadas contra ARQ-002 (sin violaciones)
- [ ] ✅ ARQ-003 actualizado (ambas matrices)
- [ ] ✅ ARQ-004 actualizado (si se encontraron parámetros nuevos)
- [ ] ✅ Si se propuso una nueva Política, el usuario la aprobó antes de agregarla a ARQ-002
- [ ] ✅ Workflow `/add-doc` ejecutado correctamente

---

## Diagrama del Flujo

```
                    ┌──────────────────┐
                    │  Nuevo FRD       │
                    │  (borrador)      │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │  Paso 1: Leer    │
                    │  ARQ-002         │
                    │  (15 Políticas)  │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │  Paso 2: Auditar │
                    │  cada regla del  │
                    │  FRD vs ARQ-002  │
                    └────────┬─────────┘
                             │
                   ┌─────────┴──────────┐
                   │                    │
            ❌ VIOLA                ✅ CONFORME
                   │                    │
          ┌────────▼─────────┐  ┌───────▼────────┐
          │  BLOQUEO TOTAL   │  │  Paso 3:       │
          │  Informar al     │  │  ¿Política     │
          │  usuario. NO     │  │  nueva?        │
          │  crear FRD.      │  └───────┬────────┘
          └──────────────────┘          │
                               ┌────────▼─────────┐
                               │  Paso 4:         │
                               │  Actualizar      │
                               │  ARQ-003         │
                               └────────┬─────────┘
                                        │
                               ┌────────▼─────────┐
                               │  Paso 5:         │
                               │  Extraer params  │
                               │  a ARQ-004       │
                               └────────┬─────────┘
                                        │
                               ┌────────▼─────────┐
                               │  Paso 6:         │
                               │  Ejecutar        │
                               │  /add-doc        │
                               └──────────────────┘
```

---

## Errores Comunes a Evitar

| Error | Consecuencia | Prevención |
|-------|--------------|------------|
| No leer ARQ-002 antes de evaluar | Aprobar un FRD que viola una Política | Paso 1 es obligatorio y explícito |
| Aprobar un FRD con violación y hacer commit | Documentación contradictoria, bugs futuros | El Gate del Paso 2 es inquebrantable |
| Crear una Política nueva sin aprobación | Políticas no validadas por el Arquitecto | Paso 3 solo propone, el usuario decide |
| No actualizar ARQ-003 tras aprobar el FRD | FRD huérfano sin trazabilidad | Paso 4 es obligatorio |
| Dejar un número hardcodeado en el FRD | Cambios de negocio requieren reescribir FRDs | Paso 5 extrae todo valor configurable |

---

> **Referencia:** `STANDARDS/ARQ_002`, `STANDARDS/ARQ_003`, `STANDARDS/ARQ_004`
