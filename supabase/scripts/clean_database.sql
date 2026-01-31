-- ⚠️ DANGER: WRIPES ALL TRANSACTIONAL DATA ⚠️
-- Este script elimina TODAS las ventas, movimientos de caja, reportes e historial.
-- PRESERVA: Cuentas de usuario (admin_profiles), Tiendas (stores), Empleados (employees), Productos y Clientes.

BEGIN;

-- 1. Tablas Transaccionales de Venta y Caja
TRUNCATE TABLE 
    public.sale_items,
    public.sales,
    public.cash_movements,
    public.cash_sessions,
    public.client_transactions,
    public.inventory_movements,
    public.price_change_logs,
    public.daily_passes,
    public.daily_reports,
    public.audit_logs,
    public.error_logs
CASCADE;

-- 2. Reinicio de Secuencias (si aplica, aunque UUIDs no usan secuencia)
-- Si usaras IDs numéricos autoincrementales, aquí irían los RESTART IDENTITY.

-- 3. Opcional: ¿Limpiar Clientes? (Descomentar si se desea)
-- TRUNCATE TABLE public.clients CASCADE;

-- 4. Opcional: ¿Resetear Stock de Productos a 0? (Descomentar si se desea)
-- UPDATE public.products SET current_stock = 0;

COMMIT;

-- Verificación de limpieza
SELECT 'Sales' as table_name, count(*) from public.sales
UNION ALL
SELECT 'Cash Sessions', count(*) from public.cash_sessions;
