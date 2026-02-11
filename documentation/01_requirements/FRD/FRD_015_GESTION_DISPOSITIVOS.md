## Documento de Requisitos Funcionales (FRD)

### FRD-015: Gestión Centralizada de Dispositivos

#### Descripción
Implementación de un sistema de gestión de dispositivos desacoplado y centralizado. Se extrae la lógica de control de acceso (aprobación/revocación) del `AuthStore` y de los componentes de UI (`ConnectedDevicesModal`, `NotificationCenter`) para consolidarla en un nuevo Dominio de Datos: `DeviceStore`.

#### Problema a Resolver
Actualmente, la gestión de dispositivos está fragmentada. El usuario quiere centralizar **toda la experiencia de usuario (UX)** dentro del Centro de Notificaciones, evitando tener que navegar a secciones administrativas separadas ("otros espacios") para gestionar accesos.

#### Solución Arquitectónica
- **Nuevo Store (`stores/devices.ts`)**: Lógica de negocio centralizada (fetch, approve, revoke).
- **NotificationCenter (UI)**: 
    - **Widget de Seguridad Embebido**: Se integra una sección fija en la parte superior ("Control de Accesos").
    - **Visibilidad Dinámica**: El widget solo aparece si hay dispositivos pendientes o conectados. Si no hay nada, desaparece.
    - **Lista Unificada**: Muestra tanto las solicitudes pendientes como los dispositivos ya conectados en esta sección prioritaria.
- **AuthStore**: Se descarga de responsabilidad de gestión de terceros.

#### Reglas de Negocio
1.  **Prioridad Visual**: La gestión de empleados siempre aparece antes que cualquier otra notificación del sistema.
2.  **Persistencia en Vista**: Los empleados conectados permanecen visibles en esta sección para permitir su revocación inmediata.
3.  **Auto-Hiding**: Si `Pending == 0` Y `Connected == 0`, la sección de seguridad se oculta completamente.

#### Casos de Uso

**CU-001: Gestión In-Situ (Embedded)**
- **Actor:** Administrador
- **Precondición:** Existe solicitud pendiente o dispositivo conectado.
- **Flujo Principal:** 
  1. Admin entra a Notificaciones.
  2. En el tope, ve el widget "Control de Accesos".
  3. Ve a "Juan (Pendiente)" -> Click Aprobar.
  4. La tarjeta de Juan pasa a estado "Conectado" (o baja a la lista de conectados) ahí mismo.
  5. Ve a "Maria (Conectada)" -> Click Revocar.
  6. Maria desaparece de la lista.

**CU-002: Limpieza Automática**
- **Actor:** Sistema
- **Flujo Principal:**
  1. Admin revoca el último dispositivo.
  2. No quedan pendientes ni conectados.
  3. El widget de seguridad desaparece de la vista.

#### Criterios de Aceptación
- [ ] `AuthStore` no contiene referencias a `pendingRequests` ni métodos `approve/reject`.
- [ ] `DeviceStore` maneja independientemente `fetchPendingRequests` y `fetchConnectedDevices`.
- [ ] El Centro de Notificaciones funciona correctamente delegando la acción al nuevo store.
- [ ] El Panel de Dispositivos lista y permite revocar correctamente sin duplicar lógica.

---

## Lista de Tareas de Alto Nivel
1. [ ] Crear `src/stores/devices.ts` y migrar lógica.
2. [ ] Limpiar `src/stores/auth.ts` (remover lógica de dispositivos).
3. [ ] Refactorizar `NotificationCenterView.vue` para usar `DeviceStore`.
4. [ ] Refactorizar `ConnectedDevicesModal.vue` para usar `DeviceStore`.
5. [ ] Verificar flujos completos (Aprobación y Revocación).

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| `stores/devices.ts` | **[NUEVO]** Centraliza lógica de negocio. |
| `stores/auth.ts` | **[REFACTOR]** Elimina gestión de devices. |
| `NotificationCenter.vue` | **[REFACTOR]** Pasa a ser presentación pura. |
| `ConnectedDevicesModal` | **[REFACTOR]** Pasa a consumir `DeviceStore`. |
