-- MIGRATION: FIX_TRIGGER_SYNC_SALE_TYPE_ERROR
-- Date: 2026-02-03
-- Objective: Fix critical bug "invalid input syntax for type integer: 'N/A'" in sync_sale_to_cash.
-- Justification: The trigger attempts COALESCE(integer, 'text'), which causes Postgres to try casting 'N/A' to integer.
-- Fix: Cast ticket_number to text before coalescing.

CREATE OR REPLACE FUNCTION public.sync_sale_to_cash()
RETURNS TRIGGER AS $$
DECLARE
  v_session_id UUID;
BEGIN
  -- Solo si es efectivo (Nequi/Fiado no entra al cajón físico)
  IF LOWER(NEW.payment_method) = 'efectivo' THEN
    -- Buscar sesión abierta para esta tienda
    SELECT id INTO v_session_id
    FROM public.cash_sessions
    WHERE store_id = NEW.store_id AND status = 'open'
    LIMIT 1;
    
    -- Si hay caja, registrar ingreso
    IF FOUND THEN
      INSERT INTO public.cash_movements (
        session_id,
        movement_type,
        amount,
        description,
        sale_id
      ) VALUES (
        v_session_id,
        'ingreso',
        NEW.total, -- Asumimos total como ingreso efectivo
        'Venta #' || COALESCE(NEW.ticket_number::text, 'N/A'), -- FIX: ::text cast added
        NEW.id
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
