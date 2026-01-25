## Documento de Requisitos Funcionales (FRD)

### Sistema de Historiales y Trazabilidad (SPEC-009)

> **Estado**: ✅ Implementado (Fase 3)

#### Descripción
Implementación de un sistema centralizado de historiales ("Evidence Hub") que permita auditar todas las operaciones críticas del negocio. Este módulo servirá como la fuente de verdad para la integridad financiera y operativa, accesible estratégicamente desde la vista de Reportes.

#### Reglas de Negocio
1.  **Inmutabilidad:** Ningún registro histórico puede ser eliminado o editado, solo anulado mediante una contra-operación registrada (ej: devolución anula venta).
2.  **Trazabilidad:** Cada registro debe contener: `timestamp`, `usuario_responsable`, `tipo_operacion` y `payload` (datos del evento).
3.  **Seguridad por Niveles:** El acceso a ciertos historiales (ej: Auditoría de Seguridad) debe estar restringido a usuarios con rol `admin`.
4.  **Acceso Contextual:** Aunque centralizados, los historiales deben ser accesibles desde contextos lógicos (Reportes -> Historiales).

#### Clasificación de Historiales

##### 🚨 Nivel 1: Críticos (Integridad Financiera)
1.  **Historial de Ventas (Transacciones):**
    *   *Detalle:* Tickets, anulaciones, métodos de pago, **empleado responsable**.
    *   *Uso:* Conciliación de caja diaria y **auditoría de desempeño por empleado** (quién vendió qué).
2.  **Historial de Arqueos (Cash Control):**
    *   *Detalle:* Aperturas, cierres, conteo de efectivo, diferencias reportadas.
    *   *Uso:* Control de flujo de efectivo y detección de faltantes.
3.  **Log de Auditoría (System Audit):**
    *   *Detalle:* Logins fallidos, cambios de PIN, accesos fuera de horario.
    *   *Uso:* Seguridad preventiva y forense.

##### ⚠️ Nivel 2: Operativos (Control de Gestión)
4.  **Kardex de Inventario:**
    *   *Detalle:* Compras, ventas, mermas, ajustes de stock.
    *   *Uso:* Rastreo de inventario fantasma o robo hormiga.
5.  **Historial de Gastos:**
    *   *Detalle:* Salidas de dinero de caja menor.
    *   *Uso:* Control de gastos operativos diarios.

##### ℹ️ Nivel 3: Valor Agregado
6.  **Historial de Créditos (Fiado):**
    *   *Detalle:* Abonos, nuevas deudas, liquidaciones.
    *   *Uso:* Gestión de cartera de clientes.
7.  **Historial de Precios:**
    *   *Detalle:* Cambios en costo y precio de venta.
    *   *Uso:* Análisis de inflación interna y márgenes.

#### Casos de Uso
-   **Actor:** Administrador / Dueño de Tienda
-   **Precondición:** Usuario autenticado con permisos de admin.
-   **Flujo Principal:**
    1.  Usuario ingresa a "Administración" -> "Reportes".
    2.  Analiza gráficas y detecta una anomalía (ej: bajón de ventas).
    3.  Pulsa botón "Ver Auditoría y Registros".
    4.  Sistema redirige a `/history` (Vista Unificada de Historiales).
    5.  Usuario filtra por fecha y tipo (ej: "Ventas" de "Hoy").
    6.  Sistema despliega lista detallada de eventos.

#### Criterios de Aceptación
- [ ] Existencia de la ruta `/history` protegida por autenticación.
- [ ] Sub-navegación o filtros funcionales para los 7 tipos de historiales.
- [ ] Renderizado correcto de listas con scroll infinito o paginación.
- [ ] Enlace funcional desde `ReportsContent.vue` hacia `/history`.

---

## Lista de Tareas de Alto Nivel
1.  [ ] Crear vista contenedora `HistoryView.vue`.
2.  [ ] Definir estructura de datos (tablas Supabase) para logs que aún no persisten (Audit, Precios).
3.  [ ] Implementar componentes de lista reutilizables (`HistoryItemCard.vue`).
4.  [ ] Conectar botón en `ReportsContent.vue`.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| `ReportsContent.vue` | Agregar botón de acceso a Historiales. |
| `router/index.ts` | Registrar ruta `/history` y sus guards. |
| `SystemAuditView.vue` | Integrar o reemplazar por la nueva vista unificada si aplica. |
