# Modelo de Datos - Refactorización Backend (Ref: DATA-001)

**Arquitecto de Datos**: @[/data]
**Basado en**: ARCH-001 (Mirror Architecture)

## 1. Mejora Estratégica: "Configuration Versioning"
Para mitigar el riesgo de "Drift" identificado en la auditoría, proponemos una mejora al ARCH-001:

> **Versioning**: La configuración del sistema tendrá un `hash` o `version`. El Frontend, al sincronizar, recibirá esta versión. Si la validación offline se hizo con una versión obsoleta de las reglas, la sincronización detectará el conflicto.

## 2. Nuevas Tablas Maestras (Unhardcoding)

### 2.1 Métodos de Pago (`payment_methods`)
Reemplaza los strings quemados ('efectivo', 'nequi') por una entidad configurable.

```sql
CREATE TABLE public.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,          -- 'cash', 'nequi', 'credit_card'
    name TEXT NOT NULL,                 -- 'Efectivo', 'Nequi / Daviplata'
    is_active BOOLEAN DEFAULT true,
    requires_reference BOOLEAN DEFAULT false, -- Si true, UI pide numero de comprobante
    allows_change BOOLEAN DEFAULT false,      -- Si true, UI calcula devuelta
    ledger_account_type TEXT DEFAULT 'asset', -- Para contabilidad futura
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: Public Read (Authenticated), Admin Write
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read_active_methods" ON public.payment_methods FOR SELECT USING (true);
```

### 2.2 Tipos de Transacción (`transaction_types`)
Para categorizar movimientos de caja e inventario.

```sql
CREATE TABLE public.transaction_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,          -- 'sale', 'expense', 'income', 'adjustment'
    description TEXT NOT NULL,
    impact_stock INTEGER DEFAULT 0,     -- -1 (Resta), 0 (Neutro), 1 (Suma)
    impact_cash INTEGER DEFAULT 0,      -- -1 (Salida), 0 (Neutro), 1 (Entrada)
    is_system BOOLEAN DEFAULT false     -- Si true, no se puede borrar ni editar
);
```

## 3. Funciones de Servidor (RPC)

### 3.1 Obtener Configuración del Sistema
Esta función entrega "La Ley" al Frontend en un solo request.

```sql
CREATE OR REPLACE FUNCTION public.rpc_get_system_config()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'payment_methods', (
            SELECT jsonb_agg(pm) FROM (
                SELECT code, name, requires_reference, allows_change 
                FROM public.payment_methods 
                WHERE is_active = true 
                ORDER BY sort_order
            ) pm
        ),
        'transaction_types', (
            SELECT jsonb_agg(tt) FROM (
                SELECT code, description, impact_stock, impact_cash 
                FROM public.transaction_types
            ) tt
        ),
        'server_timestamp', now()
    );
END;
$$;
```

## 4. Impacto en `rpc_procesar_venta_v2`

El RPC actual hardcodea la lógica del cambio:
`v_change := CASE WHEN p_payment_method = 'efectivo' ...`

Al refactorizar, deberá consultar `payment_methods` para saber si calcula cambio:
```sql
-- Pseudocódigo del cambio
SELECT allows_change INTO v_allows_change 
FROM public.payment_methods 
WHERE code = p_payment_method;

IF v_allows_change THEN
   v_change := GREATEST(0, p_amount_received - v_total);
ELSE
   v_change := 0;
END IF;
```

## 5. Instrucciones para el Frontend (@[/ux])
1.  Al iniciar app (`App.vue` o `AuthStore`), consumir `rpc_get_system_config`.
2.  Guardar esta config en Pinia (`useConfigStore`).
3.  Renderizar botones de pago basados en el array `payment_methods`, no en botones hardcodeados.
