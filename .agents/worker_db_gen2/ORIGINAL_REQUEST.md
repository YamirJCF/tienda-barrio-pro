## 2026-07-16T22:04:57-05:00
You are the Database Developer / Supabase Implementer (Gen 2) for Milestone 1.
Your working directory is: c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\worker_db_gen2
Please load the supabase-admin skill (path: c:\Users\Windows 11\OneDrive\Desktop\prueba\.agent\skills\supabase-admin\SKILL.md).
You need to address the change requests raised by Reviewer 2.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Please modify the following files:
1. `c:\Users\Windows 11\OneDrive\Desktop\prueba\supabase\migrations\20260711170000_reconcile_client_transactions_and_ledger.sql`:
   - Add parameter check at the beginning of the `registrar_abono` function:
     ```sql
     -- Validar monto positivo
     IF p_amount <= 0 THEN
       RETURN json_build_object(
         'success', false,
         'error', 'El monto del abono debe ser mayor a cero',
         'code', 'INVALID_AMOUNT'
       );
     END IF;
     ```
   - Add secure `search_path` to `registrar_abono` to prevent hijacking vulnerabilities:
     ```sql
     CREATE OR REPLACE FUNCTION public.registrar_abono(p_client_id uuid, p_amount numeric)
      RETURNS json
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public, pg_temp
     AS $function$
     ```
   - Align RPC response to ActionResponse format (User Rule 4.2) while maintaining backward compatibility:
     On success:
     ```sql
     RETURN json_build_object(
       'success', true,
       'new_balance', v_new_balance,
       'data', json_build_object('new_balance', v_new_balance)
     );
     ```
     On validation error (e.g. amount exceeds balance):
     ```sql
     RETURN json_build_object(
       'success', false,
       'error', format('El abono ($%s) supera la deuda actual ($%s)', p_amount, v_client.balance),
       'code', 'AMOUNT_EXCEEDS_BALANCE'
     );
     ```
   - Add a btree index on `client_ledger.reference_id` to optimize views:
     ```sql
     -- 7. Add index on client_ledger.reference_id
     CREATE INDEX IF NOT EXISTS idx_ledger_reference ON public.client_ledger (reference_id);
     ```
     Place this index creation statement inside the transaction block, before `COMMIT;`.

2. `c:\Users\Windows 11\OneDrive\Desktop\prueba\tests\sql\00_seed_data.sql`:
   - Keep the truncation modifications you did (`TRUNCATE TABLE client_ledger CASCADE;`).
   - Insert a corresponding `venta_fiado` record in `client_ledger` for 'Cliente Fiador' (cedula = 'C002') with `amount = 150000` right after clients are inserted, to maintain database balance consistency:
     ```sql
     -- Insertar ledger inicial para Cliente Fiador para mantener consistencia
     INSERT INTO public.client_ledger (client_id, store_id, amount, previous_balance, reference_id, transaction_type)
     SELECT 
         id, 
         store_id, 
         150000, 
         0, 
         NULL, 
         'venta_fiado'
     FROM public.clients 
     WHERE cedula = 'C002' 
     LIMIT 1;
     ```

Please execute these modifications, apply/verify them on the database if possible, and write your completion status to `c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\worker_db_gen2\progress.md` and handoff to `c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\worker_db_gen2\handoff.md`.
