# FRD-002: Registro y Gestión de Cuentas Administrativas (Dueños)

### Nombre de la Funcionalidad
Alta de Nuevas Tiendas y Cuentas de Administrador

#### Descripción
Proceso mediante el cual un nuevo dueño de negocio (Admin) crea su cuenta en el sistema. Este proceso genera simultáneamente la identidad digital del usuario (Autenticación) y la entidad del negocio (Base de Datos), estableciendo la relación de propiedad raíz.

#### Reglas de Negocio
1.  **Unicidad de Cuenta:** El correo electrónico del Admin es el identificador único global. No pueden existir dos cuentas con el mismo email, incluso para tiendas diferentes.
2.  **Relación 1:1 Inicial:** Al registrarse, el Admin se vincula automáticamente como "Dueño Propietario" de la tienda creada.
3.  **Validación de Identidad Obligatoria:**
    *   El sistema **NO permite el acceso** al Dashboard hasta que el email sea verificado.
    *   El flujo debe interrumpirse tras el registro y redirigir a una pantalla de "Verifica tu correo".
4.  **Credenciales Maestras:**
    *   El Admin maneja **Email + Contraseña** robusta (Min 8 car, alfanumérica).
    *   El Admin **SI configura un PIN de Caja** (4-6 dígitos).
    *   **Uso Exclusivo:** Este PIN se usa ÚNICAMENTE para la ceremonia de **Apertura y Cierre de Caja**. No se utilizará para aprobaciones generales ni descuentos.

#### Casos de Uso

**Caso A: Registro con Verificación Estricta**
- **Actor:** Emprendedor (Nuevo Usuario)
- **Precondición:** No tiene cuenta previa.
- **Flujo:**
    1.  Usuario completa formulario y envía.
    2.  Sistema crea cuenta en estado `unverified` y envía correo con Magic Link/Token.
    3.  **Redirección Inmediata:** Usuario es llevado a pantalla `CheckEmailView`.
    4.  **Pantalla de Espera:**
        *   Muestra: "Te hemos enviado un correo a [email]".
        *   Botón: "Reenviar correo" (Habilitado tras 60s de espera - Rate Limit).
        *   Límite: Máximo 3 reenvíos por hora.
    5.  Usuario abre su inbox y hace clic en "Verificar Cuenta".
    6.  Sistema valida token, cambia estado a `verified` y redirige al Dashboard.

**Caso B: Recuperación de Acceso**
- **Actor:** Admin existente
- **Flujo:**
    1.  Olvida contraseña.
    2.  Solicita reset vía email.
    3.  Recibe token de un solo uso (Magic Link o OTP).
    4.  Define nueva contraseña.
    5.  *Seguridad:* Este evento cierra todas las sesiones activas del Admin.

#### Requisitos de Datos (Input para Equipo de Data)
Para que el Equipo de Datos diseñe el ERD, requerimos almacenar:

1.  **Entidad `stores`:**
    *   `id` (UUID): PK
    *   `name` (String): Nombre comercial
    *   `slug` (String, Unique): URL amigable (ej: tienda-pepe)
    *   `plan` (Enum): Free/Pro/Enterprise
    *   `created_at`: Timestamp

2.  **Entidad `profiles` (Dueños/Admins):**
    *   `id` (UUID): Vinculado a Auth Provider
    *   `store_id` (FK): Relación a su tienda
    *   `role` (Enum): 'owner', 'manager'
    *   `cash_pin_hash`: Para apertura/cierre de caja (Cambiado de master_pin)
    *   `is_verified` (Boolean)

#### Criterios de Aceptación
- [ ] El registro crea atómicamente la tienda y el usuario (Transacción DB).
- [ ] No se permite la creación de tiendas "huérfanas" (sin dueño).
- [ ] El password nunca se guarda en texto plano (Hashing gestionado por Auth Provider).

---

## Impacto en el Sistema
| Componente | Modificación |
|------------|--------------|
| **Supabase Auth** | Configurar templates de email para confirmación y reset password. |
| **Store (Pinia)** | Limpiar `authStore` para usar cliente real de Supabase Auth en lugar de array local. |
| **RegisterView** | Añadir manejo de errores de backend (ej: "Email ya registrado en otra tienda"). |
