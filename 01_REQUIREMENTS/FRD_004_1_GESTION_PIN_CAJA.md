# FRD-004-1: Gestión de PIN de Caja (Cash PIN)

### Nombre de la Funcionalidad
Configuración y Ciclo de Vida del PIN de Caja

#### Descripción
Sub-módulo de seguridad enfocado exclusivamente en la "Llave de la Caja". Este PIN es independiente de la contraseña de login del Admin y sirve como firma electrónica para autorizar movimientos de dinero.

#### Reglas de Negocio
1.  **Formato:** El PIN de caja es un código numérico de **6 dígitos** (ej: 090909).
2.  **Unicidad por Tienda:** Existe un solo PIN Maestro de Caja por tienda, asociado a la cuenta del Admin/Dueño.
3.  **Ámbito de Uso Restringido:**
    *   Este PIN se usa **ÚNICA Y EXCLUSIVAMENTE** para: **Abrir Caja y Cerrar Caja**.
    *   NO tiene ninguna otra función en el sistema (no autoriza descuentos, no borra ventas, etc).
4.  **Recuperación:** Al ser local y crítico, si se pierde el PIN, solo puede restablecerse verificando nuevamente la contraseña maestra del Admin (re-autenticación).
5.  **Bloqueo por Intentos:**
    *   3 intentos fallidos consecutivos bloquean la entrada de PIN por 5 minutos.
    *   Esto previene ataques de fuerza bruta manuales en el POS.
6.  **Jerarquía de Modificación:**
    *   **Solo el ADMIN** puede Crear o Cambiar el PIN de Caja.
    *   Un empleado (incluso con permisos) **JAMÁS** podrá ver la pantalla de configuración de PIN.

#### Casos de Uso

**Caso A: Configuración "Just-in-Time" (Flujo Continuo)**
- **Actor:** Admin (En cuenta nueva)
- **Precondición:** No existe PIN configurado aún.
- **Flujo:**
    1.  Admin intenta entrar a "Abrir Caja".
    2.  Sistema detecta `hasPinConfigured = false`.
    3.  **Redirección Automática:** Lleva al Admin a la pantalla "Configurar PIN" (Interrupción forzosa).
    4.  Admin crea y confirma el PIN de 6 dígitos.
    5.  **Retorno Automático:** Sistema guarda y redirige *inmediatamente* de vuelta a "Abrir Caja".
    6.  El flujo operativo no se pierde.

**Caso B: Cambio de PIN (Rotación)**
- **Actor:** Admin
- **Flujo:**
    1.  Admin va a "Configuración" -> "Seguridad".
    2.  Selecciona "Cambiar PIN de Caja".
    3.  **Validación 1:** Sistema pide PIN Actual.
    4.  **Validación 2:** Sistema pide Nuevo PIN + Confirmación.
    5.  Si PIN Actual es válido -> Se actualiza el hash.

**Caso C1: Challenge al Abrir (Ingreso al Módulo)**
- **Trigger:** Usuario intenta entrar a `/cash-control` cuando la caja está CERRADA (FRD-004 Caso A).
- **Flujo:**
    1.  Sistema intercepta navegación.
    2.  Modal pide: "PIN de Caja para Abrir".
    3.  Validación Exitosa -> Permite entrar a pantalla "Ingresar Monto Base".

**Caso C2: Challenge al Cerrar (Firma de Arqueo)**
- **Trigger:** Usuario pulsa "Confirmar Cierre" tras contar el dinero (FRD-004 Caso B).
- **Flujo:**
    1.  Modal pide: "PIN de Caja para Firmar Cierre".
    2.  Validación Exitosa -> Cierra sesión y guarda reporte.

#### Requisitos de Datos (Input para Equipo de Data)
Entidad `stores` (Ampliación):
*   `cash_pin_hash`: String (Hash seguro, no texto plano).
*   `pin_failed_attempts`: Integer.
*   `pin_locked_until`: Timestamp.

#### Criterios de Aceptación
- [ ] El keypad del UI debe restringir input a solo números.
- [ ] El PIN no debe viajar en texto plano por la red (Hash en cliente o canal seguro).
- [ ] El bloqueo de 5 minutos debe persistir incluso si se recarga la página.

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| **CashControlStore** | Implementar lógica de bloqueo temporal (`lockedUntil`). |
| **PinSetupModal** | Asegurar validación de 6 dígitos (actualmente el código tiene mezcla de 4/6, estandarizar a 6). |
