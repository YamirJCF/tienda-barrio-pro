# 🦅 Protocolo de Validación: Resiliencia Offline y Sincronización

**Tipo de Prueba:** Pruebas de Integración Reales (Entorno de Producción/Dev)
**Objetivo:** Verificar que la aplicación soporte la pérdida total de conectividad, persista los datos ("cache") y se sincronice automáticamente al recuperar la señal.

> **⚠️ ADVERTENCIA CRÍTICA:**
> A diferencia del Modo Auditoría, estas pruebas **SÍ ENVÍAN DATOS** a la base de datos real (Supabase).
> *   **Recomendación:** Use un usuario de prueba o una tienda de prueba para no ensuciar datos contables reales.
> *   **Requisito:** `Audit.off()` debe estar activado (Modo Producción habilitado).

---

## 1. Conceptos Clave

*   **Persistencia ("El Cache"):** La capacidad de la App de guardar datos en su dispositivo (`IndexedDB` y `localStorage`) cuando no hay nube.
*   **Cola de Sincronización (SyncQueue):** El buzón de salida donde se acumulan las ventas esperando internet.
*   **Reconciliación:** El proceso automático de enviar esos datos cuando vuelve la señal.

---

## 2. Herramientas Necesarias

No necesita software especial, solo su navegador (Chrome/Edge):
1.  Presione `F12` para abrir las herramientas de desarrollador.
2.  Vaya a la pestaña **Network** (Red).
3.  Busque el menú desplegable que dice "No throttling" o "Sin limitaciones".
4.  Seleccione **Offline** para "cortar el cable" virtualmente.

---

## 3. Guía Paso a Paso (El "Test de Fuego")

### Escenario A: Lectura Offline (La Prueba de Memoria)
*Objetivo: Verificar que puedo ver mis datos sin internet.*

1.  **Preparación:** Inicie sesión estando conectado para bajar los datos iniciales.
2.  **Corte:** Active **Offline** en la pestaña Network.
3.  **Acción:** Recargue la página (F5) o navegue entre secciones.
4.  **Validación Esperada:**
    *   [ ] La aplicación carga correctamente.
    *   [ ] El inventario y productos son visibles.
    *   [ ] No aparecen pantallas de error ("Dinosaurio de Chrome").
    *   [ ] (Opcional) Aparece un indicador visual de "Sin Conexión".

### Escenario B: Escritura Offline (La Prueba del Buzón)
*Objetivo: Verificar que puedo vender sin internet.*

1.  **Estado:** Mantenga el navegador en **Offline**.
2.  **Acción:** Realice una venta completa en el POS.
3.  **Validación Esperada:**
    *   [ ] La venta se procesa con éxito visualmente (ticket, confirmación).
    *   [ ] El stock local se descuenta inmediatamente.
    *   [ ] La venta aparece en "Historial de Ventas" (localmente).

### Escenario C: Sincronización (La Prueba de Reconciliación)
> **⚠️ REQUISITO PREVIO:** Este paso requiere una conexión Backend (Supabase) funcional.
> Si no tiene backend configurado, **la prueba fallará aquí** (y es el comportamiento esperado).

*Objetivo: Verificar que los datos suben a la nube.*

1.  **Acción:** Desactive el modo **Offline** (vuelva a "No throttling").
2.  **Observación:** Observe la consola (`Console`) o la pestaña Network.
3.  **Validación Esperada (Con Backend Activo):**
    *   [ ] El sistema detecta la red (`Online`).
    *   [ ] La `SyncQueue` se dispara automáticamente.
    *   [ ] Verifica en Supabase (Dashboard) que la venta creada en el paso B ya existe en la nube.

**Validación Esperada (Sin Backend - Estado Actual):**
    *   [x] El sistema detecta la red (`Online`).
    *   [x] La `SyncQueue` intenta enviar los datos.
    *   [x] **Error Controlado:** La consola muestra error de conexión (404/Network Error) pero la App **NO SE ROMPE**.
    *   [x] Los datos permanecen en la cola o pasan a DLQ (Dead Letter Queue).

---

## 4. Solución de Problemas Comunes

| Síntoma | Diagnóstico | Solución |
| :--- | :--- | :--- |
| **Al recargar offline, sale el dinosaurio.** | El Service Worker o el Cache no están configurados correctamente para los "assets" (HTML/JS). | Revisar configuración de Vite PWA. |
| **La venta offline da error.** | La validación de stock local falló o hay un error en `saleRepository`. | Revisar logs de consola. |
| **Al volver online, no sube la venta.** | El "Event Listener" de `online` no se disparó o la cola se atascó. | Recargar la página (esto fuerza un reintento de sincronización). |

---

**Firma Digital de Validación:**
*AntiGravity Agent - Lead QA*
