# Documentación Técnica: Control de Caja

> **Basado en:** [FRD-004](../FRD/FRD_004_CONTROL_DE_CAJA.md) y [FRD-004-1](../FRD/FRD_004_1_GESTION_PIN_CAJA.md)

## Descripción
Vista crítica de gestión de efectivo. Actúa como el "Switch Maestro" de la tienda: controla la apertura (inicio de jornada) y el cierre (arqueo).

## Ruta
`/cash-control`

## Tecnologías Clave
*   **Stores:** `useCashRegisterStore`, `useAuthStore`
*   **Componentes:** `PinSetupModal`, `PinChallengeModal`
*   **Estado Global:** `isStoreOpen` (Derivado de la sesión actual).

## Flujos de UI (Rescatados de Legacy)

### 1. Estado "Caja Cerrada" (Apertura)
El usuario llega aquí porque el sistema lo redirigió (POS Lockout) o entró voluntariamente.

**UI Elements:**
*   Header: "Apertura de Turno".
*   Input gigante: "Monto Base" (focus automático).
*   Botón Principal: "ABRIR CAJA".
*   *Comportamiento:* Al hacer click, se dispara el **PIN Challenge** (si el usuario es Admin o si se requiere firmar la apertura).

### 2. Estado "Caja Abierta" (Cierre/Arqueo)
El usuario entra para cerrar el turno.

**UI Elements:**
*   **Panel de Resumen (Read-only):**
    *   Base Inicial (+)
    *   Ventas Efectivo (+)
    *   Gastos (-)
    *   **= Debe haber en caja** (Resaltado).
*   **Input de Conteo:** "¿Cuánto dinero tienes físico?".
*   **Feedback Visual de Diferencia:**
    *   Verde: Cuadrado ($0).
    *   Rojo: Faltante (-$xx).
    *   Azul: Sobrante (+$xx).
*   Botón de Acción: "CERRAR TURNO".
*   *Comportamiento:* Al confirmar, se dispara el **PIN Challenge** para firmar.

## Datos
| Campo UI | Fuente de Datos (Store) |
|---|---|
| Base Inicial | `cashRegisterStore.currentSession.openingBalance` |
| Ventas Efectivo | `salesStore.todayCash` (O calculado desde transacciones) |
| Gastos | `expensesStore.todayTotal` |
| Monto Contado | Input local (`v-model`) |

## Reglas de Interfaz (UX)
1.  **Bloqueo de Navegación:** Si la caja está cerrada, intentar navegar a `/pos` debe fallar y redirigir aquí.
2.  **Transparencia:** Mostrar siempre el "Esperado" antes de pedir el "Contado" (Modelo Transparente segun FRD-004).
