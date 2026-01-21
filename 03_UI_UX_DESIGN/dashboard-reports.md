# Diseño UX/UI - Dashboard y Reportes (WO-PHASE2-004)

> **Rol**: Diseñador de UX/UI
> **Fecha**: 2026-01-21

## 1. Dashboard Principal (`DashboardView.vue`)

### Mapa de Navegación
- **Ruta**: `/` (Home)
- **Conexiones**:
  - `[Toggle]` → `/cash-control` (Si está abierto y se cierra)
  - `[Card Inventario]` → `/inventory`
  - `[Card Ventas]` → `/reports` (Nueva ruta o tab)
  - `[Bell icon]` → `/notifications`

### Detalle de Pantalla

1.  **Header**:
    - Título de la tienda.
    - Acciones a la derecha: Notificaciones, Perfil de Usuario.

2.  **Tarjeta de Estado (Hero)**:
    - **Visual**: Grande, prominente.
    - **Estados**:
        - *Cerrado*: Gris oscuro/Negro. Toggle "Desliza para ABRIR".
        - *Abierto*: Azul/Verde. Toggle "ABIERTO". Muestra hora de apertura.
    - **Interacción**: Deslizar el toggle lleva a la lógica de apertura o cierre (Caja).

3.  **Grid de Estadísticas (KPIs)**:
    - Diseño de 2 columnas.
    - **Caja Actual**: Icono `payments` (Verde). Muestra el efectivo teórico en caja.
    - **Ventas Hoy**: Icono `show_chart` (Azul). Muestra Total Ventas. *Subtítulo*: "X Transacciones".
    - **Por Cobrar**: Icono `person` (Naranja). Total Fiado hoy.
    - **Inventario**: Icono `inventory_2` (Morado). Total productos. *Alerta*: "X bajo stock" (Rojo) si aplica.

4.  **Accesos Rápidos (Admin)**: 
    - Lista limpia de acciones: "Empleados", "Configuración".

### Lógica de Componentes
- **StatCard**: Debe recibir `subtitle` y `alert` opcionales. Animación ligera al cargar datos.
- **Onboarding**: Si el inventario está vacío, reemplazar las stats con un banner "Agrega tu primer producto".

---

## 2. Centro de Reportes (`ReportsContent.vue`)

### Mapa de Navegación
- **Ubicación**: Dentro de `/admin` tab "Reportes".

### Detalle de Pantalla

1.  **Filtros Globales**:
    - **Tiempo**: Tabs "Hoy | Semana | Mes".
    - **Cajero** (NUEVO): Dropdown "Todos | [Nombre Empleado]".
    - **Método de Pago**: Checkboxes o tabs para filtrar (opcional, ya desglosado visualmente).

2.  **Resumen Financiero (Card Principal)**:
    - Estilo "Dark Glassmorphism".
    - Muestra: Ventas Totales.
    - Desglose secundario: Costo Estimado, Ganancia Bruta.

3.  **Desglose por Origen**:
    - Grid de tarjetas pequeñas: Efectivo, Bancos (Nequi), Fiado.

4.  **Sección: Valoración de Inventario (NUEVO)**:
    - Solo visible si el usuario tiene permiso (Admin).
    - **Card**:
        - "Costo del Inventario": Suma de `stock * cost`.
        - "Valor de Venta": Suma de `stock * price`.
        - "Margen Potencial": Porcentaje y Valor.

5.  **Rankings**:
    - Tabs: "Más Vendidos", "Stock Bajo", "Sin Movimiento".

### Instrucción para el Orquestador
1.  **Dashboard**: Asegurar que los widgets consuman datos en tiempo real de `salesStore` y `inventoryStore`.
2.  **Reportes**:
    - Implementar filtro de `employeeId` en `ReportsContent`.
    - Crear nuevo computed `inventoryValuation` en `InventoryStore` o calcularlo localmente en `ReportsContent` para la nueva tarjeta.
    - Usar `product.cost` si existe, sino fallback a 70%.
