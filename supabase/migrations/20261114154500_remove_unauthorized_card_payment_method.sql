-- ==============================================================================
-- MIGRATION: REMOVE UNAUTHORIZED CARD PAYMENT METHOD (FRD-007 / DICT-004 / SDD-007-01)
-- Description: Elimina definitivamente el método de pago no autorizado 'card'
--              ('Tarjeta Débito/Crédito') reactivado por omisión en
--              20260413040000_restore_analytics_and_config.sql y blinda la tabla
--              public.payment_methods contra códigos fuera del dominio oficial.
-- ==============================================================================

DELETE FROM public.payment_methods
WHERE code = 'card';

ALTER TABLE public.payment_methods
DROP CONSTRAINT IF EXISTS payment_methods_allowed_codes_check;

ALTER TABLE public.payment_methods
ADD CONSTRAINT payment_methods_allowed_codes_check
CHECK (code IN ('cash', 'nequi', 'daviplata', 'fiado', 'bre'));
