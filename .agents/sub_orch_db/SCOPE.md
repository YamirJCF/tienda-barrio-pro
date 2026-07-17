# Scope: Milestone 1 - Database Migration & RPC

## Architecture
- Database layer: Supabase PostgreSQL database containing `client_ledger` table and a new view `client_transactions` which replaces the old `client_transactions` table.
- RPC functions: `registrar_abono(p_client_id uuid, p_amount numeric)` updated to write into `client_ledger` instead of `client_transactions`.

## Milestones
| # | Name | Scope | Status |
|---|------|-------|--------|
| 1 | Create Migration | Create the SQL file `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql` with backfill, dropping of table, view creation, permissions, and RPC recreation inside a single transaction block. | PLANNED |
| 2 | Update clean_database.sql | Modify `supabase/scripts/clean_database.sql` to truncate `client_ledger` instead of `client_transactions`. | PLANNED |

## Interface Contracts
- RPC `registrar_abono(p_client_id uuid, p_amount numeric)` returning json containing `success` (boolean), `new_balance` (numeric) or `error` (text), `code` (text) on failure.
