# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

- **Usuario Primario:** Tendero de barrio colombiano (dueño/administrador) y sus empleados de confianza.
- **Situación Operativa:** Operación de mostrador en tiempo real desde smartphones Android (81% del mercado objetivo) o navegador de escritorio, frecuentemente con una sola mano, atendiendo clientes en fila bajo condiciones variables de iluminación y conectividad intermitente.
- **Trabajo por Resolver (JTBD):** Reemplazar la libreta física de papel por un sistema rápido y a prueba de errores para cobrar en el Punto de Venta (POS), llevar cuentas claras de crédito ("fiado"), controlar el inventario por lotes (FIFO), auditar la apertura/cierre de caja y supervisar los permisos y turnos del personal.

## Product Purpose

**Tienda Barrio Pro** es una libreta digital con funciones financieras y operativas avanzadas diseñada para tiendas de barrio en Colombia. Su propósito es eliminar las pérdidas invisibles (fugas de efectivo, fiados olvidados, márgenes mal calculados y descontrol de inventario) sin exigir conocimientos contables complejos ni trámites fiscales. El éxito se mide en ventas registradas en menos de 3 toques, saldos de caja cuadrados al centavo y visibilidad inmediata de la rentabilidad real.

## Positioning

A diferencia de los sistemas ERP o POS empresariales diseñados para cadenas y facturación electrónica DIAN, **Tienda Barrio Pro** opera bajo el modelo de **"Mostrador de Precisión con Autoridad en el Servidor"**: combina la inmediatez táctil de una libreta de bolsillo (incluyendo comandos rápidos por texto, calculadora de peso e interfaz móvil resiliente offline en POS) con un motor contable y de seguridad bancario en PostgreSQL/Supabase (cálculos financieros 100% en backend, trazabilidad FIFO, control estricto de dispositivos y aprobación de pase diario).

## Operating Context

- **Superficie Operativa (`frontend/` — Modo `Operate`):** Aplicación PWA en Vue 3 + Pinia + Tailwind CSS v4 conectada a Supabase. Incluye Punto de Venta (`POSView`), Control de Caja (`CashControlView`), Inventario y Entradas de Stock (`InventoryView`, `StockEntryView`), Cartera de Clientes/Fiado (`ClientListView`, `ClientDetailView`), Cuentas por Pagar y Proveedores (`PayablesView`, `SuppliersView`), Gastos (`ExpensesView`), Reportes Financieros (`FinancialDashboardView`, `ReportsHubView`) y Centro de Seguridad/Empleados (`AdminHubView`, `EmployeeManagerView`, `DailyWaitingRoom`, `GatekeeperPending`).
- **Superficie Comercial (`landing/` — Modo `Persuade`):** Sitio web en Vue 3 enfocado en comunicar la propuesta de valor a tenderos y aliados comerciales con demostraciones interactivas de Finanzas, Inventario y Operación, priorizando tipografía expresiva y claridad visual sin ruido decorativo.
- **Rituales Diarios del Negocio:**
  1. Solicitud de acceso diario / desbloqueo por PIN de empleado (`PinUnlockModal`, `DailyWaitingRoom`).
  2. Apertura de caja con base en efectivo.
  3. Despacho continuo en mostrador (efectivo, transferencia manual o fiado con validación de cupo).
  4. Registro de compras a proveedores y gastos de caja menor.
  5. Arqueo y cierre de caja diario (con soporte para auditoría de cierres forzados).

## Capabilities and Constraints

- **Autoridad Estricta del Backend (Inviolable):** Todo cálculo financiero (totales, subtotales, saldos de fiado, costos FIFO, utilidad neta y arqueos de caja) se ejecuta exclusivamente en RPCs de PostgreSQL/Supabase. El frontend jamás suma precios ni inventa estados financieros; solo pide, espera con *skeletons* fieles y presenta el payload.
- **Prohibición de Fallos Silenciosos:** Ningún error de red o rechazo de regla de negocio se oculta con `$0`, `null` o listas vacías; todo fallo muestra su causa y ruta de recuperación.
- **Resiliencia Offline Acotada:** El módulo POS permite encolar ventas ante caídas temporales de red (`syncQueue`), mientras que los módulos administrativos (Inventario, Caja, Clientes, Empleados, Reportes) exigen conexión activa para garantizar consistencia transaccional.
- **Exclusiones Estratégicas Permanentes (`SYSTEM_BOUNDARIES.md`):**
  - Sin facturación electrónica DIAN ni cálculo de impuestos legales (los recibos son comprobantes internos de control).
  - Sin pasarelas de pago bancarias integradas (el cobro es físico/directo y el registro es declarativo).
  - Sin arquitectura multi-sucursal (1 instancia de tienda = 1 negocio físico con 1 propietario Admin).

## Brand Commitments

- **Voz y Tono:** Directo, claro, respetuoso del oficio del tendero colombiano ("Vender", "Fiado", "Base de Caja", "Cuadre", "Proveedores"). Cero jerga corporativa o tecnicismos en inglés visibles al usuario.
- **Identidad Dual Cohesiva:**
  - En operación (`frontend/`): Azul Operativo (`#245feb`), Esmeralda de Liquidez (`#10b981` / `#0df2aa`) y Pizarra Profunda (`#111621`).
  - En comunicación comercial (`landing/`): Teal Editorial (`#0F766E` / `#14B8A6`) con contraste de tinta negra (`#0C0E12`).

## Evidence on Hand

- Especificaciones funcionales y legales documentadas en `documentation/01_requirements/` (`SPEC_001_AUTORIDAD_DEL_SERVIDOR.md`, `SYSTEM_BOUNDARIES.md`, `FRD-001` a `FRD-006`).
- Componentes base implementados en `frontend/src/components/ui/` (`BaseButton`, `BaseInput`, `FormInputCurrency`, `StatCard`, `BaseModal`, `BaseEmptyState`, `BaseListSkeleton`) y demostraciones animadas en `landing/src/components/`.
- No fabricar testimonios comerciales falsos, logos de clientes inexistentes ni certificaciones fiscales DIAN que contradigan `SYSTEM_BOUNDARIES.md`.

## Product Principles

1. **Velocidad de Mostrador sobre Decoración:** Si una tarea frecuente (vender, buscar producto, abonar fiado) puede resolverse en 2 toques en vez de 4, se elimina cualquier paso o adorno intermedio.
2. **El Dato Financiero es Sagrado:** Las cifras monetarias y cantidades usan siempre alineación tabular (`JetBrains Mono` / `tabular-nums`), jerarquía inequívoca y estados de carga explícitos (*skeletons* estructurales y bloqueo de doble envío).
3. **Claridad Bajo Presión:** Cada estado vacío, alerta de cupo superado o bloqueo de seguridad explica exactamente qué ocurrió y cuál es la acción inmediata para continuar operando.
4. **Ergonomía Táctil Mobile-First:** Controles diseñados para el pulgar en pantallas de 360px–430px de ancho, con áreas de toque generosas (`min-h-11`), barra de navegación inferior fija (`BottomNav`) y retroalimentación táctil visual inmediata (`active:scale-95`).

## Accessibility & Inclusion

- Contraste mínimo WCAG AA (4.5:1 en texto de cuerpo y etiquetas operativas, 3:1 en titulares y cifras de gran tamaño) pensado para pantallas de gama media/baja con brillo variable en interiores y exteriores de tienda.
- Prevención de zoom accidental en inputs móviles y objetivos táctiles cómodos para usuarios de todas las edades.
