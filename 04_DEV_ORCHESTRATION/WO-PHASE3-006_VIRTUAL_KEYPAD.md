## Orden de Trabajo - Teclado Virtual (AU-03)

### Contexto
El reporte de auditoría (AU-03) señala que el Login usa el teclado del sistema para el PIN, lo cual es incómodo en pantallas táctiles de POS.
**Objetivo**: Implementar el `PinKeypad` existente en la vista de Login cuando el usuario es un Empleado (no usa email).

### Estado Git Actual
- Rama a crear: `feat/au-03-virtual-keypad`
- Comando: `git checkout -b feat/au-03-virtual-keypad`

---

### Plan de Acción Atómico

#### Tarea 1: Integración en LoginView
**Archivo**: `src/views/LoginView.vue`
1.  Importar `PinKeypad.vue`.
2.  Modificar la sección del input de contraseña (`div class="relative"`).
    -   Usar `v-if="isAdminLogin"` para el input de texto normal (Admins usan contraseña compleja).
    -   Usar `v-else` para mostrar el `PinKeypad`.
3.  Lógica de Binding:
    -   El `PinKeypad` debe actualizar la ref `password`.
    -   Manejar el evento `@complete` para hacer auto-login (opcional, o dejar que el usuario presione "Ingresar").
    -   Configurar `PinKeypad` con `length="4"` (el estándar de empleados).
4.   Ajustes Visuales:
    -   Asegurar que el keypad no rompa el contenedor (max-width).

### Bloque de Prompt para Antigravity

```markdown
## Prompt para AU-03 (Virtual Keypad)

### Contexto
- Vista: `src/views/LoginView.vue`
- Componente: `src/components/PinKeypad.vue`

### Requerimientos
1. Detectar si es Admin (`isAdminLogin`).
2. Si es Admin: Mostrar input de contraseña estándar (comportamiento actual).
3. Si es Empleado (no es Admin):
   - Ocultar input de contraseña.
   - Mostrar `PinKeypad` configurado para 4 dígitos.
   - Vincular la entrada del Keypad a la variable `password`.
   - El botón "Ingresar" debe seguir funcionando.
```

### Comandos de Consola
```bash
git checkout -b feat/au-03-virtual-keypad
```
