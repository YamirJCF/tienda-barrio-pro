# Documento de Diseño de Base de Datos (DBD) - Caja Multicanal

## Modelo de Datos - Caja Multicanal (Fase 1)

> **Nota de Trazabilidad:** Este documento fue renombrado de DBD_020 a DSD_020 para alinearse al estándar v2.0.

### Explicación Lógica
Para soportar cierres de caja detallados por método de pago sin alterar destructivamente el historial, introducimos una arquitectura de tabla anexa (`cash_session_balances`). Esta tabla registra el saldo esperado, saldo físico real, y el descuadre (difference) aglomerado por método de pago para cada sesión de caja. 

Además, se formaliza el método de pago (`payment_method`) a nivel transaccional en `cash_movements`.

### Bloque de Código SQL
```sql
-- 1. cash_movements: Añadir columna y backfill
ALTER TABLE public.cash_movements
ADD COLUMN payment_method TEXT;

-- (El Backfill se hará loteado o en ventana de mantenimiento)
-- UPDATE public.cash_movements SET payment_method = 'efectivo' WHERE payment_method IS NULL;
-- ALTER TABLE public.cash_movements ALTER COLUMN payment_method SET NOT NULL;
-- ALTER TABLE public.cash_movements ALTER COLUMN payment_method SET DEFAULT 'efectivo';

-- 2. cash_session_balances: Nueva tabla
CREATE TABLE public.cash_session_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.cash_sessions(id) ON DELETE CASCADE,
    payment_method TEXT NOT NULL,
    expected_amount NUMERIC(12, 0) NOT NULL DEFAULT 0,
    actual_amount NUMERIC(12, 0) DEFAULT NULL,
    difference NUMERIC(12, 0) DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT cash_session_balances_unique_method UNIQUE (session_id, payment_method)
);

-- Índices
CREATE INDEX idx_cash_session_balances_session ON public.cash_session_balances(session_id);

-- 3. RLS Policies (Bicefalia Employees y Admins)
ALTER TABLE public.cash_session_balances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lectura balances caja para employees y admins"
ON public.cash_session_balances FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.cash_sessions cs
        JOIN public.store_employees se ON cs.store_id = se.store_id
        WHERE cs.id = cash_session_balances.session_id
          AND se.employee_id = public.get_employee_id_from_session()
    )
    OR
    EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid()
    )
);

CREATE POLICY "Escritura balances caja para employees y admins"
ON public.cash_session_balances FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.cash_sessions cs
        JOIN public.store_employees se ON cs.store_id = se.store_id
        WHERE cs.id = cash_session_balances.session_id
          AND se.employee_id = public.get_employee_id_from_session()
    )
    OR
    EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid()
    )
);

CREATE POLICY "Actualización balances caja para employees y admins"
ON public.cash_session_balances FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.cash_sessions cs
        JOIN public.store_employees se ON cs.store_id = se.store_id
        WHERE cs.id = cash_session_balances.session_id
          AND se.employee_id = public.get_employee_id_from_session()
    )
    OR
    EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid()
    )
);
```

### Diccionario de Datos

#### Tabla: `cash_movements` (Modificación)
| Columna | Tipo | Descripción |
|---------|------|-------------|
| payment_method | TEXT | Método de pago del movimiento (efectivo, nequi, daviplata, fiado). Retroactivamente backfilleado como 'efectivo'. |

#### Tabla: `cash_session_balances` (Nueva)
| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | UUID | PK |
| session_id | UUID | Referencia a la sesión (`cash_sessions`) |
| payment_method | TEXT | Identificador del canal (ej. 'efectivo', 'nequi') |
| expected_amount | NUMERIC | Saldo teórico calculado por el sistema en el canal |
| actual_amount | NUMERIC | Saldo físico real declarado por el operario |
| difference | NUMERIC | Descuadre (actual_amount - expected_amount) |
| created_at | TIMESTAMPTZ | Fecha de creación |
| updated_at | TIMESTAMPTZ | Fecha de última actualización |

### Instrucción para el Orquestador
1. Generar la migración SQL (`20260727000000_multichannel_schema.sql`).
2. El backfill de `cash_movements` debe hacer `SET DEFAULT 'efectivo'`.
3. El backfill de `cash_sessions` a `cash_session_balances` debe calcular la `difference` con precisión matemática (`actual_balance - expected_balance`) en un script `INSERT INTO ... SELECT`.
