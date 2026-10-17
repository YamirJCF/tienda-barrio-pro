# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-005)

> **Componente Auditado:** `frontend/src/views/SystemAuditView.vue` y `frontend/src/data/repositories/auditRepository.ts` (y `frontend/src/utils/audit.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_005_AUDITORIA_TRAZABILIDAD.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_005_AUDITORIA_TRAZABILIDAD.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/views/SystemAuditView.vue` (registrada en `frontend/src/router/index.ts:183-186` bajo `/sys-audit` con `devOnly: true`)
- **Capa de Datos y Repositorios:** `frontend/src/data/repositories/auditRepository.ts`
- **Utilidades:** `frontend/src/utils/audit.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contratos de Interfaz (RPC y JSON Schemas)

### 5.1 Especificación: `rpc_obtener_auditoria_evidence_hub`
- **Tipo:** RPC Postgres / Lectura (READ-ONLY)
- **Parámetros de Entrada:**
  - `p_store_id` (UUID, Not Null): Identificador de la tienda activa.
  - `p_domain` (TEXT, Nullable, Default 'todos'): Dominio a consultar ('todos', 'caja', 'ventas', 'inventario', 'seguridad', 'precios', 'creditos').
  - `p_event_type` (TEXT, Nullable): Filtro específico de tipo de evento.
  - `p_severity` (TEXT, Nullable): Filtro por nivel de severidad ('info', 'warning', 'critical').
  - `p_start_date` (TIMESTAMPTZ, Nullable): Límite temporal inferior (default: NOW() - INTERVAL '7 days').
  - `p_end_date` (TIMESTAMPTZ, Nullable): Límite temporal superior (default: NOW()).
  - `p_limit` (INTEGER, Nullable, Default 50): Límite de registros por página (máx 100).
  - `p_offset` (INTEGER, Nullable, Default 0): Desplazamiento para paginación.

- **Payload de Respuesta Exitosa (Contrato Canónico { data, count }):**
  ```json
  {
    "data": [
      {
        "id": "UUID",
        "domain": "caja | ventas | inventario | seguridad | precios | creditos",
        "event_type": "STRING",
        "severity": "info | warning | critical",
        "resource_id": "STRING | null",
        "actor_id": "UUID",
        "actor_name": "STRING",
        "ip_address": "STRING | null",
        "created_at": "TIMESTAMPTZ",
        "metadata": {}
      }
    ],
    "count": 128
  }
  ```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: `rpc_obtener_auditoria_evidence_hub`
- **Invocación RPC:**
  - Código real: En `auditRepository.ts:53-87`, la función `getLogs` ejecuta `.from('audit_seguridad').select('*, employees:actor_id (name)')` y `getPriceChangeLogs` en `auditRepository.ts:94-105` ejecuta `.from('audit_precios').select(...)`.
  - Resultado: **Discrepancia Crítica**. El repositorio hace consultas directas sobre tablas PostgREST en vez de llamar al RPC canónico `rpc_obtener_auditoria_evidence_hub`.
- **Parámetros del RPC (`p_store_id`, `p_domain`, `p_start_date`, `p_end_date`, `p_severity`, `p_limit`, `p_offset`):**
  - Código real: Inexistente en frontend. El cliente no envía `p_domain`, `p_start_date` ni `p_end_date`.
  - Resultado: **Ausente**.
- **Payload `{ data, count }`:**
  - Código real: `auditRepository.ts:58` retorna `Promise<AuditLog[]>`, ignorando por completo el `count` del servidor.
  - Resultado: **Discrepancia**.

### Operación: `rpc_log_security_event`
- **Invocación RPC:**
  - Código real: En `auditRepository.ts:33-37`, invoca `supabase.rpc('rpc_log_security_event', { p_event_type: eventType, p_store_id: storeId, p_metadata: metadata })`.
  - Resultado: **Presente y Conforme**.

---

## Bloque 2b — Verificación de Límites Financieros y Lógica de Negocio

- **Ceguera de Costos (`POL-SEC-01`):**
  - En `auditRepository.ts:113-114`, expone directamente `oldPrice` y `newPrice`. Al no pasar por `rpc_obtener_auditoria_evidence_hub`, si un cajero consulta `audit_precios` o Kardex, los costos no sufren redacción server-side (`unit_cost -> null`).
- **Atajos Temporales Rápidos (Hoy, Ayer, 7 días, 30 días):**
  - Inexistentes en `SystemAuditView.vue` ni en `auditRepository.ts`.
- **Vista de Pruebas Dev vs Evidence Hub Operativo:**
  - `SystemAuditView.vue` está configurado con `devOnly: true` en el enrutador (`router/index.ts:186`) y solo ejecuta pruebas sintéticas unitarias (`testDataIntegrity`, `testCartShield`, etc.), careciendo de pantalla para que el administrador inspeccione eventos de auditoría del negocio.

---

## Bloque 3 — Verificación de Manejo de Errores

| Código de Error SDD | Estado en Código Actual | Tratamiento en UI | Conforme |
|---|---|---|---|
| `UNAUTHORIZED_ROLE` (403) | No capturado | `auditRepository.ts:84` silencia con `logger.error` y retorna `[]` (Fallo silencioso) | ❌ No |
| `STORE_ACCESS_DENIED` | No capturado | Retorna array vacío `[]` | ❌ No |
| Network / Supabase Error | `catch (e) { return [] }` | No hay toast ni notificación al usuario; array vacío silencioso | ❌ No |

---

## Bloque 4 — Verificación de Estados de Carga e Interacción

- **Skeletons / Loading State:** `SystemAuditView.vue` tiene un spinner local (`Loader2`) para su suite de pruebas sintéticas. La vista real del Evidence Hub no existe, por lo que carece de Skeletons canónicos de auditoría.
- **Bloqueo de Interacción:** `isTestRunning` bloquea el botón "Ejecutar Todas" en el suite de pruebas.

---

## Bloque 5 — Resumen de Discrepancias y Plan de Acción

### 5.1 Conteo Mecánico de Hallazgos (Regla 9.1: N = 4)
- **UX-1 (Severidad Alta):** Ausencia de vista de Evidence Hub. `SystemAuditView.vue` (`/sys-audit`) es una suite de pruebas sintéticas local (Dev-Only: `devOnly: true`), no implementa la visualización federada multi-dominio de auditoría (`caja`, `ventas`, `inventario`, `seguridad`, `precios`, `creditos`), los atajos temporales ("Hoy", "Ayer", "7 días", "30 días") ni el visor de metadatos forenses requeridos por `SDD_005` y `FRD_005`.
- **UX-2 (Severidad Alta):** Bypasseo del contrato RPC `rpc_obtener_auditoria_evidence_hub`. `auditRepository.ts:60-73` ejecuta consultas directas a la tabla PostgREST `.from('audit_seguridad').select(...)` y `auditRepository.ts:94-105` a `.from('audit_precios')`, en lugar de invocar `supabase.rpc('rpc_obtener_auditoria_evidence_hub', { p_store_id, p_domain, ... })`. Esto omite la verificación obligatoria `assert_store_access(p_store_id)`, la ceguera de costos (`cost redaction`) y la federación multi-dominio.
- **UX-3 (Severidad Media):** Violación del contrato canónico de paginación `{ data, count }`. `auditRepository.ts:53-87` retorna un arreglo plano (`AuditLog[]`) desechando el conteo total de registros del servidor (`count`), impidiendo la paginación formal y el cálculo de páginas en UI.
- **UX-4 (Severidad Baja):** Mapeo asimétrico de severidad y actor. `auditRepository.ts:79` infiere severidad desde `log.metadata?.severity || 'info'` porque `audit_seguridad` no tiene columna `severity` física, en lugar de consumir el payload unificado del RPC que devuelve `severity` y `actor_name` resueltos por el backend.

---

### 5.2 Auto-Chequeo Anti-Sesgo (Regla 9.4)
- **9.1 Invariante de Reconciliación:** $N = 4$ hallazgos documentados en el Bloque 5.1 y citados exactamente.
- **9.2 No-Fusión de Dimensiones:** Que `rpc_log_security_event` funcione correctamente no atenúa la ausencia de la vista de Evidence Hub ni el bypasseo en `getLogs`.
- **9.3 Cita de Fuentes:** Las discrepancias se basan en la inspección real de `SystemAuditView.vue`, `auditRepository.ts:60-73`, y `router/index.ts:183-186`.
- **9.4 Veredicto:** 🟡 **CON OBSERVACIONES (4 discrepancias detectadas)**.

---

## 📌 Instrucción para el Orquestador (Etapa 4)

1. En `frontend/src/data/repositories/auditRepository.ts`:
   - Refactorizar `getLogs` para invocar `supabase.rpc('rpc_obtener_auditoria_evidence_hub', { p_store_id, p_domain, p_event_type, p_severity, p_start_date, p_end_date, p_limit, p_offset })`.
   - Retornar `{ data: AuditLog[], count: number }` respetando el contrato canónico.
2. En `frontend/src/views/SystemAuditView.vue` (o nueva vista `EvidenceHubView.vue` enlazada al menú administrativo):
   - Proveer la interfaz de Evidence Hub con selector de dominio (`todos`, `caja`, `ventas`, `inventario`, `seguridad`, `precios`, `creditos`), atajos temporales (Hoy, Ayer, 7D, 30D), tabla de auditoría con severidad (`info`, `warning`, `critical`), modal de metadatos forenses estructurados y paginación reactiva usando `count`.
