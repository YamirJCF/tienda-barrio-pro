-- DIAGNOSTIC: INSPECT CASH_MOVEMENTS SCHEMA
SELECT 
    column_name, 
    data_type
FROM information_schema.columns
WHERE table_name = 'cash_movements';
