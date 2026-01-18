# ⚙️ Orden de Trabajo #005 - Seguridad y Acceso POS

**Referencia:** `implementation_plan.md` | `06_SECURITY_ACCESS_UX.md`
**Rama:** `feat/security-access`

## 1. Contexto y Objetivos
Implementar reglas de negocio estrictas para controlar el acceso al POS y asegurar la configuración de PIN. La prioridad es la **robustez** (evitar bypass) y la **resiliencia** (fallar de forma segura sin romper la UI).

## 2. Instrucciones de Ejecución (Antigravity)

### Tarea A: Reforzar `CashControlView.vue` (Redirect PIN)
**Objetivo:** Si el usuario intenta abrir caja sin PIN, redirigirlo al setup inmediatamente en lugar de solo mostrar un error estático.
1.  **Modificar `src/views/CashControlView.vue`:**
    -   En el método `goToPinStep`, si `!hasPinConfigured`:
        -   En lugar de retornar, activar `showPinSetupModal = true` (asegúrate de importar y colocar el componente `PinSetupModal` si no está presente o usar el existente).
        -   **UX Critical:** Si el modal emite `@close` sin éxito, redirigir a `/admin` (Cancelación = Salida).
    -   Asegurar que `PinSetupModal` se renderice correctamente en la plantilla.

### Tarea B: Blindar `POSView.vue` (Access Guards)
**Objetivo:** Impedir el uso del POS si la caja está cerrada o no hay inventario.
1.  **Modificar `src/views/POSView.vue`:**
    -   **Guard `onMounted`:** Verificar condiciones críticas al montar.
    -   **Integrar `NoPermissionOverlay`:**
        -   **Caso 1 (Caja Cerrada):** Si `storeStatusStore.isClosed` (o `!salesStore.isStoreOpen`), mostrar overlay.
            -   *Acción:* Botón "Abrir Turno" -> `/cash-control`.
        -   **Caso 2 (Sin Inventario):** Si `inventoryStore.totalProducts === 0`, mostrar overlay.
            -   *Acción:* Botón "Crear Producto" -> `/inventory` (o modal).
    -   **Data Sync:** Asegurar que `salesStore` y `cashControlStore` actualicen sus banderas de estado consistentemente.

### Tarea C: Verificación de Regresión (QA)
**Objetivo:** Confirmar que no rompimos nada.
1.  **Test 1:** Entrar a `/pos` directo por URL con caja cerrada -> Debe bloquear. (Bypass prevention).
2.  **Test 2:** Entrar a `/cash-control` sin PIN -> Debe abrir modal. Cancelar modal -> Debe ir a `/admin` (Loop prevention).
3.  **Test 3:** Configurar PIN -> Abrir Caja -> POS Desbloqueado (Fluxo normal).

## 3. Comandos de Git
```bash
git checkout -b feat/security-access
# ... realizar cambios ...
git add .
git commit -m "feat: enforce pin setup and pos access guards"
```

## 4. Definición de Hecho (DoD)
- [ ] No es posible acceder a la interfaz funcional del POS si la caja está cerrada.
- [ ] No es posible acceder con inventario 0.
- [ ] Intentar abrir caja sin PIN fuerza el flujo de creación.
- [ ] Los stores mantienen coherencia en el estado `isStoreOpen`.
