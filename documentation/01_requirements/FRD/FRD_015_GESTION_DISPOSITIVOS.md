# FRD-015: Gestión Centralizada de Dispositivos

> **Módulo:** Seguridad / Accesos  
> **Versión:** 2.0 (Saneamiento documental 2026-08-07)  
> **Estado:** Aprobado  
> **SDD Asociado:** SDD_015 (Por crear — Fase 3-P2)

---

## Descripción

El sistema DEBE proveer un punto de control centralizado y unificado para que el Administrador gestione los accesos de dispositivos (solicitudes pendientes y dispositivos actualmente conectados). Esta gestión DEBE ser accesible sin necesidad de navegar a secciones administrativas separadas — DEBE estar integrada dentro del flujo principal de notificaciones del Administrador.

---

## Reglas de Negocio

1. **Prioridad de Visibilidad:** La sección de control de accesos a dispositivos DEBE aparecer siempre por encima de cualquier otra notificación del sistema. El Administrador nunca debe buscar entre notificaciones para encontrar solicitudes de acceso pendientes.

2. **Persistencia de Dispositivos Conectados:** El listado de dispositivos con sesión activa DEBE permanecer visible en la sección de control de accesos para permitir su revocación inmediata sin navegar a otra sección.

3. **Auto-Ocultamiento:** Cuando no existan solicitudes pendientes Y no existan dispositivos con sesión activa, la sección de control de accesos DEBE ocultarse completamente de la vista. No DEBE mostrar un estado vacío permanente.

4. **Vista Unificada:** Las solicitudes de acceso pendientes y los dispositivos ya conectados DEBEN mostrarse en la misma sección de control, distinguidos visualmente por su estado (Pendiente / Conectado).

5. **Dominio Exclusivo del Admin:** Solo el Administrador PUEDE aprobar, rechazar o revocar accesos de dispositivos. Un empleado NUNCA DEBE ver ni acceder a esta sección de control.

---

## Casos de Uso

**Caso A: Gestión de Acceso en el Flujo de Notificaciones**

- **Actor:** Administrador
- **Precondición:** Existe al menos una solicitud de acceso pendiente o un dispositivo con sesión activa.
- **Flujo Principal:**
  1. El Administrador accede al centro de notificaciones.
  2. El sistema muestra la sección de control de accesos en la posición más prominente (tope de la lista).
  3. El Administrador visualiza las solicitudes pendientes y los dispositivos conectados en una sola vista.
  4. El Administrador selecciona una solicitud pendiente y la aprueba.
  5. El sistema registra la aprobación y actualiza el estado del dispositivo a Conectado en la misma vista, sin recargar la página.
  6. El Administrador selecciona un dispositivo conectado y lo revoca.
  7. El sistema registra la revocación y el dispositivo desaparece del listado inmediatamente.
- **Postcondición:** El estado de accesos queda actualizado. La revocación es inmediata y persistente.

**Caso B: Auto-Ocultamiento por Estado Vacío**

- **Actor:** Sistema
- **Precondición:** No existen solicitudes pendientes ni dispositivos con sesión activa.
- **Flujo Principal:**
  1. El Administrador revoca el último dispositivo activo.
  2. El sistema verifica que el conteo de pendientes = 0 y el conteo de conectados = 0.
  3. La sección de control de accesos desaparece de la vista automáticamente.
- **Postcondición:** La vista de notificaciones no muestra secciones vacías.

**Caso C: Rechazo de Solicitud de Acceso**

- **Actor:** Administrador
- **Precondición:** Existe al menos una solicitud de acceso pendiente.
- **Flujo Principal:**
  1. El Administrador visualiza la solicitud de acceso de un dispositivo desconocido o no autorizado.
  2. El Administrador selecciona la opción de rechazar la solicitud.
  3. El sistema registra el rechazo y elimina la solicitud del listado inmediatamente.
  4. El dispositivo rechazado no obtiene acceso al sistema.
- **Postcondición:** La solicitud desaparece del listado. El dispositivo no tiene acceso.

---

## Criterios de Aceptación

- [ ] **CA-015-01:** La sección de control de accesos aparece en la posición más prominente del flujo de notificaciones, por encima de cualquier otra notificación.
- [ ] **CA-015-02:** Las solicitudes pendientes y los dispositivos conectados se muestran en una sola sección unificada.
- [ ] **CA-015-03:** La aprobación de una solicitud cambia el estado del dispositivo a Conectado sin recargar la página completa.
- [ ] **CA-015-04:** La revocación de un dispositivo lo elimina del listado inmediatamente.
- [ ] **CA-015-05:** Cuando `pendientes = 0 AND conectados = 0`, la sección de control desaparece completamente de la vista.
- [ ] **CA-015-06:** Los empleados no tienen acceso a la sección de control de dispositivos bajo ninguna circunstancia.
- [ ] **CA-015-07:** Las operaciones de aprobación, rechazo y revocación quedan registradas en el historial de auditoría del sistema.

---

## Requisitos de Datos (Para Equipo Data)

El sistema DEBE mantener:

| Información | Descripción |
|-------------|-------------|
| Estado del dispositivo | Pendiente / Conectado / Revocado / Rechazado |
| Identificación del dispositivo | Nombre o referencia que permita al Admin reconocer el dispositivo |
| Identificación del usuario solicitante | A qué empleado pertenece el dispositivo |
| Marca de tiempo de la solicitud | Cuándo fue enviada la solicitud de acceso |
| Marca de tiempo de la acción | Cuándo fue aprobado, rechazado o revocado |
| Responsable de la acción | Qué Administrador tomó la decisión |
