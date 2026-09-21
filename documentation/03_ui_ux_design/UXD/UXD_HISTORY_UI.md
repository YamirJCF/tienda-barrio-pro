## Diseño UX/UI - Sistema de Historiales (Evidence Hub)

### Mapa de Navegación
1.  **Entrada:** `ReportsContent.vue` (Botón "Auditoría y Registros") -> `/history`
2.  **Vista Principal:** `HistoryView.vue` (Lista unificada con filtros)
    -   **Filtro Principal (Chips):** Ventas | Caja | Auditoría | Inventario | Gastos | Créditos | Precios
    -   **Filtro Secundario (Fecha):** Hoy | Semana | Mes | Rango
    -   **Filtro Terciario (Empleado):** Dropdown con lista de empleados (especialmente para Ventas)
3.  **Detalle:** Modal o expansión (`HistoryDetailModal.vue`) al hacer clic en un ítem.

### Detalle de Pantalla (`HistoryView.vue`)
-   **Header:** Botón "Atrás" (vuelve a Reportes), Título "Historiales".
-   **Barra de Filtros:** Carrusel horizontal de chips para seleccionar el tipo de historial.
-   **Filtros Contextuales:**
    -   Selector de Fecha.
    -   Selector de Empleado (visible si el tipo es 'Ventas' o 'Auditoría').
-   **Lista de Eventos:**
    -   Diseño de tarjeta minimalista (`HistoryItemCard`).
    -   Icono lateral indicando el tipo (ej: 🛒 Ventas, 💰 Caja, 🛡️ Auditoría).
    -   **Línea 1:** Descripción principal (ej: "Venta Ticket #1024").
    -   **Línea 2:** Usuario responsable y Hora (ej: "Por: Juan - 10:42 AM").
    -   **Línea 3:** Valor monetario (si aplica) destacado a la derecha (ej: "+$150.000").
-   **Empty State:** Ilustración amigable cuando no hay registros con los filtros actuales.

### Lógica de Componentes
-   **Navegación:** Al cambiar el chip de tipo, se recarga la lista consultando la tabla correspondiente en Supabase.
-   **Scroll Infinito:** Cargar de 20 en 20 para rendimiento.
-   **Filtro de Empleado:**
    -   Debe listar todos los empleados registrados.
    -   Al seleccionar uno, se vuelve a consultar la BDD filtrando por `user_id` o `employee_name`.
-   **Detalle:**
    -   Ventas: Muestra los productos del ticket.
    -   Auditoría: Muestra IP, dispositivo, y detalle del evento.

### Instrucción para el Orquestador
-   Pedir la creación de `HistoryView.vue` en `src/views`.
-   Implementar el composable `useHistory` que unifique la lógica de consulta a diferentes tablas (polimorfismo de datos).
-   Crear componente `HistoryItemCard.vue` altamente reutilizable.
