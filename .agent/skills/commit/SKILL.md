---
name: commit
description: Automatizar commits de git con mensajes descriptivos
---

# Workflow: Commit de Cambios

## 🧭 Control de Flujo (Pipeline)
- **Nivel:** 5 — Guardado Local (Rutas B y C)
- **Rama permitida:** `feat/*`, `fix/*`, `docs/*`, `refactor/*`, `chore/*`, `audit/*` (**PROHIBIDO** hacer commit directo en `master`; para borradores en `draft/*` usar `add-doc`).
- **Entrada requerida (Gate In):** Verificación real completada (`verification-before-completion`), sello vigente de `scan-impact.mjs` si se tocaron capas compartidas, y validación limpia de gobernanza UX (`verify-ux-governance.mjs` + `ux-fitness.spec.ts` vía `.githooks/`).
- **Límite estricto:** Solo guarda cambios en el repositorio Git local; **PROHIBIDO** ejecutar `git push` y **PROHIBIDO** usar `git commit --no-verify` (Regla 12). Si el commit toca Zona de Gobernanza UX exige `[UX-ARCH-APPROVED]` + `UX-ADR-XXX`; si toca Zona de Guardarraíles/`LOCKFILE.md` exige `[LOCKFILE-APPROVED]`. Prohibido mezclar gobernanza/guardarraíles con código de producto en el mismo commit.
- **🛑 Freno de Emergencia (Hard Stop):** Si `git branch --show-current` es `master`, o si los hooks versionados `.githooks/pre-commit` / `.githooks/commit-msg` (`verify-impact-hook.mjs` o `verify-ux-governance.mjs`) rechazan el commit → DETENERSE y reportar al usuario.
- **➡️ Siguiente eslabón:** `push-sync`
  - **En Modo AUTO:** Si el commit local es exitoso (`✅`), ejecuta `push-sync` de inmediato sin preguntar.
  - **En Modo PAUSADO:** Confirma el hash del commit local, indica *"Siguiente paso en la ruta: `push-sync`"* y espera confirmación.

---

Usar este workflow al completar una tarea/fase para guardar cambios en git.

## Pasos

// turbo
0. Verificar que NO estás en la rama de producción (`master`):
```bash
git branch --show-current
```
*(Si la rama actual es `master`, ABORTAR inmediatamente y crear/cambiar a una rama de trabajo `feat/*`, `fix/*`, etc.).*

// turbo
1. Verificar el estado actual de git para no mezclar gobernanza UX con código de producto ni arrastrar archivos temporales:
```bash
git status --short
```

// turbo
2. Agregar explícitamente solo los archivos correspondientes al commit (evitar `git add -A` si hay archivos temporales sin relación o mezclas prohibidas):
```bash
git add <archivos-del-commit>
```

3. Hacer commit con mensaje descriptivo (incluyendo `[UX-ARCH-APPROVED]` y/o `[LOCKFILE-APPROVED]` únicamente cuando haya aprobación explícita y corresponda a la zona tocada; **nunca usar `--no-verify`**):
```bash
git commit -m "[tipo]: [descripción breve]"
```

## Convención de Mensajes

| Tipo | Uso |
|------|-----|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `refactor` | Refactorización sin cambio funcional |
| `style` | Cambios de estilo/formato |
| `docs` | Documentación |
| `perf` | Mejoras de rendimiento |
| `chore` | Tareas de mantenimiento |

## Ejemplos de Mensajes

```
feat: agregar calculadora de peso para productos
fix: corregir validación de precio en formulario
refactor: mover lógica de datos a carpeta src/data
style: mejorar diseño de botones en POS
```

## Regla de Oro

**Hacer commit después de:**
- Completar una fase del task.md
- Corregir un bug importante
- Antes de una refactorización grande
- Al final de una sesión de trabajo
