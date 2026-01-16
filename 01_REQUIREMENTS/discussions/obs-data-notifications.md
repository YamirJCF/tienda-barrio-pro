# Observación Arquitectura de Datos: Sistema de Notificaciones

> **Autor:** Agente Arquitecto de Datos  
> **Fecha:** 2026-01-15  
> **Referencia:** [notifications.md](../notifications.md)  
> **Estado:** ✅ Resuelto - Incorporado en FRD Final

---

## Resumen Ejecutivo

La propuesta actual del sistema de notificaciones está diseñada **exclusivamente para frontend** con almacenamiento en `localStorage`. Esta es una decisión válida para la fase MVP, pero requiere planificación de escalabilidad hacia backend.

---

## ✅ Validación de la Propuesta Frontend

| Aspecto | Evaluación |
|---------|------------|
| Persistencia localStorage | ✅ Apropiado para MVP frontend-only |
| Límite 50 items | ✅ Previene problemas de rendimiento |
| Estructura `SystemNotification` | ✅ Bien normalizada, extensible |

---

## ⚠️ Observaciones Técnicas

### 1. Campo `metadata` debe ser tipado estrictamente

El FRD propone:

```typescript
metadata?: {
    productId?: number;
    clientId?: string;
    amount?: string;
}
```

**Problema:** `productId` debería ser `string` (UUID) para consistencia con el schema de Supabase.

**Corrección sugerida:**

```typescript
metadata?: {
    productId?: string;    // UUID
    clientId?: string;     // UUID  
    saleId?: string;       // UUID
    amount?: number;       // Decimal, no string
}
```

### 2. Falta campo `icon` mencionado en observación UX

El archivo `obs-ux-notifications.md` sugiere agregar campo `icon` para cada tipo de notificación. Confirmo que es buena práctica para la UI.

---

## 📊 Plan de Escalabilidad Backend (Futuro)

Cuando se requiera sincronización multi-dispositivo o notificaciones push, se necesitará tabla:

### Tabla Propuesta: `notifications`

```sql
-- NOTA: Solo implementar cuando se requiera backend
-- Por ahora, la propuesta localStorage del FRD es correcta

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  employee_id UUID REFERENCES employees(id) ON DELETE CASCADE, -- NULL = para todos
  type TEXT CHECK (type IN ('security', 'inventory', 'finance', 'general')) NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  icon TEXT DEFAULT 'notifications',
  is_read BOOLEAN DEFAULT false,
  actionable BOOLEAN DEFAULT false,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  read_at TIMESTAMPTZ
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_notifications_store ON notifications(store_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(store_id, is_read) WHERE is_read = false;

-- RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "view_own_store_notifications" ON notifications
FOR SELECT USING (
  store_id IN (SELECT store_id FROM employees WHERE id = auth.uid())
);
```

### Diccionario de Datos

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | UUID | Identificador único |
| store_id | UUID FK | Tienda a la que pertenece |
| employee_id | UUID FK | Empleado destino (NULL = broadcast) |
| type | TEXT | security, inventory, finance, general |
| title | TEXT | Título de la notificación |
| message | TEXT | Cuerpo del mensaje |
| icon | TEXT | Nombre del Material Symbol |
| is_read | BOOLEAN | Estado de lectura |
| actionable | BOOLEAN | ¿Tiene botones de acción? |
| metadata | JSONB | Datos adicionales (productId, amount, etc.) |
| created_at | TIMESTAMPTZ | Fecha de creación |
| read_at | TIMESTAMPTZ | Fecha de lectura |

---

## 🔧 Trigger de Notificación Automática (Futuro)

Cuando se migre a backend, se puede generar notificaciones automáticamente:

```sql
-- Trigger: Generar notificación cuando stock < min_stock
CREATE OR REPLACE FUNCTION notify_low_stock()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.current_stock < NEW.min_stock AND OLD.current_stock >= OLD.min_stock THEN
    INSERT INTO notifications (store_id, type, title, message, metadata)
    VALUES (
      NEW.store_id,
      'inventory',
      'Stock Bajo: ' || NEW.name,
      'Quedan ' || NEW.current_stock || ' unidades',
      json_build_object('productId', NEW.id)::jsonb
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_low_stock_notification
AFTER UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION notify_low_stock();
```

---

## ✅ Veredicto

| Decisión | Estado |
|----------|--------|
| Implementar con localStorage (MVP) | ✅ **Aprobado** |
| Crear tabla `notifications` en Supabase | 🔶 **Diferido** hasta sincronización multi-dispositivo |

---

## Correcciones Sugeridas al FRD

1. Cambiar `metadata.productId` de `number` a `string` (UUID)
2. Cambiar `metadata.amount` de `string` a `number`
3. Agregar campo `icon: string` a interface `SystemNotification`

---

## Instrucción para el Orquestador

Para implementar el sistema de notificaciones:

1. **NO crear tabla en Supabase** - La propuesta actual es frontend-only ✅
2. Crear `stores/notificationsStore.ts` con persistencia localStorage
3. Integrar con `inventoryStore` y `salesStore` para disparar notificaciones
4. Considerar las correcciones de tipos mencionadas arriba
