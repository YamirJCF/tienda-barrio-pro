# FRD-004_1: Gestión de PIN de Caja

### Nombre de la Funcionalidad
Configuración y Ciclo de Vida del PIN de Caja

#### Descripción
Sub-módulo de seguridad enfocado exclusivamente en la "Llave de la Caja". Este PIN es independiente de la contraseña de login del Admin y sirve como firma electrónica para autorizar movimientos de dinero.

---

## Reglas de Negocio

1. **Formato:**
    - El PIN de caja es un código numérico de **mínimo 4 y máximo 6 dígitos**.
    - El sistema DEBE aceptar cualquier longitud dentro de este rango.

2. **Unicidad por Tienda:**
    - Existe un solo PIN Maestro de Caja por tienda, asociado a la cuenta del Admin/Dueño.

3. **Ámbito de Uso Restringido:**
    - Este PIN se usa ÚNICA Y EXCLUSIVAMENTE para: **Abrir Caja y Cerrar Caja**.
    - NO tiene ninguna otra función en el sistema.
    - NO autoriza descuentos, NO borra ventas, NO aprueba operaciones especiales.

4. **Recuperación:**
    - Si se pierde el PIN, solo puede restablecerse verificando nuevamente la contraseña maestra del Admin.
    - El sistema DEBE pedir re-autenticación completa antes de permitir cambiar el PIN.

5. **Bloqueo por Intentos Fallidos:**
    - 3 intentos fallidos consecutivos bloquean la entrada de PIN por 5 minutos.
    - Este bloqueo persiste aunque se recargue la página.
    - Mensaje al usuario: "Demasiados intentos fallidos. Espera X minutos."

6. **Jerarquía de Modificación:**
    - Solo el ADMIN puede crear o cambiar el PIN de caja.
    - Un empleado (incluso con permisos) NUNCA puede ver la pantalla de configuración de PIN.

---

## Casos de Uso

**Caso A: Configuración Inicial (Just-in-Time)**
- **Actor:** Admin (cuenta nueva sin PIN configurado)
- **Precondición:** No existe PIN configurado.
- **Flujo Principal:**
    1. Admin intenta entrar a "Abrir Caja".
    2. Sistema detecta que no hay PIN configurado.
    3. Sistema redirige automáticamente a pantalla "Configurar PIN".
    4. Admin crea PIN de 4-6 dígitos y lo confirma.
    5. Sistema guarda el PIN y redirige inmediatamente de vuelta a "Abrir Caja".
    6. El flujo operativo continúa sin interrupción.
- **Postcondición:** PIN configurado, Admin puede continuar con apertura de caja.

**Caso B: Cambio de PIN (Rotación de Seguridad)**
- **Actor:** Admin
- **Precondición:** PIN ya existe.
- **Flujo Principal:**
    1. Admin navega a configuración de seguridad.
    2. Selecciona "Cambiar PIN de Caja".
    3. Sistema solicita PIN actual.
    4. Admin ingresa PIN actual → Sistema valida.
    5. Si es válido → Sistema solicita nuevo PIN + confirmación.
    6. Sistema actualiza el PIN.
- **Postcondición:** Nuevo PIN activo inmediatamente.

**Caso C: Challenge al Abrir Caja**
- **Actor:** Usuario con permiso de caja
- **Precondición:** Caja cerrada.
- **Flujo Principal:**
    1. Usuario intenta acceder al control de caja.
    2. Sistema muestra modal solicitando PIN de caja.
    3. Si PIN correcto → Permite continuar con apertura.
    4. Si PIN incorrecto → Muestra intentos restantes (3, 2, 1).
    5. Si 3 intentos fallidos → Bloquea por 5 minutos.
- **Postcondición:** Acceso concedido si PIN válido.

**Caso D: Challenge al Cerrar Caja**
- **Actor:** Usuario con permiso de caja
- **Precondición:** Caja abierta, conteo completado.
- **Flujo Principal:**
    1. Usuario pulsa "Confirmar Cierre" tras completar el conteo.
    2. Sistema muestra modal solicitando PIN para firmar el arqueo.
    3. Si PIN correcto → Cierra sesión y guarda reporte.
    4. Si PIN incorrecto → Mismo flujo de reintentos que Caso C.
- **Postcondición:** Arqueo firmado, caja cerrada.

---

## Requisitos de Datos (Para Equipo Data)

**Extensión de Entidad Tienda:**
- Hash del PIN de caja (nunca texto plano)
- Contador de intentos fallidos
- Timestamp de bloqueo (hasta cuándo está bloqueado)

---

## Criterios de Aceptación

- [ ] El keypad de la interfaz acepta solo números.
- [ ] El sistema acepta PINs de 4, 5 o 6 dígitos.
- [ ] El PIN nunca viaja ni se almacena en texto plano.
- [ ] El bloqueo de 5 minutos persiste aunque se recargue la página.
- [ ] Solo el Admin puede acceder a la configuración de PIN.
- [ ] Los empleados no ven la opción de configurar/cambiar PIN, solo la de ingresar.
