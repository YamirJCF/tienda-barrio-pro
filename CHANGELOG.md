# Bitácora de Cambios (Changelog)

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Versionado Semántico](https://semver.org/lang/es/).

---

## [No Publicado/En Desarrollo]
### Agregado (Added)
- (Próximos cambios aparecerán aquí)

---

## [v0.5.0] - 2026-01-12 - "Blindaje Total"

### Seguridad (Security)
- Implementado `useDataIntegrity.ts` para sanitización automática de localStorage al inicio.
- Bloqueo de inyección de NaN/Infinity en el carrito de compras (`cart.ts`).
- Validación defensiva en `addItem()` y `addWeighableItem()`.
- Fallback seguro de parseInt en `POSView.vue` (NaN → 1).
- Router Guards estrictos: control de acceso por estado de autenticación.
- Panel de Auditoría (`/sys-audit`) restringido solo a modo DEV.

### Agregado (Added)
- Nueva vista `SystemAuditView.vue` con 4 tests automatizados de integridad.
- Composable `useDataIntegrity.ts` para verificación de datos al inicio.
- Archivo de tipos `vite-env.d.ts` para compatibilidad con `import.meta.env`.
- Notificaciones toast en POSView (éxito al agregar, error si PLU no existe).
- Estado de procesamiento (`isProcessing`) con spinner en botón COBRAR.

### Cambiado (Changed)
- `RegisterStoreView.vue`: Validación de email con regex, función async con try/catch.
- `POSView.vue`: Feedback visual con toasts, botón COBRAR con estado de carga.
- `completeSale()` ahora es async con delay de 600ms para UX.
- Router: Ruta `/sys-audit` usa lazy loading condicional (`import.meta.env.DEV`).

### Documentación (Docs)
- Creado `docs/SECURITY_PROTOCOLS.md` con protocolos de seguridad del frontend.

---

## [v0.4.0] - 2026-01-11 - "Refactorización UI"

### Agregado (Added)
- Componentes reutilizables: `StatCard`, `NoPermissionOverlay`, `ListMenuItem`.
- Composable `useCurrencyFormat` para formateo de moneda.

### Cambiado (Changed)
- Consolidación de estilos CSS en `index.css`.
- Separación de lógica de localStorage de la UI.

---

## [v0.3.0] - 2026-01-09 - "Sistema de Permisos"

### Agregado (Added)
- Sistema de permisos para empleados (canSell, canViewInventory, etc.).
- Enforcements de permisos en vistas protegidas.

---

## [v0.2.0] - 2025-12-25 - "Gestión de Caja"

### Agregado (Added)
- Separación de "Cerrar Caja" y "Cerrar Tienda".
- Store `storeStatus.ts` para estado operativo.
- Bloqueo de ventas cuando la tienda está cerrada.

---

## [v0.1.0] - 2025-12-21 - "MVP Inicial"

### Agregado (Added)
- Vista POS con teclado numérico.
- Carrito de compras con soporte para productos pesables.
- Gestión de inventario básica.
- Sistema de clientes y fiados.
- Autenticación con PIN.
