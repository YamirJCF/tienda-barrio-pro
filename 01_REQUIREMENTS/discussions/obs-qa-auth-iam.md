# Observaciones QA - Autenticación Unificada e IAM

**Referencia:** SPEC-005 (`auth-unificada-iam.md`)  
**Fecha:** 2026-01-15  
**Rol:** QA y Auditoría

---

## Veredicto: ✅ Aprobado con Observaciones Menores

---

## Observaciones

### 1. 🟡 Fingerprinting No Especificado

**Problema:** No se define cómo se genera `device_fingerprint`.

**Riesgo:** Implementaciones inconsistentes entre desarrolladores.

**Recomendación:** Especificar algoritmo (FingerprintJS, canvas hash, o combinación de `userAgent + screen + timezone`).

---

### 2. 🟡 Sin Expiración de Sesión

**Problema:** No se menciona TTL para `employee_sessions`.

**Riesgo:** Sesiones huérfanas que nunca expiran.

**Recomendación:** Agregar campo `expires_at` o política de limpieza periódica.

---

### 3. 🟡 Rate Limiting Ausente

**Problema:** No hay protección contra fuerza bruta en login.

**Riesgo:** Atacante puede probar miles de PINs.

**Recomendación:** Contador de intentos fallidos + cooldown (ej: 5 intentos → 15 min bloqueo).

---

### 4. 🔵 Mecanismo de Notificación

**Problema:** Solo menciona "notificar al Admin" sin detallar el canal.

**Aclarar:** ¿Push notification, email, badge in-app, o los tres?

---

### 5. 🔵 UX de Dispositivo Rechazado

**Problema:** No se define qué ve el empleado cuando `status = rejected`.

**Aclarar:** ¿Puede solicitar re-aprobación? ¿Ve motivo del rechazo?

---

## Validación de Schema

✅ `login_empleado_unificado` en `supabase-schema.sql` implementa correctamente las 3 capas.

---

## Resolución Requerida

- [x] Definir algoritmo de fingerprinting → **SHA-256(userAgent+screen+timezone+lang)**
- [x] Definir política de expiración de sesiones → **TTL 8 horas + pg_cron**
- [x] Definir mecanismo de rate limiting → **5 intentos / 15 min cooldown**

✅ **Observaciones resueltas por Arquitecto (2026-01-15)**

Documento listo para implementación.
