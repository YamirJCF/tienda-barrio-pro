## Modelo de Datos - Sistema de Historiales

### Explicación Lógica
Para soportar los 7 niveles de historiales sin crear una "súper tabla" ineficiente, mantendremos tablas especializadas pero con estructuras de campos comunes para facilitar la visualización unificada si se deseara en el futuro (aunque por ahora se consultarán por separado).
Se introducen nuevas tablas para `system_audit_logs` y `price_change_logs`. Las demás (ventas, movimientos de stock) ya existen pero se verificará que tengan índices por `created_at` y `created_by`.

### Bloque de Código SQL

```sql
-- 1. Log de Auditoría del Sistema (Seguridad)
CREATE TABLE public.system_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    store_id UUID NOT NULL REFERENCES public.stores(id),
    user_id UUID REFERENCES auth.users(id), -- Puede ser nulo si es un intento de login fallido desconocido
    event_type TEXT NOT NULL, -- 'login_success', 'login_failed', 'pin_change', 'unauthorized_access'
    severity TEXT DEFAULT 'info', -- 'info', 'warning', 'critical'
    details JSONB DEFAULT '{}'::jsonb, -- IP, dispositivo, input fallido
    ip_address TEXT
);

-- Índices para búsqueda rápida
CREATE INDEX idx_audit_store_date ON public.system_audit_logs(store_id, created_at DESC);
CREATE INDEX idx_audit_user ON public.system_audit_logs(user_id);

-- RLS
ALTER TABLE public.system_audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins ver logs de su tienda" ON public.system_audit_logs
    FOR SELECT USING (auth.uid() IN (
        SELECT profile_id FROM public.store_members WHERE store_id = system_audit_logs.store_id AND role = 'admin'
    ));
CREATE POLICY "Sistema inserta logs" ON public.system_audit_logs
    FOR INSERT WITH CHECK (true); -- Idealmente restringir a Service Role, pero por ahora permitimos insert autenticado

-- 2. Historial de Cambios de Precio
CREATE TABLE public.price_change_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    store_id UUID NOT NULL REFERENCES public.stores(id),
    product_id BIGINT NOT NULL REFERENCES public.products(id), -- Asumiendo BIGINT por products.id actual
    changed_by UUID NOT NULL REFERENCES auth.users(id),
    old_price NUMERIC,
    new_price NUMERIC,
    old_cost NUMERIC,
    new_cost NUMERIC,
    reason TEXT -- 'inflation', 'correction', 'promotion'
);

CREATE INDEX idx_price_log_store_date ON public.price_change_logs(store_id, created_at DESC);
CREATE INDEX idx_price_log_product ON public.price_change_logs(product_id);

ALTER TABLE public.price_change_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Ver historial precios tienda" ON public.price_change_logs
    FOR SELECT USING (auth.uid() IN (
        SELECT profile_id FROM public.store_members WHERE store_id = price_change_logs.store_id
    ));
```

### Diccionario de Datos (Nuevas Tablas)

#### system_audit_logs
| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | UUID | ID único |
| event_type | TEXT | Categoría del evento |
| severity | TEXT | Nivel de alerta (critical para notificaciones) |
| details | JSONB | Datos flexibles del contexto |

#### price_change_logs
| Columna | Tipo | Descripción |
|---------|------|-------------|
| product_id | BIGINT | Referencia al producto modificado |
| old_price | NUMERIC | Precio antes del cambio |
| new_price | NUMERIC | Precio después del cambio |

### Instrucción para el Orquestador
-   Ejecutar estos scripts en Supabase.
-   Actualizar `types/supabase.ts` para incluir estas nuevas definiciones.
-   Asegurar que las tablas existentes (`tickets`, `stock_movements`, `cash_cuts`) tengan índices en `created_by` para el filtro de empleados.
