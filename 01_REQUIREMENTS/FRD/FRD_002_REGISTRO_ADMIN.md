# FRD-002: Registro y Gestión de Cuentas Administrativas

### Nombre de la Funcionalidad
Alta de Nuevas Tiendas y Cuentas de Administrador

#### Descripción
Proceso mediante el cual un nuevo dueño de negocio (Admin) crea su cuenta en el sistema. Este proceso genera simultáneamente la identidad digital del usuario (Autenticación) y la entidad del negocio, estableciendo la relación de propiedad raíz.

---

## Reglas de Negocio

1. **Unicidad de Cuenta:** El correo electrónico del Admin es el identificador único global. No pueden existir dos cuentas con el mismo email, incluso para tiendas diferentes.

2. **Relación 1:1 Inicial:** Al registrarse, el Admin se vincula automáticamente como "Dueño Propietario" de la tienda creada.

3. **Validación de Identidad Obligatoria:**
    - El sistema NO permite el acceso al Dashboard hasta que el email sea verificado.
    - El flujo DEBE interrumpirse tras el registro y redirigir a una pantalla de verificación.

4. **Credenciales Maestras:**
    - El Admin maneja Email + Contraseña robusta (Mínimo 8 caracteres, alfanumérica).
    - El Admin DEBE configurar un PIN de Caja (ver FRD-004_1).
    - **Uso Exclusivo del PIN:** Este PIN se usa ÚNICAMENTE para la ceremonia de Apertura y Cierre de Caja. No tiene ninguna otra función en el sistema.

---

## Casos de Uso

**Caso A: Registro con Verificación Estricta**
- **Actor:** Emprendedor (Nuevo Usuario)
- **Precondición:** No tiene cuenta previa en el sistema.
- **Flujo Principal:**
    1. Usuario completa formulario de registro (email, contraseña, nombre de tienda).
    2. Sistema crea cuenta en estado `no verificado` y envía correo con enlace de verificación.
    3. Sistema redirige inmediatamente a pantalla de "Verifica tu correo".
    4. Pantalla muestra: "Te hemos enviado un correo a [email]".
    5. Botón "Reenviar correo" se habilita tras 60 segundos de espera.
    6. Límite de reenvíos: Máximo 3 por hora.
    7. Usuario abre su inbox y hace clic en "Verificar Cuenta".
    8. Sistema valida token, cambia estado a `verificado` y redirige al Dashboard.
- **Postcondición:** Cuenta verificada con tienda asociada.

**Caso B: Recuperación de Acceso**
- **Actor:** Admin existente
- **Precondición:** Admin tiene cuenta verificada pero olvidó contraseña.
- **Flujo Principal:**
    1. Admin solicita recuperación de contraseña vía email.
    2. Sistema envía enlace de un solo uso.
    3. Admin define nueva contraseña.
    4. Sistema cierra TODAS las sesiones activas del Admin por seguridad.
- **Postcondición:** Nueva contraseña activa, sesiones anteriores invalidadas.

---

## Requisitos de Datos (Para Equipo Data)

**Entidad Tienda:**
- Identificador único
- Nombre comercial
- Identificador amigable único (slug)
- Plan de suscripción
- Fecha de creación

**Entidad Perfil de Admin:**
- Identificador vinculado al proveedor de autenticación
- Relación con Tienda
- Rol: 'owner' o 'manager'
- Hash del PIN de caja (para operaciones de caja)
- Estado de verificación

---

## Criterios de Aceptación

- [ ] El registro crea atómicamente la tienda y el usuario en una única transacción.
- [ ] No se permite la creación de tiendas "huérfanas" (sin dueño asignado).
- [ ] La contraseña nunca se almacena en texto plano.
- [ ] El email de verificación se envía en menos de 30 segundos tras el registro.
- [ ] El botón "Reenviar correo" respeta el límite de 60 segundos y 3 intentos por hora.
- [ ] La recuperación de contraseña invalida todas las sesiones activas.
