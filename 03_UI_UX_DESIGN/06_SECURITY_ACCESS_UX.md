# 🔐 Diseño UX/UI - Seguridad y Control de Acceso

## 1. Flujo de Configuración de PIN Forzado

**Objetivo:** Garantizar que ninguna caja se abra sin un PIN de seguridad configurado, sin fricción excesiva para el usuario.

### Mapa de Navegación
1.  **Usuario intenta "Abrir Caja"** (`/cash-control`).
2.  **Sistema detecta ausencia de PIN.**
3.  **Modal `PinSetupModal` aparece automáticamente** (sobre la vista de apertura).
    - *Estado:* Setup (Creación).
4.  **Interacción del Usuario:**
    - *Opción A (Éxito):* Configura PIN -> Confirma PIN -> Modal cierra -> Usuario permanece en "Abrir Caja" con el campo de PIN ahora habilitado.
    - *Opción B (Cancelación):* Cierra modal -> Sistema redirige automáticamente al **Dashboard** (`/admin`). *Razón: No tiene sentido estar en una pantalla que no puedes usar.*

### Lógica de Componentes
-   **Modal de PIN (`PinSetupModal`)**:
    -   Debe bloquear la interacción con el fondo (backdrop estático).
    -   Al completar (evento `@success`), debe disparar un "toast" de éxito: "PIN Configurado correctamente".
    -   Al cancelar/cerrar (evento `@close` sin éxito), ejecutar `router.push('/admin')`.

---

## 2. Reglas de Bloqueo del POS (Access Guard)

**Objetivo:** Prevenir estados inconsistentes (ventas sin caja abierta) y experiencias vacías (ventas sin productos).

### Detalle de Pantalla: POS Bloqueado (Overlay)
Este estado reemplaza o cubre la interfaz del POS cuando no se cumplen las condiciones.

**Variante A: Caja Cerrada**
-   **Icono:** Storefront cerrado o Candado (`storefront` / `lock`).
-   **Título:** "Tu tienda está cerrada".
-   **Mensaje:** "Para realizar ventas, primero debes iniciar el turno y abrir la caja."
-   **Botón Primario:** `Abrir Caja ahora` -> Redirige a `/cash-control`.
-   **Botón Secundario:** `Ir al Dashboard` -> Redirige a `/`.

**Variante B: Sin Inventario**
-   **Icono:** Caja vacía (`inventory_2`).
-   **Título:** "No tienes productos para vender".
-   **Mensaje:** "Tu inventario está vacío. Agrega tus primeros productos para comenzar."
-   **Botón Primario:** `Crear Producto` -> Redirige a `/inventory` (idealmente abriendo el modal de crear).
-   **Botón Secundario:** `Ir al Dashboard`.

### Instrucción para el Orquestador
1.  **Modificar `CashControlView.vue`**:
    -   Implementar la lógica de "Cancelación = Salida". Si el usuario cierra el modal de setup sin terminar, sacarlo de la vista.
2.  **Actualizar `POSView.vue`**:
    -   Utilizar el componente existente `NoPermissionOverlay.vue` (o extenderlo) para manejar estos dos nuevos estados.
    -   Asegurar que la validación ocurra al **Montar** (`onMounted`) y sea reactiva (si abro la caja en otra pestaña, esta debería desbloquearse, aunque esto es un "nice to have").

---

## 3. Prevención de Errores (Checklist)
-   [ ] **Loop Infinito:** Evitar que si el usuario entra a POS y es redirigido a Caja, y luego cancela, vuelva a POS. El punto de retorno seguro siempre es el `/admin` o `/`.
-   [ ] **Feedback Visual:** El input de PIN en `CashControl` debe mostrar claramente cuando está bloqueado por falta de configuración (ej. borde rojo o mensaje helper).
