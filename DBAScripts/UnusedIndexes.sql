use Dxc
go
SELECT
    DB_NAME() AS database_name,
    s.name AS schema_name,
    o.name AS table_name,
    i.name AS index_name,
    i.index_id,
    i.type_desc AS index_type,
    COALESCE(us.user_seeks, 0) AS user_seeks,
    COALESCE(us.user_scans, 0) AS user_scans,
    COALESCE(us.user_lookups, 0) AS user_lookups,
    COALESCE(us.user_updates, 0) AS user_updates,
    (COALESCE(us.user_seeks, 0)
     + COALESCE(us.user_scans, 0)
     + COALESCE(us.user_lookups, 0)) AS total_reads,
    CASE
        WHEN (COALESCE(us.user_seeks, 0)
            + COALESCE(us.user_scans, 0)
            + COALESCE(us.user_lookups, 0)) = 0
        THEN 'UNUSED'
        ELSE 'USED'
    END AS index_usage_status
FROM sys.indexes i
JOIN sys.objects o
    ON i.object_id = o.object_id
JOIN sys.schemas s
    ON o.schema_id = s.schema_id
LEFT JOIN sys.dm_db_index_usage_stats us
    ON i.object_id = us.object_id
   AND i.index_id = us.index_id
   AND us.database_id = DB_ID()
WHERE
    o.type = 'U'                     -- user tables
    AND i.index_id > 0               -- exclude heaps
    AND i.is_primary_key = 0         -- keep PKs
    AND i.is_unique_constraint = 0   -- keep unique constraints
ORDER BY total_reads ASC, user_updates DESC;
