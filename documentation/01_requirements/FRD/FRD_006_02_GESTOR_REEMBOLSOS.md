# FRD-006-02: Gestor de Reembolsos (Devoluciones de Clientes)

### Orquestación Atómica de Ingresos Logísticos y Egresos Monetarios

#### Descripción
Herramienta especializada ubicada en la pantalla de "Administración" (sección "Equipo"), diseñada exclusivamente para manejar las devoluciones de productos por parte de clientes. Su propósito es resolver la "paradoja de la devolución": ingresar stock y sacar dinero simultáneamente. Al ser un módulo independiente, evita contaminar las ventas del POS y prohíbe la manipulación manual de inventarios, asegurando que el dinero reembolsado cuadre perfectamente en el turno de caja actual.

---

## Reglas de Negocio

1. **Control de Acceso Basado en Perfil:** No se requieren PINs temporales. El acceso a esta herramienta está gobernado estrictamente por el sistema de permisos. Un empleado solo podrá visualizar y ejecutar esta función si el Administrador le ha otorgado explícitamente dicho permiso en su perfil de usuario.
2. **Entrada Manual por PLU:** El registro del producto a devolver se realiza digitando manualmente su código identificador interno (PLU), prescindiendo del uso del escáner de código de barras.
3. **Cálculo de Monto Estricto e Inmutable:** Una vez ingresado el PLU y la cantidad de unidades, el sistema calcula automáticamente el valor monetario a devolver (basado en el precio de venta del sistema). Este monto total desglosado es **exacto e inalterable** por el usuario. El sistema y el cajero asumen este valor como la única verdad contable para el reembolso.
4. **Transacción Atómica Bidireccional:** Al confirmar el reembolso, el sistema ejecuta una única transacción en la base de datos que dispara dos eventos simultáneos:
   - **Evento Logístico:** Incrementa el inventario del PLU en la cantidad especificada.
   - **Evento Financiero:** Registra un "Egreso" (salida de efectivo) en la sesión de caja activa por el monto exacto calculado.
5. **Dependencia de Turno Activo:** Para poder entregar dinero al cliente, el sistema exige que el usuario tenga un Turno de Caja (Sesión) abierto y vigente. El egreso queda amarrado al `session_id` actual, asegurando que el arqueo de caja al final del día refleje el dinero entregado por la devolución.

---

## Casos de Uso

**Caso A: Reembolso por Producto Devuelto**
- **Actor:** Administrador o Empleado con permiso explícito de Reembolso.
- **Precondición:** El cliente devuelve mercancía en buen estado. El actor tiene un turno de caja activo.
- **Flujo Principal:**
  1. El actor navega a la pantalla de "Administración", bajo la sección "Equipo", y abre la herramienta de Reembolsos.
  2. Digita manualmente el código PLU del producto.
  3. Ingresa la cantidad de productos a devolver.
  4. El sistema calcula y muestra en pantalla el total exacto a reembolsar al cliente.
  5. El actor confirma la operación.
  6. El sistema extrae el dinero contablemente de la sesión de caja y suma el stock al inventario de forma automática.
- **Flujo Alternativo (Sin Permiso):** Si un cajero sin autorización intenta acceder a la ruta, el sistema le deniega el acceso visual o funcional.
- **Flujo Alternativo (Sin Turno):** Si el actor tiene permisos pero su caja está cerrada, el sistema aborta la operación advirtiendo que no hay caja de dónde sacar el dinero.
- **Postcondición:** El inventario aumenta, el flujo de caja del turno actual registra un gasto por reembolso, y el cajón físico de dinero cuadra.

---

## Criterios de Aceptación
- [ ] **CA-FRD-006-02-01:** La herramienta de devoluciones DEBE estar protegida por la matriz de roles y permisos existente, denegando el renderizado o ejecución a usuarios sin autorización.
- [ ] **CA-FRD-006-02-02:** La interfaz DEBE requerir la digitación del PLU y PROHIBIR la edición manual del campo "Monto a Reembolsar", el cual debe ser un cálculo inyectado por el sistema.
- [ ] **CA-FRD-006-02-03:** El backend DEBE abortar (rollback) la operación si la inserción del ingreso de inventario falla, o si la inserción del egreso de caja falla, garantizando consistencia.
- [ ] **CA-FRD-006-02-04:** La función backend DEBE exigir un `session_id` activo para procesar el egreso de dinero.
