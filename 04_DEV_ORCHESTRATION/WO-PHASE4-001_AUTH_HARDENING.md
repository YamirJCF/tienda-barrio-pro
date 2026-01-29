## Orden de Trabajo - Fortalecimiento de Autenticación (AU-05, AU-07)

### Contexto
Para cerrar los hallazgos de auditoría `AU-05` (Sala de Espera) y `AU-07` (Política de Contraseñas), necesitamos robustecer la vista de Login y el Registro.

### Estado Git Actual
- Rama a crear: `fix/ux-auth-hardening`
- Comando: `git checkout -b fix/ux-auth-hardening`

---

### Plan de Acción Atómico

#### Tarea 1: Sala de Espera (AU-05)
**Archivo**: `src/views/LoginView.vue`
1.  Modificar `handleLogin` para capturar el error específico `GATEKEEPER_PENDING`.
2.  Crear un estado reactivo `showWaitingRoom` (bool).
3.  Implementar una tarjeta visual "Sala de Espera" que reemplace el formulario cuando `showWaitingRoom` es true.
    *   Texto: "Tu dispositivo está pendiente de aprobación."
    *   Botón: "Reenviar solicitud" (Con debounce de 30s).
    *   Botón secundario: "Regresar al Login".

#### Tarea 2: Política de Contraseñas (AU-07)
**Archivo**: `src/views/RegisterView.vue` (y `src/utils/validators.ts` si existe)
1.  Actualizar la validación de contraseña.
2.  **Regla**: Min 8 caracteres + 1 Número + 1 Letra.
3.  Mostrar feedback visual en tiempo real (Lista de requisitos que se marcan en verde).

### Bloque de Prompt para Antigravity

```markdown
## Prompt para AU-05 y AU-07

### Contexto
- `src/views/LoginView.vue`
- `src/views/RegisterView.vue`

### Objetivos
1. **LoginView (Sala de Espera)**:
   - Si `authStore.login` lanza error con código `GATEKEEPER_PENDING` (o similar string), cambiar la vista a "Sala de Espera".
   - Mostrar icono de reloj/alerta amarila.
   - Mensaje amigable: "El administrador debe aprobar este dispositivo para [Alias]."
   - Botón "Reintentar" que vuelva a disparar validación.

2. **RegisterView (Strong Password)**:
   - En el campo `password`, agregar validación: `^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$` (Min 8 chars, 1 letra, 1 numero).
   - Mostrar mensaje de error claro si no cumple: "Mínimo 8 caracteres, al menos una letra y un número".
```
