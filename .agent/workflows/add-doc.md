---
description: Agregar nuevos documentos a 01_REQUIREMENTS siguiendo el sistema de trazabilidad
---

# Workflow: Agregar Documentación (/add-doc)

> [!CAUTION]
> **OBLIGATORIO:** Este workflow debe ejecutarse SIEMPRE que se cree un nuevo documento en `01_REQUIREMENTS/`.

---

## Pre-Requisitos

Antes de crear documentación, verificar:
- [ ] El documento no existe ya en la carpeta
- [ ] Tienes toda la información necesaria del usuario

---

## Pasos OBLIGATORIOS

### 1. Crear el documento en `01_REQUIREMENTS/`

```bash
# Verificar que no existe
ls 01_REQUIREMENTS/*.md | Select-String "nombre-documento"
```

- Usar formato `kebab-case.md`
- Incluir secciones obligatorias según `SISTEMA_TRAZABILIDAD.md`

---

### 2. ⚠️ ACTUALIZAR MAPA LÓGICA GLOBAL (OBLIGATORIO)

> [!IMPORTANT]
> **NUNCA omitir este paso.** Según `SISTEMA_TRAZABILIDAD.md` línea 81:
> "✅ SIEMPRE Se actualiza MAPA_LOGICA_GLOBAL.md tras un cambio exitoso"

Editar `04_DEV_ORCHESTRATION/MAPA_LOGICA_GLOBAL.md`:

1. **Actualizar versión** en el encabezado (incrementar vX)
2. **Actualizar contador** de "Módulos documentados" en Resumen Ejecutivo
3. **Agregar fila** en "Tabla de Sincronización por Módulo":

| Módulo | Archivo Requisitos | Vista/Componente | Nivel Sync | Estado |
|--------|-------------------|------------------|------------|--------|
| [Nombre] | `nuevo-doc.md` | ⏳ Pendiente / `NombreView.vue` | 🟡 SPEC / 🟢 100% | **Por implementar** / **Sincronizado** |

---

### 3. Actualizar documentación relacionada (si aplica)

- Si el nuevo documento afecta a otros, agregar referencias cruzadas
- Actualizar `SECURITY_PROTOCOLS.md` si es tema de seguridad
- Actualizar `TODO_DASHBOARD.md` con tareas pendientes

---

### 4. Ejecutar /commit

```bash
git add -A
git commit -m "docs: agregar [nombre-documento] - [descripción breve]"
```

---

### 5. Ejecutar /push-sync

Sincronizar con GitHub según workflow de push.

---

## Checklist Final de Validación

Antes de notificar al usuario que terminaste, verificar:

- [ ] ✅ Documento creado en `01_REQUIREMENTS/`
- [ ] ✅ `MAPA_LOGICA_GLOBAL.md` actualizado (versión + contador + fila)
- [ ] ✅ Referencias cruzadas agregadas (si aplica)
- [ ] ✅ Commit realizado con mensaje `docs:`
- [ ] ✅ Push a GitHub completado

---

## Errores Comunes a Evitar

| Error | Consecuencia | Prevención |
|-------|--------------|------------|
| No actualizar MAPA_LOGICA_GLOBAL | Documento invisible en el mapa | Seguir paso 2 SIEMPRE |
| No incrementar contador de módulos | Métricas incorrectas | Verificar Resumen Ejecutivo |
| Olvidar push | Cambios solo locales | Ejecutar /push-sync |

---

> **Referencia:** `04_DEV_ORCHESTRATION/SISTEMA_TRAZABILIDAD.md`
