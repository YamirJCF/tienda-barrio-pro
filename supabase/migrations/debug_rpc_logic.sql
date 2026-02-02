-- DIAGNOSTICO DE LOGICA RPC
-- Probaremos si la lógica "1 dia atras" funciona con el ID visible en la captura

-- ID extraído de la captura (Fila 1)
-- 3cf2e9a6-1b36-4128-ad5d-56df29d72bf9

SELECT 
    id, 
    status,
    requested_at,
    now() as current_server_time,
    (now() - interval '24 hours') as cutoff_time,
    CASE 
        WHEN requested_at > (now() - interval '24 hours') THEN 'VISIBLE'
        ELSE 'OCULTO POR FECHA'
    END as visibility_check
FROM public.daily_passes
WHERE employee_id = '3cf2e9a6-1b36-4128-ad5d-56df29d72bf9';
