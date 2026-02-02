-- Optimization: Add composite index for faster session history loading
-- Date: 2026-02-01
-- Author: QA Team

-- Checks if index exists relative to session_id and created_at sorting
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cash_movements_session_created 
ON public.cash_movements (session_id, created_at);

-- Explanation:
-- This index prevents the database from performing an in-memory Sort operation
-- when executing: SELECT * FROM cash_movements WHERE session_id = ? ORDER BY created_at ASC;
