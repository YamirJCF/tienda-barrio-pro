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

## 6. PROTOCOLO IAM-01: Aprobación de Dispositivos (Device Fingerprinting)

> [!IMPORTANT]
> Este protocolo se activa cuando el backend Supabase está integrado.

### 6.1 Registro de Dispositivo

Cada vez que un empleado intenta loguearse desde un dispositivo no reconocido, el sistema:

1. Captura `user_agent` y un identificador único (fingerprint).
2. Inserta una solicitud en `access_requests` con estado `pending`.
3. Notifica al Administrador vía sistema de notificaciones.

**Tabla involucrada:** `access_requests`

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | UUID | Identificador único |
| `employee_id` | UUID | Referencia al empleado |
| `device_fingerprint` | TEXT | Hash único del dispositivo |
| `user_agent` | TEXT | Información del navegador |
| `status` | TEXT | `pending`, `approved`, `rejected` |
| `reviewed_by` | UUID | Admin que revisó la solicitud |
| `created_at` | TIMESTAMPTZ | Fecha de solicitud |
| `reviewed_at` | TIMESTAMPTZ | Fecha de revisión |

### 6.2 Validación de Acceso

El RPC `login_empleado_unificado` denegará el token JWT si el estado del dispositivo no es `approved`.

**Códigos de error:**

| Código | Mensaje UI |
|--------|------------|
| `GATEKEEPER_PENDING` | "Dispositivo en espera de aprobación del Administrador" |
| `GATEKEEPER_REJECTED` | "Acceso denegado desde este dispositivo" |

---

## 7. PROTOCOLO OP-01: Gatekeeper de Operación

### 7.1 Regla de Oro

La creación de registros en `sales` e `inventory_movements` (tipo `venta`) **solo es posible** si existe un registro activo en `cash_cuts` (o `cash_register`) sin `closing_time`.

```sql
-- Verificación de tienda abierta
SELECT EXISTS (
  SELECT 1 FROM cash_register 
  WHERE store_id = ? 
    AND date = CURRENT_DATE 
    AND type = 'opening'
    AND NOT EXISTS (
      SELECT 1 FROM cash_register 
      WHERE store_id = ? 
        AND date = CURRENT_DATE 
        AND type = 'closing'
    )
);
```

### 7.2 Excepción Administrativa

Los **Administradores** pueden realizar ajustes de inventario incluso con la tienda cerrada por motivos de auditoría.

| Operación | Empleado (Tienda Cerrada) | Admin (Tienda Cerrada) |
|-----------|---------------------------|------------------------|
| Ver inventario | ✅ Permitido | ✅ Permitido |
| Ajuste de stock | ❌ Bloqueado | ✅ Permitido |
| Crear venta | ❌ Bloqueado | ❌ Bloqueado |

### 7.3 Comportamiento UI

Cuando `is_store_open == false`:

- **Dashboard:** Acceso completo, banner informativo "Inicie jornada para vender"
- **POS:** Redirige a Dashboard con notificación
- **Inventario (Vista):** Acceso completo
- **Inventario (Edición):** Solo Admin

---

> **Nota:** Este documento debe ser revisado cada vez que se modifique la lógica crítica de `src/stores/`.
