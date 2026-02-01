## Orden de Trabajo - Login Progresivo (WO-PHASE4-003)

### Contexto
El usuario ha detectado una sobrecarga cognitiva en la pantalla de Login: el teclado numérico aparece prematuramente.
**Solución**: Implementar "Progressive Disclosure" (Divulgación Progresiva). Dividir el login en dos pasos claros.

### Estado Git Actual
- Rama a crear: `feat/ux-progressive-login`
- Comando: `git checkout -b feat/ux-progressive-login`

---

### Plan de Acción Atómico

#### Tarea 1: Lógica de Pasos en LoginView
**Archivo**: `src/views/LoginView.vue`

1.  **Estados**:
    *   Crear referencia `currentStep` ('identity' | 'credential').
    *   Inicializar en 'identity'.

2.  **Paso 1 (Identidad)**:
    *   Mostrar SOLO el campo "Usuario".
    *   **Enlace "Crear Tienda"**: Visible solo en este paso (debajo o cerca del botón).
    *   Botón "Continuar" (Validar que no esté vacío).
    *   Al hacer submit:
        *   Analizar el input.
        *   Si tiene '@' -> Asumir Admin -> Ir a Paso 2 (Modo Password).
        *   Si no tiene '@' -> Asumir Empleado -> Ir a Paso 2 (Modo Keypad).

3.  **Paso 2 (Credencial)**:
    *   Mostrar Avatar/Nombre (o el usuario ingresado) para contexto.
    *   **Si es Admin**:
        *   Mostrar Input Password estándar.
        *   Mostrar enlace "¿Olvidaste tu contraseña?" (Solo aquí).
    *   **Si es Empleado**: Mostrar `PinKeypad` (Autofocus).
    *   Botón "Ingresar".
    *   Botón "Atrás" (Flecha izquierda) para corregir el usuario (volver a Paso 1).

4.  **Animaciones**:
    *   Usar transiciones simples (`v-if/v-else` con `<Transition mode="out-in">`) para suavizar el cambio.

### Bloque de Prompt para Antigravity

```markdown
## Prompt para Progressive Login

### Contexto
- `src/views/LoginView.vue`

### Objetivos
1. Refactorizar `LoginView.vue` para separar la entrada de usuario de la credencial.
2. **Step 1**: Solo pedir "Usuario". Validar input no vacío.
3. **Step 2**:
   - Si usuario tiene '@', mostrar campo Password (BaseInput).
   - Si no, mostrar `PinKeypad`.
4. Agregar botón "Atrás" en Step 2 para volver a Step 1 y limpiar credenciales.
5. **Enlaces**:
   - Step 1: Mostrar enlace "Crear cuenta / Registrar Tienda".
   - Step 2 (Admin): Mostrar enlace "¿Olvidaste tu contraseña?".
   - Step 2 (Empleado): NO mostrar enlaces de recuperación.
6. Mantener la lógica de `GatekeeperPending` (no tocar).
```
