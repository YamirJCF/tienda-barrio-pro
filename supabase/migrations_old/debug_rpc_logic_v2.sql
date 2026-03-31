-- DIAGNOSTICO DE LOGICA RPC (V2 - ID CORRECTO)
-- Probaremos si la lógica "1 dia atras" funciona con el EMPLOYEE ID correcto

-- ID extraído de la captura (Columna employee_id)
-- ea8577fd-eef6-4900-8b20-fdd36c9cf6f0

SELECT 
    id, 
    status,
    pass_date,
    requested_at,
    now() as current_server_time,
    (now() - interval '24 hours') as cutoff_time,
    CASE 
        WHEN requested_at > (now() - interval '24 hours') THEN 'VISIBLE'
        ELSE 'OCULTO POR FECHA'
    END as visibility_check
FROM public.daily_passes
WHERE employee_id = 'ea8577fd-eef6-4900-8b20-fdd36c9cf6f0';
