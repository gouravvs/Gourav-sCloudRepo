SELECT
    r.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    DB_NAME(r.database_id) AS database_name,
    r.status,
    r.command,
    r.start_time,
    DATEDIFF(SECOND, r.start_time, GETDATE()) AS running_time_seconds,
    r.cpu_time AS cpu_time_ms,
    r.total_elapsed_time AS total_elapsed_time_ms,
    r.reads,
    r.writes,
    r.logical_reads,
    r.wait_type,
    r.wait_time AS wait_time_ms,
    r.blocking_session_id,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
        END - r.statement_start_offset) / 2) + 1
    ) AS running_statement,
    st.text AS full_batch_text
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s
    ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE s.is_user_process = 1

-- Add the minutes ,currently like queries taking longer than 5 mins 
--AND DATEDIFF(MINUTE, r.start_time, GETDATE()) >= 5
ORDER BY r.start_time;
