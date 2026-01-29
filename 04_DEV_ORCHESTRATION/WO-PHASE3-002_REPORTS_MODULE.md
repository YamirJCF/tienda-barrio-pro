## Orden de Trabajo - Implementación Módulo de Reportes (RE-02)

### Estado Git Actual
- Rama a crear: `feat/re-02-reports-module`
- Comando: `git checkout -b feat/re-02-reports-module`

---

### Plan de Acción Atómico

#### Tarea 1: Estructura y Navegación
**Objetivo**: Asegurar que `/reports` sea accesible y tenga la estructura base.
1.  Verificar `src/router/index.ts`. Si no existe ruta `/reports`, crearla apuntando a `ReportsView.vue` (o usar `ReportsContent` dentro de un layout Admin).
2.  Crear `src/views/ReportsView.vue` si no existe (Wrapper de `ReportsContent`).
3.  Actualizar `ReportsContent.vue` con el esqueleto del diseño (Grid Layout).
4.  *TIEMPO ESTIMADO: 15 min*

#### Tarea 2: Lógica de Negocio (Store Aggregation)
**Objetivo**: Centralizar cálculos financieros en `salesStore` o un composable dedicado.
1.  Utilizar `getDailyStats` de `salesStore` (ya existente).
2.  Crear Computed `financialSummary` en `ReportsContent`:
    -   Total Ventas (Suma total).
    -   Total Costos (Suma `item.quantity * product.cost`). *Requiere obtener producto o guardar costo en venta.*
    -   Margen Bruto (Ventas - Costos).
3.  Implementar Filtros de Fecha (Hoy, Semana, Mes).
4.  *TIEMPO ESTIMADO: 25 min*

#### Tarea 3: Componentes de Visualización (UI)
**Objetivo**: Construir las tarjetas de reporte definidas en el diseño.
1.  **SummaryCard**: Componente visual para KPIs (Ventas, Ganancia, Ticket Promedio).
2.  **PaymentBreakdown**: Tarjeta con desglose (Efectivo vs Nequi vs Fiado).
3.  **InventoryValuation**: Tarjeta (Solo Admin) con valor total del inventario.
4.  *TIEMPO ESTIMADO: 30 min*

---

### Bloque de Prompt para Antigravity

#### Prompt 1: Tarea 1+2 (Skeleton & Logic)
```markdown
## Prompt para Módulo de Reportes (RE-02) - Parte 1

### Contexto
- Archivo: `src/components/ReportsContent.vue`
- Store: `src/stores/sales.ts`, `src/stores/inventory.ts`

### Objetivo
Implementar la lógica y estructura base del Centro de Reportes.

### Requerimientos
1. **Estado de Filtros**:
   - `dateRange`: 'today' | 'week' | 'month' (Default: 'today').
   - `selectedEmployee`: string | null (Default: null/Todos).

2. **Propiedades Computadas**:
   - `filteredSales`: Array de ventas filtrado por fecha y empleado.
   - `summary`: Objeto con `{ totalSales, totalCost, grossMargin, salesCount }`.
     - *Nota*: Si la venta no guardó el costo histórico, usar 0 o un estimado.
   - `paymentBreakdown`: Objeto con totales por método (`cash`, `nequi`, `fiado`).

3. **Template**:
   - Barra superior con los Filtros (Botones para rango, Select para empleado).
   - Grid css para alojar los futuros widgets.
   - Mostrar "Resumen Financiero" básico (texto plano por ahora) para validar cálculos.
```

#### Prompt 2: Tarea 3 (UI Widgets)
```markdown
## Prompt para Módulo de Reportes (RE-02) - Parte 2

### Contexto
- Archivo: `src/components/ReportsContent.vue`

### Objetivo
Embellecer la data con componentes visuales "StatCards" y Tablas.

### Cambios Visuales
1. **Hero Card (Resumen)**:
   - Fondo oscuro/gradiente (Glassmorphism).
   - Mostrar "Ventas Totales" en grande.
   - Mostrar pequeños indicadores de "Margen" y "Ticket Promedio".

2. **Desglose de Pagos**:
   - 3 Tarjetas horizontales o una fila con 3 columnas.
   - Iconos: 💵 (Efectivo), 📱 (Nequi), 🤝 (Fiado).
   - Colores: Verde, Morado, Ámbar.

3. **Valoración de Inventario** (Si es Admin):
   - Importar `useInventoryStore`.
   - Calcular `totalValuation` (sum(stock * price)) y `totalCost` (sum(stock * cost)).
   - Mostrar tarjeta "Capital en Inventario".
```

### Comandos de Consola
```bash
git checkout -b feat/re-02-reports-module
```
