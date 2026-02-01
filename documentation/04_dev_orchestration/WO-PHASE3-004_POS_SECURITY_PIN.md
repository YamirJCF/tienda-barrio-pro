si.## Orden de Trabajo - Seguridad POS: PIN de Caja (PO-02)

### Contexto
El reporte de auditoría indica que la apertura de caja "Solo pide monto". Actualmente, si no hay PIN configurado, el sistema bloquea la acción con un mensaje "Debes configurar PIN", lo cual puede interpretarse como una falla de flujo o simplemente una mala UX.
**Objetivo**: Asegurar que la apertura/cierre de caja SIEMPRE requiera un PIN. Si no existe, obligar a crearlo en el momento.

### Estado Git Actual
- Rama a crear: `feat/po-02-pos-security`
- Comando: `git checkout -b feat/po-02-pos-security`

---

### Plan de Acción Atómico

#### Tarea 1: Mejora de Flujo en Vista (UX)
**Archivo**: `src/views/CashControlView.vue`
1.  Importar `PinSetupModal` (actualmente solo se usa `PinChallengeModal`).
2.  Modificar `handleSubmit()`:
    -   **Actual**: Si `!hasPinConfigured`, muestra error Toast y retorna.
    -   **Nuevo**: Si `!hasPinConfigured`, abrir `PinSetupModal` con modo 'setup'.
        -   Al completar setup -> Proceder automáticamente al challenge o a la acción directa.
    -   Si `hasPinConfigured` -> Abrir `PinChallengeModal` (comportamiento actual).
    
#### Tarea 2: Validación de Integridad (Store)
**Archivo**: `src/stores/cashControl.ts`
1.  Revisar que `checkPinConfigured` se llame al montar la vista para asegurar reactividad (ya existe `init`, pero un doble chequeo no hace daño).

### Bloque de Prompt para Antigravity

```markdown
## Prompt para PO-02 (flujo PIN mejorado)

### Contexto
- Vista: `src/views/CashControlView.vue`
- Componentes: `PinChallengeModal`, `PinSetupModal`

### Requerimientos
1. Agregar `PinSetupModal` a la vista.
2. Interceptar el intento de apertura/cierre:
   - Si no hay PIN: Mostrar "Configurar PIN de Seguridad" (Setup Modal).
   - Al terminar Setup: Continuar flujo.
   - Si hay PIN: Mostrar "Autorizar Apertura" (Challenge Modal).
```

### Comandos de Consola
```bash
git checkout -b feat/po-02-pos-security
```
