

-- This gives all the wait types related to CPU,I/O,memory 
SELECT  *
FROM sys.dm_os_wait_stats; 
 
-- This focus only on tempDB related waits and I/0
SELECT
   wait_type,
  waiting_tasks_count AS Total_Waits,
   wait_time_ms AS Total_Wait_Time_ms,
   100.0 * wait_time_ms / SUM(wait_time_ms) OVER() AS Pct_Total_Wait_Time,
  signal_wait_time_ms,
   wait_time_ms - signal_wait_time_ms AS Resource_Wait_Time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGELATCH%'

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type IN (
    'PAGELATCH_UP',
    'PAGELATCH_EX'
);

SELECT
    wt.wait_type,
    wt.wait_duration_ms,
    wt.blocking_session_id,
    r.database_id,
    DB_NAME(r.database_id) AS database_name,
    r.command
FROM sys.dm_os_waiting_tasks wt
JOIN sys.dm_exec_requests r
    ON wt.session_id = r.session_id
WHERE wt.wait_type LIKE 'PAGELATCH%'
  AND r.database_id = 2; -- tempdb
