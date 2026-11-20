---
name: release
description: Ritual de guardado seguro con CHANGELOG, commit semántico y tag
---

# Protocolo de Guardado Seguro (Release Ritual)

## 🧭 Control de Flujo (Pipeline)
- **Nivel:** 5 — Cierre de Versión y Etiquetado en Producción (Ruta D)
- **Rama permitida:** `master` (Única rama oficial de producción)
- **Entrada requerida (Gate In):** Orden explícita del usuario + validaciones de `/deploy` en verde + Panel de Auditoría (`/#/sys-audit`) en verde ✅.
- **Límite estricto:** Solo etiqueta versiones estables en `master` con `CHANGELOG.md` actualizado; prohibido etiquetar releases desde ramas `draft/*` o `feat/*` sin integrar.
- **🛑 Freno de Emergencia (Hard Stop):** Si `/#/sys-audit` tiene errores 🔴 o el build falla → ABORTAR el release y reportar al usuario.
- **➡️ Siguiente eslabón:** Fin de la Ruta D (Versión publicada y etiquetada en `origin/master`).

---

// turbo-all

## Pre-requisitos
1. Asegúrate de que el Panel de Auditoría (`/#/sys-audit`) esté en verde ✅
2. Actualiza `CHANGELOG.md` moviendo cambios de "En Desarrollo" a nueva versión

## Pasos del Ritual

### 1. Ver estado de Git
```bash
git status
```

### 2. Agregar todos los cambios
```bash
git add .
```

### 3. Commit con mensaje semántico
Usa el formato: `tipo(alcance): descripción`

Tipos válidos:
- `feat`: Nueva funcionalidad
- `fix`: Corrección de bug
- `docs`: Solo documentación
- `refactor`: Cambio de código sin alterar funcionalidad
- `sec`: Cambios de seguridad

Ejemplo:
```bash
git commit -m "sec(core): implementación de blindaje y validación de datos"
```

### 4. Crear tag de versión
```bash
git tag -a vX.Y.Z -m "Descripción de la versión"
```

### 5. Push a producción con tags
```bash
git push origin master --tags
```

## Notas
- NUNCA guardes si el Panel de Auditoría tiene errores 🔴
- SIEMPRE actualiza CHANGELOG.md antes del commit
- Los tags son "fotos" del código - úsalos para versiones estables
