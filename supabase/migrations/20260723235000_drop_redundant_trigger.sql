-- Eliminar trigger redundante que causaba colisión con el constraint de cash_movements
-- debido a que rpc_procesar_venta_v2 inserta inicialmente con total = 0
DROP TRIGGER IF EXISTS trg_sales_to_cash ON public.sales;
DROP FUNCTION IF EXISTS public.sync_sale_to_cash();
