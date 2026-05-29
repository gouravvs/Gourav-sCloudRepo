SET NOCOUNT ON;
-- OS memory information
SELECT
    total_physical_memory_kb / 1024 AS [OS_Total_Memory_MB],
    available_physical_memory_kb / 1024 AS [OS_Available_Memory_MB],
    system_memory_state_desc AS [OS_Memory_State]
INTO #OSMemory
FROM sys.dm_os_sys_memory;

-- SQL Server memory configuration (explicit conversion)
SELECT
    name,
    CONVERT(BIGINT, value_in_use) AS [Configured_Value_MB]
INTO #SQLMemory
FROM sys.configurations
WHERE name IN ('min server memory (MB)', 'max server memory (MB)');

-- Final combined view
SELECT
    o.OS_Total_Memory_MB,
    o.OS_Available_Memory_MB,
    smin.Configured_Value_MB AS [SQL_Min_Memory_MB],
    smax.Configured_Value_MB AS [SQL_Max_Memory_MB],
    (o.OS_Total_Memory_MB - smax.Configured_Value_MB) AS [Memory_Left_For_OS_MB]
FROM #OSMemory o
CROSS JOIN #SQLMemory smin
CROSS JOIN #SQLMemory smax
WHERE smin.name = 'min server memory (MB)'
  AND smax.name = 'max server memory (MB)';
DROP TABLE #OSMemory;
DROP TABLE #SQLMemory;
