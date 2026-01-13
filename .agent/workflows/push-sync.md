---
description: Sincronización automática con GitHub tras commit exitoso
---

# Workflow: Push Sync (Sincronización Remota Automática)

Este workflow automatiza el envío de cambios a GitHub tras un commit exitoso.

## Condiciones de Ejecución

| ID | Condición | Descripción |
|----|-----------|-------------|
| C01 | ✅ Commit exitoso | El commit anterior no debe tener errores |
| C02 | ✅ Rama válida | Solo ramas `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`, `audit/` |
| C03 | ⚠️ Build exitoso | Si estás en `03_SRC`, verificar que compile sin errores |

> [!CAUTION]
> **NUNCA** hacer push directo a `main` o `master`. Siempre usar ramas de funcionalidad.

---

## Pasos

// turbo
1. Verificar que hay commits pendientes de push:
```bash
git status
```

// turbo
2. Obtener el nombre de la rama actual:
```bash
git branch --show-current
```

3. **VALIDACIÓN DE RAMA**: Verificar que la rama NO sea `main` ni `master`.
   - Si es `main` o `master`: **ABORTAR** y notificar al usuario.
   - Si es una rama de funcionalidad: Continuar.

// turbo
4. (Condicional) Si hay cambios en `03_SRC/`, verificar build:
```bash
cd 03_SRC && npm run build
```
   - Si el build **FALLA**: **ABORTAR** push y notificar error.
   - Si el build **PASA** o no hay cambios en 03_SRC: Continuar.

5. Ejecutar push a origin:
```bash
git push origin [NOMBRE_RAMA_ACTUAL]
```

// turbo
6. Confirmar el estado del push:
```bash
git log origin/[NOMBRE_RAMA_ACTUAL] -1 --oneline
```

---

## Ejemplo de Ejecución Completa

```bash
# 1. Verificar estado
git status

# 2. Obtener rama
git branch --show-current
# Salida: feat/new-feature

# 3. Validar rama (manual - verificar que no sea main)

# 4. Verificar build (si aplica)
cd 03_SRC && npm run build

# 5. Push
git push origin feat/new-feature

# 6. Confirmar
git log origin/feat/new-feature -1 --oneline
```

---

## Mensaje de Confirmación

Al finalizar exitosamente, reportar:

```
✅ Cambios sincronizados en GitHub
   Rama: [nombre-de-la-rama]
   Commit: [hash-corto] [mensaje]
   URL: https://github.com/YamirJCF/tienda-barrio-pro/tree/[rama]
```

---

## Integración con commit.md

Este workflow se ejecuta **automáticamente** después de usar `/commit` cuando:
1. El commit fue exitoso (exit code 0)
2. La rama actual es una rama de funcionalidad
3. El build de Vue.js pasa (si hay cambios en 03_SRC)

---

## Ramas Protegidas (NO hacer push directo)

| Rama | Acción Requerida |
|------|------------------|
| `main` | Pull Request obligatorio |
| `master` | Pull Request obligatorio |
| `production` | Pull Request obligatorio |

---

## Troubleshooting

| Error | Solución |
|-------|----------|
| `rejected - non-fast-forward` | Hacer `git pull --rebase` primero |
| `permission denied` | Verificar credenciales de GitHub |
| `build failed` | Corregir errores de compilación antes de push |
| `rama protegida` | Crear PR en lugar de push directo |
