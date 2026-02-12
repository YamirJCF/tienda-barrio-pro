-- ==============================================================================
-- MIGRATION: DEACTIVATE CARD PAYMENT METHOD
-- Description: Disables 'Tarjeta Débito/Crédito' payment method.
--              The system does not use card payments.
--              rpc_get_system_config already filters by is_active = true.
-- Impact: UI will no longer show the card tab in CheckoutModal.
-- ==============================================================================

UPDATE public.payment_methods 
SET is_active = false 
WHERE code = 'card';
