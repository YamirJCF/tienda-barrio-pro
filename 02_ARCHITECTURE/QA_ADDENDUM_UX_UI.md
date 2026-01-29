# Addendum QA: Estándares de Seguridad y Resiliencia para UX/UI

> **De:** Equipo QA y Auditoría (@[/qa])
> **Para:** Equipo UX/UI (@[/ux])
> **Referencia:** `WORK_REQUEST_UX_UI.md`
> **Fecha:** 2026-01-28

---

## 1. Objetivo

Este documento complementa la solicitud de trabajo de UX/UI estableciendo las **reglas no negociables** de seguridad, protección de datos y manejo de fallos que la interfaz debe cumplir. El objetivo no es solo que la App "se vea bien", sino que sea **segura y robusta**.

---

## 2. Políticas de Seguridad Frontend (Client-Side)

El equipo UX/UI debe auditar y corregir cualquier violación a estas políticas:

### 2.1 Manejo de Datos Sensibles
*   **Prohibido:** Mostrar PINs de empleados en texto plano en cualquier input o log.
*   **Prohibido:** Almacenar datos financieros (total de ventas del día, arqueos) en `localStorage` persistente sin encriptación.
*   **Requerido:** El campo de PIN debe ser siempre `type="password"` o similar, con máscara visual `****`.
*   **Requerido:** Limpiar estados sensibles (token de sesión, usuario activo) inmediatamente al cerrar sesión.

### 2.2 Validación de Entradas (Input Sanity)
Aunque el Backend es la autoridad final, el Frontend es la primera línea de defensa:
*   **Tipos de Datos:** Los inputs numéricos (precios, stock) deben impedir la escritura de caracteres no numéricos.
*   **Límites:** Respetar visualmente los límites de caracteres definidos en el diccionario de datos (ej: nombres de 50 chars).
*   **Inyección:** Asegurar que ningún contenido de usuario se renderice usando `v-html` a menos que sea estrictamente necesario y esté sanitizado.

### 2.3 Prevención de Abuse (Debounce/Throttle)
*   **Botones de Acción Crítica:** (Pagar, Guardar, Borrar) DEBEN deshabilitarse inmediatamente tras el primer clic (`isSubmitting = true`) para evitar dobles envíos o condiciones de carrera.

---

## 3. Recomendaciones de Resiliencia (Fail-Safe)

El sistema debe fallar con elegancia, nunca con una "pantalla blanca de la muerte".

### 3.1 Manejo de Errores Visuales
*   **Toast vs Modal:**
    *   Errores transitorios (ej: "No hay conexión") -> **Toast** (Notification).
    *   Errores bloqueantes (ej: "Sesión expirada") -> **Modal/Redirección**.
*   **Mensajes Amigables:** Nunca mostrar al usuario el error crudo de SQL o Supabase (ej: `23505: unique_violation`). Traducir a "Este registro ya existe".

### 3.2 Estados de Carga (Skeletons)
*   Mientras se esperan datos del Backend, la UI NO DEBE mostrar estados vacíos ("No hay productos") falsos. Debe mostrar indicadores de carga (`SkeletonLoader`).

### 3.3 Modo Offline
*   Si la App detecta desconexión (`navigator.onLine === false`), debe mostrar un indicador visual claro (borde rojo, icono desconectado).
*   Deshabilitar acciones que requieran estrictamente servidor (ej: Login inicial, Sincronización) o encolarlas explícitamente.

---

## 4. Criterios de Aceptación QA

El equipo QA rechazará cualquier entrega de UX/UI que presente:

1.  **Fuga de Información:** Datos sensibles visibles en la URL o consola del navegador.
2.  **Inconsistencia de Estado:** Botones habilitados cuando la acción no es posible (ej: Pagar con carrito vacío).
3.  **Bloqueo Indefinido:** Spinners que giran por siempre sin timeout o mensaje de error.
4.  **Bypass de Frontend:** Posibilidad de saltar una validación de negocio simple editando el HTML (ej: habilitar un botón "disabled" y que la acción se dispare sin re-validar datos obligatorios).

---

## 5. Proceso de Revisión Final

Una vez que UX/UI complete su auditoría y correcciones:
1.  **QA ejecutará pruebas de penetración ligera** sobre los formularios refactorizados.
2.  **QA simulará fallos de red** durante transacciones críticas.
3.  **QA validará la sanitización** de inputs.

**Nota:** La aprobación de QA es requisito para el cierre de la Fase 4.

---

## Firma

**Ingeniero de QA y Seguridad**
2026-01-28
