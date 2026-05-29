USE YourDatabase;
GO

SELECT
    s.name              AS stats_name,
    s.auto_created,
    s.user_created,
    s.has_filter,
    s.filter_definition,
    c.name              AS column_name
FROM sys.stats s
JOIN sys.stats_columns sc
    ON s.object_id = sc.object_id
   AND s.stats_id = sc.stats_id
JOIN sys.columns c
    ON sc.object_id = c.object_id
   AND sc.column_id = c.column_id
JOIN sys.objects o
    ON s.object_id = o.object_id
JOIN sys.schemas sch
    ON o.schema_id = sch.schema_id
    --Mention schema name , table name and column name
WHERE sch.name = 'YourSchema'
  AND o.name   = 'YourTable'
  AND c.name   = 'YourColumn';
