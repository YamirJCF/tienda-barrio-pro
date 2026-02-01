# ARCH_003: Protocolo de Saneamiento de Código (Code Housekeeping)

## Contexto
Siguiendo la recomendación de consultoría técnica externa, establecemos este protocolo para mantener la "higiene" del proyecto. El objetivo es eliminar deuda técnica pasiva (código muerto) sin alterar la lógica de negocio activa.

## Los 4 Pilares del Saneamiento (Adaptado)

### 1. Estructura y Archivos (El Esqueleto)
- **Desafío Detectado**: Existencia de carpetas de prueba duplicadas (`src/__tests__` vs `src/test`).
- **Norma**: Centralizar todas las pruebas unitarias en `src/__tests__` (convención Jest/Vitest) y eliminar `src/test` si es redundante.
- **Acción**: Escaneo periódico de archivos huérfanos.

### 2. Dependencias (El Equipaje)
- **Herramienta**: Ejecución mensual de `npm audit` y revisión de `package.json`.
- **Meta**: Mantener el bundle ligero eliminando librerías de un solo uso.

### 3. Limpieza de Ruido (Código Muerto)
- **Tipos Zombis**: Eliminación de interfaces en `types/` que no tengan referencias.
- **Funciones Comentadas**: "Si está comentado, se borra". El historial de Git es el backup.

### 4. Logs y TODOs
- **Logs**: Prohibido `console.log` en ramas de producción (`main`, `staging`).
- **TODOs**: Tiempo de vida máximo de 30 días.

---

## Plan de Ejecución Inmediata (Operación Limpieza)

### Paso 1: Unificación de Pruebas
1. Revisar contenido de `frontend/src/test`.
2. Migrar pruebas valiosas a `frontend/src/__tests__`.
3. Eliminar `frontend/src/test`.

### Paso 2: Escaneo con Knip (Opcional pero recomendado)
Instalar y ejecutar `knip` para detectar exportaciones no usadas.

### Paso 3: Limpieza Manual
1. Búsqueda global de `console.log`.
2. Búsqueda global de bloques comentados extensos.

---

## Frecuencia
Este ritual debe ejecutarse **antes de cada Release Mayor** (versiones X.0.0 o 0.X.0).
