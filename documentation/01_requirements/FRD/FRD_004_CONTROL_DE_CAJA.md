# FRD-004: Control de Caja (Turnos)

> **Módulo:** Caja / Operaciones  
> **Versión:** 2.0 (Saneamiento 2026-08-07 — Decisión D-01: Erradicación del PIN de caja)  
> **Estado:** Aprobado  
> **SDD Asociado:** SDD_004

---

## Reglas de Negocio

1. **Unicidad de Sesión:**
    - Solo puede haber UNA sesión de caja abierta por tienda en un momento dado.
    - No se permiten cajas simultáneas en este MVP.

2. **Bloqueo Operativo (POS Inaccesible):**
    - Si la caja está cerrada, el sistema de ventas DEBE estar completamente bloqueado.
    - Esto aplica a TODOS los roles, incluyendo el Admin.
    - **Nadie puede vender sin caja abierta.**
    - En estado cerrado, solo se permite consultar precios e inventario en modo lectura.

3. **Requisito para Operar Caja:**
    - Solo empleados con el permiso `canOpenCloseCash` pueden abrir o cerrar la caja.
    - La autenticación se valida contra la sesión/token JWT principal del usuario.
    - El Admin siempre tiene este permiso implícitamente.
    - **Nota de Arquitectura (Decisión D-01, 2026-08-07):** El PIN de caja fue erradicado por redundancia de seguridad. La validación se delega al control de acceso basado en tokens y permisos.

4. **Inmutabilidad de Transacciones:**
    - Una vez registrado un movimiento (ingreso/gasto), NO puede borrarse ni editarse.
    - Si hubo error, se DEBE crear un contra-movimiento correctivo.

5. **Fórmula de Conciliación:**
    - `Saldo Esperado = Base Inicial + Ventas Efectivo + Ingresos Manuales - Gastos/Retiros`
    - Esta fórmula se calcula automáticamente y se muestra al cerrar.

---

## Casos de Uso

**Caso A: Apertura de Turno**
- **Actor:** Empleado con permiso `canOpenCloseCash`
- **Precondición:** Caja cerrada, pase diario aprobado.
- **Flujo Principal:**
    1. Usuario ingresa al módulo de control de caja.
    2. Sistema verifica permisos y estado de caja.
    3. Muestra pantalla "Apertura de Turno".
    4. Usuario ingresa monto base (fondo de cambio).
    5. Usuario confirma.
    6. Sistema abre sesión y habilita el POS.
- **Postcondición:** Caja abierta, ventas habilitadas.

**Caso B: Cierre de Turno (Arqueo)**
- **Actor:** Empleado con permiso `canOpenCloseCash`
- **Precondición:** Caja abierta.
- **Flujo Principal:**
    1. Usuario selecciona "Cerrar Turno".
    2. Sistema solicita conteo de dinero físico (Arqueo Ciego).
    3. Usuario realiza conteo físico e ingresa el dinero real que tiene en mano.
    4. Usuario pulsa "Confirmar Cierre".
    5. Sistema cierra la sesión y guarda el reporte histórico.
    6. Sistema calcula y registra la diferencia entre esperado y real.
- **Postcondición:** Caja cerrada, pases diarios expirados, POS bloqueado hasta próxima apertura.

**Caso C: Registro de Gasto (Salida de Dinero)**
- **Actor:** Empleado
- **Precondición:** Caja abierta.
- **Flujo Principal:**
    1. Usuario saca dinero para pagar algo (ej: proveedor, almuerzo).
    2. Ingresa a "Gastos" → "Nuevo Gasto".
    3. Digita monto y motivo obligatorio.
    4. Sistema registra el movimiento y resta del Saldo Esperado inmediatamente.
- **Postcondición:** Movimiento registrado, saldo actualizado.

**Caso D: Recuperación de Turno Olvidado**
- **Actor:** Empleado o Admin (Cualquiera que inicie sesión)
- **Precondición:** Existe un turno abierto con fecha anterior a hoy.
- **Flujo Principal:**
    1. Usuario inicia sesión.
    2. Sistema detecta turno caducado.
    3. Sistema muestra alerta bloqueante: "Turno anterior no cerrado".
    4. Sistema redirige forzosamente a la pantalla de Cierre de Caja.
    5. Usuario realiza el conteo del dinero actual (real).
    6. Usuario confirma cierre (ingresa PIN si aplica).
    7. Sistema cierra el turno antiguo con fecha de cierre actual.
    8. Sistema libera el bloqueo y permite abrir un Nuevo Turno.
- **Postcondición:** Turno viejo cerrado, sistema listo para operar hoy.

---

## Requisitos de Datos (Para Equipo Data)

**Entidad Sesión de Caja:**
- Identificador único
- Relación con Tienda
- Empleado que abrió
- Empleado que cerró (puede ser diferente)
- Balance de apertura
- Balance de cierre (declarado por usuario)
- Balance calculado (por el sistema)
- Diferencia
- Estado: abierta/cerrada
- Timestamps de inicio y fin

**Entidad Transacción de Caja:**
- Identificador único
- Relación con Sesión
- Tipo: ingreso/gasto
- Monto
- Descripción obligatoria
- Referencia a venta (si aplica)
- Timestamp

---

## Criterios de Aceptación

- [ ] No se puede abrir caja si ya hay una abierta.
- [ ] El POS está completamente bloqueado cuando la caja está cerrada.
- [ ] Solo usuarios con permiso `canOpenCloseCash` ven las opciones de abrir/cerrar.
- [ ] El cierre de caja no requiere PIN (Decisión D-01).
- [ ] Cada movimiento de caja tiene descripción obligatoria.
- [ ] El cierre genera un registro inmutable con la diferencia calculada.
- [ ] Al cerrar la caja, los permisos operativos de venta quedan bloqueados.
- [ ] El sistema detecta y bloquea turnos con fecha de apertura < hoy.
- [ ] No se permite abrir un nuevo turno si existe uno caducado pendiente de cierre.
```
