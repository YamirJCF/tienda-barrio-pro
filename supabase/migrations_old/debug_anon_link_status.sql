-- DIAGNOSTIC: CHECK ANON LINK STATUS
SELECT 
    id, 
    employee_id, 
    status, 
    auth_user_id, -- This is the Critical Column
    requested_at
FROM public.daily_passes
WHERE pass_date = CURRENT_DATE
ORDER BY requested_at DESC;
