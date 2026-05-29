SET NOCOUNT ON;

DECLARE @StartTime DATETIME = DATEADD(HOUR, -190, GETDATE());

CREATE TABLE #ErrorLog
(
    LogDate     DATETIME,
    ProcessInfo NVARCHAR(50),
    Text        NVARCHAR(MAX)
);

INSERT INTO #ErrorLog
EXEC xp_readerrorlog 
    0,          -- current error log
    1,          -- SQL Server error log
    NULL,
    NULL,
    @StartTime,
    NULL,
    N'desc';

SELECT
    LogDate,
    ProcessInfo,
    Text
FROM #ErrorLog
WHERE
    Text LIKE '%error%'
 OR Text LIKE '%fail%'
 OR Text LIKE '%deadlock%'
 OR Text LIKE '%I/O%'
 OR Text LIKE '%corrupt%'
 OR Text LIKE '%stack dump%'
 OR Text LIKE '%timeout%'
 OR Text LIKE '%severity%'
ORDER BY LogDate DESC;

DROP TABLE #ErrorLog;
