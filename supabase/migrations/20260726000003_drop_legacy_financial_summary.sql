-- Migration: Drop legacy get_financial_summary RPC
-- Date: 2026-07-26

-- Eliminación segura sin CASCADE. Si algún objeto inesperado depende de esta función,
-- la migración fallará previniendo una caída silenciosa.
DROP FUNCTION IF EXISTS get_financial_summary(UUID, DATE, DATE);
