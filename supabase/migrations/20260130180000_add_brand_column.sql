-- =============================================
-- MIGRATION: ADD MISSING BRAND COLUMN
-- Fecha: 2026-01-30
-- Autor: @[/qa]
-- Descripción: Agrega la columna 'brand' a la tabla products para evitar pérdida de datos.
-- El frontend permite ingresar marca, pero la base de datos no tenía donde guardarla.
-- =============================================

ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS brand text;

-- Actualizar comentario para documentación
COMMENT ON COLUMN public.products.brand IS 'Marca del producto (opcional)';
