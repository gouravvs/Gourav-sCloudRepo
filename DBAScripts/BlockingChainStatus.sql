;WITH BlockingCTE AS
(
    -- Anchor: blocked sessions
    SELECT
        r.session_id,
        r.blocking_session_id,
        r.start_time,
        DATEDIFF(SECOND, r.start_time, GETDATE()) AS running_time_sec,
        s.login_name,
        s.host_name,
        s.program_name,
        DB_NAME(r.database_id) AS database_name,
        r.status,
        r.wait_type,
        r.wait_time AS wait_time_ms,
        r.command,
        CAST(r.session_id AS VARCHAR(200)) AS blocking_chain
    FROM sys.dm_exec_requests r
    JOIN sys.dm_exec_sessions s
        ON r.session_id = s.session_id
    WHERE r.blocking_session_id <> 0

    UNION ALL

    -- Recursive: walk up to root blocker
    SELECT
        r.session_id,
        r.blocking_session_id,
        r.start_time,
        DATEDIFF(SECOND, r.start_time, GETDATE()) AS running_time_sec,
        s.login_name,
        s.host_name,
        s.program_name,
        DB_NAME(r.database_id) AS database_name,
        r.status,
        r.wait_type,
        r.wait_time AS wait_time_ms,
        r.command,
        CAST(c.blocking_chain + ' -> ' + CAST(r.session_id AS VARCHAR(10)) AS VARCHAR(200))
    FROM sys.dm_exec_requests r
    JOIN sys.dm_exec_sessions s
        ON r.session_id = s.session_id
    JOIN BlockingCTE c
        ON r.blocking_session_id = c.session_id
)
SELECT
    blocking_chain,
    session_id,
    blocking_session_id,
    running_time_sec,
    login_name,
    host_name,
    program_name,
    database_name,
    status,
    wait_type,
    wait_time_ms,
    command,
    st.text AS running_sql_text
FROM BlockingCTE b
OUTER APPLY sys.dm_exec_sql_text(
    (SELECT sql_handle FROM sys.dm_exec_requests WHERE session_id = b.session_id)
) st
ORDER BY blocking_chain;
