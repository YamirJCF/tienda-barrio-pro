# PAC-UXD: Pre-Auditoría Contextual para Interfaz de Usuario

> **Tipo:** Protocolo gemelo de PAC-N — mismo rigor, distinto objeto de estudio
> (Frontend en vez de esquema de Base de Datos).
> **Rol:** Cartógrafo, no muro. Este protocolo **encuentra y reporta**
> discrepancias — nunca detiene la ejecución por sí mismo. Solo el
> protocolo de ejecución (PEA-N) tiene autoridad para declarar un Halt,
> y únicamente en el momento de construir/corregir, no durante el mapeo.
> **Origen:** El sistema auditaba el backend a nivel paranoico (tablas,
> RLS, impactos cruzados vía PAC-N/PVS-A) pero dejaba pasar el Frontend
> sin auditoría de igual rigor — permitiendo bugs ya detectados en
> producción (payload con campos calculados en cliente, estados de error
> indistinguibles de "sin datos") que ningún protocolo existente cubría.

---

## 0. Principios Heredados (sin modificación)

Los Principios Anti-Sesgo ya consolidados aplican íntegros:
- **0.1 Invariante de Reconciliación por Conteo** — todo hallazgo listado
  durante el mapeo debe aparecer referenciado en el resumen final; ninguno
  desaparece por "no ser tan grave".
- **0.2 No-Fusión de Dimensiones** — que un componente tenga buen manejo de
  loading no compensa que su payload filtre un campo prohibido; se reportan
  por separado.
- **0.3 Prohibición de Citar la Fuente Auditada Como Evidencia Propia** —
  que el propio SDD describa un contrato de interfaz no es evidencia de que
  el componente Vue real lo cumpla; solo cuenta la lectura directa del
  código del componente.
- **0.4 Auto-Chequeo Obligatorio Antes de Cualquier Cierre.**

**Diferencia respecto a PVS-A:** estos principios rigen la *honestidad* del
reporte, no su capacidad de bloqueo. PAC-UXD nunca detiene el proceso — solo
garantiza que lo que reporta sea completo y no esté sesgado hacia una
conclusión tranquilizadora.

---

## 1. Alcance y Objeto de Estudio

PAC-UXD audita **componentes Vue ya construidos** contra el **Contrato de
Interfaz (Sección 5) del SDD** correspondiente. No es una guía para
construir UI nueva — es la contraparte de PVS-A para lo que ya existe en
`frontend/src/`.

| Campo | Descripción |
|---|---|
| **Componente(s) objetivo** | Ruta exacta del/los `.vue` a auditar |
| **SDD/FRD fuente** | Documento cuyo Contrato de Interfaz se usa como referencia |
| **¿Mueve dinero o cantidades?** | Determina si aplica el Bloque 4 (SPEC-011) |

---

## 2. Bloques de Mapeo (evidencia cruda, cero interpretación)

Mismo espíritu que Fase A del PVS-A: cada bloque cierra en un checkpoint,
se cita textual, nunca se resume de memoria.

### Bloque 1 — Identificación
- `.1` Nombre y ruta exacta del componente.
- `.2` Cita textual completa de la Sección 5 (Contrato de Interfaz) del SDD fuente.
- `.3` **CHECKPOINT.**

### Bloque 2 — Verificación Mecánica del Contrato de Payload
Por cada campo que la Sección 5.1 declara como entrada del RPC:
- `.4` Buscar textualmente en el código real del componente si ese campo
  se envía en la llamada. Cita literal de la línea encontrada, o
  declaración explícita de ausencia.
- `.5` **CHECKPOINT** por campo. Detenerse.

### Bloque 2b — Verificación de Backend Authority (obligatorio, sin excepción)
- `.6` Búsqueda explícita en el payload de salida real: ¿aparece algún
  campo de precio/total/monto **calculado en el cliente**
  (`total`, `unit_price`, `amount_calculated`, o equivalente)?
- `.7` **CHECKPOINT.** Si `.6` encuentra alguno de estos campos, se marca
  como **hallazgo de severidad alta** — no se minimiza ni se combina con
  otros hallazgos menores (aplica 0.2).

### Bloque 3 — Matriz de Estados vs. Manejo Real
- `.8` Listar textualmente cada estado del Diagrama de Estados del SDD
  (mismo diagrama ya usado en PVS-A Bloque 4).
- `.9` Por cada estado, buscar en el componente el manejo correspondiente
  (loading, disabled, mensaje visible) — cita literal o ausencia declarada.
- `.10` Cruce explícito: ¿cada estado de `.8` tiene su manejo en `.9`? Sí/No individual.
- `.11` **CHECKPOINT.**

**Regla anti-"$0 disfrazado" (obligatoria dentro de este bloque):**
Para cada estado de error del backend, verificar explícitamente si en el
código real ese error se asigna a una variable que también representa
"sin datos"/cero, sin una bandera de error separada y visible. Si es así,
es un hallazgo automático de severidad alta — este fue exactamente el bug
encontrado en `PayablesView` (fallo de permisos renderizado como "Deuda
Total $0").

### Bloque 4 — Verificación contra SPEC-011 (condicional)
- `.12` Si el componente muestra dinero/cantidades: confirmar formato
  contra el estándar ya establecido. Cita literal del formateo usado.
- `.13` **CHECKPOINT.**

### Bloque 5 — Verificación de Permisos/Rol
- `.14` ¿El SDD o el diseño UX ya definió una restricción de rol para este
  componente (ej. "solo Admin")?
- `.15` Si sí: buscar en el código real si esa restricción está aplicada
  (guard de router, `v-if`, disabled) — cita literal, no inferencia.
- `.16` **CHECKPOINT.**

---

## 3. Informe de Hallazgos (nunca un Gate bloqueante)

A diferencia de PVS-A (que tiene Gates con poder de Halt), PAC-UXD produce
únicamente un **Informe de Hallazgos** — una tabla de reporte, sin
capacidad de detener nada por sí misma:

| ID | Hallazgo | Sección/Bloque de origen | Severidad |
|---|---|---|---|
| UX-1 | [Descripción concreta, citando el micro-paso] | Bloque N, `.N` | Alta/Media/Baja |

**Regla de cierre (aplicando 0.1):** el número de filas de esta tabla debe
coincidir exactamente con el número de hallazgos negativos producidos en
los Bloques 1-5 — ninguno omitido por parecer menor.

### Qué hacer con el Informe (fuera del alcance de este protocolo)

PAC-UXD entrega el Informe y termina ahí. La decisión de:
- Corregir el componente ahora,
- Escalar un hallazgo de severidad alta a un Halt real (esto solo puede
  decidirse dentro de PEA-N, en el momento de ejecutar la corrección, no
  aquí), o
- Aceptar el hallazgo como deuda técnica documentada (con la misma
  honestidad que ya exigimos en PVS-A — nunca como excusa para no
  reportarlo)

...es una decisión posterior, del protocolo de ejecución correspondiente.
**PAC-UXD nunca decide esto por sí mismo — solo lo hace visible.**

---

## 4. Estado Compuesto Ampliado (integración con PVS-A)

Cuando un SDD tenga componente de UI, su Estado Compuesto (Bloque 7e de
PVS-A) se amplía a **tres dimensiones**, no dos:

| Dimensión 1 (Documental) | Dimensión 2 (Backend) | Dimensión 3 (Frontend, este protocolo) | Estado Compuesto |
|---|---|---|---|
| 🟢 | 🟢 | 🟢 | 🟢 Confirmado — válido en documento, backend y frontend |
| 🟢 | 🟢 | 🔴 | 🟡 Backend Listo / Frontend Incompleto |
| 🟢 | 🔴 | cualquiera | 🟡 Implementación Bloqueada (ver PVS-A) |
| 🔴 | cualquiera | cualquiera | 🔴 Rechazado |

El documento maestro (`AUDITORIA_EJECUCION_PLAN_SDD.md`) recibe las tres
dimensiones por separado, nunca fusionadas en un solo color.

---

## 5. Dónde se Guarda (Trazabilidad)

Mismo patrón de organización ya establecido — separado por objeto de
auditoría, no mezclado con PVS-A:

```
documentation/01_requirements/
├── VERIFICACION/
│   ├── PVS_A_SDD_XXX.md        ← Backend (ya existente)
│   └── PAC_UXD_SDD_XXX.md      ← Frontend (nuevo, este protocolo)
```

El Informe de Hallazgos de cada componente se escribe incrementalmente,
checkpoint por checkpoint — igual que PVS-A, nunca al final del proceso.
