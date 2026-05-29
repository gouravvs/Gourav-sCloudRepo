use DXC
go
SELECT
    DB_NAME() AS database_name,
    s.name AS schema_name,
    o.name AS table_name,
    st.name AS statistics_name,
    sp.last_updated,
    sp.rows,
    sp.rows_sampled,
    sp.modification_counter,
    CASE
        WHEN sp.last_updated IS NULL THEN 'NEVER UPDATED'
        WHEN sp.modification_counter > (sp.rows * 0.20) THEN 'STALE'
        ELSE 'OK'
    END AS stats_health_status
FROM sys.stats st
JOIN sys.objects o
    ON st.object_id = o.object_id
JOIN sys.schemas s
    ON o.schema_id = s.schema_id
CROSS APPLY sys.dm_db_stats_properties(st.object_id, st.stats_id) sp
WHERE o.type = 'U'     -- user tables only
ORDER BY sp.last_updated ASC;
