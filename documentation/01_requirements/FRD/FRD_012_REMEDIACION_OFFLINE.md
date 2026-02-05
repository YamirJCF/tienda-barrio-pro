# FRD-012-R: Remediación del Módulo Offline

> **Versión:** 2.0
> **Fecha:** 2026-02-05
> **Estado:** Aprobado para Implementación
> **Decisión Arquitectónica:** Opción B - "Offline Defensivo"

---

## 1. Descripción

Remediación del sistema de sincronización offline para garantizar operación confiable durante apagones eléctricos y redes móviles saturadas. El sistema permitirá ventas sin conexión con validación local preventiva y sincronización segura.

---

## 2. Contexto del Problema

| Factor | Situación Actual |
|--------|-----------------|
| Apagones eléctricos | 3-5 veces/semana, duración 2-4 horas |
| Comportamiento de red | Usuarios cambian a datos móviles → red saturada |
| Impacto económico estimado | ~$3.6M COP/mes en ventas fallidas sin remediación |
| Estado actual del módulo | Encolamiento sin validación + operación de sincronización obsoleta |

---

## 3. Reglas de Negocio

### RN-R01: Validación de Stock Local
El sistema **DEBE** verificar el stock disponible en el módulo de inventario local antes de encolar una venta sin conexión. Si el stock local es menor que la cantidad solicitada, la venta **DEBE** rechazarse con mensaje claro.

### RN-R02: Validación de Crédito Local
Para ventas tipo "fiado", el sistema **DEBE** verificar que el saldo actual más el monto de la venta no exceda el límite de crédito del cliente, usando datos del módulo de clientes local. Si excede, la venta **DEBE** rechazarse con mensaje claro.

### RN-R03: Sincronización con Operación Segura
El motor de sincronización **DEBE** usar la versión actual (V2) de la operación de procesamiento de venta para garantizar integridad financiera.

### RN-R04: Indicador Visual de Modo Offline
Cuando el sistema detecte ausencia de conexión a internet, **DEBE** mostrar un indicador visible al usuario: "Modo Offline - Ventas limitadas al stock local".

### RN-R05: Recuperación de Sesión
Si la sesión del usuario expira durante operación sin conexión, el sistema **DEBE** solicitar re-autenticación antes de intentar sincronizar las ventas pendientes.

---

## 4. Casos de Uso

### Caso A: Venta Offline Válida
- **Actor:** Empleado/Tendero
- **Precondición:** Sin conexión a internet. Producto con stock disponible localmente.
- **Flujo Principal:**
    1. El usuario selecciona productos y cantidades.
    2. El sistema verifica stock local.
    3. El sistema encola la venta localmente.
    4. El sistema actualiza el stock local (optimista).
    5. El sistema muestra confirmación con indicador "Pendiente de Sincronización".
- **Postcondición:** Venta guardada localmente. Stock local reducido.

### Caso B: Venta Offline Rechazada por Stock
- **Actor:** Empleado/Tendero
- **Precondición:** Sin conexión a internet. Stock local insuficiente.
- **Flujo Principal:**
    1. El usuario selecciona productos y cantidades.
    2. El sistema verifica stock local.
    3. El sistema detecta stock insuficiente.
    4. El sistema muestra error: "Stock insuficiente. Disponible: X unidades".
- **Flujo Alternativo:** El usuario reduce la cantidad o cancela.
- **Postcondición:** Venta NO procesada. Stock local sin cambios.

### Caso C: Venta Fiado Rechazada por Crédito
- **Actor:** Empleado/Tendero
- **Precondición:** Sin conexión. Cliente seleccionado excedería límite de crédito.
- **Flujo Principal:**
    1. El usuario selecciona venta fiado para cliente.
    2. El sistema verifica límite de crédito local.
    3. El sistema detecta que se excedería el límite.
    4. El sistema muestra error: "Límite de crédito excedido".
- **Postcondición:** Venta NO procesada. Saldo del cliente sin cambios.

### Caso D: Sincronización Post-Reconexión
- **Actor:** Sistema (Automático)
- **Precondición:** Ventas pendientes en cola. Internet disponible.
- **Flujo Principal:**
    1. El sistema detecta conexión a internet.
    2. El sistema verifica sesión válida.
    3. El sistema envía ventas pendientes al servidor (FIFO).
    4. El servidor procesa atómicamente cada venta.
    5. El sistema marca ventas como sincronizadas.
- **Flujo Alternativo:** Si sesión expirada, solicitar re-login.
- **Postcondición:** Ventas sincronizadas. Cola vacía.

---

## 5. Criterios de Aceptación

- [ ] Venta offline rechazada si stock local insuficiente
- [ ] Venta fiado offline rechazada si excede límite de crédito
- [ ] Sincronización usa operación de venta V2
- [ ] Indicador visible en modo offline
- [ ] Solicitud de re-login si sesión expira durante sincronización

---

## 6. Requisitos de Datos (Para Equipo Data)

No se requieren cambios en el esquema de base de datos. La operación de procesamiento de venta V2 ya existe y está validada.
