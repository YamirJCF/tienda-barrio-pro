## Reporte de Auditoría - Resumen Diario Inteligente (FRD-008)

### Puntaje de Robustez: 35/100
**Estado:** 🛑 NO APTO PARA PRODUCCIÓN

### Matriz de Riesgos

| # | Severidad | Descripción | Archivo/Línea |
|---|-----------|-------------|---------------|
| 1 | 🔴 **CRÍTICO** | **Cálculo Financiero en Cliente:** El total de ventas se suma en el navegador usando `reduce()`. Esto es vulnerable a manipulación y errores de redondeo en JS. | `ReportsContent.vue:118` |
| 2 | 🔴 **CRÍTICO** | **Lógica de Negocio Falsa:** El costo de mercancía se "inventa" como el 70% de la venta. Esto entrega información financiera falsa al usuario. | `ReportsContent.vue:124` |
| 3 | 🔴 **CRÍTICO** | **Filtrado Inseguro (Data Leak):** Se descargan *todas* las ventas al cliente y se filtran por cajero en memoria. Un usuario técnico podría ver ventas de otros cajeros en el payload de red. | `ReportsContent.vue:82-95` |
| 4 | 🟠 **ALTO** | **Divergencia UX/UI:** La implementación ignora los principios de diseño "Conversacional" y "Semáforo" del FRD, reemplazándolos con un dashboard genérico difícil de interpretar en <5s. | `ReportsContent.vue` (General) |
| 5 | 🟡 **MEDIO** | **Problema de Rendimiento (Escalabilidad):** Al carecer de paginación o RPC de resumen, la carga inicial traerá miles de registros inútiles solo para mostrar un total. | `useSalesStore` / `ReportsContent` |

### Análisis de Resiliencia

*   **Tolerancia a Fallos:** BAJA. Si la carga masiva de ventas falla por timeout, el usuario se queda sin ver nada. No hay manejo de estado "offline" para el resumen.
*   **Integridad de Datos:** COMPROMETIDA. Los cálculos de "Ganancia" no son reales, induciendo al dueño del negocio a decisiones erróneas.
*   **Seguridad (RLS):** DÉBIL. Depende de que el filtro del cliente funcione para ocultar datos, en lugar de que la base de datos restrinja el acceso.

### Plan de Mitigación

Para elevar el puntaje a >90/100, se requiere la siguiente intervención inmediata:

1.  **Backend (Arquitecto de Datos):**
    *   Crear RPC `get_daily_summary(date)` que encapsule la lógica financiera, el semáforo y las alertas.
    *   Este RPC debe manejar la seguridad RLS internamente.

2.  **Frontend (UX):**
    *   **Eliminar** toda la lógica matemática de `ReportsContent.vue`.
    *   **Rediseñar** la UI para coincidir con el FRD-008 (Semáforo, Héroe gigante, Texto conversacional).
    *   Implementar manejo de estados del RPC: `Loading` (Skeleton) -> `Success` (Data) -> `Error` (Mensaje amigable).

3.  **Limpieza:**
    *   Remover la lógica "mock" de costo de mercancía (70%).
    *   Remover el filtrado de cajeros en el cliente (debe venir filtrado del servidor).
