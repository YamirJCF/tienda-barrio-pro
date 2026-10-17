# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-020)

> **Componente Auditado:** `frontend/src/views/CashControlView.vue` y `frontend/src/components/cash/CloseRegisterModal.vue` (junto con `cashRegister.ts` y `cashRepository.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_020_CAJA_MULTICANAL.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_020_CAJA_MULTICANAL.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Vistas y Modales Auditados:**
  - `frontend/src/views/CashControlView.vue`
  - `frontend/src/components/cash/CloseRegisterModal.vue`
- **Capa de Stores y Repositorios:**
  - `frontend/src/stores/cashRegister.ts`
  - `frontend/src/data/repositories/cashRepository.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.1 Operación: `rpc_abrir_caja_multicanal`
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Entradas:**
  ```json
  {
    "p_store_id": "UUID (Obligatorio)",
    "p_opening_cash": "NUMERIC >= 0 (Obligatorio, asignado a canal efectivo)"
  }
  ```
- **Salida Exitosa:**
  ```json
  {
    "success": true,
    "data": {
      "session_id": "UUID",
      "status": "open",
      "channels": [
        { "payment_method": "efectivo", "opening_balance": 50000.00 },
        { "payment_method": "nequi", "opening_balance": 0.00 },
        { "payment_method": "llave_bre", "opening_balance": 0.00 }
      ]
    }
  }
  ```

### 5.2 Operación: `rpc_cerrar_caja_multicanal`
- **Tipo:** RPC Postgres / Acción (WRITE)
- **Entradas:**
  ```json
  {
    "p_session_id": "UUID (Obligatorio)",
    "p_balances": [
      { "payment_method": "efectivo", "actual_amount": 125000.00 },
      { "payment_method": "nequi", "actual_amount": 45000.00 },
      { "payment_method": "llave_bre", "actual_amount": 0.00 }
    ]
  }
  ```
- **Salida Exitosa:**
  ```json
  {
    "success": true,
    "data": {
      "session_id": "UUID",
      "status": "closed",
      "closed_at": "TIMESTAMPTZ",
      "consolidated": {
        "expected_balance": 165000.00,
        "actual_balance": 170000.00,
        "difference": 5000.00
      },
      "balances": [
        { "payment_method": "efectivo", "expected_amount": 120000.00, "actual_amount": 125000.00, "difference": 5000.00 },
        { "payment_method": "nequi", "expected_amount": 45000.00, "actual_amount": 45000.00, "difference": 0.00 },
        { "payment_method": "llave_bre", "expected_amount": 0.00, "actual_amount": 0.00, "difference": 0.00 }
      ]
    }
  }
  ```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componentes identificados y Contrato de Interfaz 5.1 y 5.2 citado textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_abrir_caja_multicanal`
- **Campo `p_store_id`:** En `CashControlView.vue:233` se pasa `storeId`, pero se enruta hacia el RPC escalar `abrir_caja` (`p_opening_balance`), no hacia `rpc_abrir_caja_multicanal`.
- **Campo `p_opening_cash`:** Ausente como nombre explícito; viaja como `p_opening_balance` en `cashRepository.ts:168`.

### Operación: `rpc_cerrar_caja_multicanal`
- **Campo `p_session_id`:** Viaja en `cashRepository.ts:187`.
- **Campo `p_balances` (`[{ payment_method, actual_amount }]`):**
  - **AUSENTE EN PAYLOAD DE RED.** En `CloseRegisterModal.vue:109-112`, el componente calcula en memoria la suma de todos los canales (`totalPhysical.value = sum(physicalCounts)`) y envía un único valor escalar a `cashRegisterStore.closeRegister(totalPhysical.value)`, el cual a su vez invoca en `cashRepository.ts:182` a `cerrar_caja` pasando `p_actual_balance = totalPhysical`.
  - La llamada canónica a `rpc_cerrar_caja_multicanal` con el array discriminado de canales no está implementada en el repositorio.

### B2.5 CHECKPOINT Bloque 2
Se detecta asimetría en el contrato de cierre: el frontend recopila la información multicanal pero la aplana a un escalar antes de enviarla.

---

## Bloque 2b — Verificación de Backend Authority (Obligatorio, sin excepción)

### B2.6 Búsqueda de Cálculos en Cliente
- En `CloseRegisterModal.vue`:
  - **Líneas 47-54:** Bucle en cliente calculando diferencias por canal:
    ```typescript
    for (const [method, expected] of Object.entries(balancesByMethod.value)) {
      const physical = new Decimal(physicalCounts.value[method] || 0);
      diffs[method] = physical.minus(expected);
    }
    ```
  - **Líneas 56-58:** Sumatoria agregada de conteo físico en memoria:
    ```typescript
    const totalPhysical = computed(() => {
      return Object.values(physicalCounts.value).reduce((sum, count) => sum.plus(new Decimal(count || 0)), new Decimal(0));
    });
    ```
  - **Líneas 60-62:** Cálculo en cliente del descuadre total:
    ```typescript
    const difference = computed(() => {
      return totalPhysical.value.minus(systemExpected.value);
    });
    ```
  - **Línea 177:** Renderiza `<span class="text-gray-900 dark:text-white text-lg">{{ formatCurrency(systemExpected) }}</span>` (rotulado como *"Total Esperado"*).
  - **Línea 187:** Renderiza `<span class="text-gray-500 dark:text-gray-400">Esperado: {{ formatCurrency(expected) }}</span>` individualmente por cada método de pago.

### B2.7 CHECKPOINT Bloque 2b
🔴 **HALLAZGO DE SEVERIDAD ALTA:** Violación del Arqueo Ciego (`POL-SEG-01`) y Backend Authority. El modal revela al usuario cuánto dinero digital y en efectivo debe haber en cada canal, permitiéndole maquillar el reporte físico para cuadrarlo antes de someterlo.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados de UI en SDD-020
1. `CajaCerrada` (Sin turno activo)
2. `ValidandoApertura` (Apertura en vuelo)
3. `CajaAbierta` (Turno abierto, métricas multicanal activas)
4. `DeclarandoArqueo` (Ingreso de conteo físico y digital ciego)
5. `ProcesandoCierre` (Invocación de RPC de cierre)
6. `CierreCompletado` (Despliegue de acta de arqueo y diferencias oficiales retornadas por BD)

### B3.9 Manejo Visual en los Componentes
- `DeclarandoArqueo`: Presente en `CloseRegisterModal.vue:181-200` mediante inputs para cada canal de `balancesByMethod`.
- `ProcesandoCierre`:
  - En `CloseRegisterModal.vue:105, 132`: Manejado con `isLoading.value = true/false`.
  - En `CashControlView.vue:32`: Manejado con `isSubmitting`.
- `CierreCompletado`:
  - En `CloseRegisterModal.vue:126`: Emite `emit('closed')` y cierra el modal inmediatamente, sin mostrar una pantalla de resultado con el acta oficial retornada por el backend.

### B3.10 Cruce de Estados
| Estado SDD-020 | Reflejo en Componente | ¿Conforme? |
|---|---|:---:|
| `CajaCerrada` | Presente en `CashControlView.vue` | Sí |
| `ValidandoApertura` | Bloqueo por botón disabled | Sí |
| `CajaAbierta` | Presente | Sí |
| `DeclarandoArqueo` | Inputs disponibles | Sí (con observación de arqueo ciego) |
| `ProcesandoCierre` | Loading spinner | Sí |
| `CierreCompletado` | Cierre inmediato sin acta post-cierre | No (Parcial) |

### B3.11 CHECKPOINT Bloque 3
Detectada ausencia de vista/resumen post-cierre que muestre las diferencias oficiales certificadas por el servidor.

---

## Bloque 4 — Verificación contra SPEC-011

### B4.12 Formateo de Moneda
- En `CloseRegisterModal.vue:86-92`: Utiliza `Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', minimumFractionDigits: 0 })`. Cumple con el estándar de moneda nacional sin centavos.

### B4.13 CHECKPOINT Bloque 4
Conforme con `SPEC-011`.

---

## Bloque 5 — Verificación de Permisos / Rol

### B5.14 Restricciones de Rol en SDD-020
- Apertura y cierre restringidos a Admin (`admin_profiles`) o cajero con permiso `canOpenCloseCash`.

### B5.15 Verificación en Código
- `CloseRegisterModal.vue` no contiene comprobación de permisos; asume que el componente padre ya realizó la validación.

### B5.16 CHECKPOINT Bloque 5
Conforme por delegación de contexto, con requerimiento de blindaje preventivo en el Store.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | **Violación de Arqueo Ciego Multicanal (`POL-SEG-01`):** `CloseRegisterModal.vue` (L177, L187) muestra *"Total Esperado"* y *"Esperado: $X"* por canal, y calcula discrepancias en cliente (L51, L61) en tiempo real. | Bloque 2b (.6, .7) | 🔴 Alta |
| UX-2 | **Aplanamiento no Canónico de Payload de Cierre:** `CloseRegisterModal.vue:109-112` y `cashRepository.ts:189` consolidan todos los canales en un solo número escalar `p_actual_balance` hacia `cerrar_caja`, omitiendo `rpc_cerrar_caja_multicanal` con `p_balances: [{ payment_method, actual_amount }]`. | Bloque 2 (.4, .5) | 🔴 Alta |
| UX-3 | **Omisión de Acta de Cierre Post-Arqueo:** El modal se cierra de forma instantánea tras la respuesta (L127), sin desplegar el acta oficial de cierre consolidada que devuelve el backend en `consolidated` y `balances`. | Bloque 3 (.9, .10) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:** Frontend aporta `🔴` debido a la violación de Arqueo Ciego y a la omisión del payload discriminado por canales hacia `rpc_cerrar_caja_multicanal`.  
  *Estado resultante para SDD-020:* `🟡 Backend Listo / Frontend Incompleto`.

---

## 📌 Instrucción para el Orquestador (/orchestrator)

Tareas atómicas para la Etapa 4 de remediación de código:
1. **Adopción de `rpc_cerrar_caja_multicanal`:** Actualizar `cashRepository.ts` para crear el método `closeRegisterMultichannel(sessionId, balances, notes)` que envíe el payload estructurado `p_balances: [{ payment_method, actual_amount }]`.
2. **Eliminación de Saldos Esperados en Formulario de Arqueo:** Ocultar las etiquetas `Esperado: {{ formatCurrency(expected) }}` y `Total Esperado` en `CloseRegisterModal.vue`. El usuario únicamente debe ver los campos de entrada para digitar lo contado.
3. **Modal de Acta de Arqueo Post-Cierre:** Presentar un paso de confirmación final que consuma el objeto `data.balances` y `data.consolidated` retornado por `rpc_cerrar_caja_multicanal` para mostrar el acta contable definitiva con los descuadres calculados por Postgres.
