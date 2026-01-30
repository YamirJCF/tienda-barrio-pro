# 📜 WO-008: Implementación de Registro Nativo y Triggers

> **Estado:** ✅ COMPLETADO
> **Rama de Trabajo:** `feature/native-registration`
> **Base:** FRD-002, QA-AUDIT-FRD-002

---

## 1. Estrategia de Ejecución

Implementaremos el cambio radical de arquitectura (de "Mock Local" a "Supabase Nativo") en 3 fases estrictas para garantizar la estabilidad detectada por QA.

### 🛡️ Requisitos Críticos de QA Integrados
1.  **Saneamiento de Inputs:** El trigger de base de datos DEBE limpiar el `store_name` para evitar inyección XSS/SQL.
2.  **Transaccionalidad:** La creación de usuario y tienda debe ser atómica.
3.  **Cross-Device:** La UI debe manejar el caso donde el usuario verifica en otro dispositivo.

---

## 2. Desglose de Tareas (Backlog)

### FASE 1: Definición Técnica (Specs)
Antes de tocar código, definimos los "planos de construcción".

- [ ] **TASK-1.1: Data Spec (DSD)**
    - **Archivo:** `02_ARCHITECTURE/DSD_001_REGISTRO_NATIVO.md`
    - **Objetivo:** Escribir el SQL del Trigger `on_auth_user_created`.
    - **Prompt:** "Diseña la función PL/pgSQL que lee `raw_user_meta_data`, sanea el input y crea la tienda en `public.stores`. Incluye manejo de excepciones."

- [ ] **TASK-1.2: UX Spec (UXD)**
    - **Archivo:** `03_UI_UX_DESIGN/UXD_002_WAITING_ROOM.md`
    - **Objetivo:** Diseñar la "Sala de Espera".
    - **Prompt:** "Diseña la pantalla intermedia entre el registro y el dashboard. Debe tener instrucciones claras, botón de reenvío y detección de estado."

### FASE 2: Backend (Supabase)
Implementación de la lógica de negocio en la base de datos.

- [ ] **TASK-2.1: Migración SQL**
    - **Archivo:** `supabase/migrations/[TIMESTAMP]_native_signup_trigger.sql`
    - **Acción:** Crear y aplicar la migración basada en el DSD.

### FASE 3: Frontend (Vue + Pinia)
Conexión de la UI con el nuevo backend.

- [ ] **TASK-3.1: Actualizar Auth Repository**
    - **Archivo:** `src/data/repositories/authRepository.ts`
    - **Cambio:** Reemplazar lógica manual por `supabase.auth.signUp()`.
    
- [ ] **TASK-3.2: Nueva Vista 'Waiting Room'**
    - **Archivo:** `src/views/auth/WaitingRoomView.vue`
    - **Detalle:** UI para usuarios `authenticated` pero no `confirmed`.

- [ ] **TASK-3.3: Ajuste de Router y Guards**
    - **Archivo:** `src/router/index.ts`
    - **Lógica:** Si `user` existe pero `!email_confirmed`, redirigir forzosamente a Waiting Room.

---

## 3. Instrucciones para la Siguiente Sesión

Para iniciar la ejecución, el usuario debe aprobar la creación de las especificaciones (Fase 1).

**Comando sugerido:**
`@[/data] y @[/ux] procedan con la FASE 1 de WO-008`
