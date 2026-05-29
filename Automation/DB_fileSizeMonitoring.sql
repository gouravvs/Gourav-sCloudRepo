
------------------------------------------------------------------------------------------------------------
---- 1. Create a Logging table to log the DB size every day 
------------------------------------------------------------------------------------------------------------
USE dba;
GO

CREATE TABLE dbo.DB_FileSize_Log
(
    LogID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CaptureTime DATETIME2 DEFAULT SYSDATETIME(),

    DatabaseName SYSNAME,
    FileName SYSNAME,
    FileType VARCHAR(10),

    TotalSizeMB DECIMAL(18,2),
    UsedSpaceMB DECIMAL(18,2),
    FreeSpaceMB DECIMAL(18,2),
    FreePercent DECIMAL(10,2),

    AutogrowthEnabled VARCHAR(5),
    AutogrowthValue VARCHAR(20),

    SpaceStatus VARCHAR(10),
    RecommendedSizeMB VARCHAR(20),
    AdditionalGrowthNeededMB VARCHAR(20),
    FreePercent_AfterResize VARCHAR(20),

    ServerName SYSNAME DEFAULT @@SERVERNAME
);
GO

-- Optional to create an index important for retention cleanup performance
CREATE INDEX IX_DB_FileSize_Log_CaptureTime
ON dbo.DB_FileSize_Log (CaptureTime);
-----------------------------------------------------------------------------------------------------------------------------------------
------2. Full Job script (Run the script to create the job includes all three steps and job schedule )
-----------------------------------------------------------------------------------------------------------------------------------------
USE [msdb]
GO

/****** Object:  Job [DB_FreeSpaceStatus]    Script Date: 27-03-2026 15:22:34 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 27-03-2026 15:22:34 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DB_FreeSpaceStatus', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job runs a script to check the free space on each database and save the status each day in a Log table in dba database . The Job is in two steps , First step being collecting the DB size status and inserting it into the logging table ... Second step is to manage the retention period and make it 7 days . Logs older that 7 days are deleted from the logging table .', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DB_size_status]    Script Date: 27-03-2026 15:22:34 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DB_size_status', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE dba;
GO

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
);
---------------------------------------------------
-- Loop through ONLINE databases only
---------------------------------------------------
DECLARE @DBName SYSNAME;
DECLARE @SQL NVARCHAR(MAX);

DECLARE db_cursor CURSOR FOR
SELECT name
FROM sys.databases
WHERE state = 0   -- ONLINE only
--AND database_id NOT IN (1,3,4); -- : skip system DBs master ,model,msdb

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DBName;

WHILE @@FETCH_STATUS = 0
BEGIN

    SET @SQL = ''
    USE ['' + @DBName + ''];

    DECLARE @LogSizeMB DECIMAL(18,4);
    DECLARE @LogUsedMB DECIMAL(18,4);

    SELECT 
        @LogSizeMB = total_log_size_in_bytes/1024.0/1024.0,
        @LogUsedMB = used_log_space_in_bytes/1024.0/1024.0
    FROM sys.dm_db_log_space_usage;

    INSERT INTO #DBFileDetails
    SELECT
        DB_NAME(),
        name,
        type_desc,
        size/128.0,

        CASE 
            WHEN type_desc = ''''ROWS''''
            THEN FILEPROPERTY(name,''''SpaceUsed'''')/128.0
            ELSE @LogUsedMB
        END,

        CASE 
            WHEN type_desc = ''''ROWS''''
            THEN (size - FILEPROPERTY(name,''''SpaceUsed''''))/128.0
            ELSE (@LogSizeMB - @LogUsedMB)
        END,

        CASE 
            WHEN type_desc = ''''ROWS''''
            THEN ((size - FILEPROPERTY(name,''''SpaceUsed''''))*100.0/size)
            ELSE ((@LogSizeMB - @LogUsedMB)*100.0/NULLIF(@LogSizeMB,0))
        END,

        CASE 
            WHEN growth = 0 THEN ''''NO''''
            ELSE ''''YES''''
        END,

        CASE 
            WHEN is_percent_growth = 1 
                THEN CAST(growth AS VARCHAR) + '''' %''''
            ELSE CAST(growth/128 AS VARCHAR) + '''' MB''''
        END

    FROM sys.database_files;
    '';

    EXEC (@SQL);

    FETCH NEXT FROM db_cursor INTO @DBName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;


---------------------------------------------------
-- Insert into logging table 
---------------------------------------------------
INSERT INTO dba.dbo.DB_FileSize_Log
(
    DatabaseName,
    FileName,
    FileType,
    TotalSizeMB,
    UsedSpaceMB,
    FreeSpaceMB,
    FreePercent,
    AutogrowthEnabled,
    AutogrowthValue,
    SpaceStatus,
    RecommendedSizeMB,
    AdditionalGrowthNeededMB,
    FreePercent_AfterResize
)
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
        WHEN FreePercent < 20 THEN ''CRITICAL''
        ELSE ''OK''
    END AS SpaceStatus,

    CASE 
        WHEN FreePercent < 20 
        THEN CAST(CAST((UsedSpaceMB / 0.80) AS DECIMAL(18,2)) AS VARCHAR(20))
        ELSE ''Not Required''
    END AS RecommendedSizeMB,

    CASE 
        WHEN FreePercent < 20 
        THEN CAST(CAST((UsedSpaceMB / 0.80) - TotalSizeMB AS DECIMAL(18,2)) AS VARCHAR(20))
        ELSE ''Not Required''
    END AS AdditionalGrowthNeededMB,

    CASE 
        WHEN FreePercent < 20 
        THEN CAST(
                CAST(((UsedSpaceMB / 0.80) - UsedSpaceMB) * 100.0 / (UsedSpaceMB / 0.80) 
                AS DECIMAL(10,2)) 
             AS VARCHAR(20))
        ELSE ''Not Required''
    END AS FreePercent_AfterResize

FROM #DBFileDetails
ORDER BY 
    DatabaseName,
    CASE 
        WHEN FileType = ''ROWS'' THEN 1
        WHEN FileType = ''LOG''  THEN 2
    END;

DROP TABLE #DBFileDetails;
GO', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Alertlogstep]    Script Date: 27-03-2026 15:22:34 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Alertlogstep', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @Message NVARCHAR(MAX) = '''';

SELECT @Message = @Message + 
    ''DB: '' + DatabaseName + 
    '', File: '' + FileName + 
    '', Free%: '' + CAST(FreePercent AS VARCHAR(10)) + CHAR(10)
FROM dba.dbo.DB_FileSize_Log
WHERE CaptureTime > DATEADD(MINUTE, -30, SYSDATETIME())
AND SpaceStatus = ''CRITICAL'';

IF @Message <> ''''
BEGIN
    RAISERROR (
        ''CRITICAL WARNING DATA FILE SPACE ALERTS: %s'',
        10,
        1,
        @Message
    ) WITH LOG;
END', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Logging table retention]    Script Date: 27-03-2026 15:22:34 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Logging table retention', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'---------------------------------------------------
-- Retention: Keep only last 7 days
---------------------------------------------------
DELETE FROM dba.dbo.DB_FileSize_Log
WHERE CaptureTime < DATEADD(DAY, -7, SYSDATETIME());', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'SizeStatusschedulde', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20260327, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'43c70a2b-570d-4b92-9764-f34063ed76e5'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


