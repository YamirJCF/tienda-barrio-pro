# 🛡️ Reporte de Auditoría QA - Plan de Normalización de Arquitectura

> **Módulo Auditado**: `implementation_plan.md` (Normalización y Preparación de Arquitectura)  
> **Fecha**: 2026-01-21  
> **Auditor**: QA/Seguridad  
> **Estado**: ⚠️ Aprobado con Observaciones

---

## Puntaje de Robustez: 78/100

| Categoría | Puntaje | Max |
|-----------|---------|-----|
| Seguridad Lógica | 22/30 | 30 |
| Seguridad del Código | 18/25 | 25 |
| Resiliencia | 20/25 | 25 |
| Completitud Documental | 18/20 | 20 |

---

## Matriz de Riesgos

| # | Severidad | Descripción | Ubicación | Estado |
|---|-----------|-------------|-----------|--------|
| 1 | 🟠 ALTO | **Stock Negativo sin Rollback**: Optimistic UI permite stock negativo pero no define mecanismo de compensación al usuario | Entregable 1 | ABIERTO |
| 2 | 🟠 ALTO | **Token en Memory sin Persistencia**: Si el navegador se cierra, el usuario pierde sesión inmediatamente | Entregable 2, línea 69 | ABIERTO |
| 3 | 🟡 MEDIO | **Conflictos de Venta Offline no Resueltos**: ¿Qué pasa si 2 cajeros venden el mismo último item offline? | Entregable 1 | ABIERTO |
| 4 | 🟡 MEDIO | **Seeds sin Validación**: Los archivos seed (`products.json`) podrían tener datos malformados | Entregable 3 | ABIERTO |
| 5 | 🔵 BAJO | **Dependencias Circulares**: WO-003 depende de sync_protocol pero sync_protocol depende de cache-strategy | Entregable 4 | ABIERTO |
| 6 | 🔵 MEJORA | **Falta Rollback Plan**: No hay documentación de cómo revertir si la migración falla | Entregable 3 | SUGERENCIA |

---

## Análisis de Seguridad Lógica

### ✅ Fortalezas Detectadas

1. **PIN nunca retorna al frontend** (línea 81): Correcto patrón de seguridad. El JWT es la única credencial persistida.

2. **Gatekeeper de 3 capas**: El flujo de autenticación valida credenciales → dispositivo → estado de tienda. Arquitectura sólida.

3. **Hard Reset elimina deuda técnica**: Decisión económicamente correcta para evitar bugs de migración.

### ⚠️ Vulnerabilidades Detectadas

#### R-01: Stock Negativo sin Compensación (🟠 ALTO)

**Problema**: El plan propone Optimistic UI donde "Stock puede quedar negativo temporalmente", pero NO especifica:
- ¿Cómo se notifica al vendedor si el servidor rechaza la venta?
- ¿Se revierte la UI de "Venta exitosa"?
- ¿Qué pasa con el recibo ya mostrado?

**Impacto**: El cajero podría mostrar confirmación de venta al cliente, pero el servidor la rechaza después. Pérdida de confianza.

**Mitigación Requerida**: Agregar a `sync_protocol_spec.md`:
```markdown
## Escenario: Venta Rechazada Post-Confirmación

1. UI muestra notificación: "⚠️ Venta #045 requiere atención"
2. Venta marcada como "PENDIENTE_REVISION" en historial
3. Admin debe aprobar/cancelar manualmente
4. Si cancela: Registrar como "Venta Anulada" con razón
```

#### R-02: Token Volátil (🟠 ALTO)

**Problema**: Línea 69 dice "Guarda session_token en memory (NO localStorage)". Esto significa:
- Si el cajero cierra pestaña por error → Debe re-loguearse
- Si el navegador crashea → Sesión perdida
- NO hay "Remember Me" para empleados frecuentes

**Impacto**: Fricción operativa. En una tienda ocupada, re-loguear cada vez es costoso.

**Mitigación Requerida**: Definir política de persistencia de sesión:
```markdown
## Política de Sesión Empleado

| Escenario | Comportamiento |
|-----------|----------------|
| Cierre de pestaña | Sesión se pierde (intencional - seguridad) |
| Inactividad > 30 min | Auto-logout + re-PIN |
| Navegador reabierto | Solicitar PIN nuevamente |
| "Recordarme" checkbox | PROHIBIDO - Solo para Admin con 2FA |
```

#### R-03: Conflicto Offline (🟡 MEDIO)

**Problema**: Dos cajeros offline pueden "vender" el mismo último item. Cuando ambos sincronizan, el servidor debe decidir:
- ¿Cuál venta gana?
- ¿Ambas se cancelan?
- ¿Se permite stock negativo?

**Mitigación Requerida**: Agregar regla de conflicto:
```markdown
## Regla de Conflicto: Última Unidad

Estrategia: **First-Sync-Wins**
- La primera venta sincronizada se confirma
- La segunda recibe error: "Stock insuficiente al sincronizar"
- La segunda va a Dead Letter Queue para revisión manual
```

---

## Análisis de Resiliencia

### ✅ Fortalezas

1. **Dead Letter Queue** ya definida en `cache-strategy.md` (MIT-02)
2. **Límite de 5 reintentos** previene loops infinitos
3. **Indicadores visuales de sync** planeados

### ⚠️ Gaps Detectados

#### R-04: Seeds Sin Validación

**Problema**: Si `products.json` tiene un campo faltante, el sistema falla silenciosamente.

**Mitigación**: Agregar script de validación de seeds:
```sql
-- Validar seeds antes de insertar
SELECT validate_seed_schema('products', :json_content);
```

#### R-06: Sin Rollback Plan

**Problema**: Si la migración a Supabase falla a mitad de camino, no hay documentación de cómo revertir.

**Mitigación**: Agregar a `DATA_MIGRATION_POLICY.md`:
```markdown
## Plan de Rollback

1. Mantener localStorage intacto hasta confirmar sync exitoso
2. Flag `migration_complete` en config
3. Si falla: Restaurar rutas a stores locales
4. Cleanup: Eliminar localStorage solo tras 7 días de producción estable
```

---

## Verificación de Completitud

| Documento Propuesto | ¿Criterios Claros? | ¿Dependencias Explícitas? | ¿Agente Asignado? |
|---------------------|--------------------|---------------------------|-------------------|
| sync_protocol_spec.md | ✅ Parcial | ❌ Falta ref a cache-strategy | N/A (Req) |
| auth-unificada-iam.md | ✅ Claro | ✅ | N/A (Req) |
| DATA_MIGRATION_POLICY.md | ✅ Claro | ❌ Sin rollback | N/A (Arch) |
| WORK_ORDERS_PHASE_1.md | ✅ Claro | ⚠️ Dependencia circular | ✅ |

---

## Plan de Mitigación para el Arquitecto

### Prioridad Inmediata (Antes de Crear Documentos)

1. **Definir política de venta rechazada post-confirmación** en sync_protocol_spec
2. **Documentar política de sesión volátil** como decisión consciente en auth-unificada-iam
3. **Agregar regla First-Sync-Wins** para conflictos de stock

### Prioridad Media (Incluir en Documentos)

4. **Script de validación de seeds** antes de carga inicial
5. **Rollback plan** en DATA_MIGRATION_POLICY.md

### Backlog

6. Revisar dependencias de Work Orders para evitar bloqueos circulares

---

## Decisión QA

| Pregunta | Respuesta QA |
|----------|--------------|
| ¿Optimistic UI es seguro? | ✅ SÍ, con mitigaciones R-01 y R-03 implementadas |
| ¿Hard Reset es recomendable? | ✅ SÍ, es la opción más limpia para producción |
| ¿El plan está listo para ejecutar? | ⚠️ PARCIAL - Requiere mitigaciones de seguridad |

---

## Veredicto Final

> **APROBADO CON OBSERVACIONES** ⚠️
> 
> El plan arquitectónico es sólido pero requiere **3 adiciones críticas** antes de crear los documentos:
> 1. Política de venta rechazada post-sync
> 2. Documentar sesión volátil como decisión consciente
> 3. Regla de conflicto First-Sync-Wins

---

*Firmado: Agente QA - 2026-01-21*
