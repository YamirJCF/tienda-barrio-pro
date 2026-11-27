# 📐 Estándar ARQ-002: Políticas Globales de Negocio y Parámetros del Sistema

**Versión:** 1.5  
**Fecha:** 2026-11-26  
**Autor:** Arquitecto de Producto  
**Estado:** ✅ Activo

---

## Problema que Resuelve

A medida que el sistema crece, las reglas operativas definidas en los FRDs individuales tienden a repetirse entre módulos, generando:
- ❌ Reglas duplicadas con redacción ligeramente distinta (inconsistencia semántica)
- ❌ Imposibilidad de saber "por qué" existe una regla sin leer todo el FRD
- ❌ Parámetros numéricos (24 horas, $50, 50 ítems) enterrados en texto narrativo
- ❌ Cambios de estrategia del negocio que obligan a buscar y modificar reglas en decenas de documentos

---

## Principio Fundamental

> **"Las Políticas dictan el POR QUÉ. Las Reglas (FRDs) dictan el QUÉ. Los Parámetros dictan el CUÁNTO."**

Una Política es una directiva estratégica del negocio que permanece estable aunque cambien los números o los flujos. Las Reglas operativas de los FRDs son implementaciones concretas de estas políticas. Los Parámetros son los valores configurables que las reglas consumen.

---

## Jerarquía de Gobernanza

```
┌─────────────────────────────────────────────────────────┐
│ POLÍTICA DE NEGOCIO (Este documento - ARQ-002)          │
│ → El "POR QUÉ" / Norma Directiva Estratégica           │
└────────────────────────────┬────────────────────────────┘
                             │ se materializa en
                             ▼
┌─────────────────────────────────────────────────────────┐
│ REGLA DE NEGOCIO (Documentos FRD individuales)          │
│ → El "QUÉ" / Lógica Operativa Concreta                 │
└────────────────────────────┬────────────────────────────┘
                             │ consume valores de
                             ▼
┌─────────────────────────────────────────────────────────┐
│ PARÁMETROS DEL SISTEMA (Sección III de este documento)  │
│ → El "CUÁNTO" / Valores Configurables                   │
└─────────────────────────────────────────────────────────┘
```

---

# I. POLÍTICAS DE NEGOCIO

## Dominio Financiero

### POL-FIN-01: Política de Solidez de Caja (Liquidez Real y Caja Dedicada POS)

- **Objetivo:** Garantizar que el saldo reportado por la caja refleje exclusivamente dinero que existe físicamente o digitalmente en el turno del mostrador en ese instante, eliminando proyecciones, promesas o expectativas.
- **Declaración:** La única caja operativa del sistema es la **Caja Dedicada POS** (la gaveta y canales del turno). Esta caja reconoce únicamente el dinero que ya cambió de manos dentro del turno (ventas cobradas, abonos recibidos, reembolsos y gastos menores pagados desde el turno). Todo pago o desembolso realizado con fondos del dueño fuera del cajón se marca simplemente como **"pago externo / fuera de caja"** (tal como opera Proveedores en FRD-019) y no altera la Caja Dedicada POS. Las mermas, el consumo del negocio, el consumo/retiro personal y los ajustes de inventario tienen **impacto $0 en la Caja Dedicada POS** (su costo se imputa directamente al Estado de Resultados / P&L del negocio).
- **Reglas que gobierna:**
  - FRD-027, Regla 1: Límite de liquidez real
  - FRD-027, Regla 3: Bloqueo matemático de sobregiro
  - FRD-027-01, Regla 4: Fidelidad al flujo puro en reportes
  - FRD-026, Reglas 1-4: Gastos menores de turno como egresos líquidos inmediatos
  - FRD-019, Regla 5: Pagos externos / fuera de caja
- **Consecuencia de violación:** Descuadre entre el dinero físico en el cajón y el saldo digital del sistema, imposibilitando la auditoría y facilitando el robo hormiga.

---

### POL-FIN-02: Política de Segregación de Canales Monetarios

- **Objetivo:** Impedir que el sistema mezcle matemáticamente el efectivo con los fondos digitales, evitando maniobras de compensación cruzada.
- **Declaración:** Cada origen de fondos válido de la Caja Dedicada POS (**Efectivo, Nequi y Llave BRE**) DEBE calcularse, mostrarse y auditarse de manera separada e independiente. Un egreso o gasto digital disminuye únicamente el saldo esperado de su respectivo canal digital y jamás el efectivo físico del cajón. Queda vetada la fusión de canales para sortear validaciones de extracción.
- **Reglas que gobierna:**
  - FRD-027, Regla 2: Segregación estricta de canales
  - FRD-026, Regla 4: Dependencia de fondos por canal
  - FRD-022, Reglas 1 y 2: Canales unificados e impacto por canal
- **Consecuencia de violación:** Un cajero podría cubrir faltantes de efectivo reportando falsamente transferencias digitales, o viceversa.

---

### POL-FIN-03: Política de Aislamiento de Promesas de Pago

- **Objetivo:** Proteger la veracidad contable del turno separando radicalmente el dinero real de las deudas pendientes (tanto a favor como en contra del negocio).
- **Declaración:** Las promesas de pago (fiados de clientes, facturas de proveedores) son registros informativos ("post-its") que documentan obligaciones futuras. Estas promesas NO TIENEN representación monetaria en el flujo de caja hasta que el dinero físicamente cambia de manos.
- **Reglas que gobierna:**
  - FRD-024, Reglas 1 y 3: Aislamiento y registro de fiados
  - FRD-019, Reglas 1 y 3: Aislamiento y registro de deudas a proveedores
  - FRD-027, Regla 1: Prohibición de consolidar créditos
- **Consecuencia de violación:** El reporte de caja mostraría ingresos ficticios (fiados no cobrados) o egresos anticipados (facturas no pagadas), destruyendo la confianza en el cuadre diario.

---

### POL-FIN-04: Política de Transformación de Promesa a Liquidez

- **Objetivo:** Definir el instante exacto en que una promesa de pago se convierte en dinero real dentro del sistema contable.
- **Declaración:** Una promesa de pago se transforma en liquidez únicamente en el momento en que el dinero cambia de manos. Esta transformación DEBE ejecutarse como una transacción atómica de doble vía: reducir el "post-it" del deudor Y registrar el movimiento en la Caja Dedicada POS del turno activo (o marcarlo como pago externo / fuera de caja cuando corresponda a proveedores), de forma simultánea e inseparable.
- **Reglas que gobierna:**
  - FRD-024, Regla 4: Abono de cliente (promesa → ingreso)
  - FRD-019, Regla 6: Pago interno a proveedor (promesa → egreso)
  - FRD-006-02, Regla 4: Reembolso (transacción atómica con acción única de stock o etiqueta `"merma"`)
- **Consecuencia de violación:** Si una de las dos vías falla sin rollback, el sistema queda en estado inconsistente (el dinero se movió pero la deuda no se actualizó, o viceversa).

---

### POL-FIN-05: Política de Distribución por Tipo de Transacción en POS

- **Objetivo:** Garantizar que el POS distribuya correctamente el resultado de cada operación al módulo financiero o contable correspondiente según su naturaleza.
- **Declaración:** El comportamiento financiero al cerrar el carrito del POS depende exclusivamente del tipo de operación seleccionado:
  - **Efectivo / Digital (Nequi, Llave BRE):** Ingresa dinero real al canal correspondiente de la Caja Dedicada POS y descuenta stock.
  - **Crédito (Fiado):** Registra deuda en Cuentas por Cobrar del cliente (requiere permiso `Fiar y cobrar abonos`), descuenta stock y registra **$0** en la Caja Dedicada POS.
  - **Consumo / Retiro Personal:** Opera literalmente como una venta en el POS (mostrando sus precios e información normal) asignada automáticamente al propio perfil del empleado que opera (solo el Administrador puede seleccionar el perfil de otra persona). Descuenta stock, registra **$0** en la Caja Dedicada POS y contabiliza el retiro al **costo de adquisición** (conservando el precio de venta como referencia) en el historial por perfil y consolidado del Estado de Resultados (P&L).
- **Nota terminológica:** "Tipo de Transacción" se refiere al método con el que el operador finaliza un carrito individual en el POS. Las mermas, el consumo operativo del negocio, las devoluciones físicas a proveedor y los ajustes de conteo son movimientos logísticos gobernados por `POL-LOG-03`.
- **Reglas que gobierna:**
  - FRD-007-01, Regla 2: Tipología de transacción de carrito
  - FRD-007-01, Regla 5: Políticas de redondeo heredadas
  - FRD-006-02, Regla 3: Cálculo inmutable de reembolso
  - FRD-006-01-02, Regla 3: Consumo/retiro personal por perfil
- **Consecuencia de violación:** El POS mezclaría ventas cobradas con fiados o retiros personales en el mismo total de efectivo, corrompiendo el arqueo del turno.

---

## Dominio Logístico

### POL-LOG-01: Política de Independencia Logística-Financiera

- **Objetivo:** Asegurar que el módulo de Inventario y la Caja Dedicada POS operen como entes autónomos, sin dependencias cruzadas que generen efectos secundarios no deseados.
- **Declaración:** El inventario es un ente logístico cuya métrica de verdad son las cantidades físicas (unidades, kilos, libras, gramos). Las operaciones de inventario (entradas, mermas, consumo del negocio, devoluciones físicas a proveedor, ajustes de conteo) TIENEN PROHIBIDO inyectar o extraer dinero de la Caja Dedicada POS o alterar automáticamente saldos en Cuentas por Pagar. Su impacto económico (valorado al costo de adquisición) se refleja únicamente en el Estado de Resultados (P&L) del negocio (`FRD-018`).
- **Reglas que gobierna:**
  - FRD-027, Regla 4: Independencia logística absoluta
  - FRD-006-01, Reglas 1 y 2: Aislamiento financiero del inventario
  - FRD-006-01-01, Reglas 2, 3 y 4: Ceguera financiera en entradas
  - FRD-006-01-02, Reglas 1 y 2: Salidas logísticas con impacto $0 en Caja POS
- **Consecuencia de violación:** Ingresar mercancía o registrar una merma descontaría dinero automáticamente del cajón del POS, descuadrando el efectivo físico del turno.

---

### POL-LOG-02: Política de Verdad Física (Anti-Negativos y Acción Única con Etiqueta `"merma"` en Reembolsos)

- **Objetivo:** Impedir que el sistema registre operaciones que desafíen la realidad física del estante. No se puede vender, mermar o devolver a un proveedor algo que el sistema cree que no existe.
- **Declaración:** El sistema DEBE abortar cualquier operación de salida del stock vendible (venta, merma de estante, consumo, devolución a proveedor, ajuste negativo) si el cálculo resultante llevaría el stock a un número negativo.
- **Regla de Acción Única en Reembolsos (`FRD-006-02`):** Cuando un cliente devuelve un producto en un reembolso, el evento se trata como una sola acción evaluando una única etiqueta **`"merma"`**:
  - Si el producto **NO tiene la etiqueta `"merma"`** (regresa en buen estado), se reingresa directamente al inventario vendible para otra venta (`+cantidad`).
  - Si el producto **SÍ tiene la etiqueta `"merma"`** (regresa dañado o vencido), el sistema lee la etiqueta, el producto **no pasa por el inventario vendible** (no suma ni resta del stock actual, sin bloquearse aunque el stock sea `0`) y ejecuta directamente su salida/pérdida como merma junto con el egreso de dinero de la Caja Dedicada POS.
- **Reglas que gobierna:**
  - FRD-006-01, Regla 3: Bloqueo estrictamente físico
  - FRD-007-01, Regla 4: Respeto al límite logístico en POS
  - FRD-006-02, Regla 4: Acción única de reembolso con etiqueta `"merma"`
- **Consecuencia de violación:** Stock negativo en el sistema o reingreso accidental de productos dañados al stock vendible.

---

### POL-LOG-03: Política de Salidas Logísticas, Consumos y Ajustes con Firma Individual

- **Objetivo:** Permitir que la tienda registre con fluidez toda pérdida, consumo o corrección física de mercancía durante la operación, garantizando firma individual exacta y valoración contable al costo sin contaminar el efectivo de la Caja Dedicada POS.
- **Declaración:** Toda reducción o corrección de stock no comercial registra **$0 en la Caja Dedicada POS**, es inmutable (cualquier error se corrige mediante contra-movimiento, nunca borrando o editando el registro original), exige motivo obligatorio y **firma individual inmutable**, se contabiliza al **costo de adquisición** en el Estado de Resultados (`FRD-018`) y se rige por estos límites naturales:
  1. **Mermas (daño, rotura, vencimiento) y Consumo del Negocio (insumos usados por la tienda):** Pueden ser registrados por **cualquier usuario activo** (Administrador o empleado, sin requerir permiso de inventario ni caja abierta) bajo su firma individual.
  2. **Consumo / Retiro Personal (Separado del consumo del negocio):** Cualquier usuario activo puede registrarlo operando literalmente como una venta en el POS asignada a **su propio perfil** (solo el Administrador puede seleccionar a otra persona), quedando auditable en el historial **por perfil y consolidado**.
  3. **Ajustes por Conteo Físico y Devolución Física a Proveedor:** Pueden ser ejecutados por el Administrador o por cualquier empleado con el permiso **`Inventario completo`**, bajo motivo obligatorio, firma individual y alerta/auditoría para el Administrador. La devolución física a proveedor solo descuenta stock y **no altera automáticamente Cuentas por Pagar** (`FRD-019`).
- **Reglas que gobierna:**
  - FRD-006, Matriz de Permisos y Movimientos Kardex
  - FRD-006-01-02, Reglas 1 a 5: Salidas logísticas directas, separación de consumo y ajustes
  - FRD-003-01, Reglas 2 y 6: Capacidades base e `Inventario completo`
  - FRD-018, Pilares 1, 3 y 4: Contabilización al costo e historial por perfil y consolidado
- **Consecuencia de violación:** Bloquear al empleado para reportar roturas o consumos provoca pérdidas ocultas; mezclar mermas con dinero de caja descuadra el arqueo del turno.

---

### POL-LOG-04: Política de Inmediatez Logística

- **Objetivo:** Garantizar que el inventario refleje la realidad física del estante en todo momento, sin depender de que se completen procesos financieros.
- **Declaración:** Toda entrada o salida de mercancía DEBE actualizar el stock de forma inmediata, independientemente de si el pago asociado fue en efectivo, a crédito, o si fue una merma o consumo con impacto $0 en caja. La disponibilidad del producto para la venta no puede quedar condicionada al estado de una factura o un cobro.
- **Reglas que gobierna:**
  - FRD-024, Regla 2: Impacto logístico inmediato en fiados
  - FRD-019, Regla 2: Independencia e inmediatez logística en proveedores
  - FRD-006-01, Regla 4: Desacoplamiento de proveedores
- **Consecuencia de violación:** Si el stock no se actualiza hasta que se pague la factura, un cliente podría intentar comprar algo que ya está en el estante pero el sistema reporta como "no disponible".

---

## Dominio de Seguridad

### POL-SEG-01: Política de Arqueo Físico de Efectivo, Cierre Diferenciado por Rol y Margen de Monedas

- **Objetivo:** Alinear la apertura y el cierre de turno con la realidad física del mostrador de una tienda de barrio —donde solo se cuenta a mano el efectivo del cajón—, evitando bloqueos artificiales al dueño y protegiendo al mismo tiempo el control de efectivo frente a empleados sin caer en fatiga de alertas por monedas sueltas.
- **Declaración:**
  1. **Declaración explícita obligatoria (Prohibición de envíos en blanco):** Tanto al abrir turno (base inicial en efectivo) como al cerrarlo (efectivo contado en cajón), el usuario DEBE digitar explícitamente un monto numérico mayor o igual a cero (`$0` solo es válido si el usuario escribe `0` deliberadamente). Un formulario sin diligenciar (`vacío`) TIENE PROHIBIDO procesarse o convertirse silenciosamente en `$0`.
  2. **Alcance estrictamente físico del arqueo (Solo Efectivo del Cajón):** El conteo manual al cerrar un turno recae **única y exclusivamente sobre los billetes y monedas del cajón físico (Efectivo)**. Los canales digitales (**Nequi y Llave BRE**) NO se cuentan manualmente en el cierre (sus fondos ingresan a cuentas externas a la gaveta física); el servidor calcula y conserva su saldo segregado (`POL-FIN-02`) como **resumen informativo de transferencias del turno** para el Administrador.
  3. **Cierre directo con visibilidad para el Administrador (Dueño):** Cuando quien cierra el turno es el Administrador, el sistema DEBE mostrarle en pantalla el **efectivo esperado en cajón** junto con el resumen informativo de movimientos por Nequi y Llave BRE del turno, permitiéndole declarar el efectivo contado y sellar el cierre en un único paso (sin intentos a ciegas ni auto-alertas).
  4. **Arqueo Ciego con Cierre Asistido y Margen Global para Empleados:** Cuando quien cierra es el empleado titular del turno, el sistema TIENE PROHIBIDO mostrarle el saldo esperado o la diferencia antes, durante y después del cierre. El empleado declara únicamente el **efectivo físico contado en el cajón** y el servidor evalúa la diferencia absoluta frente al efectivo esperado usando el parámetro global fijo del sistema `P_MARGEN_DESCUADRE_EFECTIVO`:
     - Si la diferencia absoluta en efectivo (sobrante o faltante) es **menor o igual** a `P_MARGEN_DESCUADRE_EFECTIVO`, el servidor sella el cierre de inmediato en ese intento sin rebote ni alerta crítica.
     - Si la diferencia absoluta **supera** `P_MARGEN_DESCUADRE_EFECTIVO`, el sistema **solo avisa que no coincide** (sin revelar el monto esperado) y otorga hasta **3 intentos** para revisar o recontar; si al **tercer intento** persiste una diferencia superior al margen, sella el cierre y dispara una **notificación/alerta inmediata al Administrador**.
  5. **Registro íntegro al peso (Cero ocultamiento o redondeo de diferencias):** Dentro o fuera de `P_MARGEN_DESCUADRE_EFECTIVO`, y sin importar si cerró el Administrador o un empleado, el servidor DEBE guardar siempre de forma inmutable la diferencia matemática exacta al peso (`Efectivo Contado - Efectivo Esperado`) en la sesión de caja y en los reportes exclusivos del Administrador. El margen gobierna únicamente el rebote de reconteo y el disparo de alerta crítica, jamás borra ni redondea el dato contable.
- **Parámetro asociado:** `P_MARGEN_DESCUADRE_EFECTIVO` (fijo global del sistema, registrado en `ARQ-004`).
- **Reglas que gobierna:**
  - FRD-004, Regla 6 y Casos A y B: Apertura explícita, arqueo exclusivo de efectivo, cierre abierto para Admin y Cierre Asistido con margen para empleados
  - FRD-027-01, Reglas 2 y 5: Ceguera del empleado sobre efectivo esperado, registro exacto al peso y alerta al tercer intento fuera de margen
  - FRD-003-01, Regla 4 y Caso B: Alcance de `Abrir/cerrar caja` para empleados frente al Administrador
  - FRD-017, RN-017-03: Cierre del titular del turno
- **Consecuencia de violación:** Permitir formularios en blanco genera aperturas/cierres accidentales en `$0`; exigir "conteo" de Nequi/Llave BRE obliga a inventar cifras de cuentas ajenas al cajón; exigir `$0` exacto en monedas físicas genera fatiga de alertas en turnos honestos; mostrar el esperado al empleado facilita retener sobrantes de efectivo.

---

### POL-SEG-02: Política de Caducidad del Turno Operativo y Continuidad Nocturna

- **Objetivo:** Forzar un ciclo contable diario que obligue al cierre y cuadre de la caja sin interrumpir artificialmente turnos nocturnos en curso.
- **Declaración:** Ningún turno operativo PUEDE permanecer activo más allá del límite temporal `P_MAX_HORAS_TURNO` (24 horas). Mientras un turno abierto no supere las 24 horas y cruce la medianoche, el Pase Diario de quienes operan ese turno continúa vigente hasta cerrarlo (`FRD-017`). Al cruzar las 24 horas, el sistema transiciona el turno a estado **"Expirado/Bloqueado"** y rechaza toda operación monetaria posterior hasta que lo cierre el empleado específico que lo abrió o el Administrador ejecute un Cierre Forzoso (en el cual **no siempre es obligatorio declarar conteo físico**).
- **Reglas que gobierna:**
  - FRD-027-02, Reglas 1, 2, 3 y 5: Límite 24h, bloqueo, resolución por quien abrió e intervención del Admin
  - FRD-017, RN-017-01 a RN-017-03: Continuidad en cruce de medianoche (<24h) y cierre por caducidad
  - FRD-001, Regla 3: Vigencia del pase durante turno nocturno activo (<24h)
- **Parámetro asociado:** `P_MAX_HORAS_TURNO`
- **Consecuencia de violación:** Un turno abierto durante días acumularía miles de transacciones sin cuadre; cortar el pase a medianoche con turno abierto paralizaría tiendas con horario nocturno.

---

### POL-SEG-03: Política de Control de Acceso por Roles, Dispositivo por Cuenta y Propiedad del Turno

- **Objetivo:** Garantizar que cada empleado tenga libertad operativa en su turno dentro de límites naturales estrictos validados en el servidor, bajo su propia cuenta y firma individual.
- **Declaración:**
  1. **Un dispositivo por cuenta:** Cada usuario opera ingresando a su propia cuenta autenticada (con Pase Diario aprobado para empleados según `FRD-001`). Si otra persona utiliza el mismo equipo físico, debe ingresar a su propia cuenta; no existen cambios rápidos por PIN compartiendo sesión.
  2. **Capacidades operativas base (todo usuario activo con Pase Diario):** Vender en POS (con caja abierta), registrar **gastos menores desde la Caja Dedicada POS** (con caja abierta, canal con fondos, categoría OPEX y motivo), registrar **mermas**, registrar **consumo del negocio** y **consumo/retiro personal** (este último como venta a su propio perfil), y consultar únicamente **sus propios movimientos del turno actual con toda su información**.
  3. **Cuatro permisos delegables independientes (apagados por defecto):** `Inventario completo` (incluye costos, baja lógica, entradas, ajustes de conteo físico y devolución física a proveedor), `Fiar y cobrar abonos` (incluye consultar ficha y estado de cuenta de clientes activos), `Abrir/cerrar caja` y `Reembolsos` (ubicado en el POS al lado del buscador).
  4. **Propiedad estricta del turno de caja:** Quien abre la caja (ese empleado específico) y el Administrador son los **únicos** con potestad para cerrarla. Si otro empleado está dentro y también posee el permiso `Abrir/cerrar caja`, tiene **estrictamente bloqueado** cerrar el turno que abrió su compañero.
  5. **Exclusividad del Administrador:** Todos los reportes del negocio y auditoría (`FRD-008`, `FRD-018`, `FRD-005`, `FRD-027-01`, historiales de consumo por perfil y consolidado), crear/editar/eliminar clientes y modificar cupos (`FRD-009`, `FRD-030`), gestionar proveedores y Cuentas por Pagar (`FRD-019`), cierres forzosos de turnos ajenos y gestión de empleados/permisos son **100% exclusivos del Administrador**.
- **Reglas que gobierna:**
  - FRD-003-01, Reglas 1 a 9: Matriz de 4 permisos delegables, capacidades base y exclusividades Admin
  - FRD-003, Reglas 4 y 5: Capacidades y permisos de empleados
  - FRD-004, Regla 3: Propiedad estricta del turno al cerrar
  - FRD-006-02, Regla 1: Control de acceso en reembolsos
- **Consecuencia de violación:** Accesos cruzados entre turnos de distintos cajeros, fugas de información financiera sensible del dueño o bloqueo operativo del mostrador.

---

## Dominio de Auditoría

### POL-AUD-01: Política de Inmutabilidad Histórica y Fotografía de Firma

- **Objetivo:** Proteger la integridad de los registros contables, logísticos y de identidad cerrados o asentados, impidiendo alteraciones retroactivas.
- **Declaración:**
  1. **Cierres y movimientos inmutables:** Una vez que un turno se cierra o se asienta un movimiento de caja o inventario (entrada, merma, consumo, ajuste, reembolso), el registro original jamás se borra ni edita; cualquier error se corrige exclusivamente mediante contra-movimiento auditable.
  2. **Fotografía histórica de la firma:** Cada registro conserva de forma inmutable la identidad (identificador, nombre y rol) que tenía el actor en el instante del evento, incluso si después el empleado es editado o desactivado.
  3. **Excepción controlada por sincronización tardía offline (`FRD-017`):** Cuando una venta realizada en POS sin conexión se sincroniza después de cerrado su turno de origen, el servidor la imputa al turno original dejando un evento `LATE_SYNC_UPDATE` atribuido a la **firma individual de quien vendió offline**, sin alterar la declaración física de quien cerró la caja.
- **Reglas que gobierna:**
  - FRD-027-01, Regla 3: Inmutabilidad del cierre
  - FRD-006-01, Regla 5: Independencia histórica
  - FRD-017, RN-017-04: Sincronización tardía con atribución por actor
  - FRD-005, Reglas 1 y 2: Inmutabilidad y fotografía histórica del actor
- **Consecuencia de violación:** Modificar registros o perder el nombre histórico del empleado destruiría la validez forense y contable de la auditoría.

---

### POL-AUD-02: Política de Trazabilidad Universal y Firma Individual Seccionada

- **Objetivo:** Asegurar que cada movimiento en el sistema quede permanentemente vinculado a la cuenta exacta que lo ejecutó, su sección operativa y su motivo documentado.
- **Declaración:** Toda operación ejecutada en cualquier sección (POS, Caja, Gastos menores, Mermas, Consumo del negocio, Consumo/retiro personal, Inventario/Ajustes, Fiados/Abonos y Reembolsos) DEBE estampar la **firma individual exacta** del actor (`Administrador` o `Empleado específico`).
  - Las operaciones monetarias (ventas POS, abonos, gastos menores de caja, reembolsos) y el consumo personal en POS exigen heredar el `session_id` del turno activo.
  - Los movimientos logísticos de bodega/estante (entradas, mermas, consumo del negocio, ajustes por conteo físico, devolución física a proveedor) no exigen caja abierta (si hay turno activo, lo referencian informativamente).
  - **Visibilidad seccionada:** Todos los reportes del negocio y auditoría son **100% exclusivos del Administrador**; el empleado durante su jornada solo visualiza **sus propios movimientos del turno actual con toda su información**.
- **Reglas que gobierna:**
  - FRD-003-01, Reglas 5 y 5b: Atribución y auditoría individual por sección
  - FRD-005, Reglas 2 y 3: Trazabilidad completa y exclusividad Admin en reportes/Evidence Hub
  - FRD-027-01, Regla 1: Reportes de caja exclusivos del Administrador
  - FRD-006-01-01, Regla 5 y FRD-006-01-02, Reglas 1-5: Trazabilidad en entradas, salidas y ajustes
  - FRD-006-02, Regla 7: Trazabilidad contable y logística del reembolso
- **Consecuencia de violación:** Operaciones anónimas o genéricas ("empleado") impedirían saber quién ejecutó cada movimiento cuando varios usuarios operan el mismo día.

---

### POL-AUD-03: Política de Detección de Anomalías y Alertas al Administrador

- **Objetivo:** Garantizar que el sistema identifique, registre y notifique automáticamente al Administrador cualquier evento crítico o descuadre.
- **Declaración:** El servidor DEBE generar registros indelebles de auditoría y emitir notificaciones/alertas al Administrador ante:
  1. **Tercer intento sin coincidencia en Cierre Asistido** (registrando la diferencia final entre lo esperado y lo declarado).
  2. **Turnos vencidos (+24h / Negligencia de Cierre) y Cierres Forzosos.**
  3. **Intentos bloqueados de cerrar un turno ajeno** o ejecutar acciones sin permiso.
  4. **Ajustes por conteo físico** realizados por empleados con `Inventario completo` y **reembolsos con etiqueta `"merma"`**.
- **Reglas que gobierna:**
  - FRD-027-01, Regla 5: Autenticidad de descuadres y alerta al tercer intento
  - FRD-027-02, Regla 4: Bandera de anomalía administrativa
  - FRD-003-01, Caso A y Regla 6: Rechazo y registro de intentos no autorizados y alertas operativas
- **Consecuencia de violación:** Faltantes reiterados, ajustes sospechosos o turnos abandonados pasarían desapercibidos para el dueño.

---

## Dominio de Privacidad y Cumplimiento Legal

### POL-PRIV-01: Política de Trazabilidad de Consentimiento y Alta de Datos Personales

- **Objetivo:** Garantizar que todo ingreso de datos personales al sistema deje una prueba inmutable en el servidor, adaptando el mecanismo de captura según quién opera la pantalla.
- **Declaración:**
  1. **Autoregistro (Dueño de Tienda ante el SaaS):** Requiere aceptación explícita mediante casillas desmarcadas por defecto, vinculadas a la versión vigente de los documentos legales y selladas con la fecha y hora del servidor.
  2. **Alta de Cliente en Cartera de Fiados (Exclusiva del Administrador):** Crear, editar o reactivar clientes es **exclusivo del Administrador**. La acción de presionar el botón de guardado constituye la confirmación del registro, sin exigir casillas adicionales, y estampa automáticamente un registro inmutable con la firma del Administrador creador y la fecha y hora del servidor.
  3. **Ventas de Contado (Consumidor Final RST):** Están exentas de cualquier captura o traza de datos personales.
- **Reglas que gobierna:**
  - FRD-029, Reglas 1 a 16: Consentimiento legal versionado y confirmación de alta en cartera
  - FRD-030, Regla 5: Confirmación en re-alta de cliente por el Administrador
  - FRD-009 y FRD-003-01, Regla 3: Exclusividad del Administrador en gestión de clientes
- **Consecuencia de violación:** Cuentas de tiendas o registros de clientes creados sin autorización del dueño o sin rastro verificable.

---

### POL-PRIV-02: Política de Eliminación Protegida y Resguardo Contable Interno

- **Objetivo:** Permitir la eliminación de clientes por parte del Administrador sin permitir jamás la evasión de deudas activas, sin destruir soportes contables históricos y sin exponer complejidad técnica ni filtros de eliminados en la interfaz.
- **Declaración:**
  1. **Protección de Deuda Activa:** Queda estrictamente prohibido eliminar cualquier cliente cuyo saldo pendiente sea mayor a cero (`$0`).
  2. **Abstracción y Resguardo Silencioso en el Servidor:** Frente al Administrador existe una única acción de eliminación y no existe filtro de "mostrar eliminados" en listas operativas. Internamente, si el cliente eliminado tiene movimientos históricos, el servidor conserva en silencio su nombre, cédula y transacciones pasadas como soporte contable obligatorio (limpiando su teléfono y cupo y ocultándolo de toda lista activa); si nunca tuvo movimientos, lo borra definitivamente.
  3. **Re-alta sin Duplicidad:** Si una cédula archivada contablemente vuelve a registrarse en el futuro por el Administrador, el servidor reutiliza y reactiva en silencio ese mismo tercero único sin exponer su estado interno previo.
- **Reglas que gobierna:**
  - FRD-030, Reglas 1 a 8: Eliminación protegida, resguardo contable silencioso y re-alta sin duplicados
  - FRD-009: Eliminación de clientes alineada a resguardo contable
- **Consecuencia de violación:** Evasión de cartera pendiente, pérdida de soportes de ingresos de caja ante auditorías fiscales o creación de terceros duplicados con la misma cédula.

---

## Dominio de Producto y Experiencia del Tendero

### POL-PROD-01: Política de Barrera Lógica, Voluntariedad y Lenguaje Único del Tendero

- **Objetivo:** Preservar la esencia de **Tienda Barrio Pro** como una *Libreta Inteligente Voluntaria con Respaldo y Orden*, impidiendo la sobre-ingeniería de minisupermercado, la jerga técnica en pantalla y los ciclos de refactorización sin sustento empírico.
- **Declaración:**
  1. **Voluntariedad y fidelidad física (`ARQ-005`, Muro 1):** El sistema gobierna con rigor matemático únicamente las operaciones que el tendero registra en él, sin secuestrar el mostrador físico ni inventar pasos que no existan en la operación real de la tienda.
  2. **Filtro de fricción (`ARQ-005`, Muro 2 y `SYSTEM_BOUNDARIES.md`):** Solo se admite fricción deliberada cuando aporta respaldo legal bilateral, control real de caja/cartera o disciplina de turno. Queda prohibido reintroducir exclusiones estratégicas (como fechas de vencimiento de productos en entradas de inventario) o exponer controles exclusivos de supervisión de personal (como la pausa operativa del POS) al propio Administrador.
  3. **Glosario Único del Tendero (`ARQ-005`, Sección III):** Toda interfaz operativa y todo documento funcional DEBE emplear vocabulario natural de tienda de barrio, quedando prohibidas siglas técnicas o contables corporativas en etiquetas de usuario (`SQL`, `OPEX`, `Atómica`, `RPC`) y mensajes al Administrador redactados como si reportara ante otro Administrador.
  4. **Inmutabilidad funcional de zonas congeladas (`ARQ-005`, Muro 3):** Los módulos declarados en zona congelada NO PUEDEN rediseñarse en su funcionamiento salvo defecto comprobado de integridad contable/seguridad o bloqueo real verificado en mostrador.
- **Reglas que gobierna:**
  - FRD-004, FRD-026 y FRD-027-01: Lenguaje de caja/gastos y fidelidad física del arqueo
  - FRD-006 y FRD-006-01-01: Lenguaje de entradas de mercancía y prohibición de fecha de vencimiento por producto
  - FRD-007-01 y FRD-003-01: Pausa operativa acotada a empleados y distinción clara de rol
- **Consecuencia de violación:** Rechazo del sistema por parte del tendero tradicional debido a complejidad artificial, contradicciones con `SYSTEM_BOUNDARIES.md` y desgaste del proyecto en refactorizaciones interminables.

---

# Documentos Complementarios

Las siguientes secciones han sido extraídas a documentos independientes para mantener la separación de responsabilidades:

| Sección | Documento | Propósito |
|---------|-----------|----------|
| Matriz de Trazabilidad Política → Regla | `ARQ_003_MATRIZ_TRAZABILIDAD_POLITICAS.md` | Mapeo bidireccional entre Políticas y FRDs |
| Diccionario de Parámetros del Sistema | `ARQ_004_DICCIONARIO_PARAMETROS_SISTEMA.md` | Valores configurables que las reglas consumen |
| Barrera Lógica y Glosario Único del Tendero | `ARQ_005_BARRERA_LOGICA_Y_GLOSARIO_TENDERO.md` | Filtro anti-desvío, zonas congeladas y vocabulario oficial |

---

## Protocolo de Uso

| Situación | Acción |
|-----------|--------|
| Estoy redactando un nuevo FRD y una regla se parece a algo que ya escribí en otro módulo | Buscar si ya existe una Política que la cubra. Si existe, referenciar la Política en el nuevo FRD en lugar de reescribir la regla. |
| El dueño quiere cambiar un número ("ahora el turno caduca a las 12 horas") | Actualizar el Diccionario de Parámetros (`ARQ-004`), no el texto del FRD. |
| Dos FRDs se contradicen en una regla | Revisar qué Política gobierna esa regla. La Política tiene autoridad sobre el FRD en caso de conflicto. |
| Estoy implementando código y necesito saber si una acción está permitida | Leer la Política del dominio correspondiente. Si la acción la viola, está prohibida sin importar lo que diga un FRD individual. |

## Responsabilidades

| Rol | Responsabilidad |
|-----|-----------------|
| **Arquitecto** | Crear, actualizar y arbitrar Políticas. Extraer nuevos parámetros. |
| **Data** | Implementar las Políticas como constraints, triggers y RPCs. Consumir parámetros desde configuración, no desde constantes. |
| **UX** | Respetar las Políticas en la interfaz. No inventar reglas visuales que contradigan una Política. |
| **QA** | Verificar que cada regla de cada FRD sea trazable a una Política de este documento. |

---

## Historial de Cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1.0 | 2026-07-31 | Arquitecto de Producto | Creación inicial. Extracción de 15 Políticas desde 11 FRDs. |
| 1.1 | 2026-07-31 | Arquitecto de Producto | POL-FIN-05 renombrada a "Tipo de Transacción". Secciones II y III migradas a ARQ-003 y ARQ-004 respectivamente. |
| 1.2 | 2026-11-08 | Arquitecto de Producto | Incorporación de POL-PRIV-01 (Trazabilidad de Consentimiento y Alta de Datos Personales) tras validación de FRD-029. |
| 1.3 | 2026-11-10 | Arquitecto de Producto | Incorporación de POL-PRIV-02 (Eliminación Protegida y Resguardo Contable Interno) tras validación de FRD-030. |
| 1.4 | 2026-11-18 | Arquitecto de Producto | Alineación integral del Acuerdo Maestro: Caja Dedicada POS y pagos externos (`POL-FIN-01/02/05`), salidas logísticas `$0`, consumo separado por perfil/negocio, ajustes bajo `Inventario completo` y etiqueta única `"merma"` en reembolsos (`POL-LOG-01/02/03`), Cierre Asistido de 3 intentos (`POL-SEG-01`), continuidad nocturna (<24h) (`POL-SEG-02`), 4 permisos delegables, 1 dispositivo por cuenta, propiedad estricta del turno y reportes exclusivos del Admin (`POL-SEG-03`, `POL-AUD-01/02/03`, `POL-PRIV-01/02`). |
| 1.5 | 2026-11-26 | Arquitecto de Producto | Enmienda de realismo operativo en `POL-SEG-01` (prohibición de apertura/cierre en blanco, arqueo físico exclusivo sobre Efectivo del cajón con canales digitales como resumen informativo, cierre con visibilidad para el Admin y Arqueo Ciego Asistido con margen global `P_MARGEN_DESCUADRE_EFECTIVO` para empleados conservando diferencia exacta al peso) e incorporación de `POL-PROD-01` vinculada al nuevo estándar `ARQ-005` (Barrera Lógica y Glosario Único del Tendero). |

---

**Firmado:** Arquitecto de Producto  
**Fecha:** 2026-11-26
