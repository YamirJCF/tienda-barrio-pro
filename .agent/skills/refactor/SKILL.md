---
name: refactor
description: Protocolo de Refactorización con Comportamiento Invariante (Ruta E) — Basado en Los Dos Sombreros (Fowler), Pruebas de Caracterización (Feathers), Ejecución por Olas (Google LSC) y Harness Engineering para Agentes.
---

# 🔧 Workflow: Refactorización con Comportamiento Invariante (`/refactor`)

## 🧭 Control de Flujo (Pipeline)
- **Nivel:** 3 y 4 — Cirugía Estructural con Comportamiento Congelado (Inicio de Ruta E)
- **Rama permitida:** `refactor/*` (nacida desde `master`; **PROHIBIDO** refactorizar directamente en `master`).
- **Entrada requerida (Gate In):** Código en funcionamiento que requiere mejora estructural (limpieza, extracción, desacoplamiento, reducción de complejidad o eliminación de duplicación) **sin** cambiar qué hace el producto (no requiere FRD nuevo).
- **Límite estricto:** **PROHIBIDO** cambiar reglas de negocio, alterar payloads/contratos sin actualizar a todos sus consumidores del Radio de Explosión, o modificar archivos `.spec.ts` durante la Fase 2 (Cirugía).
- **🛑 Freno de Emergencia (Hard Stop):**
  1. Si durante el refactor descubres un bug funcional o necesitas cambiar una regla de negocio → **DETENERSE** (no mezclar sombreros: reportar al usuario para abrir un `fix/*` aparte).
  2. Si toca archivos de `.agent/LOCKFILE.md` sin aprobación explícita.
  3. Si tras 2 intentos en una Ola los tests congelados siguen fallando → Revertir la Ola (`git checkout -- <archivos>`) y reportar al usuario.
- **➡️ Siguiente eslabón:**
  `refactor (Fase 1: Ecógrafo + Foto Antes con test-expert)` ➔ `refactor (Fase 2: Cirugía por Olas con tests congelados)` ➔ `refactor (Fase 3: Foto Después determinista)` ➔ `code-reviewer` ➔ `verification-before-completion` ➔ `commit` ➔ `push-sync`.
  - **En Modo AUTO:** Ejecuta Fase 1 → Fase 2 (Ola por Ola) → Fase 3 y encadena directamente con `code-reviewer` ➔ `verification-before-completion` ➔ `commit` ➔ `push-sync` sin preguntar, salvo que salte un Freno de Emergencia.
  - **En Modo PAUSADO:** Presenta la Fase 1 (Ecógrafo + Foto Antes en verde + Plan de Olas) y espera confirmación del usuario antes de ejecutar cada Ola.

---

## ⚖️ Las 3 Leyes del Arnés de Refactorización

### Ley 1 — Los Dos Sombreros (*Martin Fowler*)
Jamás mezcles el sombrero de **"Añadir/Cambiar Función"** con el sombrero de **"Refactorizar"**.
- Con esta skill activa, el sistema es una **Caja Negra**: para las mismas entradas, debe producir exactamente las mismas salidas, los mismos efectos secundarios y los mismos errores que antes.
- Si encuentras un bug mientras refactorizas, **no lo arregles en silencio dentro del refactor**: anótalo y repórtalo al usuario.

### Ley 2 — Foto Antes y Cerrojo de Tests (*Michael Feathers + Harness Engineering*)
Un agente probabilístico nunca puede ser juez y parte de su propio refactor:
1. Antes de tocar código de producción, debe existir una **Foto Antes** (tests unitarios o de caracterización pasando en verde `✅`).
2. Una vez que la Foto Antes está en verde, **todos los archivos `*.spec.ts` quedan CONGELADOS**.
3. **Trampa Prohibida:** Está terminantemente prohibido editar, borrar assertions, ajustar mocks o agregar `.skip` en un `.spec.ts` durante la Fase 2 para forzar que el refactor pase.

### Ley 3 — Grafo Estático y Ejecución por Olas (*Google LSC + Regla 10*)
Prohibido hacer refactors masivos ("Big Bang"). Todo cambio que toque más de un archivo debe dividirse en **Olas atómicas** donde cada Ola deje el sistema compilando y con los tests en verde.

---

## 🛠️ Secuencia Obligatoria de Ejecución

### Fase 1: Reconocimiento Estático y "Foto Antes" (Pre-Cirugía)

1. **Verificar o crear rama `refactor/*`:**
   ```bash
   git branch --show-current
   ```
   *(Si estás en `master`, crear rama: `git checkout -b refactor/descripcion-corta`).*

2. **Ejecutar el Ecógrafo Estructural (Regla 10.1 de `AGENTS.md`):**
   ```bash
   node scripts/scan-impact.mjs <entidad_tabla_rpc_store_o_componente>
   ```
   *(Si el refactor incluye SQL, ejecutar también la consulta `pg_proc` de la Regla 6).*
   Imprimir obligatoriamente:
   - **Contratos RVC Activos:** `[Filas devueltas en Eje 1]`
   - **Radio de Explosión (Vecinos):** `[Archivos .sql, .ts y .vue en Ejes 2 y 3]`
   - **Plan de Olas:** `[Ola 1: ... | Ola 2: ...]` (máximo 1 responsabilidad estructural por Ola).

3. **Tomar la "Foto Antes" (Baseline con `test-expert`):**
   Ejecutar la suite de tests relacionada:
   ```bash
   cd frontend && npm run test
   ```
   - **¿El código a refactorizar NO tiene tests que cubran su comportamiento actual?**
     Antes de tocar una sola línea de producción, usa las reglas de `test-expert` para escribir una **Prueba de Caracterización** que capture el comportamiento actual y verifica que pase en verde (`✅`).
   - Declarar explícitamente:
     `📸 FOTO ANTES EN VERDE — Archivos .spec.ts quedan CONGELADOS a partir de este punto.`

---

### Fase 2: Cirugía por Olas (Con `.spec.ts` Congelados)

Por cada **Ola** planificada:

1. **Aplicar la transformación estructural** en los archivos de producción (`.ts`, `.vue`, `.sql`) respetando las fronteras de autoridad (`data` para BD, `ux`/`impeccable` para UI).
2. **Muro de Acoplamiento (Muro 2):** Si una función o interfaz interna cambia de firma o ubicación, actualizar en la misma Ola a **todos** los consumidores listados en el Radio de Explosión de la Fase 1.
3. **Limpieza (YAGNI / Código Muerto):** Eliminar imports huérfanos, funciones viejas ya reemplazadas y código comentado antes de cerrar la Ola.

---

### Fase 3: Verificación Determinista ("Foto Después")

Al terminar cada Ola, ejecutar **en este orden exacto** las 3 barreras deterministas:

1. **Barrera 1 — Auditoría del Cerrojo de Tests (Anti-Trampa):**
   ```bash
   git status --short -- "*.spec.ts"
   ```
   *Criterio:* Ningún archivo `.spec.ts` existente puede haber sido modificado durante la Fase 2 para debilitar o acomodar una prueba.

2. **Barrera 2 — Compilación y Tipos Estrictos:**
   ```bash
   cd frontend && npx vue-tsc --noEmit 2>&1 | Select-String -Pattern "error TS" -NotMatch "_legacy_backup","\.bak",".spec.ts"
   ```
   *Criterio:* 0 errores TypeScript en archivos de producción.

3. **Barrera 3 — Igualdad de Comportamiento (`Foto Después === Foto Antes`):**
   ```bash
   cd frontend && npm run test
   ```
   *(Si se tocaron archivos `.vue` o `.css`, ejecutar también `.agent\skills\impeccable\scripts\impeccable.cmd detect --json <archivos>`).*
   *Criterio:* 100% de los tests pasan en verde con los mismos resultados de la Foto Antes.

> [!WARNING]
> **Protocolo de Rollback Rápido:** Si las Barreras 2 o 3 fallan y la causa no se corrige en máximo 2 intentos, **PROHIBIDO** acumular parches encima. Revierte los archivos de la Ola actual, divide la Ola en un paso más pequeño y vuelve a empezar.

---

## 📋 Declaración de Cierre de Refactorización

Antes de pasar a `code-reviewer`, imprime este bloque con datos reales:

```text
✅ REFACTORIZACIÓN COMPLETADA CON COMPORTAMIENTO INVARIANTE
- Rama: refactor/[nombre]
- Ecógrafo ejecutado: node scripts/scan-impact.mjs [objetivos]
- Radio de Explosión cubierto: [N/N consumidores actualizados]
- Foto Antes (Vitest): [X passed]
- Cerrojo .spec.ts: INTACTO (0 assertions debilitados durante Fase 2)
- Barrera TypeScript (vue-tsc): 0 errores
- Foto Después (Vitest): [X passed — 100% idéntico a Foto Antes]
- Sombrero de Fowler: RESPETADO (0 cambios en reglas de negocio)
➡️ Siguiente eslabón: code-reviewer
```
