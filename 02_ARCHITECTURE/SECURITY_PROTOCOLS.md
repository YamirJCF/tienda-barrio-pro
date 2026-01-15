# 🛡️ Protocolos de Seguridad y Resiliencia (Frontend)

**Última Actualización:** Enero 2026
**Estado:** Blindado (Ready for Beta)
**Alcance:** Cliente (Browser) & LocalStorage

Este documento detalla los mecanismos de defensa implementados en el cliente para garantizar la estabilidad, integridad de datos y seguridad operativa de "Tienda de Barrio Pro" antes de la integración con el Backend real.

---

## 1. Sistema Inmunológico (Integridad de Datos)

El frontend implementa un mecanismo de **Auto-Sanitización** al inicio para prevenir "Pantallas Blancas de la Muerte" causadas por datos corruptos en el navegador.

* **Componente:** `src/composables/useDataIntegrity.ts`
* **Trigger:** Se ejecuta inmediatamente en `App.vue` antes de montar la vista.
* **Reglas de Purga:**
    * Si un JSON en `localStorage` no es válido (syntax error) -> **Se elimina**.
    * Si `tienda-cart` no tiene un array de `items` -> **Se elimina**.
    * Si `tienda-auth` no tiene estructura válida -> **Se elimina** (Logout forzado).

> **⚠️ Regla de Desarrollo:** Nunca asumir que `localStorage` tiene datos válidos. Siempre usar los Stores de Pinia que ya han pasado por este filtro.

---

## 2. Blindaje Matemático (Business Logic Shield)

Para proteger las finanzas del tendero, el núcleo de ventas rechaza operaciones numéricas inválidas que podrían corromper el historial de caja.

* **Vectores Bloqueados:** `NaN`, `Infinity`, números negativos en cantidades, inyecciones de texto en inputs numéricos.
* **Defensa en Capas:**
    1.  **Vista (`POSView`):** Los inputs convierten valores no numéricos a `1` (Safe Default).
    2.  **Store (`cart.ts`):** Rechaza silenciosamente cualquier objeto con cantidad inválida y emite `console.warn`.

---

## 3. Panel de Auditoría (Herramienta Interna)

El sistema incluye una suite de pruebas E2E integrada para autodiagnóstico.

* **Ruta:** `/#/sys-audit`
* **Acceso:** Restringido solo a entorno de desarrollo (`import.meta.env.DEV`).
* **Función:** Ejecuta 4 pruebas destructivas (simuladas) para verificar que los escudos de seguridad funcionan.

### 🚨 Protocolo de Ciclo de Vida
Este panel es una herramienta temporal ("Andamio").

1.  **Fase Beta:** Mantener oculto pero funcional para testers.
2.  **Fase Producción:** El Router lo excluye automáticamente del build final.
3.  **Fase Backend:** **ELIMINAR INMEDIATAMENTE** el archivo `src/views/SystemAuditView.vue` y su ruta al integrar Supabase/Firebase.

---

## 4. Control de Acceso (Router Guards)

La navegación está estrictamente controlada por `src/router/index.ts`.

| Estado Usuario | Intenta Acceder a... | Acción del Sistema |
| :--- | :--- | :--- |
| **Anónimo** | Rutas Privadas (Dashboard) | Redirige a `/login` |
| **Logueado** | Login / Registro | Redirige a `/` (Dashboard) |
| **Logueado (Sin Tienda)** | Cualquier Ruta | Fuerza redirección a `/register-store` |

---

## 5. Contrato Futuro con Backend (Backend Handoff)

Cuando se conecte la base de datos real, el equipo de Backend debe respetar estas reglas para mantener la compatibilidad con el frontend blindado:

1.  **Manejo de Errores:** El API debe retornar errores con códigos HTTP estándar (401, 403, 422). El frontend ya tiene interceptores visuales (`useNotifications`) listos para mostrarlos.
2.  **Persistencia:** Al migrar de `localStorage` a API, se debe actualizar `useDataIntegrity.ts` para validar la respuesta del servidor o eliminarlo si ya no es necesario.
3.  **Autenticación:** El frontend espera que el objeto `User` contenga un campo `permissions` explícito para renderizar la UI (RBAC).

---

> **Nota:** Este documento debe ser revisado cada vez que se modifique la lógica crítica de `src/stores/`.
