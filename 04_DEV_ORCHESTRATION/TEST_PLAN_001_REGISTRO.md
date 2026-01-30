# TEST-001: Creación de Tienda Nativa (E2E)

> **Objetivo:** Verificar que el registro desde la UI crea correctamente los registros en `auth.users` y `public.stores` (vía Trigger).
> **Rol:** QA Automation

## Datos de Prueba
- **Timestamp:** `[DYNAMIC]`
- **Email:** `qa.test.[TIMESTAMP]@example.com`
- **Password:** `Test1234!` (Cumple política: 8 chars, 1 num, 1 letra)
- **Nombre Tienda:** `Tienda QA [TIMESTAMP]`
- **Nombre Dueño:** `QA Bot`

## Pasos de Ejecución

1.  **Navegación UI:** Ir a `/register-store`.
2.  **Interacción:** Llenar formulario y enviar.
3.  **Validación Frontend:**
    *   Verificar redirección a `/auth/waiting-verification`.
    *   Verificar que `authStore` no tenga sesión activa (o parcial).
4.  **Validación Backend (SQL):**
    *   Buscar usuario en `auth.users`.
    *   Buscar tienda en `public.stores` (Verificar `slug` generado y `owner_id`).
    *   Verificar integridad referencial.

## Criterios de Éxito
- [ ] Usuario creado en `auth.users`.
- [ ] Tienda creada en `public.stores` con nombre saneado.
- [ ] UI redirige correctamente.
- [ ] No hay errores de consola críticos.
