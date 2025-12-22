---
description: Automatizar commits de git con mensajes descriptivos
---

# Workflow: Commit de Cambios

Usar este workflow al completar una tarea/fase para guardar cambios en git.

## Pasos

// turbo
1. Verificar el estado actual de git:
```bash
git status --short
```

// turbo
2. Agregar todos los cambios al staging:
```bash
git add -A
```

3. Hacer commit con mensaje descriptivo:
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
