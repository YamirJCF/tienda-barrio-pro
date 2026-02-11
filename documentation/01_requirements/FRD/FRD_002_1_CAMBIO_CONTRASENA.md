# FRD-002.1: Cambio de Contraseña de Cuenta Administrativa

### Nombre de la Funcionalidad
Cambio de Contraseña desde Perfil del Administrador

#### Descripción
Funcionalidad que permite al Administrador (dueño de tienda) cambiar su contraseña de acceso directamente desde su panel de perfil, sin abandonar la aplicación. El flujo requiere verificación de identidad mediante contraseña actual antes de establecer una nueva, e invalida automáticamente todas las demás sesiones activas de la cuenta por seguridad.

**Extensión de:** FRD-002 (Registro y Gestión de Cuentas Administrativas)

---

## Reglas de Negocio

1. **Verificación de Identidad Obligatoria:** El sistema DEBE solicitar la contraseña actual antes de permitir el cambio. No se permite cambio directo solo por tener sesión activa.

2. **Validación de Nueva Contraseña:**
   - Mínimo 6 caracteres
   - Debe coincidir con el campo de confirmación
   - No se permite que sea idéntica a la contraseña actual (validación de Supabase)

3. **Invalidación de Sesiones (Seguridad Crítica):**
   - Al completarse el cambio, TODAS las sesiones activas en otros dispositivos/navegadores son invalidadas automáticamente.
   - La sesión actual (donde se realizó el cambio) se mantiene activa.
   - Las sesiones en **pestañas del mismo navegador** NO se invalidan (comparten `localStorage` = misma sesión JWT).

4. **Delegación al Proveedor de Identidad:** La custodia y actualización de credenciales recae exclusivamente en Supabase Auth. El backend NO almacena ni manipula contraseñas.

---

## Casos de Uso

**Caso A: Cambio Exitoso (Flujo Principal)**
- **Actor:** Administrador (Dueño de Tienda)
- **Precondición:** El usuario está autenticado y tiene sesión activa.
- **Flujo Principal:**
    1. Admin abre el perfil de usuario (sidebar).
    2. Admin pulsa "Seguridad y Contraseña".
    3. Se abre modal con campos: Contraseña Actual, Nueva Contraseña, Confirmar.
    4. Admin llena los campos y pulsa "Actualizar Contraseña".
    5. El sistema verifica la contraseña actual contra Supabase Auth (`signInWithPassword`).
    6. El sistema actualiza la contraseña (`updateUser`).
    7. El sistema invalida todas las demás sesiones (`signOut({ scope: 'others' })`).
    8. Se muestra estado de éxito: "¡Contraseña actualizada!".
- **Postcondición:** Nueva contraseña activa. Otros dispositivos forzados a re-autenticarse.

**Caso B: Contraseña Actual Incorrecta**
- **Actor:** Administrador
- **Precondición:** El usuario intenta cambiar su contraseña pero ingresa la actual incorrectamente.
- **Flujo Principal:**
    1. Admin llena los campos con contraseña actual incorrecta.
    2. El sistema verifica contra Supabase Auth → falla.
    3. Se muestra error inline: "La contraseña actual es incorrecta".
    4. No se modifica nada. No se invalidan sesiones.
- **Postcondición:** Sin cambios. El usuario puede reintentar.

**Caso C: Validación de Formulario**
- **Actor:** Administrador
- **Flujo Alternativo:**
    - Si nueva contraseña < 6 caracteres → Error inline: "Mínimo 6 caracteres"
    - Si confirmación no coincide → Error inline: "Las contraseñas no coinciden"
    - Botón "Actualizar" deshabilitado hasta que toda la validación pase.

---

## Alcance de Invalidación de Sesiones

| Escenario | ¿Se invalida? | Razón |
|-----------|:-------------:|-------|
| Otro navegador (Chrome vs Firefox) | ✅ | Sesiones JWT independientes |
| Otro dispositivo (PC vs Celular) | ✅ | Sesiones JWT independientes |
| Normal vs Incógnito | ✅ | `localStorage` separado |
| Dos pestañas del mismo navegador | ❌ | Comparten `localStorage` = misma sesión |

---

## Impacto en el Sistema

| Componente | Modificación |
|------------|--------------|
| `authRepository.ts` | Nuevo método `changePassword(email, current, new)` |
| `auth.ts` (Pinia Store) | Nuevo método `changePassword(current, new)` expuesto |
| `ChangePasswordModal.vue` (NUEVO) | Modal completo con validación y estados |
| `UserProfileSidebar.vue` | "Seguridad y Contraseña" abre modal en vez de navegar |

---

## Criterios de Aceptación

- [x] El botón "Seguridad y Contraseña" abre un modal de cambio de contraseña.
- [x] Se requiere la contraseña actual antes de permitir el cambio.
- [x] La nueva contraseña se valida inline (min. 6 chars, coincidencia).
- [x] Al completarse, se muestran estado de éxito y mensaje confirmatorio.
- [x] Todas las sesiones en otros dispositivos se invalidan tras el cambio.
- [x] La sesión actual se mantiene activa.
