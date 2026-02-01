# FRD-011: Manejo de Errores y Resiliencia

> **Módulo:** Transversal  
> **Versión:** 1.0  
> **Fecha:** 2026-01-27  
> **Estado:** Aprobado

---

## Descripción

El sistema DEBE manejar todos los escenarios de fallo de manera controlada, garantizando que el usuario nunca pierda datos, siempre sepa qué está pasando, y pueda continuar operando incluso ante problemas de conectividad.

---

## Principios Fundamentales

| Principio | Regla |
|-----------|-------|
| **Fail-Safe** | El sistema NUNCA debe "romperse" ni mostrar pantallas de error técnico |
| **Transparencia** | El usuario DEBE saber qué pasó mediante mensajes comprensibles |
| **Recuperabilidad** | El usuario DEBE poder continuar operando después de cualquier error |
| **No-Pérdida** | Los datos del usuario NUNCA se pierden por un error del sistema |

---

## Reglas de Negocio

### RN-011-01: Clasificación de Errores

El sistema DEBE clasificar cada error en una de las siguientes categorías:

| Categoría | Descripción | Mensaje al Usuario |
|-----------|-------------|-------------------|
| Conectividad | Pérdida de conexión a internet o servidor | "Sin conexión" |
| Negocio | Regla de negocio no satisfecha | Mensaje específico de la regla |
| Acceso Denegado | Usuario sin permisos o cuenta desactivada | "No tienes acceso a esta función" |
| Datos | Información inválida o corrupta | "Verifica la información" |
| Sistema | Error inesperado | "Error inesperado. Intenta de nuevo" |

### RN-011-02: Modo Offline Automático (Solo Ventas)

Cuando el sistema detecte pérdida de conexión durante una venta:
1. El sistema DEBE activar modo offline automáticamente
2. El sistema DEBE iniciar un temporizador interno de **60 segundos**
3. Si el temporizador llega a cero, el sistema DEBE notificar: "Estás trabajando sin internet"
4. Cuando la conexión se restablezca, el sistema DEBE notificar: "Conexión restablecida"
5. La segunda notificación SOLO aparece si la primera fue emitida

### RN-011-03: Prevención de Ventas Duplicadas

El sistema DEBE generar un identificador único para cada venta ANTES de enviarla al servidor. Si la venta se reintenta con el mismo identificador, el servidor DEBE retornar la venta existente sin duplicarla.

### RN-011-04: Stock Insuficiente

Si el stock de un producto se agota entre que el usuario lo agrega al carrito y confirma la venta:
1. El sistema DEBE informar qué producto tiene stock insuficiente
2. El sistema DEBE mostrar la cantidad disponible actual
3. El sistema DEBE ofrecer ajustar la cantidad

### RN-011-05: Validación de Estado de Cuenta en Cada Operación

El sistema DEBE validar que el usuario tenga estado "activo" en CADA operación del servidor:
1. Si el estado es "inactivo" o "eliminado", el servidor DEBE rechazar la operación
2. El sistema DEBE mostrar mensaje: "Tu cuenta ha sido desactivada"
3. El sistema DEBE cerrar la sesión local automáticamente
4. El sistema DEBE redirigir a la pantalla de inicio

> **Nota:** Esta validación aplica a empleados. El Admin no puede ser desactivado.

### RN-011-06: Datos Corruptos en Almacenamiento Local

Si el sistema detecta datos corruptos o inválidos en el almacenamiento local:
1. PRIMERO intentar reparar (eliminar solo los registros inválidos)
2. Si la reparación falla, resetear ese módulo a estado vacío
3. SIEMPRE notificar al usuario: "Detectamos un problema con los datos locales"

### RN-011-07: Errores Desconocidos

Para cualquier error no clasificado:
1. El sistema DEBE mostrar mensaje genérico: "Ocurrió un error inesperado"
2. El sistema DEBE ofrecer opciones: "Reintentar" y "Volver al inicio"
3. El sistema NUNCA debe mostrar información técnica (códigos, trazas, IPs)

---

## Casos de Uso

### Caso A: Venta sin Conexión

- **Actor:** Vendedor
- **Precondición:** Caja abierta, carrito con productos
- **Flujo Principal:**
    1. Vendedor confirma venta
    2. Sistema detecta que no hay conexión
    3. Sistema activa modo offline automáticamente
    4. Sistema guarda venta localmente
    5. Sistema inicia temporizador de 60 segundos
    6. Temporizador llega a cero
    7. Sistema muestra notificación: "Estás trabajando sin internet"
    8. Vendedor continúa vendiendo normalmente
- **Flujo Alternativo:** Si la conexión regresa antes del paso 6, el temporizador se cancela y las ventas se sincronizan silenciosamente.
- **Postcondición:** Ventas guardadas localmente, pendientes de sincronización

### Caso B: Conexión Restablecida

- **Actor:** Sistema
- **Precondición:** Modo offline activo, notificación de "sin internet" mostrada
- **Flujo Principal:**
    1. Sistema detecta que la conexión regresó
    2. Sistema muestra notificación: "Conexión restablecida"
    3. Sistema sincroniza ventas pendientes
    4. Al completar, muestra: "X ventas sincronizadas"
- **Postcondición:** Ventas sincronizadas con el servidor

### Caso C: Stock Agotado al Pagar

- **Actor:** Vendedor
- **Precondición:** Carrito con productos, caja abierta
- **Flujo Principal:**
    1. Vendedor confirma venta de 5 unidades de Producto X
    2. Sistema valida stock en servidor
    3. Solo hay 2 unidades disponibles
    4. Sistema muestra: "Stock insuficiente de Producto X. Disponible: 2"
    5. Vendedor ajusta cantidad a 2
    6. Vendedor confirma nuevamente
- **Postcondición:** Venta procesada con cantidad ajustada

### Caso D: Cuenta Desactivada Durante Operación

- **Actor:** Empleado
- **Precondición:** Empleado logueado, realizando operación
- **Flujo Principal:**
    1. Empleado intenta realizar una operación
    2. Servidor valida estado de cuenta
    3. Estado es "inactivo" (Admin lo desactivó)
    4. Servidor rechaza operación con código ACCOUNT_DISABLED
    5. Sistema muestra: "Tu cuenta ha sido desactivada"
    6. Sistema cierra sesión local
    7. Sistema redirige a pantalla de inicio
- **Postcondición:** Empleado sin acceso, debe contactar al Admin

---

## Criterios de Aceptación

### Conectividad
- [ ] Al perder conexión durante venta, se activa modo offline automáticamente
- [ ] Temporizador de 60 segundos inicia al entrar en modo offline
- [ ] Notificación "sin internet" aparece solo si temporizador llega a cero
- [ ] Notificación "conexión restablecida" aparece solo si hubo notificación previa

### Ventas
- [ ] Las ventas offline se identifican con identificador único
- [ ] No es posible crear ventas duplicadas por reintentos

### Stock
- [ ] Error de stock insuficiente muestra el producto afectado
- [ ] Error de stock insuficiente muestra cantidad disponible
- [ ] Usuario puede ajustar cantidad desde el error

### Acceso
- [ ] Cada operación del servidor valida que el usuario esté activo
- [ ] Cuenta desactivada recibe rechazo inmediato
- [ ] Al recibir ACCOUNT_DISABLED, la sesión local se cierra

### Datos
- [ ] Datos corruptos se intentan reparar antes de resetear
- [ ] Usuario es notificado si hubo problemas con datos locales

### Mensajes
- [ ] Ningún error muestra información técnica al usuario
- [ ] Todo error tiene mensaje comprensible en español

---

## Requisitos de Datos (Para Equipo Data)

El módulo de ventas requiere un campo de identificador único generado por el cliente que el servidor debe validar para evitar duplicados.

El módulo de notificaciones requiere persistir el estado de "notificación offline emitida" para saber si debe emitir la notificación de "conexión restablecida".

---

## Trazabilidad

| Documento | Referencia |
|-----------|------------|
| FRD_007 | Ventas - Proceso principal afectado |
| FRD_004 | Control de Caja - Contexto de sesión |
| SYSTEM_BOUNDARIES | Limitaciones de modo offline |
| TECH_SPECS/error-handling-implementation | Detalles técnicos de implementación |
