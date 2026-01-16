# Reporte de Auditoría - Sistema de Notificaciones

> **Auditor:** QA y Auditoría (Ciberseguridad)  
> **Fecha:** 2026-01-15  
> **Documento Auditado:** [notifications.md](../notifications.md)  
> **Estado:** ✅ Resuelto - Incorporado en FRD Final v1.1

---

## Puntaje de Robustez: 78/100

| Categoría | Puntuación | Max |
|-----------|------------|-----|
| Completitud del Documento | 25 | 25 |
| Seguridad Lógica | 18 | 25 |
| Seguridad del Código (Diseño) | 15 | 25 |
| Resiliencia | 20 | 25 |

---

## Matriz de Riesgos

| # | Severidad | Descripción | Ubicación | Plan Mitigación |
|---|-----------|-------------|-----------|-----------------|
| 1 | 🟠 ALTO | No hay validación de longitud para `title` y `message` | Interface `SystemNotification` líneas 70-85 | Agregar límites: title ≤ 100 chars, message ≤ 500 chars |
| 2 | 🟠 ALTO | Falta sanitización de metadata antes de persistir | Store propuesto línea 119 | Validar UUID format antes de guardar |
| 3 | 🟡 MEDIO | Sin límite de frecuencia de notificaciones (spam potential) | UC-02, UC-03 | Rate limit: máx 5 notificaciones/minuto por tipo |
| 4 | 🟡 MEDIO | localStorage sin encriptación | Persistencia línea 126 | Documentar que datos son no-sensibles; considerar obfuscación |
| 5 | 🔵 BAJO | No hay expiración automática de notificaciones antiguas | Store propuesto | Agregar TTL de 30 días además del límite de 50 |

---

## ✅ Aspectos Positivos del Documento

| Aspecto | Evaluación |
|---------|------------|
| Estructura de datos tipada | ✅ TypeScript interfaces correctas |
| Límite de 50 notificaciones | ✅ Previene DoS de localStorage |
| Separación toast vs centro | ✅ Buena arquitectura |
| Casos de uso definidos | ✅ Flujos claros |
| Revisiones incorporadas | ✅ Trazabilidad completa |

---

## Análisis de Seguridad Lógica

### A. Reglas de Negocio

| Regla | Estado | Observación |
|-------|--------|-------------|
| Badge muestra conteo no leídas | ✅ OK | Definido en UC-01 |
| Ocultar badge sin notificaciones | ✅ OK | Regla 4 |
| Límite 50 notificaciones | ✅ OK | Persistencia |
| Stock < min_stock genera notificación | ⚠️ | Falta definir: ¿Solo una vez o cada venta? |

### B. Edge Cases No Documentados

1. **Notificación Duplicada:** ¿Qué pasa si el stock sube y baja repetidamente del umbral?
   - **Sugerencia:** Agregar flag `notifiedLowStock` al producto para evitar spam

2. **Notificaciones Accionables Sin Respuesta:** ¿Expiran? ¿Se archivan?
   - **Sugerencia:** Definir TTL de 24h para notificaciones de seguridad

3. **Conflicto Multi-Tab:** Si la app está abierta en 2 pestañas, ¿cómo se sincroniza localStorage?
   - **Sugerencia:** Usar evento `storage` para sincronizar estado entre tabs

---

## Análisis de Seguridad del Código (Diseño)

### A. Exposición de Datos

| Dato | Exposición | Riesgo | Mitigación |
|------|------------|--------|------------|
| `metadata.productId` | localStorage | Bajo | UUIDs no son sensibles |
| `metadata.clientId` | localStorage | Bajo | UUIDs no son sensibles |
| `metadata.amount` | localStorage | Medio | Montos visibles en DevTools |

> **Veredicto:** Datos no críticos, pero documentar en SECURITY_PROTOCOLS.md

### B. Input Validation (Por Implementar)

El FRD define la interface pero no especifica validación:

```typescript
// SUGERENCIA: Agregar al store
const validateNotification = (n: SystemNotification): boolean => {
  if (n.title.length > 100) return false;
  if (n.message.length > 500) return false;
  if (n.metadata?.productId && !isValidUUID(n.metadata.productId)) return false;
  return true;
};
```

---

## Análisis de Resiliencia

### A. Manejo de Fallos

| Escenario | ¿Documentado? | Sugerencia |
|-----------|---------------|------------|
| localStorage lleno | ❌ No | Catch error y limpiar notificaciones antiguas |
| Datos corruptos en localStorage | ❌ No | Try/catch en hidratación + reset graceful |
| Notificación con tipo inválido | ❌ No | Defaultear a `general` |

### B. Fail-Safe Propuesto

```typescript
// Agregar al store
const loadFromStorage = () => {
  try {
    const data = localStorage.getItem('app_notifications');
    if (!data) return [];
    const parsed = JSON.parse(data);
    // Validar cada item
    return parsed.filter(isValidNotification);
  } catch (e) {
    console.warn('[Notifications] Datos corruptos, reseteando...');
    localStorage.removeItem('app_notifications');
    return [];
  }
};
```

---

## Inconsistencias Detectadas

| # | Inconsistencia | Ubicación | Acción |
|---|----------------|-----------|--------|
| 1 | FRD dice icono `shield` pero implementación actual usa `lock_person` | Línea 97 NotificationCenterView.vue vs FRD línea 222 | Estandarizar a `shield` como dice el FRD |
| 2 | Interface no tiene campo `time` pero implementación lo usa | Línea 10 NotificationCenterView.vue | El FRD define `createdAt` (ISO), se formatea a relativo |
| 3 | Campo `icon` es nuevo, implementación actual lo calcula dinámicamente | getIconConfig() líneas 94-105 | Migrar a leer del store cuando se implemente |

---

## Plan de Mitigación (Para Orquestador)

### Crítico (Antes de Implementar)
1. ✅ Agregar validación de longitud en `addNotification()`
2. ✅ Agregar validación de UUID para metadata

### Alto (Durante Implementación)
3. ✅ Implementar rate limiting en generación de notificaciones
4. ✅ Agregar flag anti-duplicado para stock bajo

### Medio (Post-MVP)
5. ⏳ Agregar expiración automática de notificaciones antiguas
6. ⏳ Sincronización multi-tab con evento `storage`

---

## Veredicto Final

| Criterio | Estado |
|----------|--------|
| ¿Documento completo? | ✅ Sí |
| ¿Seguro para implementar? | ✅ Sí, con mitigaciones |
| ¿Bloqueante para despliegue? | ❌ No |

**Recomendación:** Proceder con implementación incorporando las validaciones sugeridas en el store.
