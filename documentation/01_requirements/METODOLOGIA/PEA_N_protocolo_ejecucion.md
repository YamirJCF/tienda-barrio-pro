# Metodología PEA-N: Protocolo de Ejecución Autónoma para SDDs

> **Tipo:** Protocolo de Ejecución (Secuencial y Semiautomático)
> **Propósito:** Orquestar el flujo de trabajo del agente para producir SDDs de forma autónoma, acumulativa y no bloqueante, implementando la metodología de corrección diferida y barrido por fases.

---

## Etapa 0: Disparador y Modo de Ejecución

El protocolo se activa automáticamente cuando se recibe la instrucción de producir un SDD del plan aprobado. No requiere confirmación manual para iniciar; la autonomía empieza aquí.

| Campo | Valor |
|---|---|
| **SDD objetivo** | [Nombre, tomado del plan de fases] |
| **Fase del plan** | [Fase N] |
| **Modo** | Secuencial semiautomático — se detiene solo en los Halts definidos en Etapa 4 |

---

## Etapa 1: Pipeline Secuencial (Estados obligatorios, en orden)

Cada estado solo puede iniciarse si el anterior terminó con salida válida. El agente no puede saltarse un estado.

| # | Estado | Acción mecánica | Salida requerida para avanzar |
|---|---|---|---|
| 1 | **CONSULTA_RVC** | Filtrar el Registro Vivo de Contratos (RVC) por las entidades declaradas en la Etapa 0 del PAC-N. | Lista de filas del RVC aplicables (puede ser vacía si el módulo es genuinamente aislado). |
| 2 | **EJECUTA_PAC_N** | Correr Etapas 1-4 del PAC-N **solo sobre lo que el RVC no cubrió**. | Ficha de Restricciones (Sección 0) completa, con Gate G-1 a G-7 satisfechos. |
| 3 | **REDACTA_BORRADOR**| Producir el SDD completo usando la plantilla aprobada. | Documento con estado 🔴 Borrador. |
| 4 | **AUTOCHEQUEO** | Verificar el borrador contra su propia Ficha de Restricciones: ¿cada fila tiene un reflejo concreto en el SDD? | Lista de discrepancias (puede ser vacía). |
| 5 | **ESCRITURA_RVC** | Insertar en el RVC toda entidad/contrato nuevo definido, y marcar 🟡 cualquier SDD anterior afectado. | RVC actualizado, con timestamp. |
| 6 | **ASIGNA_ESTADO** | Marcar el SDD como 🟡 Validado Localmente (nunca 🟢 directamente). | Estado final del documento para esta corrida. |
| 7 | **SIGUIENTE** | Repetir desde el estado 1 para el siguiente SDD de la fase. | — |

> [!NOTE]
> Al terminar todos los SDDs de una Fase, se dispara automáticamente un barrido de reconciliación (mini-PAC-R sobre los 🟡 acumulados) antes de iniciar la Fase siguiente.

---

## Etapa 2: Límites de Autonomía (Qué puede decidir el agente)

### 2.1 El agente PUEDE decidir sin escalar:
- Nombres lógicos de operaciones/entidades dentro del SDD (no técnicos).
- Cómo organizar/agrupar los diagramas de secuencia cuando el FRD tiene múltiples casos de uso.
- Qué consultas SQL de verificación correr y en qué orden (dentro del marco definido en PAC-N).
- Redacción y formato de las tablas internas del SDD.

### 2.2 El agente DEBE escalar como pregunta abierta (nunca decidir solo):
- Cualquier vacío que implique una regla de negocio nueva no derivable de un FRD, política ARQ-002, o fila del RVC.
- Contradicciones directas entre dos fuentes ya aprobadas (dos filas del RVC, o un FRD vs. un SDD vecino).
- Decisiones que afecten dinero, permisos o seguridad y que no tengan precedente exacto en el RVC.

---

## Etapa 3: Protocolo de Resolución de Vacíos No Estipulados (Jerarquía)

Qué hacer cuando no hay regla explícita. Ejecutar en este orden y detenerse en el primer match antes de escalar:

1. **¿El RVC tiene una fila análoga (misma naturaleza, distinto módulo)?**  
   → Aplicar el mismo patrón por consistencia.
2. **¿Alguna política de ARQ_002 resuelve el caso por generalidad?**  
   → Aplicar la directiva implícita (ej. POL-LOG-03 sobre el POS como embudo).
3. **¿Existe un SDD ya consolidado (🟢) que resolvió un caso equivalente?**  
   → Adoptar el mismo criterio, documentando la analogía explícitamente.
4. **Si ninguna de las tres aplica:**  
   → Elegir la interpretación **más restrictiva y reversible** (la que menos compromete al sistema — ej. negar por defecto, exigir un campo obligatorio). Esta es una decisión temporal de avance.
5. **Registro Obligatorio:**  
   → Cualquier resolución de los pasos 1, 3 o 4 se registra obligatoriamente en una nueva sección del SDD: `§ Supuestos No Estipulados`, con el criterio usado y la pregunta abierta para validación humana posterior.

---

## Etapa 4: Condiciones de Parada Obligatoria (Halt)

Únicos casos donde el pipeline se detiene y espera respuesta humana antes de continuar:

| # | Condición de Halt | Por qué no se resuelve con Etapa 3 |
|---|---|---|
| **H-1** | Dos filas del RVC se contradicen entre sí de forma directa. | No hay "más restrictivo" posible — son mutuamente excluyentes, no complementarios. |
| **H-2** | El vacío involucra dinero, límites de crédito, o permisos, y ningún paso 1-3 aplica. | El costo de una interpretación incorrecta es demasiado alto para avanzar solo con "más restrictivo". |
| **H-3** | El SDD requiere marcar como 🟡 más de 2 SDDs en estado 🟢 Consolidado. | Señal de que el plan de fases tiene un problema estructural de orden, no solo un gap puntual. |
| **H-4** | El FRD fuente mismo tiene una contradicción interna. | No es un problema de diseño del SDD — es un problema del documento padre. |
