# FRD-004: Control de Caja V1 (Turnos)

### Nombre de la Funcionalidad
Gestión de Sesiones de Caja (Apertura, Movimientos y Cierre)

#### Descripción
Módulo crítico que controla el flujo de efectivo físico en la tienda. Establece límites temporales ("Turnos" o "Sesiones") para responsabilizar a los cajeros del dinero procesado durante su gestión.

#### Reglas de Negocio
1.  **Unicidad de Sesión:** Solo puede haber **UNA sesión de caja abierta** por tienda en un momento dado. No se permiten cajas simultáneas en este MVP.
2.  **Bloqueo Operativo (POS Lockout):**
    *   **Estado Cerrado = POS Inaccesible.**
    *   Si la caja está cerrada, la vista principal de Ventas (`/pos`) debe mostrar un **Overlay Bloqueante** o redirigir a "Apertura de Caja".
    *   Esto aplica a **TODOS** los roles (Admin esclavo del proceso). Nadie vende sin caja abierta.
    *   Solo se permite "Ver Precios" o "Consultar Inventario" en modo lectura.
3.  **Inmutabilidad de Transacciones:** Una vez registrado un movimiento (ingreso/gasto), no puede borrarse ni editarse. Si hubo error, se debe crear un contra-movimiento correctivo.
4.  **Fórmula de Conciliación:**
    `Saldo Esperado = Base Inicial + Ventas Efectivo + Ingresos Manuales - Gastos/Retiros`

#### Casos de Uso

**Caso A: Apertura de Turno**
- **Actor:** Empleado (con permiso `canOpenCloseCash` O supervisado por Admin)
- **Precondición:** Caja cerrada.
- **Flujo:**
    1.  Usuario intenta ingresar a "Control de Caja".
    2.  **Challenge de Seguridad:** Sistema solicita PIN de Caja inmediatamente.
    3.  Usuario ingresa PIN -> Sistema valida.
    4.  Si es correcto, muestra pantalla "Apertura de Turno".
    5.  Usuario ingresa **Monto Base** (Fondo de cambio).
    6.  Usuario confirma -> Sistema abre sesión (`status: 'open'`).
    7.  Sistema habilita POS y redirige al **Dashboard**.

**Caso B: Cierre de Turno (Arqueo)**
- **Actor:** Empleado
- **Precondición:** Caja abierta.
- **Flujo:**
    1.  Usuario selecciona "Cerrar Turno".
    2.  **Visualización Transparente:** El sistema muestra cuánto *debería* haber (Saldo Esperado) y el desglose de ventas/gastos.
    3.  **Conteo Físico:** Usuario ingresa el dinero real que tiene en mano.
    4.  Usuario pulsa "Confirmar Cierre".
    5.  **Challenge de Seguridad:** Sistema solicita PIN de Caja para firmar el arqueo.
    6.  Si PIN es correcto -> Sistema cierra la sesión y guarda el reporte histórico.

**Caso C: Registro de Gasto (Salida de Dinero)**
- **Actor:** Empleado
- **Flujo:**
    1.  Usuario saca dinero para pagar algo (ej: Proveedor de hielo, Almuerzo).
    2.  Ingresa a "Gastos" -> "Nuevo Gasto".
    3.  Digita Monto y Motivo.
    4.  Sistema resta del Saldo Esperado inmediatamente.

#### Requisitos de Datos (Input para Equipo de Data)
Entidad `cash_sessions`:
*   `id` (UUID): PK.
*   `store_id` (FK).
*   `opened_by` (FK: employee_id).
*   `closed_by` (FK: employee_id).
*   `opening_balance` (Decimal).
*   `closing_balance` (Decimal, Nullable).
*   `calculated_balance` (Decimal, Nullable).
*   `difference` (Decimal, Nullable).
*   `status`: 'open' | 'closed'.
*   `started_at` / `ended_at` (Timestamps).

Entidad `cash_transactions`:
*   `id` (UUID).
*   `session_id` (FK).
*   `type`: 'income' (Venta/Ingreso) | 'expense' (Gasto/Retiro).
*   `amount` (Decimal).
*   `description` (String).
*   `related_sale_id` (FK, Nullable): Para trazar origen venta.

#### Criterios de Aceptación
- [ ] No Permitir abrir caja si ya hay una abierta.
- [ ] El sistema debe persistir la sesión incluso si se recarga el navegador (Persistencia Local/Remota).
- [ ] El cierre de caja genera un registro inmutable en el historial.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| **POS View** | **Router Guard:** Si `isOpen=false`, redirigir obligatoriamente a `/cash-control`. El POS no debe ni renderizarse. |
| **CashRegisterStore** | Lógica central de cálculo. |
