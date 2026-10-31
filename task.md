# Tareas de Verificación en Vivo — Credenciales de Prueba (ycfamir@gmail.com)

## Cosas por Observar (Checklist de Verificación con Evidencia Real)

- [x] **1. Autenticación en Supabase Auth:**
  - Login con `ycfamir@gmail.com` / `ycfamir.123`.
  - **Evidencia Real:** `user.id: 3bdfa298-a756-4f84-9aea-17f5aafbe017`, `expires_in: 3600`, JWT generado exitosamente.

- [x] **2. Identidad y Asociación de Tienda en BD:**
  - Identificar si el usuario es `admin` (`admin_profiles`) o empleado (`employees`).
  - **Evidencia Real:** Usuario identificado como `role: 'owner'` (`admin_profiles`) y perfil activo en `employees` (`name: 'YAMIR'`). Tienda asociada: `"maria"` (`store_id: b63adadd-8679-4abc-af6c-d72ac3aa49e1`).

- [x] **3. Autoridad de Sesión en Servidor (SDD-013 v3.1.0):**
  - Ejecutar `rpc_verificar_estado_sesion()` con el JWT del usuario autenticado.
  - **Evidencia Real:** Respuesta del RPC: `{"success": true, "status": "active", "role": "owner", "store_id": "b63adadd-8679-4abc-af6c-d72ac3aa49e1", "store_name": "maria"}`.

- [x] **4. Seguridad Centralizada (Regla 4):**
  - Invocar `get_current_store_id()` autenticado.
  - **Evidencia Real:** Retornó `b63adadd-8679-4abc-af6c-d72ac3aa49e1` de forma consistente.
  - Invocar `assert_store_access(store_id)`: Acceso concedido sin excepciones.

- [x] **5. Comprobación de RPCs Críticas (Las que antes arrojaban HTTP 400):**
  - `get_daily_summary(p_store_id)`: ✅ Respondió 200 con payload `['alerts', 'reminder', 'hero_number', 'traffic_light', 'money_breakdown']`.
  - `get_stagnant_products(p_store_id)`: ✅ Respondió 200 con 22 productos estancados calculados.
  - `get_history_ventas(p_store_id, p_start_date, p_end_date)`: ✅ Respondió 200 con array de ventas.
  - `rpc_get_comprehensive_financial_report(p_store_id, p_start_date, p_end_date)`: ✅ Respondió 200 con balance financiero completo (`cogs`, `revenue`, `net_profit`, `fiado_pendiente`, `operational_expenses`).
  - **Evidencia Real:** Cero errores HTTP 400; llamadas resueltas limpiamente.

- [x] **6. Comportamiento Defensivo ante Pérdida de Token:**
  - Invocar `rpc_verificar_estado_sesion()` anónimo / sin token.
  - **Evidencia Real:** Cliente sin token recibe `{ success: false, status: 'requires_login', reason: 'NO_AUTH_TOKEN' }` en HTTP 200 sin excepción Postgres, permitiendo a la UI redirigir al login en vez de arrojar error 400.

- [x] **7. Integración Frontend (authRepository & Store):**
  - Verificada la interoperabilidad de `useSessionGuard`, `authStore.verifySessionWithServer` y `authRepository.loginStore` (137 tests de Vitest pasados al 100%).
