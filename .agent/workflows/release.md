---
description: Ritual de guardado seguro con CHANGELOG, commit semántico y tag
---

# Protocolo de Guardado Seguro (Release Ritual)

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

### 5. Push con tags (si tienes remoto)
```bash
git push origin main --tags
```

## Notas
- NUNCA guardes si el Panel de Auditoría tiene errores 🔴
- SIEMPRE actualiza CHANGELOG.md antes del commit
- Los tags son "fotos" del código - úsalos para versiones estables
