SELECT TOP (200)
    DB_NAME(st.dbid) AS database_name,
    qs.execution_count,
    qs.total_logical_reads,
    qs.total_logical_writes,
    (qs.total_logical_reads + qs.total_logical_writes) AS total_logical_io,
    (qs.total_logical_reads / qs.execution_count) AS avg_logical_reads,
    (qs.total_logical_writes / qs.execution_count) AS avg_logical_writes,
    SUBSTRING(
        st.text,
        (qs.statement_start_offset / 2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset) / 2) + 1
    ) AS query_text,
    st.text AS full_batch_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY total_logical_io DESC;
