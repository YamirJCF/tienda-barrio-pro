# 📐 Estándar ARQ-002: Políticas Globales de Negocio y Parámetros del Sistema

**Versión:** 1.0  
**Fecha:** 2026-07-31  
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

### POL-FIN-01: Política de Solidez de Caja (Liquidez Real)

- **Objetivo:** Garantizar que el saldo reportado por la caja refleje exclusivamente dinero que existe físicamente o digitalmente en ese instante, eliminando proyecciones, promesas o expectativas.
- **Declaración:** La caja del sistema reconoce únicamente el dinero que ya cambió de manos. Ningún módulo externo (Inventario, Fiados, Proveedores) tiene autoridad para inyectar o extraer valores monetarios de la caja si no hay un intercambio real de liquidez.
- **Reglas que gobierna:**
  - FRD-027, Regla 1: Límite de liquidez real
  - FRD-027, Regla 3: Bloqueo matemático de sobregiro
  - FRD-027-01, Regla 4: Fidelidad al flujo puro en reportes
  - FRD-026, Reglas 1-4: Gastos como egresos líquidos inmediatos
- **Consecuencia de violación:** Descuadre entre el dinero físico en el cajón y el saldo digital del sistema, imposibilitando la auditoría y facilitando el robo hormiga.

---

### POL-FIN-02: Política de Segregación de Canales Monetarios

- **Objetivo:** Impedir que el sistema mezcle matemáticamente el efectivo con los fondos digitales, evitando maniobras de compensación cruzada.
- **Declaración:** Cada origen de fondos (Efectivo, Transferencia Bancaria, Billetera Digital) DEBE calcularse, mostrarse y auditarse de manera separada e independiente. Queda vetada la fusión de canales para sortear validaciones de extracción.
- **Reglas que gobierna:**
  - FRD-027, Regla 2: Segregación estricta de canales
  - FRD-026, Regla 4: Dependencia de fondos por canal
- **Consecuencia de violación:** Un cajero podría cubrir faltantes de efectivo reportando falsamente transferencias digitales, o viceversa.

---

### POL-FIN-03: Política de Aislamiento de Promesas de Pago

- **Objetivo:** Proteger la veracidad contable del turno separando radicalmente el dinero real de las deudas pendientes (tanto a favor como en contra del negocio).
- **Declaración:** Las promesas de pago (fiados de clientes, facturas de proveedores) son registros informativos ("post-its") que documentan obligaciones futuras. Estas promesas NO TIENEN representación monetaria en el flujo de caja hasta que el dinero físicamente cambia de manos.
- **Reglas que gobierna:**
  - FRD-024, Reglas 1 y 3: Aislamiento y registro de fiados
  - FRD-025, Reglas 1 y 3: Aislamiento y registro de deudas a proveedores
  - FRD-027, Regla 1: Prohibición de consolidar créditos
- **Consecuencia de violación:** El reporte de caja mostraría ingresos ficticios (fiados no cobrados) o egresos anticipados (facturas no pagadas), destruyendo la confianza en el cuadre diario.

---

### POL-FIN-04: Política de Transformación de Promesa a Liquidez

- **Objetivo:** Definir el instante exacto en que una promesa de pago se convierte en dinero real dentro del sistema contable.
- **Declaración:** Una promesa de pago se transforma en liquidez únicamente en el momento en que el dinero cambia de manos. Esta transformación DEBE ejecutarse como una transacción atómica de doble vía: reducir el "post-it" del deudor Y registrar el movimiento en la caja del turno activo, de forma simultánea e inseparable.
- **Reglas que gobierna:**
  - FRD-024, Regla 4: Abono de cliente (promesa → ingreso)
  - FRD-025, Regla 4: Pago a proveedor (promesa → egreso)
  - FRD-006-02, Regla 4: Reembolso (transacción atómica bidireccional)
- **Consecuencia de violación:** Si una de las dos vías falla sin rollback, el sistema queda en estado inconsistente (el dinero se movió pero la deuda no se actualizó, o viceversa).

---

### POL-FIN-05: Política de Distribución por Tipo de Cierre

- **Objetivo:** Garantizar que el POS distribuya correctamente el resultado de cada transacción al módulo financiero correspondiente según su naturaleza.
- **Declaración:** El comportamiento financiero post-venta depende exclusivamente del método de cierre seleccionado por el cajero. Cada tipo de cierre tiene un destinatario financiero predefinido e inmutable: Efectivo/Digital va a Caja, Crédito va a Cuentas por Cobrar, y Baja Logística registra ingreso cero.
- **Reglas que gobierna:**
  - FRD-007-01, Regla 2: Tipología de cierre de carrito
  - FRD-007-01, Regla 5: Políticas de redondeo heredadas
  - FRD-006-02, Regla 3: Cálculo inmutable de reembolso
- **Consecuencia de violación:** El POS mezclaría ventas reales con mermas o fiados en el mismo total, corrompiendo el reporte Z del turno.

---

## Dominio Logístico

### POL-LOG-01: Política de Independencia Logística-Financiera

- **Objetivo:** Asegurar que el módulo de Inventario y el módulo de Caja operen como entes completamente autónomos, sin dependencias cruzadas que generen efectos secundarios no deseados.
- **Declaración:** El inventario es un ente logístico aislado. Su única métrica de verdad son las cantidades físicas (unidades, kilos, gramos). Las operaciones de inventario TIENEN PROHIBIDO condicionar sus movimientos al estado financiero de una transacción, y viceversa. La salida de un producto no garantiza un ingreso en caja; un ingreso en caja no requiere la salida de un producto.
- **Reglas que gobierna:**
  - FRD-027, Regla 4: Independencia logística absoluta
  - FRD-006-01, Reglas 1 y 2: Aislamiento financiero del inventario
  - FRD-006-01-01, Reglas 2, 3 y 4: Ceguera financiera en entradas
- **Consecuencia de violación:** Ingresar mercancía descontaría dinero automáticamente de la caja (aunque el proveedor haya dado crédito), o vender a fiado no descontaría el producto (porque "no se pagó").

---

### POL-LOG-02: Política de Verdad Física (Anti-Negativos)

- **Objetivo:** Impedir que el sistema registre operaciones que desafíen la realidad física del estante. No se puede vender, mermar o devolver algo que el sistema cree que no existe.
- **Declaración:** El sistema DEBE abortar cualquier operación de salida (venta, merma, devolución a proveedor) si el cálculo resultante llevaría el stock a un número negativo. Este es un bloqueo logístico absoluto que funciona de manera autónoma a las validaciones financieras.
- **Reglas que gobierna:**
  - FRD-006-01, Regla 3: Bloqueo estrictamente físico
  - FRD-007-01, Regla 4: Respeto al límite logístico en POS
- **Consecuencia de violación:** Stock negativo en el sistema genera ventas fantasma, reportes de inventario inservibles y desconfianza total en el Kardex.

---

### POL-LOG-03: Política de Embudo Único de Egresos (POS)

- **Objetivo:** Centralizar todos los egresos rutinarios de mercancía a través del Punto de Venta para garantizar que cada producto que abandona el estante quede vinculado a un turno, un cajero y un motivo auditable.
- **Declaración:** El POS es la única herramienta del sistema con jurisdicción para restar unidades del stock de forma rutinaria. El módulo de Inventario TIENE PROHIBIDO ofrecer interfaces de salida (Mermas, Consumos, Devoluciones). Toda reducción de stock operativa DEBE canalizarse por el carrito del POS.
- **Reglas que gobierna:**
  - FRD-006-01-02, Reglas 1 y 2: Prohibición de salidas manuales y delegación al POS
  - FRD-007-01, Regla 1: Embudo universal de egresos
- **Excepción documentada:** El Ajuste de Cuadre por inventario físico (anual/mensual), ejecutado exclusivamente por el Administrador, es la única operación que modifica stock sin pasar por el POS. *Trade-off:* Se acepta esta excepción porque los ajustes de cuadre son correctivos infrecuentes que requieren autorización administrativa, y forzarlos a pasar por el POS distorsionaría los reportes de ventas.

---

### POL-LOG-04: Política de Inmediatez Logística

- **Objetivo:** Garantizar que el inventario refleje la realidad física del estante en todo momento, sin depender de que se completen procesos financieros.
- **Declaración:** Toda entrada o salida de mercancía DEBE actualizar el stock de forma inmediata, independientemente de si el pago asociado fue en efectivo, a crédito, o si fue una merma sin valor monetario. La disponibilidad del producto para la venta no puede quedar condicionada al estado de una factura o un cobro.
- **Reglas que gobierna:**
  - FRD-024, Regla 2: Impacto logístico inmediato en fiados
  - FRD-025, Regla 2: Impacto logístico inmediato en proveedores
  - FRD-006-01, Regla 4: Desacoplamiento de proveedores
- **Consecuencia de violación:** Si el stock no se actualiza hasta que se pague la factura, un cliente podría intentar comprar algo que ya está en el estante pero el sistema reporta como "no disponible".

---

## Dominio de Seguridad

### POL-SEG-01: Política de Arqueo Ciego

- **Objetivo:** Prevenir la manipulación del conteo físico de dinero por parte del cajero, garantizando que el arqueo sea una declaración honesta y no una copia del dato del sistema.
- **Declaración:** Durante el transcurso de un turno activo y en el instante de cerrarlo, el sistema TIENE PROHIBIDO mostrar al cajero cuál es el saldo total esperado. El operario DEBE contar el dinero a ciegas y declarar la suma real.
- **Reglas que gobierna:**
  - FRD-027-01, Regla 2: Ceguera operativa
- **Consecuencia de violación:** El cajero podría manipular billetes para hacerlos cuadrar artificialmente con la expectativa del software, anulando el propósito de la auditoría.

---

### POL-SEG-02: Política de Caducidad del Turno Operativo

- **Objetivo:** Forzar un ciclo contable diario que obligue al cierre y cuadre de la caja, impidiendo turnos perpetuos que acumulen errores y dificulten la detección de anomalías.
- **Declaración:** Ningún turno operativo PUEDE permanecer activo más allá del límite temporal establecido. Al cruzar este umbral, el sistema transiciona el turno a estado "Expirado/Bloqueado" y rechaza toda operación financiera posterior.
- **Reglas que gobierna:**
  - FRD-027-02, Reglas 1, 2, 3 y 5: Límite 24h, bloqueo, resolución e intervención
- **Parámetro asociado:** `P_MAX_HORAS_TURNO`
- **Consecuencia de violación:** Un turno abierto durante días acumularía miles de transacciones sin cuadre, haciendo imposible detectar faltantes o robos oportunos.

---

### POL-SEG-03: Política de Control de Acceso por Roles

- **Objetivo:** Garantizar que cada función sensible del sistema (reembolsos, anulaciones, cierres forzosos) esté protegida por la matriz de permisos, sin recurrir a mecanismos externos como PINs temporales almacenados en el navegador.
- **Declaración:** El acceso a funciones privilegiadas está gobernado exclusivamente por el sistema de roles y permisos centralizado. Un usuario solo puede ejecutar una función si el Administrador le ha otorgado explícitamente dicho permiso en su perfil.
- **Reglas que gobierna:**
  - FRD-006-02, Regla 1: Control de acceso en reembolsos
  - FRD-007-01, Regla 3: Anclaje de turno (solo cajeros con sesión)
- **Consecuencia de violación:** Funciones sensibles quedarían expuestas a usuarios no autorizados, o el sistema dependería de mecanismos inseguros (localStorage) para la validación.

---

## Dominio de Auditoría

### POL-AUD-01: Política de Inmutabilidad Histórica

- **Objetivo:** Proteger la integridad de los registros contables cerrados, impidiendo que cambios futuros en el catálogo o en el sistema alteren retroactivamente los datos financieros pasados.
- **Declaración:** Una vez que un turno se cierra, su instantánea matemática es irreversible. Nadie, ni siquiera un Administrador, PUEDE alterar o recalcular reportes sellados. Las actualizaciones de catálogo (cambios de precio, corrección de costos) TIENEN PROHIBIDO alterar retrospectivamente el valor de ventas o ingresos ya registrados.
- **Reglas que gobierna:**
  - FRD-027-01, Regla 3: Inmutabilidad del cierre (sello de tiempo)
  - FRD-006-01, Regla 5: Independencia histórica
- **Consecuencia de violación:** Modificar precios retroactivamente cambiaría reportes de auditoría pasados, destruyendo la confianza del dueño en los números históricos y generando vulnerabilidades legales.

---

### POL-AUD-02: Política de Trazabilidad Universal

- **Objetivo:** Asegurar que cada movimiento en el sistema (venta, merma, reembolso, gasto) quede permanentemente vinculado a un turno, un usuario responsable y un motivo documentado.
- **Declaración:** Toda transacción que afecte liquidez o inventario DEBE heredar forzosamente el `session_id` del turno activo. El sistema provee dos niveles de reporte: uno operativo (para el cajero) y uno de auditoría interna (para el dueño), garantizando que las mermas y consumos se totalicen de forma separada a las ventas reales.
- **Reglas que gobierna:**
  - FRD-027-01, Regla 1: Dicotomía del reporte
  - FRD-006-01-01, Regla 5: Motivos de entrada permitidos
  - FRD-006-01-02, Reglas 4 y 5: Anclaje al turno y aislamiento de bajas
  - FRD-007-01, Regla 3: Anclaje obligatorio al turno en POS
  - FRD-006-02, Regla 5: Dependencia de turno en reembolsos
- **Consecuencia de violación:** Transacciones "huérfanas" (sin turno ni usuario) serían imposibles de auditar, generando agujeros negros contables donde la mercancía desaparece sin rastro.

---

### POL-AUD-03: Política de Detección de Anomalías

- **Objetivo:** Garantizar que el sistema identifique, registre y alerte automáticamente sobre cualquier comportamiento irregular (descuadres, negligencia de cierre, cierres forzosos).
- **Declaración:** Toda diferencia entre lo esperado por el sistema y lo declarado por el operario DEBE generar un registro de ajuste indeleble y emitir alertas silenciosas a los perfiles de administración. Los turnos que caduquen sin cierre voluntario DEBEN marcarse permanentemente como "Negligencia de Cierre".
- **Reglas que gobierna:**
  - FRD-027-01, Regla 5: Autenticidad de descuadres
  - FRD-027-02, Regla 4: Bandera de anomalía administrativa
- **Consecuencia de violación:** Faltantes de dinero pasarían desapercibidos, robos hormiga se acumularían sin detección, y el dueño perdería visibilidad sobre la operación de su tienda.

---

# II. MATRIZ DE TRAZABILIDAD POLÍTICA → REGLA

| Política | FRDs que Gobierna | Módulos Afectados |
|----------|-------------------|-------------------|
| POL-FIN-01 | FRD-027, FRD-027-01, FRD-026 | Caja, Reportes, Gastos |
| POL-FIN-02 | FRD-027, FRD-026 | Caja, Gastos |
| POL-FIN-03 | FRD-024, FRD-025, FRD-027 | Fiados, Proveedores, Caja |
| POL-FIN-04 | FRD-024, FRD-025, FRD-006-02 | Fiados, Proveedores, Reembolsos |
| POL-FIN-05 | FRD-007-01, FRD-006-02 | POS, Reembolsos |
| POL-LOG-01 | FRD-027, FRD-006-01, FRD-006-01-01 | Caja, Inventario, Entradas |
| POL-LOG-02 | FRD-006-01, FRD-007-01 | Inventario, POS |
| POL-LOG-03 | FRD-006-01-02, FRD-007-01 | Salidas, POS |
| POL-LOG-04 | FRD-024, FRD-025, FRD-006-01 | Fiados, Proveedores, Inventario |
| POL-SEG-01 | FRD-027-01 | Reportes, Caja |
| POL-SEG-02 | FRD-027-02 | Caja, POS, Gastos, Fiados |
| POL-SEG-03 | FRD-006-02, FRD-007-01 | Reembolsos, POS |
| POL-AUD-01 | FRD-027-01, FRD-006-01 | Reportes, Inventario |
| POL-AUD-02 | FRD-027-01, FRD-006-01-01, FRD-006-01-02, FRD-007-01, FRD-006-02 | Todos |
| POL-AUD-03 | FRD-027-01, FRD-027-02 | Reportes, Caja |

---

# III. DICCIONARIO DE PARÁMETROS DEL SISTEMA

> [!IMPORTANT]
> Los siguientes valores son los parámetros configurables que las reglas de los FRDs consumen. Los números no son la regla; son variables de la regla. Cambiar un parámetro aquí no requiere reescribir ningún FRD ni redesplegar código, solo actualizar la tabla de configuración del sistema.

| Código | Nombre | Valor Actual | Unidad | Política Origen | FRD que lo Consume |
|--------|--------|-------------|--------|-----------------|-------------------|
| `P_MAX_HORAS_TURNO` | Vida máxima de un turno de caja | 24 | Horas | POL-SEG-02 | FRD-027-02 |
| `P_REDONDEO_MULTIPLO` | Múltiplo de redondeo para subtotales | 50 | Pesos (COP) | POL-FIN-05 | FRD-007-01 |
| `P_MAX_ITEMS_CARRITO` | Límite de productos por transacción | 50 | Unidades | POL-FIN-05 | FRD-007-01 |

> [!NOTE]
> **Alcance Diferido:** A medida que se formalicen nuevos FRDs o se descubran valores numéricos enterrados en las reglas existentes, este diccionario DEBE actualizarse. La condición para revisar este documento es: "Si un FRD contiene un número que podría cambiar por decisión del dueño sin alterar la lógica del software, ese número debe extraerse aquí".

---

# IV. PROTOCOLO DE USO

## ¿Cuándo consultar este documento?

| Situación | Acción |
|-----------|--------|
| Estoy redactando un nuevo FRD y una regla se parece a algo que ya escribí en otro módulo | Buscar si ya existe una Política que la cubra. Si existe, referenciar la Política en el nuevo FRD en lugar de reescribir la regla. |
| El dueño quiere cambiar un número ("ahora el turno caduca a las 12 horas") | Actualizar la Sección III (Diccionario de Parámetros), no el texto del FRD. |
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
| 1.0 | 2026-07-31 | Arquitecto de Producto | Creación inicial. Extracción de 15 Políticas desde 11 FRDs. Diccionario de 3 parámetros iniciales. |

---

**Firmado:** Arquitecto de Producto  
**Fecha:** 2026-07-31
