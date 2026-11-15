# FRD-003-01: Matriz de Permisos de Empleados (Fuente de Verdad)

> **Estado:** 🟡 VALIDADO CONTRA POLÍTICAS (`ARQ-002`, `/validate-policy`). Pendiente de formalización en SDD/DSD e implementación (Fase 3).
> **Enmienda a:** FRD-003 (Regla 5). Al implementarse en SDD/DSD, DEBE reconciliar FRD-006, FRD-006-02, FRD-008, FRD-009, FRD-018, FRD-027-01 y la UI de formulario de empleado.

### Nombre de la Funcionalidad
Alcance exacto de los permisos asignables a un empleado

#### Descripción
Define, en un solo lugar, qué puede y qué no puede hacer un empleado según los permisos que el Administrador le asigna. Reemplaza las definiciones dispersas y contradictorias entre documentos. Todo permiso se valida en el servidor (FRD-002) y toda acción del empleado queda registrada con su identidad.

---

## Reglas de Negocio

1. **Modelo de cinco permisos independientes (POL-SEG-03).** Cada empleado tiene exactamente estos interruptores, todos apagados por defecto:
   - **Inventario completo**
   - **Fiar y cobrar abonos**
   - **Abrir/cerrar caja**
   - **Ver reportes**
   - **Reembolsos**
2. **Vender es implícito.** Todo empleado con Pase Diario puede operar el POS (FRD-003 R4). No es un permiso configurable.
3. **Gestión de clientes es exclusiva del Administrador.** Crear, editar y eliminar clientes y cambiar cupos NO es delegable (FRD-009).
4. **Autoridad del servidor.** El servidor DEBE rechazar con error de seguridad explícito cualquier operación cuyo permiso el empleado no tenga, sin importar lo que muestre u oculte la interfaz (FRD-002). Ocultar un botón NO es control de acceso.
5. **Atribución y auditoría obligatorias.** Toda acción realizada por un empleado (venta, abono, reembolso, apertura/cierre y **toda acción de inventario permitida**: crear, editar o eliminar un producto y registrar entradas) DEBE guardarse en el servidor con la etiqueta de identificación del empleado, fecha y hora, de forma inmutable (POL-AUD-02). El empleado no puede alterar ni borrar esa etiqueta. A mayor delegación operativa, mayor trazabilidad: la gestión del catálogo y entradas se concede porque cada acción es auditable por el Administrador.
5b. **Eliminación de productos con trazabilidad.** Eliminar un producto es una baja lógica: el producto desaparece del catálogo activo pero conserva su historial y la etiqueta de quién lo eliminó (POL-AUD-01). El Administrador puede consultar lo eliminado.
6. **Alcance por permiso (qué puede el empleado, qué NO puede y qué corresponde únicamente al Administrador):**

| Permiso | El empleado PUEDE | El empleado NO PUEDE / Exclusivo del Administrador |
|---|---|---|
| **Inventario completo** | Ver catálogo, stock, costo y Kardex; crear, editar y eliminar productos (baja lógica); registrar entradas de mercancía (POL-LOG-01, FRD-006-01-01) | Realizar **Ajustes de Cuadre por inventario físico** sin pasar por el POS (**exclusivo del Administrador**, POL-LOG-03); registrar salidas operativas directas desde Inventario como mermas, consumos o devoluciones (toda salida operativa se canaliza por el POS, POL-LOG-03); mover dinero de caja ni crear/modificar deudas o facturas con proveedores (**exclusivo del Administrador**, POL-LOG-01, FRD-006-01-01, FRD-019) |
| **Fiar y cobrar abonos** | Seleccionar "Fiado" al cobrar en el POS (respetando el cupo asignado del cliente); registrar abonos de clientes con caja abierta y canal de pago | Crear, editar o eliminar clientes; cambiar cupos de crédito (**exclusivo del Administrador**, FRD-009, POL-PRIV-01, POL-PRIV-02); fiar superando cupo o cobrar abonos con caja cerrada |
| **Abrir/cerrar caja** | Abrir y cerrar su propio turno con arqueo ciego | Ver el saldo esperado ni diferencias **antes, durante ni al momento de cerrar** (POL-SEG-01); consultar turnos de otros usuarios ni realizar auditoría/gestión de cierres ajenos (**exclusivo del Administrador**) |
| **Ver reportes** | Ver el reporte parcial y ciego de su turno activo; ver el resumen diario de ventas (FRD-008) | Ver saldo esperado o diferencias de arqueo (POL-SEG-01), historial de turnos cerrados, reporte forense de auditoría ni el panel financiero consolidado (**exclusivo del Administrador**, FRD-018 CA-018-06) |
| **Reembolsos** | Ejecutar reembolsos de clientes con caja abierta y fondos suficientes en el canal elegido (FRD-006-02) | Reembolsar sin turno activo (POL-AUD-02); compensar entre canales monetarios distintos (POL-FIN-02); realizar anulaciones administrativas de ventas o alterar historial cerrado (**exclusivo del Administrador**, POL-AUD-01) |

6b. **Acciones exclusivas del Administrador (no delegables a empleados bajo ningún permiso).** Ninguno de los cinco interruptores otorga acceso a:
   - Crear o editar empleados, cambiar PINs ni modificar permisos (Regla 8, POL-SEG-03).
   - Crear, editar o eliminar clientes, ni modificar sus cupos de crédito (Regla 3, FRD-009).
   - Ejecutar **Ajustes de Cuadre por inventario físico** fuera del POS (POL-LOG-03).
   - Gestionar proveedores, facturas de compra, cuentas por pagar ni pagos a proveedores (POL-LOG-01, FRD-019).
   - Consultar el panel financiero consolidado, historial completo de turnos cerrados, diferencias de cuadre/arqueo, catálogo de productos eliminados con trazabilidad de auditoría y reportes forenses (POL-SEG-01, POL-AUD-03, FRD-018).
   - Configurar parámetros de la tienda o realizar anulaciones administrativas de ventas fuera de reembolso operativo (FRD-007).

7. **Los permisos no se heredan ni se implican** salvo lo escrito en la tabla. Que un empleado tenga un permiso no le da otro.
8. **Edición de permisos solo por Administrador**, validada en servidor. Un empleado no puede modificar sus propios permisos.
9. **Efecto inmediato.** Un cambio de permisos DEBE aplicarse en la siguiente operación del empleado, sin esperar a un nuevo inicio de sesión.

---

## Casos de Uso

**Caso A: Empleado sin permiso intenta una acción restringida**
- **Actor:** Empleado.
- **Precondición:** No tiene el permiso requerido.
- **Flujo Principal:**
    1. El empleado intenta la acción, por la interfaz o por una llamada directa al servidor.
    2. El servidor consulta el perfil del empleado y detecta que falta el permiso.
    3. El servidor aborta, no modifica nada y devuelve un error de seguridad explícito.
    4. La interfaz muestra un mensaje claro: "No tienes permiso para esta acción. Pídeselo al administrador."
- **Postcondición:** Sin cambios en datos; el intento queda registrado.

**Caso B: Empleado con permiso opera**
- **Flujo Principal:** el empleado ejecuta la acción permitida; el servidor la registra con la identidad del empleado.
- **Postcondición:** El Administrador puede ver quién hizo qué.

**Caso C: Administrador cambia permisos**
- **Flujo Principal:** el Administrador activa o desactiva interruptores en el perfil; el servidor valida su rol y guarda; el siguiente movimiento del empleado ya usa los permisos nuevos.

---

## Criterios de Aceptación
- [ ] **CA-003-01-01:** El formulario de empleado ofrece exactamente los cinco permisos de la Regla 1 más la capacidad de vender implícita.
- [ ] **CA-003-01-02:** Una llamada directa al servidor sin el permiso correspondiente es rechazada con error de seguridad, para cada uno de los cinco permisos.
- [ ] **CA-003-01-03:** Un empleado sin "Fiar y cobrar abonos" no puede cobrar a fiado ni registrar abonos.
- [ ] **CA-003-01-04:** Un empleado con "Ver reportes" no puede obtener saldo esperado, historial de turnos ni datos financieros consolidados, ni por interfaz ni por llamada directa.
- [ ] **CA-003-01-05:** Todo movimiento de empleado muestra su identidad en el historial y esta no es modificable.
- [ ] **CA-003-01-05b:** Toda acción de inventario de un empleado (crear, editar, eliminar producto y registrar entradas) queda con su etiqueta de identificación y es consultable por el Administrador.
- [ ] **CA-003-01-05c:** Un empleado con "Inventario completo" ve el costo del producto, puede eliminarlo (baja lógica) y registrar entradas, pero no puede ejecutar ajustes de cuadre físico ni salidas operativas fuera del POS (exclusivos del Administrador / POS según POL-LOG-03); uno sin el permiso no accede al módulo de inventario ni por interfaz ni por llamada directa.
- [ ] **CA-003-01-06:** Un cambio de permisos rige desde la siguiente operación del empleado.
- [ ] **CA-003-01-07:** Solo el Administrador puede editar permisos de empleados.

---

## Requisitos de Datos (Para Equipo Data)
- Los permisos del empleado son cinco indicadores independientes de verdadero/falso, apagados por defecto.
- Cada movimiento de inventario, venta, abono, reembolso y apertura/cierre guarda el identificador del empleado responsable.
- El servidor dispone de una verificación única y reutilizable de permisos, que consultan todas las operaciones restringidas.

---

## Enmiendas que provoca este documento (pendiente de ejecutar en Fase 3 / Docs)
| Documento | Cambio |
|---|---|
| FRD-003 R5 | Reemplazar los 5 toggles por los de la Regla 1; eliminar "ver inventario" como permiso separado |
| FRD-006 (matriz de permisos y criterios de aceptación) | Unificar "ver" y "gestionar" inventario en "Inventario completo". Derogar "Eliminar producto: solo Admin", "costo visible solo para Admin" y los criterios de aceptación que los exigen, manteniendo exclusivos del Administrador los ajustes de cuadre físico (POL-LOG-03) |
| FRD-006-02 | El permiso explícito de reembolso pasa a ser "Reembolsos"; deja de depender de gestión de inventario |
| FRD-009 | "Registrar abono: ✅ Empleado" pasa a requerir "Fiar y cobrar abonos" |
| FRD-008 / FRD-027-01 | Definir el alcance del empleado con "Ver reportes" (Regla 6) |
| ARQ-003 / ARQ-004 | Trazabilidad sincronizada en ARQ-003; sin parámetros numéricos nuevos para ARQ-004 |

---

## Decisiones registradas (Regla 7 de trade-offs)
- **D-1 – Control operativo del catálogo y entradas en Inventario (incluye costo y baja lógica; excluye ajustes de cuadre físico).**
  - *Qué:* dentro de las operaciones permitidas a empleados en Inventario (ver catálogo/stock/costo/Kardex, crear/editar/eliminar por baja lógica y entradas), no hay ocultamiento de costo; los ajustes de cuadre físico (`POL-LOG-03`), las salidas operativas fuera del POS (`POL-LOG-03`) y proveedores/cuentas por pagar (`POL-LOG-01`) siguen siendo exclusivos del Administrador / POS.
  - *Por qué:* ocultar el costo mientras se delega la edición del catálogo es contradictorio y obliga a dos niveles de permiso; las acciones delegadas se compensan con auditoría total (Regla 5), mientras el ajuste de cuadre físico conserva autorización administrativa exclusiva por `POL-LOG-03`.
  - *Revisar si:* se detectan bajas o entradas anómalas en la auditoría, o si el Administrador decide restringir el costo o delegar ajustes físicos mediante enmienda a `POL-LOG-03`.
- **D-2 – Fusión de "ver" y "gestionar" inventario.**
  - *Qué:* desaparece el empleado de solo consulta de stock.
  - *Por qué:* simplifica el modelo; el POS ya permite buscar productos para vender sin este permiso.
  - *Revisar si:* aparece la necesidad de un rol de solo consulta.

## Pendientes
- Formalización de SDD/DSD y refactorización de código en Fase 3 tras la validación de políticas (`/validate-policy`).
