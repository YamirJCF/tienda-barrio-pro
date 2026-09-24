---
name: pac-uxd
description: Pre-Auditoría Contextual para Interfaz de Usuario (PAC-UXD) - Cartógrafo de discrepancias en componentes Vue contra el Contrato de Interfaz del SDD
---

# 🎨 Workflow: PAC-UXD — Pre-Auditoría Contextual para Interfaz de Usuario

> **Norma Metodológica:** Este workflow implementa y ejecuta directamente la metodología oficial especificada en [`documentation/01_requirements/METODOLOGIA/PAC_UXD_protocolo.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/METODOLOGIA/PAC_UXD_protocolo.md).
> 
> **Rol:** Cartógrafo, no muro. Este protocolo **encuentra y reporta** discrepancias — nunca detiene la ejecución por sí mismo. Solo el protocolo de ejecución (`PEA-N` o `/orchestrator`) tiene autoridad para declarar un Halt en el momento de planificar/construir, nunca durante el mapeo.

---

## ⚡ ACTIVACIÓN

Invocar este workflow cuando se desee auditar un componente Vue construido contra el Contrato de Interfaz (Sección 5) de su SDD correspondiente:

```
/pac-uxd [RUTA_DEL_COMPONENTE_VUE] [NUMERO_SDD]
Ejemplo: /pac-uxd frontend/src/views/PayablesView.vue 019
```

---

## 0. Principios Anti-Sesgo Obligatorios

- **0.1 Invariante de Reconciliación por Conteo:** El número total de hallazgos negativos producidos en los Bloques 1-5 debe coincidir exactamente con las filas del Informe de Hallazgos final. Ninguno se omite por "parecer menor".
- **0.2 No-Fusión de Dimensiones:** Un aspecto positivo (ej. buen loading) nunca se usa como justificación o mitigante de un aspecto negativo (ej. cálculo de total en cliente).
- **0.3 Prohibición de Citar la Fuente Auditada Como Evidencia Propia:** Que el SDD describa un contrato no es evidencia de que el `.vue` lo cumpla; solo cuenta la cita textual de la línea de código real en el componente.
- **0.4 Auto-Chequeo Obligatorio Antes de Cualquier Cierre.**

---

## 📋 Pasos de Ejecución del Protocolo

El reporte debe escribirse incrementalmente, checkpoint por checkpoint, en el archivo de destino:
`documentation/01_requirements/VERIFICACION/PAC_UXD_SDD_[NUMERO].md`

---

### Bloque 1 — Identificación
- **B1.1** — Declarar el nombre y la ruta exacta del componente `.vue` a auditar.
- **B1.2** — Citar textualmente y completa la **Sección 5 (Contrato de Interfaz)** del SDD fuente correspondiente.
- **B1.3** — **CHECKPOINT.** Declarar cierre del Bloque 1.

---

### Bloque 2 — Verificación Mecánica del Contrato de Payload
Por cada campo de entrada que la Sección 5.1 del SDD declara para el RPC/operación:
- **B2.4** — Buscar textualmente en el código real del componente si ese campo se envía en la llamada al backend. Citar literalmente la línea encontrada o declarar explícitamente su ausencia.
- **B2.5** — **CHECKPOINT por campo.**

---

### Bloque 2b — Verificación de Backend Authority (Obligatorio, sin excepción)
- **B2.6** — Búsqueda explícita en el payload o llamadas del componente: ¿aparece algún campo de precio, subtotal, total o monto **calculado en el cliente** (`total`, `unit_price`, `amount_calculated` o equivalente)?
- **B2.7** — **CHECKPOINT.** Si se encuentra cálculo en cliente, marcar automáticamente como **hallazgo de severidad ALTA** (aplica principio 0.2).

---

### Bloque 3 — Matriz de Estados vs. Manejo Real
- **B3.8** — Listar textualmente cada estado del Diagrama de Estados del SDD.
- **B3.9** — Por cada estado, buscar en el código del componente su manejo visual correspondiente (skeleton/spinner para loading, disabled en botones para vuelo, mensaje visible para error, etc.) — citar la línea literal o declarar su ausencia.
- **B3.10** — Cruce explícito: ¿Cada estado de B3.8 tiene su reflejo en B3.9? Responder Sí/No individualmente.
- **B3.11** — **CHECKPOINT.**
- **Regla anti-"$0 disfrazado":** Verificar explícitamente que los errores del backend (ej. fallo de permisos o red) no se asignen a una variable que renderice "$0" o "sin datos" sin una bandera de error visible y diferenciada.

---

### Bloque 4 — Verificación contra SPEC-011 (Condicional)
- **B4.12** — Si el componente muestra dinero, precios o cantidades físicas: confirmar que el formateo respete el estándar `SPEC-011`. Citar literalmente el código de formateo usado.
- **B4.13** — **CHECKPOINT.**

---

### Bloque 5 — Verificación de Permisos / Rol
- **B5.14** — ¿El SDD o el diseño definió una restricción de rol o acceso para esta pantalla o acción (ej. "solo Admin")?
- **B5.15** — Si aplica: buscar en el código real si la restricción está implementada (guards de router, `v-if`, directivas de rol, disabled) con cita textual de la línea.
- **B5.16** — **CHECKPOINT.**

---

## 📊 Formato del Entregable (Informe de Hallazgos)

El archivo generado en `documentation/01_requirements/VERIFICACION/PAC_UXD_SDD_[NUMERO].md` debe concluir con la siguiente estructura:

```markdown
# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-[NUMERO])

> **Componente Auditado:** `[ruta/al/componente.vue]`  
> **SDD Fuente:** `[ruta/al/SDD_XXX.md]`  
> **Fecha:** YYYY-MM-DD  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | [Descripción concreta citando el micro-paso y línea] | Bloque N (.X) | 🔴 Alta / 🟡 Media / 🔵 Baja |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `[🟢 Conforme / 🟡 Observaciones Menores / 🔴 Fallas Críticas / Incompleto]`
- **Impacto en Estado Compuesto:**
  - Si no hay hallazgos de severidad alta: Frontend aporta `🟢`.
  - Si hay al menos un hallazgo de severidad alta: Frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
[Resumen de los ítems que deben convertirse en tareas atómicas de corrección en la próxima orden de trabajo]
```

---

## 📁 Archivo de Destino

Guardar siempre en: **`documentation/01_requirements/VERIFICACION/PAC_UXD_SDD_[NUMERO].md`**
