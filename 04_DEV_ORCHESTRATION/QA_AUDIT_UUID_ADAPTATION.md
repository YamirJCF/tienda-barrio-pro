# 🛡️ Reporte de Auditoría - UUID Adaptation (07_UUID_ADAPTATION.md)

> **Fecha**: 2026-01-21  
> **Auditor**: QA Senior / Ingeniero de Ciberseguridad  
> **Documento Evaluado**: [07_UUID_ADAPTATION.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/03_UI_UX_DESIGN/07_UUID_ADAPTATION.md)

---

## 🎯 Puntaje de Robustez: 62/100

| Categoría | Puntos | Máximo | Notas |
|-----------|--------|--------|-------|
| **Seguridad Lógica** | 20/25 | 25 | Buenas directrices, falta unicidad de ticket_number |
| **Precisión Documental** | 12/25 | 25 | Discrepancias críticas frontend/backend |
| **Resiliencia** | 15/25 | 25 | No aborda colisiones ni sincronización |
| **Completitud UX** | 15/25 | 25 | Falta mapeo de empleados y gastos |

---

## ⚠️ Matriz de Riesgos

| # | Severidad | Descripción | Archivo/Línea | Estado |
|---|-----------|-------------|---------------|--------|
| 1 | 🔴 **CRÍTICO** | **Documento asume sincronización inexistente**: El documento afirma que `ticket_number` viene del backend SQL pero el frontend usa `nextId` local (autoincremental en memoria). NO hay conexión con Supabase. | `sales.ts:133`, Doc:L46 | ❌ Bloqueante |
| 2 | 🔴 **CRÍTICO** | **IDs numéricos en rutas Vue**: La ruta `/clients/:id` usa `number` (L17, L77), NO UUID. Al migrar a Supabase se romperán todas las URLs guardadas. | `ClientListView.vue:77`, `router/index.ts:58` | ❌ Bloqueante |
| 3 | 🟠 **ALTO** | **Tipo incorrecto en stores**: Todos los stores (`sales.ts`, `inventory.ts`, `clients.ts`, `employees.ts`) definen `id: number` con `nextId.value++`. No son compatibles con UUID. | `sales.ts:20`, `inventory.ts:12` | ⚠️ Requiere refactor |
| 4 | 🟠 **ALTO** | **ticket_number no es único global**: El schema SQL define `ticket_number SERIAL` pero es POR TIENDA (no hay constraint). Cuando sincronice múltiples tiendas habrá colisiones. | `supabase-schema.sql:108` | ⚠️ Arquitectural |
| 5 | 🟡 **MEDIO** | **Placeholders incompletos**: El documento sugiere etiquetas como "Buscar por nombre, cédula o teléfono" pero el código actual solo muestra "Buscar por nombre o cédula..." (falta teléfono). | `ClientListView.vue:124` | 📝 Mejora |
| 6 | 🟡 **MEDIO** | **getSaleById usa number**: El método `getSaleById(id: number)` no funcionará con UUIDs. | `sales.ts:149` | 📝 Refactor pendiente |
| 7 | 🔵 **BAJO** | **Inconsistencia de padding**: El documento sugiere `padStart(4, '0')` pero el código usa `padStart(3, '0')`. | `POSView.vue:151` vs Doc:L223 | 📝 Cosmético |

---

## 🔍 Análisis de Seguridad Lógica

### A1. Exposición de Identificadores Internos

**Hallazgo**: El documento correctamente prohíbe mostrar UUIDs al usuario. Sin embargo:

| Riesgo | Evaluación |
|--------|-----------|
| **UUID en URLs visible al usuario** | ⚠️ Aceptable (doc lo valida) |
| **UUID en consola/logs** | ✅ Permitido para debugging |
| **UUID en recibos impresos** | ✅ Prohibido correctamente |
| **Inyección de UUID en búsquedas** | ❓ No hay validación backend |

### A2. Manipulación de IDs en URLs

**Riesgo Actual (ALTO)**: Las rutas usan IDs numéricos secuenciales:
```javascript
// ClientListView.vue:77
const openClientDetail = (clientId: number) => {
  router.push(`/clients/${clientId}`);
};
```

**Vulnerabilidad**: Un usuario puede intentar acceder a `/clients/1`, `/clients/2`, etc. para enumerar clientes. Con UUIDs esto sería imposible (fuerza bruta inviable).

**Mitigación Requerida**: Las políticas RLS de Supabase deben validar que el `client_id` pertenezca al `store_id` del usuario autenticado.

---

## 🔄 Análisis de Resiliencia

### B1. Colisiones de ticket_number

**Problema**: El schema define:
```sql
ticket_number SERIAL
```

Esto genera números consecutivos POR BASE DE DATOS, no por tienda. Si hay múltiples tiendas:
- Tienda A: Ticket #1, #2, #3
- Tienda B: #4, #5, #6

**Impacto**: Cuando el usuario de Tienda B abra su app verá que su primer ticket es #4, no #1.

**Solución Sugerida**:
```sql
-- Agregar constraint compuesto
ticket_number INTEGER NOT NULL DEFAULT 1,
CONSTRAINT unique_ticket_per_store UNIQUE(store_id, ticket_number)
```

Y usar un trigger para autoincrement por tienda.

### B2. Sincronización Offline → Online

**Problema No Documentado**: El documento no aborda qué pasa cuando:
1. Usuario crea venta offline (ID local = 45)
2. Sincroniza con Supabase (UUID = abc-123)
3. ¿Qué pasa con referencias locales al ID 45?

**Riesgo**: Data corruption o ventas duplicadas.

---

## 📋 Discrepancias Documento vs. Código

| Afirmación en Documento | Realidad en Código | Impacto |
|------------------------|-------------------|---------|
| "El sistema YA usa ticket_number" | Frontend usa `nextId` local | 🔴 Falso |
| "salesStore.nextId → ticket_number backend" | No hay conexión a Supabase | 🔴 Falso |
| "padStart(4, '0')" | Código usa `padStart(3, '0')` | 🟡 Menor |
| "Rutas aceptan UUID" | Rutas usan `:id` tipo number | 🔴 Falso |
| "Esquema SQL: products.plu TEXT" | Correcto ✅ | ✅ Correcto |

---

## 🛠️ Plan de Mitigación

### Prioridad 1: Correcciones Críticas (Bloqueantes)

#### WO-UUID-001: Corregir Afirmaciones Falsas en Documento
```markdown
**Archivo**: 03_UI_UX_DESIGN/07_UUID_ADAPTATION.md
**Acción**: Agregar sección "Estado Pre-Migración" que claramente indique:
- ⚠️ El frontend ACTUALMENTE usa IDs numéricos locales
- ⚠️ La migración a UUID requiere refactor de stores y tipos
- ⚠️ Los cambios documentados son DIRECTRICES FUTURAS, no estado actual
```

#### WO-UUID-002: Definir Estrategia de Migración de IDs
```markdown
**Documento Nuevo**: 02_ARCHITECTURE/UUID_MIGRATION_STRATEGY.md
**Contenido**:
1. Plan de conversión: number → UUID en stores
2. Estrategia para URLs: Hash-based routing o direct UUID
3. Mapeo de IDs locales a UUIDs en sincronización
4. Rollback plan si migración falla
```

### Prioridad 2: Mejoras de Seguridad

#### WO-UUID-003: Validar ticket_number por Tienda
```sql
-- Agregar trigger para autoincrement por store_id
CREATE OR REPLACE FUNCTION get_next_ticket_number(p_store_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_next INTEGER;
BEGIN
  SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_next
  FROM sales WHERE store_id = p_store_id;
  RETURN v_next;
END;
$$ LANGUAGE plpgsql;
```

#### WO-UUID-004: Actualizar Placeholders de Búsqueda
```markdown
**Archivos a modificar**:
- ClientListView.vue:124 → "Buscar por nombre, cédula o teléfono..."
- ProductSearchModal.vue:103 → ✅ Ya correcto
- InventoryView.vue:100 → "Buscar por nombre, marca o PLU..."
```

### Prioridad 3: Documentación

#### WO-UUID-005: Actualizar Tabla de Identificadores (Sección 5)
Agregar columnas:
- "Estado Actual" (Implementado/Pendiente)
- "Formato Backend" (SERIAL/UUID)
- "Formato Frontend Actual" (number/string)

---

## ✅ Aspectos Positivos del Documento

| Aspecto | Evaluación |
|---------|-----------|
| Principio "UUID nunca visible" | ✅ Excelente directriz |
| Mapeo de identificadores funcionales | ✅ Completo y útil |
| Guía de implementación para desarrolladores | ✅ Clara y práctica |
| Checklist de verificación QA | ✅ Útil para testing |
| Decisión de URLs largas aceptables | ✅ Pragmático y correcto |

---

## 📊 Resumen Ejecutivo

**VEREDICTO**: El documento `07_UUID_ADAPTATION.md` es una **excelente guía conceptual** para la adaptación a UUIDs, pero contiene **afirmaciones incorrectas sobre el estado actual** del sistema. El frontend **NO** está conectado a Supabase y usa IDs numéricos locales.

**Recomendación**: 
1. **NO APROBAR** el documento sin correcciones
2. Agregar sección clara distinguiendo "Estado Actual" vs "Estado Objetivo"
3. Crear documento de migración técnica en `02_ARCHITECTURE/`
4. Priorizar el refactor de stores antes de continuar desarrollo

---

> **Auditor**: QA Senior  
> **Estado**: REQUIERE CORRECCIONES  
> **Fecha Próxima Revisión**: Tras implementar WO-UUID-001 y WO-UUID-002
