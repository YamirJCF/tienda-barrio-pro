---
name: push-sync
description: Sincronización remota con GitHub tras validación formal
---

# Workflow: Push Sync (Sincronización Remota Deliberada)

## 🧭 Control de Flujo (Pipeline)
- **Nivel:** 5 — Sincronización Remota de Desarrollo (Cierre de Rutas B y C)
- **Rama permitida:** `feat/*`, `fix/*`, `docs/*`, `chore/*`, `refactor/*`, `audit/*` (**PROHIBIDO** en `master` y en `draft/*`).
- **Entrada requerida (Gate In):** Commit local limpio (`commit`) + protocolo de validación aprobado (`validate-policy`, `pac-uxd` o tests/build en verde).
- **Límite estricto:** Sube únicamente la rama de trabajo actual a `origin`; **PROHIBIDO** hacer push o merge directo a `master`.
- **🛑 Freno de Emergencia (Hard Stop):** Si la rama es `master` o `draft/*`, o si `npm run build` falla → ABORTAR push y reportar al usuario.
- **➡️ Siguiente eslabón:** Fin de las Rutas B/C (para pasar a producción en `master`, el usuario debe solicitar explícitamente la Ruta D: `deploy` / `release`).
  - **En Modo AUTO y PAUSADO:** Al confirmar el push remoto, entrega el resumen final y detiene el flujo (nunca dispara `deploy` por cuenta propia).

---

Este workflow envía cambios validados a GitHub de forma explícita y deliberada.

> [!IMPORTANT]
> **POLÍTICA DE PUSH:** No se hace push remoto automático de borradores ni tareas en progreso. `/push-sync` se invoca únicamente cuando una funcionalidad, documento o fase ha sido formalmente aprobada y validada por sus respectivos protocolos.

## Condiciones de Ejecución

| ID | Condición | Descripción |
|----|-----------|-------------|
| C01 | ✅ Validación previa | El documento o código pasó su protocolo de validación |
| C02 | ✅ Commit exitoso | El commit de la rama no debe tener errores pendientes |
| C03 | ✅ Rama válida | Solo ramas `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`, `audit/` |
| C04 | ⚠️ Build exitoso | Si estás en `frontend/` (o código fuente), verificar que compile sin errores |

> [!CAUTION]
> **NUNCA** hacer push directo a `master` (rama oficial de producción) ni subir ramas `draft/*`. Siempre usar ramas de funcionalidad o documentación validada.

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

3. **VALIDACIÓN DE RAMA**: Verificar que la rama NO sea `master` (ni `main`/`production`) ni empiece por `draft/`.
   - Si es `master` o `draft/*`: **ABORTAR** y notificar al usuario.
   - Si es una rama de funcionalidad/documentación válida: Continuar.

// turbo
4. (Condicional) Si hay cambios en `frontend/`, verificar build:
```bash
cd frontend && npm run build
```
   - Si el build **FALLA**: **ABORTAR** push y notificar error.
   - Si el build **PASA** o no hay cambios de código: Continuar.

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
# Salida: feat/new-feature o docs/FRD_099

# 3. Validar rama (manual - verificar que no sea main)

# 4. Verificar build (si aplica código)
cd frontend && npm run build

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

## Cuándo usar este workflow

| Situación | Workflow |
|-----------|----------|
| Guardado de iteración local en borrador | `/add-doc` (crea/actualiza rama `draft/`) |
| Guardado local de código en progreso | `/commit` |
| **Sincronización remota tras validación formal** | **`/push-sync`** ← Este |
| Deploy a producción | `/deploy` |

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
