# ⚙️ DEV ORCHESTRATION - Phase 1: Shift Continuity & 24h Forced Close (FRD-017)

## Estrategia Git

| Elemento | Descripción |
|----------|-------------|
| **Rama** | `feat/forced-close-24h` |
| **Inicio** | `git checkout -b feat/forced-close-24h` |
| **Commits** | `feat: add 24h forced close RPC and audit logs`, `refactor: remove midnight calendar expiration in auth`, `feat: add 24h stale detection to cash register store`, `feat: add forced close audit modal in cash control` |
| **Merge** | Revisión de QA (testing de 24h) y luego `git merge feat/forced-close-24h` hacia `main`. |

---

## Orden de Trabajo 1 - Backend Database RPC for 24h Forced Closure

### Estado Git Actual
- Rama a crear: `feat/forced-close-24h`
- Comando: `git checkout -b feat/forced-close-24h`

### Plan de Acción Atómico
1. Generar migración vacía usando la CLI de Supabase.
2. Escribir el script SQL para crear la función `rpc_check_and_force_close_shifts`.
3. Aplicar la migración a la base de datos de desarrollo mediante Supabase CLI o el MCP.

### Bloque de Prompt para Antigravity

```markdown
## Prompt para Antigravity

### Contexto
Estás implementando la Fase 1 del FRD-017 (Cierre forzado a las 24 horas).
Debes crear una nueva migración en `supabase/migrations/`.

### Objetivo
1. Ejecuta `npm run supabase migration new forced_close_24h` en la raíz del proyecto.
2. Copia el siguiente código SQL en el archivo generado:
```sql
-- Migration: 24h Forced Closure Mechanism & Audit Logging
-- Date: 2026-07-25
-- FRD-017 v3.0 Compliance

CREATE OR REPLACE FUNCTION rpc_check_and_force_close_shifts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    r RECORD;
    v_ingresos DECIMAL;
    v_gastos DECIMAL;
    v_expected DECIMAL;
    closed_count INT := 0;
BEGIN
    FOR r IN 
        SELECT id, store_id, opening_balance, opened_at 
        FROM public.cash_sessions 
        WHERE status = 'open' 
          AND opened_at < (NOW() - INTERVAL '24 hours')
    LOOP
        -- Calcular ingresos de la sesión
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'ingreso';
        
        -- Calcular gastos de la sesión
        SELECT COALESCE(SUM(amount), 0) INTO v_gastos
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'gasto';
        
        v_expected := r.opening_balance + v_ingresos - v_gastos;

        -- 1. Cerrar la sesión de caja
        UPDATE public.cash_sessions 
        SET status = 'closed',
            expected_balance = v_expected,
            actual_balance = NULL, 
            difference = NULL,
            closed_at = NOW()
        WHERE id = r.id;

        -- 2. Insertar registro de auditoría
        INSERT INTO public.audit_logs (store_id, action, entity, entity_id, payload, created_at) 
        VALUES (r.store_id, 'FORCED_CLOSE_24H', 'cash_sessions', r.id, 
            jsonb_build_object('reason', 'Shift exceeded 24 hours without manual closure', 'opened_at', r.opened_at, 'forced_at', NOW(), 'expected_balance', v_expected), NOW());

        -- 3. Insertar notificación para el administrador
        INSERT INTO public.notifications (store_id, type, title, message, audience, is_read, created_at) 
        VALUES (r.store_id, 'finance', '⚠️ Cierre Forzado de Caja (24 Horas)', 'Una caja fue cerrada automáticamente por el sistema tras cumplir 24 horas abierta. Se requiere verificación de saldo antes de iniciar nuevo turno.', 'admin', FALSE, NOW());

        closed_count := closed_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'closed_shifts', closed_count);
END;
$$;

GRANT EXECUTE ON FUNCTION rpc_check_and_force_close_shifts() TO authenticated;
```
3. Aplica la migración a la base de datos.

### Restricciones
- No uses `GRANT EXECUTE TO anon`.
- Usa el MCP de Supabase o la CLI para confirmar que la migración se aplica correctamente.

### Definición de Hecho (DoD)
- El archivo de migración existe.
- La función RPC existe en la base de datos de desarrollo y compila sin errores de sintaxis.
```

---

## Orden de Trabajo 2 - Auth Store Refactor (Remove Midnight Calendar Logout)

### Plan de Acción Atómico
1. Modificar `frontend/src/stores/auth.ts` para eliminar la validación de `lastDate !== today`.

### Bloque de Prompt para Antigravity

```markdown
## Prompt para Antigravity

### Contexto
Archivo objetivo: `frontend/src/stores/auth.ts`

### Objetivo
Eliminar la expiración astronómica (corte de medianoche). 
Busca la propiedad computada `deviceApproved` (o similar que use `dailyAccessState`) y elimina cualquier validación que revoque el acceso si `lastDate !== today`.

### Restricciones
- No elimines la validación del PIN ni otros controles de seguridad.
- La sesión operativa debe permanecer activa incluso si la fecha del calendario cambia (cruce de medianoche).

### Definición de Hecho (DoD)
- El store de auth ya no revoca la sesión activa simplemente por cambiar de día en el calendario.
```

---

## Orden de Trabajo 3 - Cash Register Store 24h Stale Detection

### Plan de Acción Atómico
1. Actualizar `frontend/src/stores/cashRegister.ts`.
2. Refactorizar `isStaleSession` para que devuelva `true` si han pasado 24 horas exactas (86,400,000 ms) desde `openingTime`.
3. Agregar la llamada RPC perezosa en `syncFromBackend`.

### Bloque de Prompt para Antigravity

```markdown
## Prompt para Antigravity

### Contexto
Archivo objetivo: `frontend/src/stores/cashRegister.ts`

### Objetivo
1. Reescribir `isStaleSession`: 
   Debe calcular la diferencia entre `Date.now()` y el `openingTime` de la sesión actual (`currentSession.value`). Si la diferencia >= 24 * 60 * 60 * 1000, retornar `true`.
2. En la función `syncFromBackend`, llamar a `rpc_check_and_force_close_shifts` si la caja se ha detectado como estancada (`isStaleSession`), y luego forzar una re-sincronización del estado desde la DB.

### Restricciones
- Maneja correctamente el estado si `currentSession` es nulo o no está `open`.
- La llamada RPC debe manejarse de forma asíncrona pero sin bloquear innecesariamente la UI principal (fire and forget, pero asegurando que el estado cambie a closed).

### Definición de Hecho (DoD)
- `isStaleSession` es matemáticamente estricto con las 24 horas.
- Si el frontend detecta una sesión vieja, dispara automáticamente el cierre forzado en backend.
```

---

## Orden de Trabajo 4 - Forced Closure Audit Warning UI

### Plan de Acción Atómico
1. Crear `frontend/src/components/ForcedCloseAuditModal.vue`.
2. Integrarlo en `frontend/src/views/CashControlView.vue`.

### Bloque de Prompt para Antigravity

```markdown
## Prompt para Antigravity

### Contexto
Archivos: 
- `frontend/src/components/ForcedCloseAuditModal.vue` (NUEVO)
- `frontend/src/views/CashControlView.vue` (MODIFICAR)

### Objetivo
1. Crear el modal `ForcedCloseAuditModal.vue` que advierta al usuario que la caja anterior fue cerrada por el límite de 24 horas. El modal debe mostrar el monto inicial y pedir que se consigne el monto físico actual para conciliar la diferencia. Este modal solo debería cerrar el proceso y redirigir al cierre formal. (Recomendación: aprovechar el RPC existente `cerrar_caja` para actualizar el `actual_balance`).
2. En `CashControlView.vue`, detectar si la sesión más reciente en historial fue cerrada forzosamente (ej. revisando si `actual_balance` es null y `status` es closed). Si es así, mostrar el `ForcedCloseAuditModal` antes de permitir abrir una caja nueva.

### Restricciones
- El diseño debe usar los estilos del sistema (BaseButton, Tailwind).
- No permitir abrir caja nueva si hay una auditoría pendiente.

### Definición de Hecho (DoD)
- El cajero es forzado a ingresar el conteo final real si su caja anterior fue cerrada automáticamente por el límite de 24 horas, bloqueando la apertura de nuevas cajas hasta que esto ocurra.
```

---
### Comandos de Consola (Fin de Rama)
```bash
git add .
git commit -m "feat: complete shift continuity and 24h forced close"
# Ready for push/merge
```
