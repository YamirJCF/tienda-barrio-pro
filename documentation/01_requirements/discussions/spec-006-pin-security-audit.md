# Reporte de Auditoría - Módulo de Seguridad PIN

**Auditor:** QA y Auditoría (SPEC-007 Post-Implementation)
**Fecha:** 2026-01-17

---

## Puntaje de Robustez: 35/100 🔴

> [!CAUTION]
> El módulo de seguridad PIN tiene **vulnerabilidades críticas** que comprometen la integridad del sistema de control de caja.

---

## Matriz de Riesgos

| # | Severidad | Descripción | Archivo/Línea | Estado |
|---|-----------|-------------|---------------|--------|
| 1 | 🔴 CRÍTICO | **PinSetupModal permite cambiar PIN sin validar PIN actual**. Cualquier persona con acceso al Admin puede sobreescribir el PIN. | `PinSetupModal.vue:111-126` | PENDIENTE |
| 2 | 🔴 CRÍTICO | **PinResetModal depende de Supabase no configurado**. El flujo de "contraseña + resetear" siempre falla. | `PinResetModal.vue:96-104` | PENDIENTE |
| 3 | 🟠 ALTO | **Opciones redundantes y confusas**. "Configurar PIN" y "Cambiar/Resetear PIN" hacen flujos diferentes pero el usuario no entiende cuál usar. | `AdminHubView.vue:180-212` | PENDIENTE |
| 4 | 🟡 MEDIO | **PinSetupModal tiene modo "change" pero no se usa**. El modal soporta `mode: 'setup' | 'change'` pero siempre se abre con `mode="setup"`. | `AdminHubView.vue:181` | PENDIENTE |
| 5 | 🔵 BAJO | **Documentación incompleta**. Los cambios de SPEC-006/007 no están reflejados en los archivos de requirements. | `01_REQUIREMENTS/` | BACKLOG |

---

## Análisis de Resiliencia

### Flujo Actual (ROTO)

```
Usuario quiere configurar/cambiar PIN:

Opción 1: "Configurar PIN de Caja"
├── Abre PinSetupModal(mode='setup')
├── Pide nuevo PIN (6 dígitos) ❌ SIN VALIDAR PIN ACTUAL
├── Confirma PIN
└── Sobrescribe PIN en localStorage ← VULNERABILIDAD

Opción 2: "Cambiar o Resetear PIN"
├── Abre PinResetModal
├── Pide contraseña de cuenta
├── Llama a supabase.auth.signInWithPassword() ← FALLA
├── Error: "Error de conexión" o "Contraseña incorrecta"
└── Usuario no puede continuar ← FLUJO ROTO
```

### Problema de UX

El usuario tiene 2 opciones pero:
- **Opción 1** funciona pero es insegura (no valida PIN actual)
- **Opción 2** no funciona en absoluto

Esto crea confusión y vulnerabilidad.

---

## Plan de Mitigación

### Corrección Propuesta: Consolidar en UN SOLO FLUJO

Eliminar la opción "Cambiar o Resetear PIN" y modificar "Configurar PIN de Caja" para que:

1. **Si NO hay PIN configurado**: Crear nuevo PIN (flujo actual)
2. **Si YA hay PIN configurado**: Validar PIN actual antes de permitir cambio

```
Flujo Corregido:

¿Hay PIN configurado?
├── NO → PinSetupModal(mode='setup')
│        └── Crear 6 dígitos + confirmar → Guardar
│
└── SÍ → PinSetupModal(mode='change')
         ├── Paso 1: Ingresar PIN actual ← NUEVA VALIDACIÓN
         ├── Paso 2: Crear nuevo PIN
         ├── Paso 3: Confirmar nuevo PIN
         └── Guardar
```

### Archivos a Modificar

| Archivo | Acción |
|---------|--------|
| `AdminHubView.vue` | Eliminar botón "Cambiar o Resetear PIN", detectar si hay PIN y pasar mode='change' |
| `PinSetupModal.vue` | Agregar paso de validación de PIN actual cuando mode='change' |
| `PinResetModal.vue` | ELIMINAR archivo (no se usará) |

---

## Imagen de Referencia (Problema Reportado)

![Opciones redundantes en Admin](file:///C:/Users/Windows%2011/.gemini/antigravity/brain/4c1c8d08-29b4-48bf-957c-26493a7f09d8/uploaded_image_1768623994518.png)

---

## Priorización de Correcciones

1. 🔴 **INMEDIATO**: Corregir PinSetupModal para validar PIN actual en mode='change'
2. 🔴 **INMEDIATO**: Eliminar opción redundante "Cambiar o Resetear PIN"
3. 🟠 **SIGUIENTE**: Actualizar AdminHubView para detectar hasPinConfigured
4. 🟡 **BACKLOG**: Actualizar documentación de SPEC-006
