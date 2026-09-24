---
name: doc-standard
description: Consultar el estándar de documentación para validar FRD, DSD, UXD y QAR
---

# 📜 Estándar de Documentación

Este workflow te guía para aplicar el estándar de documentación del proyecto.

## Instrucción Principal

**ANTES de redactar o revisar cualquier documento**, lee el estándar completo:

```
01_REQUIREMENTS/DOCUMENTATION_STANDARD.md
```

---

## Resumen Rápido por Tipo de Documento

### FRD (Arquitecto) - ¿QUÉ hace el sistema?
- **CERO código fuente**
- **CERO nombres de archivos o componentes**
- Reglas prescriptivas (DEBE, NO PUEDE)
- Sin ambigüedades ("puede ser", "opcionalmente")

### DSD (Data) - ¿CÓMO se estructura el dato?
- Referencia obligatoria a FRD
- Toda tabla con RLS
- SQL ejecutable
- Diccionario de datos completo

### UXD (UX/UI) - ¿CÓMO interactúa el usuario?
- Referencia obligatoria a FRD
- Estados de interfaz (Loading, Empty, Error, Success)
- Mobile-first
- Sin lógica de negocio inventada

### QAR (QA) - ¿ES SEGURO y CORRECTO?
- Referencia a documentos auditados
- Pruebas reproducibles
- Plan de mitigación con responsables
- No introduce nuevos requisitos

---

## Checklist de Validación Rápida

Antes de entregar cualquier documento, ejecuta:

### Para FRD:
```
□ ¿Cero código fuente?
□ ¿Cero nombres de archivos/componentes?
□ ¿Todas las reglas son prescriptivas?
□ ¿Cero ambigüedades?
□ ¿Casos de uso completos?
```

### Para DSD:
```
□ ¿Referencia a FRD existente?
□ ¿Todas las tablas tienen RLS?
□ ¿SQL ejecutable sin errores?
□ ¿Diccionario de datos completo?
```

### Para UXD:
```
□ ¿Referencia a FRD existente?
□ ¿Estados de interfaz definidos?
□ ¿Cero lógica de negocio inventada?
```

### Para QAR:
```
□ ¿Referencias a documentos auditados?
□ ¿Pruebas reproducibles?
□ ¿Plan de mitigación con responsables?
```

---

## Acción

Si el documento NO cumple el checklist → **RECHAZAR** con feedback específico citando el criterio violado.
