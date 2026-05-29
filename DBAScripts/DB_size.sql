CREATE TABLE #DBFileDetails
(
DatabaseName SYSNAME,
FileName SYSNAME,
FileType VARCHAR(10),
TotalSizeMB DECIMAL(18,2),
UsedSpaceMB DECIMAL(18,2),
FreeSpaceMB DECIMAL(18,2),
FreePercent DECIMAL(10,2),
AutogrowthEnabled VARCHAR(5),
AutogrowthValue VARCHAR(20)
)

EXEC sp_MSforeachdb '
USE [?]

DECLARE @LogSizeMB DECIMAL(18,4)
DECLARE @LogUsedMB DECIMAL(18,4)

SELECT 
    @LogSizeMB = total_log_size_in_bytes/1024.0/1024.0,
    @LogUsedMB = used_log_space_in_bytes/1024.0/1024.0
FROM sys.dm_db_log_space_usage

INSERT INTO #DBFileDetails
SELECT
    DB_NAME(),
    name,
    type_desc,

    size/128.0,

    CASE 
        WHEN type_desc = ''ROWS''
        THEN FILEPROPERTY(name,''SpaceUsed'')/128.0
        ELSE @LogUsedMB
    END,

    CASE 
        WHEN type_desc = ''ROWS''
        THEN (size - FILEPROPERTY(name,''SpaceUsed''))/128.0
        ELSE (@LogSizeMB - @LogUsedMB)
    END,

    CASE 
        WHEN type_desc = ''ROWS''
        THEN ((size - FILEPROPERTY(name,''SpaceUsed''))*100.0/size)
        ELSE ((@LogSizeMB - @LogUsedMB)*100.0/@LogSizeMB)
    END,

    CASE 
        WHEN growth = 0 THEN ''NO''
        ELSE ''YES''
    END,

    CASE 
        WHEN is_percent_growth = 1 
            THEN CAST(growth AS VARCHAR) + '' %''
        ELSE CAST(growth/128 AS VARCHAR) + '' MB''
    END

FROM sys.database_files
'
SELECT 
    DatabaseName,
    FileName,
    FileType,
    TotalSizeMB,
    UsedSpaceMB,
    FreeSpaceMB,
    FreePercent,
	   AutogrowthEnabled,
    AutogrowthValue,

    CASE 
        WHEN FreePercent < 20 THEN 'CRITICAL'
        ELSE 'OK'
    END AS SpaceStatus,

    CASE 
        WHEN FreePercent < 20 
        THEN CAST(CAST((UsedSpaceMB / 0.80) AS DECIMAL(18,2)) AS VARCHAR(20))
        ELSE 'Not Required'
    END AS RecommendedSizeMB,

    CASE 
        WHEN FreePercent < 20 
        THEN CAST(CAST((UsedSpaceMB / 0.80) - TotalSizeMB AS DECIMAL(18,2)) AS VARCHAR(20))
        ELSE 'Not Required'
    END AS AdditionalGrowthNeededMB,

    CASE 
        WHEN FreePercent < 20 
        THEN CAST(
                CAST(((UsedSpaceMB / 0.80) - UsedSpaceMB) * 100.0 / (UsedSpaceMB / 0.80) 
                AS DECIMAL(10,2)) 
             AS VARCHAR(20))
        ELSE 'Not Required'
    END AS FreePercent_AfterResize

 

FROM #DBFileDetails

ORDER BY 
    DatabaseName,
    CASE 
        WHEN FileType = 'ROWS' THEN 1
        WHEN FileType = 'LOG'  THEN 2
    END;
DROP TABLE #DBFileDetails