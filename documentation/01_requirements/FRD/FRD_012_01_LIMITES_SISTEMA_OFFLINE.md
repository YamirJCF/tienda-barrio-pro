# FRD-012-01: Acoplamiento y Límites Estrictos del Sistema Offline

### Nombre de la Funcionalidad
Delimitación Operativa, Frontera de Seguridad y Resolución Defensiva del Modo Offline.

#### Descripción
El modo "Offline" del sistema no es un clon de la aplicación completa, sino un mecanismo de supervivencia de emergencia para garantizar la continuidad comercial durante apagones o cortes de red. Este documento establece los límites arquitectónicos del modo offline, definiendo con precisión la frontera entre fallas de transporte de red y rechazos autoritativos de seguridad, protegiendo las colas de transacciones legítimas y prohibiendo operaciones monetarias complejas o turnos perpetuos sin conexión.

---

## Reglas de Negocio

### RN-OFF-01: Límite Transaccional Estricto (Solo Ventas)
El sistema offline está acoplado **única y exclusivamente** al flujo del Punto de Venta (POS).
- La única operación encolable en modo offline es la creación de una venta (`CREATE_SALE`).
- **Quedan terminantemente prohibidos en modo offline:** Ajustes de inventario (Mermas/Consumos), Devoluciones a proveedores, Gastos operativos y Cierres de Caja.
- Cualquier intento de encolar una operación distinta a una venta DEBE ser bloqueada y descartada por la cola de sincronización para prevenir corrupciones.

### RN-OFF-02: Bloqueo en Origen (Validación Local Preventiva)
Para cumplir con la *POL-LOG-02 (Anti-Negativos)*, el modo offline es defensivo.
- El sistema DEBE validar el carrito contra el stock descargado localmente en caché ANTES de permitir la venta offline.
- Si el stock local es insuficiente, la venta offline SE BLOQUEA INMEDIATAMENTE. No se encola para ver si en el servidor hubiese existencias.

### RN-OFF-03: Límite de Encolamiento y Protección de Credenciales
El sistema offline no está diseñado para operar días enteros sin internet.
- Se establece un límite máximo de transacciones encoladas (`P_MAX_OFFLINE_QUEUE_SIZE`). Una vez alcanzado este límite, el sistema DEBE rechazar nuevas ventas hasta que se recupere la conexión y se drene la cola.
- Si al recuperar la conexión o durante la sincronización las credenciales del usuario o su pase diario se encuentran vencidos, la cola de sincronización DEBE pausarse inmediatamente en estado de espera de autenticación. El sistema TIENE PROHIBIDO agotar los reintentos técnicos o descartar las ventas legítimas hacia la Cola de Letras Muertas (DLQ) por motivos de vencimiento de credenciales o de acceso. La sincronización se reanuda automáticamente una vez que el usuario renueva su acceso.

### RN-OFF-04: Inmutabilidad Histórica y Fallos Técnicos (DLQ)
Una venta realizada offline bajo las reglas locales de ese momento es un **hecho histórico inmutable** (*POL-AUD-01*). 
- El servidor **TIENE PROHIBIDO** rechazar la sincronización de una venta offline por motivos de lógica de negocio que hayan cambiado durante el corte de red (ej. si el Administrador dio de baja el producto o si el stock en el servidor llegó a cero). El Punto de Venta ya realizó su validación preventiva local en el momento de la venta.
- Si una venta falla al sincronizarse, **DEBE** ser estrictamente por **fallos técnicos de transporte o de servidor** (ej. timeout de red persistente, error interno 500 del servidor, fallos de integridad criptográfica).
- El sistema reintentará 3 veces ante fallos técnicos comprobados. Tras 3 fallos técnicos, la venta se mueve a la Cola de Letras Muertas (DLQ).
- En la DLQ, el administrador puede **Reintentar** o **Eliminar** (solo en caso de pruebas o ventas fantasma comprobadas), pero el sistema asume que la venta es legítima.

### RN-OFF-05: Resiliencia ante Cambios de Esquema (Bandeja de Intervención)
Si durante el corte de red el Administrador realizó cambios estructurales en el servidor provocando incompatibilidad de formato:
- El sistema receptor DEBE detectar la incompatibilidad antes de procesarla para evitar anomalías en el almacenamiento central.
- La transacción incompatible **NO SE INVALIDA ni se considera errónea** (la información de la venta sigue siendo un hecho real). 
- En lugar de rechazarla, el sistema la mueve a la Bandeja de Intervención Técnica (DLQ). Allí esperará hasta que el sistema actualice su estructura o un administrador resuelva la incompatibilidad, garantizando que el registro histórico de la venta no se pierda.

### RN-OFF-06: Indicador Visual de Cola de Sincronización
Mientras el sistema esté en modo offline con ventas encoladas, la interfaz DEBE mostrar un indicador persistente con el número de ventas pendientes de sincronización sobre el límite máximo permitido (ej. "3/50 ventas pendientes").

1. **Visibilidad Permanente:** El indicador DEBE ser visible en todo momento mientras existan ventas encoladas, independientemente de la pantalla activa del POS.
2. **Alerta Preventiva:** Cuando la cola alcance el 80% de su capacidad máxima (`P_MAX_OFFLINE_QUEUE_SIZE`), el sistema DEBE cambiar el indicador a un estado de alerta visual acompañado del mensaje: "Cola de sincronización casi llena. Reconecta a internet pronto."
3. **Alerta Crítica:** Cuando la cola alcance el 100% de su capacidad, el indicador DEBE cambiar a estado crítico y el POS DEBE bloquearse según RN-OFF-03, mostrando: "Límite de ventas offline alcanzado. Reconecta a internet para continuar."

### RN-OFF-07: Distinción Estricta entre Falla de Red y Rechazo de Seguridad
El sistema DEBE activar el Modo Offline única y exclusivamente ante la ausencia comprobada de conectividad de transporte físico o caídas de red.
- Todo rechazo emitido activamente por el servidor por razones de seguridad, denegación de tienda, credenciales vencidas, cuenta desactivada o pase diario expirado constituye una respuesta válida en línea y NO PUEDE ser clasificada como falla de red.
- El sistema TIENE PROHIBIDO activar el Modo Offline o presentar saldos o turnos de caja almacenados localmente cuando el servidor rechaza una solicitud por denegación de acceso o falta de autorización.
- Ante un rechazo de autorización con red disponible, el sistema DEBE purgar el estado operativo optimista local (preservando las colas de sincronización pendientes) y conducir al usuario al flujo de inicio de sesión o validación correspondiente.

### RN-OFF-08: Caducidad del Contexto Offline y Límite de Turno
El Modo Offline hereda los límites de caducidad del ciclo contable diario (*POL-SEG-02*).
- El sistema NO PUEDE permitir la ejecución ni el registro de ventas en Modo Offline si el turno de caja almacenado en el dispositivo ha superado el límite temporal de `P_MAX_HORAS_TURNO` desde su apertura original.
- Si el dispositivo se encuentra sin red y el turno local alcanza o supera `P_MAX_HORAS_TURNO`, el sistema DEBE bloquear inmediatamente la generación de nuevas ventas offline y mostrar: "El turno de caja ha caducado por límite de tiempo. Reconecte a internet para cerrar caja."
- Queda terminantemente prohibido iniciar un turno de caja nuevo en Modo Offline.

### RN-OFF-09: Sello Inmutable de Autoría y Turno en Cola Offline
Toda venta registrada en Modo Offline DEBE estampar de forma obligatoria e inmutable en su registro de cola:
1. El identificador del turno de caja activo en el momento de la venta.
2. El identificador del colaborador o cajero responsable que concretó la venta.
3. La marca de tiempo local exacta de la transacción.

Al restablecerse la conexión, el servidor DEBE imputar la venta contablemente al turno de caja y al colaborador identificados en dicho sello, respetando la *POL-AUD-02 (Trazabilidad Universal)* y la *POL-AUD-01 (Inmutabilidad Histórica)*. Si el turno original ya hubiese sido cerrado por otro usuario o por caducidad temporal, el servidor DEBE conciliar el impacto contable sobre el turno correspondiente y registrar una alerta de auditoría por actualización tardía sin distorsionar el turno actual.

---

## Casos de Uso

**Caso A: Empleado intenta ajustar inventario sin internet**
- **Actor:** Empleado Operativo.
- **Precondición:** Sin conexión a internet.
- **Flujo Principal:**
  1. El empleado intenta registrar una "Merma" por ruptura de producto.
  2. El sistema detecta modo offline.
  3. El sistema aborta la operación y notifica: "Las operaciones de inventario requieren conexión a internet obligatoria".
- **Postcondición:** Nada se encola.

**Caso B: Venta atascada por fallo técnico o de esquema**
- **Actor:** Sistema / Servidor.
- **Precondición:** Dispositivo recupera conexión tras ventas offline.
- **Flujo Principal:**
  1. La conexión regresa. La cola envía la venta.
  2. El servidor responde con un error técnico 500 o el interceptor detecta incompatibilidad de esquema.
  3. El sistema reintenta 3 veces ante el fallo técnico y no logra respuesta exitosa.
  4. La venta se traslada a la bandeja DLQ.
  5. El sistema notifica al administrador: "Transacciones requieren revisión técnica para sincronizarse".
  6. El administrador revisa la DLQ y, tras solventar la incidencia, presiona "Reintentar".
- **Postcondición:** La transacción se preserva intacta en la bandeja de intervención sin descarte silencioso.

**Caso C: Recuperación de conexión con Pase Diario Expirado**
- **Actor:** Empleado Operativo / Sistema.
- **Precondición:** El empleado realizó 5 ventas offline durante la tarde. La tienda cerró y al día siguiente el empleado llega al local con el celular aún conteniendo las 5 ventas offline.
- **Flujo Principal:**
  1. El celular detecta conexión a internet e inicia la sincronización de la cola.
  2. El servidor responde con rechazo de seguridad por pase diario del día anterior vencido.
  3. El sistema clasifica el error como rechazo de autorización y NO como fallo técnico.
  4. La cola de sincronización se pausa inmediatamente en estado de requerimiento de autenticación, sin incrementar el contador de fallos de las ventas ni moverlas a DLQ.
  5. La interfaz solicita al empleado renovar su pase diario del día o notifica al Administrador.
  6. Una vez aprobado el pase diario o re-autenticado el usuario, la cola se reanuda automáticamente y procesa las 5 ventas imputándolas al turno original donde se generaron.
- **Postcondición:** Cero pérdidas de ventas en DLQ; trazabilidad e integridad garantizadas.

**Caso D: Intento de venta offline con turno caducado (> 24h)**
- **Actor:** Empleado Operativo.
- **Precondición:** Dispositivo sin internet con turno abierto hace 25 horas.
- **Flujo Principal:**
  1. El empleado agrega productos al carrito e intenta presionar "Cobrar".
  2. El sistema evalúa el timestamp de apertura del turno local contra el límite `P_MAX_HORAS_TURNO`.
  3. El sistema detecta que el turno superó las 24 horas y bloquea el botón de cobro.
  4. Se muestra el mensaje: "El turno de caja ha caducado por límite de tiempo. Reconecte a internet para cerrar caja."
- **Postcondición:** Ninguna venta huérfana es encolada sobre un turno caducado.

---

## Criterios de Aceptación
- [ ] **CA-OFF-01:** Intentar ejecutar un ajuste manual de inventario sin internet resulta en un bloqueo UI y no genera un registro en IndexedDB.
- [ ] **CA-OFF-02:** Alcanzar el límite `P_MAX_OFFLINE_QUEUE_SIZE` bloquea el botón de cobrar en el POS offline.
- [ ] **CA-OFF-03:** Las ventas fallidas por causas estrictamente técnicas van a DLQ tras 3 reintentos y solo pueden ser reintentadas o eliminadas.
- [ ] **CA-OFF-04:** Mientras existan ventas encoladas, un indicador muestra el avance respecto al límite de forma persistente.
- [ ] **CA-OFF-05:** Al alcanzar el 80% de la capacidad de la cola, el indicador cambia a estado de alerta visual.
- [ ] **CA-OFF-06:** Un error de autorización, credenciales vencidas o denegación de tienda emitido por el servidor NO activa el modo offline ni oculta el error bajo pantallas en caché.
- [ ] **CA-OFF-07:** Si la sincronización offline falla por pase expirado o credenciales inválidas, la cola se pausa sin enviar registros a la DLQ hasta que el usuario se revalide.
- [ ] **CA-OFF-08:** Toda transacción encolada offline incluye de forma obligatoria e inmutable el turno de caja de origen, el cajero responsable y la marca de tiempo de la venta.
- [ ] **CA-OFF-09:** El sistema bloquea ventas offline si el turno local abierto supera el límite temporal `P_MAX_HORAS_TURNO`.
