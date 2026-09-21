---
description: Agregar nuevos documentos a 01_REQUIREMENTS siguiendo el sistema de trazabilidad y autoguardado en ramas draft
---

# Workflow: Agregar Documentación (/add-doc)

> [!CAUTION]
> **OBLIGATORIO:** Este workflow debe ejecutarse SIEMPRE que se cree o itere un nuevo documento en `01_REQUIREMENTS/`.

---

## Pre-Requisitos

Antes de crear documentación, verificar:
- [ ] El documento no existe ya en la carpeta (o estás iterando una versión borrador)
- [ ] Tienes toda la información necesaria del usuario

---

## Pasos OBLIGATORIOS

### 1. Crear o Actualizar el documento en `01_REQUIREMENTS/`

```bash
# Verificar que no existe duplicado con otro nombre
ls 01_REQUIREMENTS/*.md | Select-String "nombre-documento"
```

- Usar formato `kebab-case.md` (o la nomenclatura oficial `FRD_XXX_...`, `DSD_XXX_...`, `UXD_XXX_...`)
- Incluir secciones obligatorias según `DOCUMENTATION_STANDARD.md`

---

### 2. ⚠️ ACTUALIZAR MAPA LÓGICA GLOBAL (OBLIGATORIO)

> [!IMPORTANT]
> **NUNCA omitir este paso.** Según `SISTEMA_TRAZABILIDAD.md`:
> "✅ SIEMPRE Se actualiza MAPA_LOGICA_GLOBAL.md tras un cambio exitoso"

Editar `04_DEV_ORCHESTRATION/MAPA_LOGICA_GLOBAL.md`:

1. **Actualizar versión** en el encabezado (incrementar vX)
2. **Actualizar contador** de "Módulos documentados" en Resumen Ejecutivo
3. **Agregar o actualizar fila** en "Tabla de Sincronización por Módulo":

| Módulo | Archivo Requisitos | Vista/Componente | Nivel Sync | Estado |
|--------|-------------------|------------------|------------|--------|
| [Nombre] | `nuevo-doc.md` | ⏳ Pendiente / `NombreView.vue` | 🟡 SPEC / 🟢 100% | **Por implementar** / **Sincronizado** |

---

### 3. Actualizar documentación relacionada (si aplica)

- Si el nuevo documento afecta a otros, agregar referencias cruzadas
- Actualizar `SECURITY_PROTOCOLS.md` si es tema de seguridad
- Actualizar `TODO_DASHBOARD.md` con tareas pendientes

---

### 4. Autoguardado Local en Rama Draft (Sin Push Remoto)

Para garantizar 100% de trazabilidad de las iteraciones sin contaminar el repositorio remoto ni la rama principal de trabajo:

```bash
# Crear o cambiar a la rama draft del documento
git checkout -B draft/[nombre-documento]
git add -A
git commit -m "docs(draft): iteración [nombre-documento]"
```

> [!NOTE]
> **No se ejecuta push remoto.** El documento se itera y guarda localmente en su rama `draft/`. El merge a la rama de trabajo y el push remoto se realizarán únicamente tras la validación formal exitosa del documento (vía `/validate-policy` para FRDs, o los protocolos PAC correspondientes).

---

## Checklist Final de Validación

Antes de notificar al usuario que terminaste esta iteración, verificar:

- [ ] ✅ Documento creado/editado en `01_REQUIREMENTS/`
- [ ] ✅ `MAPA_LOGICA_GLOBAL.md` actualizado (versión + contador + fila)
- [ ] ✅ Referencias cruzadas agregadas (si aplica)
- [ ] ✅ Autoguardado local completado en rama `draft/[nombre-documento]`

---

## Errores Comunes a Evitar

| Error | Consecuencia | Prevención |
|-------|--------------|------------|
| No actualizar MAPA_LOGICA_GLOBAL | Documento invisible en el mapa | Seguir paso 2 SIEMPRE |
| No incrementar contador de módulos | Métricas incorrectas | Verificar Resumen Ejecutivo |
| Hacer push a remoto de un borrador | Historial remoto sucio e inestable | Mantener cambios en rama `draft/` local hasta validación |

---

> **Referencia:** `04_DEV_ORCHESTRATION/SISTEMA_TRAZABILIDAD.md`
