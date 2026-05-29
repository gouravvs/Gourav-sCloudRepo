use DXC 
go
SELECT
    DB_NAME(mid.database_id) AS database_name,
    OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id) AS schema_name,
    OBJECT_NAME(mid.object_id, mid.database_id) AS table_name,
    migs.user_seeks,
    migs.user_scans,
    migs.avg_total_user_cost,
    migs.avg_user_impact,
    (migs.user_seeks + migs.user_scans)
        * migs.avg_total_user_cost
        * (migs.avg_user_impact / 100.0) AS estimated_improvement_score,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id, mid.database_id)
        + '_' + REPLACE(ISNULL(mid.equality_columns, ''), ', ', '_')
        + ' ON '
        + OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id)
        + '.' + OBJECT_NAME(mid.object_id, mid.database_id)
        + ' (' + ISNULL(mid.equality_columns, '')
        + CASE
            WHEN mid.equality_columns IS NOT NULL
             AND mid.inequality_columns IS NOT NULL
            THEN ', '
            ELSE ''
          END
        + ISNULL(mid.inequality_columns, '') + ')'
        + ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement
FROM sys.dm_db_missing_index_group_stats migs
JOIN sys.dm_db_missing_index_groups mig
    ON migs.group_handle = mig.index_group_handle
JOIN sys.dm_db_missing_index_details mid
    ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY estimated_improvement_score DESC;
