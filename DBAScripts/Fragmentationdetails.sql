use DXC
go

SELECT
    DB_NAME() AS database_name,
    s.name AS schema_name,
    o.name AS table_name,
    i.name AS index_name,
    i.index_id,
    i.type_desc AS index_type,
    ips.avg_fragmentation_in_percent,
    ips.fragment_count,
    ips.avg_fragment_size_in_pages,
    ips.page_count,
    ips.alloc_unit_type_desc
FROM sys.dm_db_index_physical_stats
    (DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i
    ON ips.object_id = i.object_id
   AND ips.index_id = i.index_id
JOIN sys.objects o
    ON ips.object_id = o.object_id
JOIN sys.schemas s
    ON o.schema_id = s.schema_id
WHERE o.type = 'U'     -- user tables only
ORDER BY ips.avg_fragmentation_in_percent DESC;
