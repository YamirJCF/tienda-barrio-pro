## Plan de QA y Estrategia de Validación (SPEC-009)

### 🛡️ Objetivo de Auditoría
Garantizar que el nuevo "Sistema de Historiales" sea una fuente de verdad inmutable y segura. Se validará que no existan vectores para falsificar auditorías y que la exposición de datos sensibles (desempeño de empleados, flujos de caja) esté estrictamente controlada.

### A. Auditoría de Seguridad Lógica (Business Logic)

#### 1. Inmutabilidad Estricta
*   **Prueba:** Intentar ejecutar `UPDATE` o `DELETE` directamente vía API (Postman/cURL) contra las tablas `tickets`, `cash_cuts`, `system_audit_logs` y `price_change_logs`.
*   **Resultado Esperado:** Todas deben fallar (401/403) o estar bloqueadas por políticas RLS/Triggers. Solo `INSERT` y `SELECT` deben ser permitidos.

#### 2. Segregación de Empleados (Data Leaks)
*   **Prueba:** En el filtro de "Empleado", inspeccionar la respuesta del endpoint que llena el dropdown.
*   **Riesgo:** Que un usuario de la Tienda A pueda ver los nombres/IDs de los empleados de la Tienda B y C.
*   **Validación:** Asegurar que la query de empleados tenga `WHERE store_id = current_store_id`.

#### 3. Integridad de Auditoría (System Audit)
*   **Caso Borde:** Intentar insertar un log con `user_id` falso o `severity` alterada.
*   **Mitigación:** Verificar que el backend sobrescriba el `store_id` y `user_id` basado en el token JWT, ignorando lo que envíe el cliente en el body.

### B. Seguridad del Código y RLS

#### 1. Revisión de Políticas RLS (Supabase)
*   **Tabla `system_audit_logs`:**
    *   `INSERT`: Actualmente definida como `WITH CHECK (true)`. **ALERTA:** Esto permite que cualquier usuario autenticado (incluso de otra tienda) inserte basura en los logs de tu tienda si adivina el ID.
    *   **Corrección Requerida:** `WITH CHECK (store_id IN (SELECT store_id FROM store_members WHERE profile_id = auth.uid()))`.

*   **Tabla `price_change_logs`:**
    *   Validar que solo usuarios con rol 'admin' o permisos de 'inventory_manager' puedan generar estos logs (generalmente vía trigger o función RPC, no inserción directa).

### C. Resiliencia y Manejo de Errores

#### 1. Fallo de Carga Parcial (Graceful Degradation)
*   **Escenario:** El usuario filtra por "Ventas" y "Auditoría". La tabla de ventas responde bien, pero `system_audit_logs` da timeout.
*   **Comportamiento Esperado:** La UI debe mostrar los resultados de ventas y una alerta de "No se pudo cargar auditoría", en lugar de una pantalla blanca o error general.

#### 2. Scroll Infinito y Rendimiento
*   **Prueba de Estrés:** Generar 1,000 registros dummy y scrollear rápidamente.
*   **Validación:** Verificar que no haya renderizado duplicado de keys (`Duplicate keys detected`) y que la memoria del navegador se mantenga estable.

---

### 🧪 Matriz de Casos de Prueba (TDD)

| ID | Tipo | Caso de Prueba | Precondición | Resultado Esperado |
|----|------|----------------|--------------|--------------------|
| QA-01 | 🛡️ Seg | Ver logs de otra tienda | Usuario autenticado en Tienda A intenta leer logs Tienda B | Acceso denegado (Empty set o Error 40X) |
| QA-02 | 🛡️ Seg | Modificar log existente | Intentar UPDATE en `system_audit_logs` | Error: Permiso denegado por RLS |
| QA-03 | 🧠 Lógica | Filtro por Empleado | Seleccionar empleado "Juan" | Solo ver tickets/logs donde `user_id` == Juan |
| QA-04 | ⚡ Res | Desconexión | Cortar red al cambiar de filtro | Mostrar Toast "Sin conexión" y mantener datos previos |

---

### Instrucciones para el Desarrollo (Pre-Code Checks)
1.  **Backend:** Ajustar la política RLS de inserción en `system_audit_logs` para validar pertenencia a la tienda.
2.  **Frontend:** Usar `Promise.allSettled` para cargar múltiples historiales simúltanemante sin que falle todo si uno falla.
