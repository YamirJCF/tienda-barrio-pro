# 📐 Estándar ARQ-004: Diccionario de Parámetros del Sistema

**Versión:** 1.0  
**Fecha:** 2026-07-31  
**Autor:** Arquitecto de Producto  
**Estado:** ✅ Activo  
**Documento Padre:** `ARQ_002_POLITICAS_GLOBALES_NEGOCIO.md`

---

## Problema que Resuelve

Los valores numéricos (límites, porcentajes, umbrales) tienden a quedar enterrados dentro del texto narrativo de los FRDs, haciendo imposible responder rápidamente: "¿Cuántas horas tiene un turno?" o "¿Cuál es el múltiplo de redondeo?". Si el dueño del negocio decide cambiar un número, no debería ser necesario buscar en 15 documentos ni redesplegar código.

---

## Principio Fundamental

> **"Los números no son la regla; son variables de la regla. Si un valor puede cambiar por decisión del dueño sin alterar la lógica del software, ese valor debe estar aquí."**

---

## Reglas de Gobernanza

1. **Separación Estricta:** Ningún FRD debe contener un valor numérico configurable sin que ese valor esté registrado en este diccionario. El FRD referencia al parámetro por su código (ej. `P_MAX_HORAS_TURNO`), no por su valor literal.
2. **Fuente Única de Verdad:** Si el valor de un parámetro cambia, se actualiza EXCLUSIVAMENTE en este documento. Los FRDs no se modifican porque ellos referencian el código del parámetro, no el número.
3. **Implementación en Base de Datos:** El equipo de Data DEBE implementar estos parámetros como registros de configuración consultables (tabla `system_parameters` o equivalente), NUNCA como constantes hardcodeadas en funciones o código fuente.

---

## Diccionario de Parámetros

> [!IMPORTANT]
> Los siguientes valores son los parámetros configurables que las reglas de los FRDs consumen. Cambiar un parámetro aquí no requiere reescribir ningún FRD ni redesplegar código, solo actualizar la tabla de configuración del sistema.

| Código | Nombre | Valor Actual | Unidad | Política Origen | FRD que lo Consume | Rango Válido |
|--------|--------|-------------|--------|-----------------|-------------------|--------------|
| `P_MAX_HORAS_TURNO` | Vida máxima de un turno de caja | 24 | Horas | POL-SEG-02 | FRD-027-02 | 1 - 48 |
| `P_REDONDEO_MULTIPLO` | Múltiplo de redondeo para subtotales | 50 | Pesos (COP) | POL-FIN-05 | FRD-007-01 | 1 - 1000 |
| `P_MAX_ITEMS_CARRITO` | Límite de productos por transacción | 50 | Unidades | POL-FIN-05 | FRD-007-01 | 1 - 500 |

> [!NOTE]
> **Alcance Diferido:** A medida que se formalicen nuevos FRDs o se descubran valores numéricos enterrados en las reglas existentes, este diccionario DEBE actualizarse. *Condición de revisión:* "Si un FRD contiene un número que podría cambiar por decisión del dueño sin alterar la lógica del software, ese número debe extraerse aquí". *Trade-off:* Se acepta iniciar con 3 parámetros porque el sistema aún está en fase de especificación y los restantes valores aún no han sido formalmente decretados por el Arquitecto. *Revisión futura:* Al finalizar la fase de FRDs y antes de iniciar la implementación técnica (DSD), se debe hacer un barrido exhaustivo de todos los FRDs para extraer parámetros pendientes.

---

## Protocolo de Actualización

| Evento | Acción Obligatoria |
|--------|-------------------|
| Un FRD nuevo contiene un valor numérico configurable | Extraer el valor a este diccionario y reemplazar el número en el FRD por la referencia al código del parámetro. |
| El dueño solicita cambiar un límite o umbral | Modificar SOLO la columna "Valor Actual" en la tabla de arriba. NO tocar los FRDs. |
| Un parámetro se vuelve obsoleto | NO eliminar la fila. Marcar el Estado como "❌ Deprecado" y documentar la razón en el Historial de Cambios. |

---

## Historial de Cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1.0 | 2026-07-31 | Arquitecto de Producto | Creación inicial. Extraída desde la Sección III de ARQ-002. Agregados Rango Válido y Protocolo de Actualización. |

---

**Firmado:** Arquitecto de Producto  
**Fecha:** 2026-07-31
