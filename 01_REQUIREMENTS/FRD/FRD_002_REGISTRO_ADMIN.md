# FRD-002: Registro y Gestión de Cuentas Administrativas

### Nombre de la Funcionalidad
Alta de Nuevas Tiendas y Cuentas de Administrador

#### Descripción
Proceso mediante el cual un nuevo dueño de negocio (Admin) crea su cuenta en el sistema utilizando el proveedor de identidad nativo de la plataforma. Este proceso crea simultáneamente la identidad digital del usuario y la entidad de negocio inicial, asegurando la propiedad mediante verificación estricta de correo electrónico.

---

## Reglas de Negocio

1.  **Identidad Única:** El correo electrónico es el identificador único del usuario en el sistema de gestión de identidades.

2.  **Política de Acceso Cero Antes de Verificar:**
    *   El usuario **NO PUEDE** acceder a las funcionalidades del sistema (Dashboard) hasta que haya confirmado su dirección de correo electrónico.
    *   El sistema de identidades gestiona el ciclo de vida de confirmación.
    *   La base de datos **DEBE** bloquear cualquier intento de escritura de usuarios no confirmados.

3.  **Vinculación de Tienda:**
    *   Al registrarse, el usuario crea su primera tienda automáticamente.
    *   El sistema **DEBE** asignar al usuario registrado el rol de "Dueño Propietario" de dicha tienda.

4.  **Gestión de Credenciales:**
    *   Las contraseñas **NO PUEDEN** ser accesibles ni almacenadas en texto plano por la lógica de negocio.
    *   La responsabilidad de la custodia y validación de credenciales recae exclusivamente en el proveedor de identidad.

---

## Casos de Uso

**Caso A: Registro Exitoso (Flujo Principal)**
- **Actor:** Emprendedor (Nuevo Usuario)
- **Precondición:** El usuario no tiene cuenta registrada.
- **Flujo Principal:**
    1.  Usuario ingresa Email, Contraseña y Nombre de Tienda en el formulario de registro.
    2.  Usuario solicita la creación de la cuenta.
    3.  El sistema de identidad registra al usuario y le envía automáticamente un correo de confirmación.
    4.  El sistema presenta una pantalla informativa de "Verificación Pendiente".
    5.  Usuario abre su correo electrónico y confirma su identidad mediante el enlace provisto.
    6.  El sistema redirige al usuario a la aplicación.
    7.  El sistema valida la confirmación y otorga acceso a la sesión.
    8.  Usuario accede al Dashboard principal.
- **Postcondición:** Usuario autenticado, verificado y vinculado a su nueva tienda.

**Caso B: Reenvío de Instrucciones de Verificación**
- **Actor:** Usuario con registro pendiente
- **Precondición:** Usuario se registró pero no completó la verificación.
- **Flujo Principal:**
    1.  Usuario solicita "Reenviar correo" desde la pantalla de espera.
    2.  El sistema instruye al proveedor de identidad para reenviar la notificación.
    3.  El sistema confirma visualmente que la instrucción fue enviada.
- **Postcondición:** Nuevo correo de verificación enviado.

---

## Requisitos de Datos (Funcionales)

**Entidad Usuario (Identidad):**
- Identificador único (UUID)
- Correo electrónico
- Estado de verificación (Confirmado / Pendiente)

**Entidad Tienda:**
- Identificador único
- Nombre comercial
- Propietario (Vinculado al Usuario)

---

## Criterios de Aceptación

- [ ] El sistema impide el acceso (Login) a usuarios que no han completado el flujo de verificación.
- [ ] El registro de un usuario desencadena ineludiblemente el envío del correo de verificación.
- [ ] La pantalla de verificación bloquea la navegación hacia áreas protegidas hasta que la sesión sea válida.
- [ ] El enlace de verificación redirige correctamente a la aplicación, restaurando el contexto de sesión.
