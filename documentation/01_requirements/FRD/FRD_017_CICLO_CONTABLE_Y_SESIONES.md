# FRD-017: Alineación del Ciclo Contable de Caja y Ciclo de Vida de Sesiones

> **Módulo:** Contabilidad / Control de Caja / Autenticación  
> **Rol:** Arquitecto de Producto y Requisitos (Desarrollador-Economista Senior)  
> **Versión:** 4.0  
> **Fecha:** 2026-10-24  
> **Estado:** ✅ Especificación Formalizada con Límite de 24 Horas  
> **Políticas Rectoras:** `POL-FIN-01`, `POL-SEG-02`, `POL-SEG-03`, `POL-LOG-01`, `POL-AUD-01`, `POL-AUD-02`, `POL-AUD-03`

---

## 1. Evaluación Económico-Contable (Análisis de Dominio)

En la economía del comercio minorista, la unidad de medida de un período contable de caja es el **Hecho Económico continuo** (el turno de trabajo), no el reloj astronómico. Un turno de 10:00 PM a 02:00 AM constituye un solo hecho económico ininterrumpido con un solo arqueo físico de efectivo.

Sin embargo, para evitar la negligencia operativa de turnos perpetuos que acumulen errores o propicien fugas de liquidez, se impone un **techo temporal estricto de `P_MAX_HORAS_TURNO` (24 horas)**. Este límite temporal generoso permite jornadas continuas o turnos dobles, pero elimina el riesgo de arrastrar descuadres por abandono de caja.

Asimismo, dado que en una tienda de barrio pueden operar de forma concurrente hasta `P_MAX_EMPLOYEES_PER_STORE` colaboradores junto al Administrador sobre una única gaveta física, cada movimiento de efectivo o venta DEBE atribuirse individualmente al colaborador responsable, distinguiendo con claridad meridiana las operaciones monetarias (que exigen caja abierta) de las operaciones logísticas y de inventario (que operan con total independencia de la caja).

---

## 2. Definición del Ciclo Contable Oficial con Techo Temporal

```mermaid
stateDiagram-v2
    [*] --> CajaCerrada: Inicio de Jornada
    CajaCerrada --> TurnoActivo: Apertura de Caja (Base Inicial)
    
    state TurnoActivo {
        [*] --> OperacionMonetaria: Ventas POS / Gastos / Abonos
        OperacionMonetaria --> OperacionMonetaria: Transacciones con Trazabilidad por Actor
    }
    
    TurnoActivo --> EvaluacionCierre: Intención de Cierre Ordinario
    TurnoActivo --> CierreForzado: Turno cumple P_MAX_HORAS_TURNO abierto
    
    state EvaluacionCierre {
        state "Arqueo Ciego con Cierre Asistido (hasta 3 intentos)" as Arqueo
        state "Conciliación y Alerta al 3er Intento (si no cuadra)" as Conciliacion
        Arqueo --> Conciliacion
    }
    
    EvaluacionCierre --> CajaCerrada: Firma de Cierre (Solo quien abrió o Admin)
    
    CierreForzado --> CajaBloqueada: Turno Expirado/Bloqueado (+24h) con auditoría
    CajaBloqueada --> CajaCerrada: Cierre por quien abrió o Cierre Forzoso del Admin
```

---

## 3. Reglas de Negocio Duras (RN)

### RN-017-01: Continuidad del Turno en Cruce de Medianoche
Un turno de caja puede cruzar libremente la medianoche sin interrupciones operativas ni cortes contables artificiales.
- Las sesiones de los usuarios y los Pases Diarios aprobados en el día calendario anterior conservan plena validez operativa después de las `00:00` horas siempre y cuando el turno de caja de la tienda continúe abierto y no haya alcanzado el límite de `P_MAX_HORAS_TURNO`.
- El sistema **TIENE PROHIBIDO** ejecutar cierres de sesión forzados o invalidar pases diarios a las `00:00` horas si existe un turno nocturno abierto en curso.

### RN-017-02: Bloqueo por Techo Temporal (`P_MAX_HORAS_TURNO` / `FRD-027-02`)
Si un turno de la Caja Dedicada POS permanece abierto exactamente `P_MAX_HORAS_TURNO` (24 horas) después de su marca temporal de apertura:
1. El servidor central transiciona automáticamente el estado del turno a **"Expirado/Bloqueado"** (`FRD-027-02`), registrando la alerta de negligencia temporal.
2. Las operaciones monetarias (ventas, gastos menores, abonos, reembolsos) quedan inmediatamente bloqueadas para toda la tienda hasta que el turno sea cerrado.
3. Si un colaborador operaba amparado exclusivamente en el turno nocturno del día anterior, su pase diario expira en ese momento; si cuenta con un pase aprobado para el día calendario actual, conserva acceso para labores logísticas no monetarias (inventario, entradas, mermas, consumo del negocio).

### RN-017-03: Propiedad Estricta del Turno y Resolución de Turno Expirado (`POL-SEG-02`, `POL-SEG-03`)
1. **Propiedad estricta al cerrar:** Tanto en cierre ordinario como al vencer las 24 horas, **únicamente el empleado específico que abrió ese turno o el Administrador** tienen potestad para cerrarlo. Cualquier otro empleado, aunque tenga activado el permiso `Abrir/cerrar caja`, tiene **estrictamente bloqueado** cerrar un turno ajeno.
2. **Cierre del titular según rol (`POL-SEG-01`):** Cuando cierra el empleado titular que abrió el turno, opera el Arqueo Ciego con Cierre Asistido exclusivamente sobre el efectivo físico del cajón evaluado contra `P_MARGEN_DESCUADRE_EFECTIVO` (hasta 3 intentos y alerta al Administrador si al tercero supera el margen, guardando siempre la diferencia exacta al peso); cuando cierra el Administrador, visualiza el efectivo esperado y el resumen digital del turno y sella en un paso.
3. **Cierre Forzoso del Administrador (`FRD-027-02`):** Si quien abrió el turno no está disponible tras vencer las 24 horas, el Administrador ejecuta el Cierre Forzoso, en el cual **no siempre es obligatorio declarar conteo físico**, registrando el evento de máxima severidad en auditoría.

### RN-017-04: Inmutabilidad de la Asignación Contable y Firma Individual con Fotografía Histórica
Toda transacción monetaria (venta, gasto menor, abono, reembolso) y retiro de consumo personal registrado durante un turno queda irrevocablemente asociado al turno activo en que se ejecutó (*Principio de Devengo*).
- **Firma Individual y 1 Dispositivo por Cuenta:** En una tienda con múltiples colaboradores operando simultáneamente desde sus propias cuentas sobre la Caja Dedicada POS, cada movimiento DEBE almacenar de forma obligatoria la firma individual del colaborador o Administrador específico que ejecutó la operación, conservando la fotografía histórica inmutable de su nombre y rol (`POL-AUD-01`, `POL-AUD-02`).
- **Sincronización Tardía de Ventas Offline:** Si una venta realizada en Modo Offline contiene un sello de turno (`origin_session_id`) que ya fue cerrado al momento de sincronizar:
  1. La venta se imputa contablemente al turno de origen al que perteneció.
  2. El servidor recalcula el balance esperado del turno de origen para reflejar el ingreso real.
  3. El sistema estampa un registro de auditoría (`LATE_SYNC_UPDATE`) atribuyendo explícitamente la diferencia a la **firma de quien vendió offline** (sin alterar la declaración física de quien cerró la caja).
  4. La venta **NO SE IMPUTA** al turno nuevo que pudiera estar abierto, protegiendo la pureza contable de ambos períodos.

### RN-017-05: Independencia de Labores Logísticas No Monetarias ante Estado de Caja
El estado de la Caja Dedicada POS (abierta, cerrada o expirada por 24 horas) rige única y exclusivamente sobre las transacciones que involucren flujo monetario o el carrito de ventas del POS.
- Las labores logísticas de Inventario (entradas, mermas, consumo del negocio, ajustes por conteo físico y devoluciones físicas a proveedor) operan con total independencia del estado de la caja (*POL-LOG-01*, *POL-LOG-03*).
- El sistema NO PUEDE bloquear el acceso ni forzar la navegación hacia el control de caja a colaboradores que no sean el titular que abrió el turno o que se encuentren ejecutando labores logísticas. *(Nota: Los módulos de Proveedores/Cuentas por Pagar y todos los Reportes son 100% exclusivos del Administrador).*

---

## 4. Casos de Uso

### CU-017-A: Operación Nocturna Continua
- **Actor:** Cajero / Colaborador.
- **Precondición:** Caja abierta el viernes a las 10:00 PM con pase diario aprobado.
- **Flujo Principal:**
  1. El colaborador procesa ventas a las 11:30 PM y continúa atendiendo a las 00:30 AM y 01:45 AM del sábado.
  2. El sistema valida que el turno no supera `P_MAX_HORAS_TURNO`.
  3. Todas las ventas se imputan al turno abierto el viernes.
  4. El colaborador realiza el arqueo de cierre a las 02:30 AM del sábado.
- **Postcondición:** Cierre limpio con todas las ventas del hecho económico unificadas.

### CU-017-B: Turno Olvidado y Cierre Forzado
- **Actor:** Sistema / Administrador.
- **Precondición:** Turno abierto a las 08:00 AM. Al terminar la jornada a las 08:00 PM nadie cierra la caja.
- **Flujo Principal:**
  1. Al día siguiente a las 08:00 AM (cumplidas las 24 horas exactas), el servidor ejecuta el Cierre Forzado.
  2. El turno queda cerrado, se expide la auditoría y se emite la notificación.
  3. A las 08:15 AM ingresa el Administrador e intenta abrir caja.
  4. El sistema le notifica que existe un turno cerrado forzosamente y solicita la declaración del efectivo real existente en la gaveta.
  5. El Administrador declara el conteo físico, el sistema asienta el descuadre y autoriza la apertura del nuevo turno.
- **Postcondición:** Trazabilidad de negligencia asentada y tienda desbloqueada.

### CU-017-C: Sincronización de Venta Offline sobre Turno ya Cerrado
- **Actor:** Colaborador / Sistema.
- **Precondición:** El colaborador vendió offline a las 06:00 PM durante un turno que el Administrador cerró a las 09:00 PM. El celular se reconecta a internet a las 10:00 PM.
- **Flujo Principal:**
  1. La cola envía la venta con su sello del turno original de las 06:00 PM.
  2. El servidor detecta que el turno original ya está cerrado.
  3. El servidor registra la venta vinculada al turno original, actualiza el balance esperado de dicho turno y genera un evento de auditoría `LATE_SYNC_UPDATE`.
  4. La venta no se mezcla con el turno del día siguiente.
- **Postcondición:** Contabilidad fidedigna sin distorsión de turnos contemporáneos.

---

## 5. Criterios de Aceptación
- [ ] **CA-017-01:** Durante un turno abierto de menos de `P_MAX_HORAS_TURNO`, el cruce de medianoche no invalida pases ni interrumpe la operación.
- [ ] **CA-017-02:** Al cumplirse `P_MAX_HORAS_TURNO`, el sistema cierra automáticamente el turno con sello de auditoría y bloquea operaciones monetarias.
- [ ] **CA-017-03:** Cada movimiento de efectivo dentro del turno almacena obligatoriamente la identidad individual del colaborador que lo ejecutó.
- [ ] **CA-017-04:** Las ventas offline sincronizadas tardíamente sobre turnos cerrados se imputan a su turno original registrando un evento `LATE_SYNC_UPDATE`.
- [ ] **CA-017-05:** El bloqueo por turno caducado o caja cerrada no impide a colaboradores autorizados trabajar en inventario o módulos no monetarios.
