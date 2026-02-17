---
description: Verificación y despliegue seguro a producción con checklist automático
---

# Workflow: Despliegue a Producción (`/deploy`)

// turbo-all

Protocolo estándar para subir código a producción **sin tener que revisar todo manualmente** cada vez. Este workflow automatiza las verificaciones críticas.

---

## Pre-requisitos
- Todos los cambios deben estar **comiteados** (usar `/commit` primero)
- El servidor de desarrollo debe estar apagado o en otra terminal

---

## Paso 1: Verificar estado limpio de Git

```bash
git status --short
```

**Criterio**: La salida debe estar vacía. Si hay cambios sin commitear, **ABORTAR** y usar `/commit` primero.

---

## Paso 2: Verificar compilación TypeScript

```bash
cd frontend && npx vue-tsc --noEmit 2>&1 | Select-String -Pattern "error TS" -NotMatch "_legacy_backup","\.bak",".spec.ts"
```

**Criterio**: No debe haber errores TS en archivos de producción (se excluyen `_legacy_backup/`, `.bak` y `.spec.ts`).

> **Nota**: Si hay errores en archivos legacy o de test, se reportan pero **no bloquean** el deploy.

---

## Paso 3: Verificar build de producción

```bash
cd frontend && npm run build
```

**Criterio**: El build debe completar con exit code 0. Si falla, **ABORTAR** e informar el error.

---

## Paso 4: Verificar tamaño del bundle

```bash
cd frontend && du -sh dist/ 2>$null; Get-ChildItem dist/assets/*.js | ForEach-Object { "$($_.Length / 1KB -as [int]) KB  $($_.Name)" } | Sort-Object -Descending
```

**Criterio**: Informativo. Reportar el tamaño total y los archivos JS más grandes. Alertar si algún chunk supera 500KB.

---

## Paso 5: Push a repositorio

```bash
git push origin master
```

---

## Paso 6: Confirmar estado final

```bash
git log -1 --oneline
```

---

## Reporte Final

Al finalizar exitosamente, reportar:

```
✅ Deploy a producción completado
   Commit: [hash] [mensaje]
   Build: OK (tamaño: XX MB)
   TypeScript: Sin errores en producción
   URL: https://github.com/YamirJCF/tienda-barrio-pro
```

---

## Checklist de Seguridad (Automático)

| Verificación | Qué revisa | Bloquea deploy |
|-------------|------------|----------------|
| Git limpio | Sin cambios uncommitted | ✅ Sí |
| TypeScript | Errores de tipo en `src/` | ✅ Sí |
| Build Vite | Compilación de producción | ✅ Sí |
| Bundle size | Tamaño de archivos JS | ⚠️ Solo alerta |

---

## Cuándo usar este workflow

| Situación | Workflow |
|-----------|----------|
| Guardado rápido de progreso | `/commit` |
| Subir cambios al repo | `/push-sync` |
| **Verificar + Subir a producción** | **`/deploy`** ← Este |
| Release con tag de versión | `/release` |
