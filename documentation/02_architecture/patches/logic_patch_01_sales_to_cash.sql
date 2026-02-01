-- =============================================
-- Patch: Lógica de Venta a Caja (Trigger)
-- Fecha: 2026-02-01
-- Autor: Architect Agent
-- Auditor: QA Agent
-- Descripción: Conecta inserciones en 'sales' con 'cash_movements'
-- si existe una sesión de caja abierta y el pago es efectivo.
-- =============================================

CREATE OR REPLACE FUNCTION public.sync_sale_to_cash()
RETURNS TRIGGER AS $$
DECLARE
  v_session_id UUID;
BEGIN
  -- Solo si es efectivo (Nequi/Fiado no entra al cajón físico)
  IF NEW.payment_method = 'efectivo' THEN
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
        'Venta #' || NEW.ticket_number,
        NEW.id
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sales_to_cash ON public.sales;
CREATE TRIGGER trg_sales_to_cash
  AFTER INSERT ON public.sales
  FOR EACH ROW EXECUTE FUNCTION public.sync_sale_to_cash();
