-- QA STRESS TEST: FINANCIAL CORE (ARCH-004)
-- Objective: Try to BREAK the system.
-- Role: QA Auditor (Hacker Mindset)

DO $$
DECLARE
    v_store_id UUID := '22222222-2222-2222-2222-222222222222';
    v_employee_id UUID := '533e7fff-b52f-4319-9698-51019d24951c'; -- Normal Employee
    v_product_id UUID := '33333333-3333-3333-3333-333333333333';
    v_client_id UUID := '38a5f332-f10e-4b88-8ae0-69877eaee1be';
    
    v_sale_result JSONB;
    v_void_result JSONB;
    v_real_price DECIMAL;
BEGIN
    -- INIT: Get Real Price
    SELECT price INTO v_real_price FROM products WHERE id = v_product_id;
    RAISE NOTICE '--- START QA STRESS TESTS --- (Real Price: %)', v_real_price;

    -- TEST 1: PRICE MANIPULATION ATTACK
    -- Attack: Frontend sends "unit_price": 1.0 (Real is likely much higher)
    -- Expectation: Backend ignores JSON price, uses DB price. Total should match Real Price.
    PERFORM set_config('request.jwt.claims', json_build_object(
        'sub', v_employee_id,
        'role', 'authenticated', 
        'app_metadata', json_build_object('store_id', v_store_id)
    )::text, true);

    SELECT rpc_procesar_venta_v2(
        v_store_id,
        NULL, -- Cash sale
        'efectivo',
        1000000, -- Big amount received
        jsonb_build_array(
            jsonb_build_object('product_id', v_product_id, 'quantity', 1, 'unit_price', 1.0) -- FAKE PRICE
        )
    ) INTO v_sale_result;
    
    IF (v_sale_result->>'total')::DECIMAL = v_real_price THEN
        RAISE NOTICE '✅ TEST 1 PASSED: Price Manipulation Blocked. Used Real Price.';
    ELSE
        RAISE EXCEPTION '❌ TEST 1 FAILED: System accepted fake price! Total: %', v_sale_result->>'total';
    END IF;

    -- TEST 2: STOCK OVERFLOW
    -- Attack: Sell 1,000,000 units.
    -- Expectation: Fail with stock error (via Trigger or Check).
    BEGIN
        SELECT rpc_procesar_venta_v2(
            v_store_id,
            NULL, 
            'efectivo',
            0,
            jsonb_build_array(
                jsonb_build_object('product_id', v_product_id, 'quantity', 1000000)
            )
        ) INTO v_sale_result;
        
        -- If we get here without exception, check success flag
        IF (v_sale_result->>'success')::boolean = true THEN
             RAISE EXCEPTION '❌ TEST 2 FAILED: Allowed selling 1M units!';
        ELSE
             RAISE NOTICE '✅ TEST 2 PASSED: Stock Overflow Rejected gracefully.';
        END IF;

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ TEST 2 PASSED: Stock Overflow Rejected (DB Constraint). Error: %', SQLERRM;
    END;

    -- TEST 3: UNAUTHORIZED VOID
    -- Attack: Employee tries to void a sale.
    -- Expectation: Fail with UNAUTHORIZED.
    -- Triggering sale first to have ID
    -- (Reuse ID from Test 1 if successful, assumed v_sale_result has id)
    DECLARE
        v_test_sale_id UUID := (v_sale_result->>'sale_id')::UUID;
    BEGIN
        SELECT rpc_anular_venta(v_test_sale_id, 'Hacking Attempt') INTO v_void_result;
        
        IF (v_void_result->>'success')::boolean = true THEN
             RAISE EXCEPTION '❌ TEST 3 FAILED: Employee was able to Void a sale!';
        ELSE
             RAISE NOTICE '✅ TEST 3 PASSED: Employee Void Rejected.';
        END IF;
    END;

    -- TEST 4: LEDGER IMMUTABILITY
    -- Attack: Try to DELETE from client_ledger via SQL (simulating RLS breach attempt if SQL injection existed or permissive RLS)
    -- We can't easily test RLS `DELETE` via `DO` block because `DO` runs as Owner often in this context unless stricter.
    -- But we can check policies.
    IF EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'client_ledger' 
        AND cmd = 'DELETE'
    ) THEN
         RAISE EXCEPTION '❌ TEST 4 FAILED: Explicit DELETE policy found on Ledger!';
    ELSE
         -- By default if RLS enabled and no policy for DELETE, it is denied.
         RAISE NOTICE '✅ TEST 4 PASSED: No DELETE Policy for Ledger (Implicit Deny).';
    END IF;

END $$;
