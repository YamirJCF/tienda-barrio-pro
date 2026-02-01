# Orden de Trabajo - Saneamiento de Código (WO_009)

## Estado Git Actual
- **Rama a crear:** `chore/code-cleanup`
- **Comando:** `git checkout -b chore/code-cleanup`

## Plan de Acción Atómico

### Tarea 1: Unificación de Pruebas
Mover todos los archivos de `frontend/src/test` a `frontend/src/__tests__` y actualizar referencias.

### Tarea 2: Limpieza de Logs
Eliminar sentencias `console.log` de todo el código de producción (`src`), permitiendo `console.error` solo en bloques `catch`.

---

## Bloques de Prompt para Antigravity

### Prompt 1: Unificación de Pruebas
```markdown
## Prompt para Antigravity

### Contexto
- `frontend/src/test` (Origen)
- `frontend/src/__tests__` (Destino)

### Objetivo
1. Mover todo el contenido de `frontend/src/test` a `frontend/src/__tests__`.
2. Si hay conflictos de nombres, priorizar el archivo en `__tests__` pero reportar el conflicto.
3. Eliminar la carpeta `frontend/src/test` al finalizar.

### Restricciones
- No elimines pruebas sin verificar que se han movido.
- No modifiques el código interno de las pruebas, solo su ubicación.

### Definición de Hecho (DoD)
- La carpeta `frontend/src/test` no existe.
- Ejecutar `npm run test` (o el script de prueba configurado) pasa exitosamente.
```

### Prompt 2: Limpieza de Logs
```markdown
## Prompt para Antigravity

### Contexto
- Carpeta `frontend/src`

### Objetivo
1. Buscar y eliminar todas las líneas que contengan `console.log(`.
2. Mantener `console.error` y `console.warn` si son legítimos (manejo de errores).

### Restricciones
- No elimines logs dentro de comentarios.
- No rompas la sintaxis si el log es la única línea de un bloque `if` (asegurar llaves `{}`).

### Definición de Hecho (DoD)
- Una búsqueda de `console.log` en `frontend/src` retorna 0 resultados (o solo en comentarios).
```

## Comandos de Consola
```bash
git checkout -b chore/code-cleanup
# Validación post-cambios
cd frontend
npm run test:unit ## o comando equivalente
cd ..
```
