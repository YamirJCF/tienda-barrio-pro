# Diseño UX/UI - Resumen Diario Inteligente (Smart Daily Summary)

> **Ref:** FRD-008, AUDIT-001
> **Tipo:** Rediseño Completo (V2)
> **Principio:** Feed Conversacional (No Dashboard)

## Mapa de Navegación
1.  **Entrada:** Bottom Navigation Bar > Icono Reportes (Gráfica/Lista).
2.  **Vista Única:** `SmartDailySummaryView`.
    *   No tiene sub-navegación (Tabs eliminados).
    *   No tiene filtros de fecha complejos (siempre muestra "Hoy" por defecto, con navegación simple atrás/adelante opcional si el backend lo permite, pero el foco es "Hoy").

## Detalle de Pantalla (De Arriba a Abajo)

### 1. Header Contextual (Semáforo)
*   **Visual:** Panel de ancho completo en la parte superior. Color de fondo dinámico según `traffic_light.status` (Verde Suave, Amarillo, Rojo Suave).
*   **Contenido:**
    *   **Fecha:** Alienada a la izquierda o centro (ej. "Martes, 4 Feb").
    *   **Mensaje:** Texto conversacional grande (ej. "¡Vas volando! +15% vs tu promedio").
*   **Objetivo:** Feedback emocional inmediato.

### 2. Hero Section (La Verdad)
*   **Visual:** Texto masivo, centrado, alto contraste.
*   **Contenido:** El monto total de ventas (`hero_number`).
*   **Formato:** Moneda sin decimales (ej. `$150.000`), usando la tipografía Display de la app.

### 3. Money Breakdown (Desglose de Caja)
*   **Visual:** Fila de 3 tarjetas compactas o indicadores debajo del Hero.
*   **Items:**
    1.  **Efectivo:** Icono billete + Monto.
    2.  **Digital:** Icono móvil/banco + Monto.
    3.  **Fiado:** Icono libreta + Monto.
*   **Estilo:** Minimalista. Si un valor es 0, se muestra en gris pero visible.

### 4. Feed de Alertas (Lista de Tareas)
*   **Visual:** Lista vertical scrollable (estilo "Notificaciones" o "To-Do List").
*   **Contenido:** Items ordenados por prioridad (Critical > Warning > Info).
*   **Anatomía del Item:**
    *   **Icono:** Indicador de tipo (Caja fuera de stock, Advertencia de fiado vencido).
    *   **Texto:** Mensaje directo (ej. "Azúcar se agotó", "Juan debe $50.000 hace 15 días").
    *   **Acción (Opcional):** Botón "ghost" pequeño a la derecha (ej.  "Ver", "Cobrar").

### 5. Recordatorio Predictivo (Footer)
*   **Visual:** Tarjeta diferenciada al final de la lista.
*   **Contenido:** Mensaje de cierre (`reminder`).
*   **Ejemplo:** "Mañana recuerda: Pedir Leche y pagar el recibo de luz".

## Lógica de Componentes

### Comportamiento Pasivo (Dumb Display)
*   El componente **NO DEBE** realizar cálculos matemáticos.
*   Muestra exactamente lo que recibe del JSON `get_daily_summary`.
*   Si `hero_number` es 150000, muestra 150000. No suma items de una lista.

### Estados de Carga
*   **Skeleton Loader:**
    *   Un bloque rectangular para el Header.
    *   Un bloque grande cuadrado para el Hero.
    *   Tres bloques pequeños horizontales para el Breakdown.
    *   Tres tiras para la lista de Alertas.
*   **NO usar spinner de pantalla completa.** El usuario debe percibir la estructura inmediatamente.

### Manejo de Errores
*   Si falla la carga: Mostrar "No pudimos cargar tu resumen" en el lugar del Hero, con un botón "Reintentar".

## Instrucción para el Orquestador

1.  **Backend (Prerrequisito):** Solicitar al Arquitecto de Datos la implementación del RPC `get_daily_summary` que devuelva la estructura JSON plana definida en la auditoría (Semaforo, Hero, Desglose, Alertas).
2.  **Frontend (Limpieza):** Eliminar `ReportsContent.vue` actual (el diseño de Dashboard con Tabs y Gráficas complejas).
3.  **Frontend (Construcción):** Crear nuevo componente `SmartDailySummary.vue` que implemente la vista vertical descrita arriba.
4.  **Store:** Crear acción `fetchDailySummary` en `reportsStore` (o `dashboardStore`) que consuma el RPC y guarde el estado.
