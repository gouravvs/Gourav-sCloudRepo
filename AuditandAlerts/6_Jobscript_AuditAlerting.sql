USE [msdb]
GO

/****** Object:  Job [AuditAlerting]    Script Date: 23-11-2025 02:39:08 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 23-11-2025 02:39:08 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'AuditAlerting', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Data Collector', 
		--change owner according to your requirement
		@owner_login_name=N'sqlserver', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [AuditLogIngestion]    Script Date: 23-11-2025 02:39:08 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'AuditLogIngestion', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=2, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE GB
GO
-- Job Step 1: Ingest Audit Data
DECLARE @Result INT;

-- 1. Execute the procedure and capture the return code
EXEC @Result = dbo.AuditIngestion; 
 
-- 2. Check for a non-zero return code (failure)
IF @Result <> 0 
BEGIN 
	-- Raise an error with Severity 16. This is CRITICAL.
    -- Severity 16 forces the SQL Agent job step to fail and halts the entire job.
	RAISERROR(''CRITICAL: Audit Ingestion failed with return code %d. Job Halted. Check Cloud Logs.'', 16, 1, @Result);
END

-- Note: If @Result is 0 (Success), the job proceeds automatically to the next step.', 
		@database_name=N'GB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [AlertFailedLogins]    Script Date: 23-11-2025 02:39:09 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'AlertFailedLogins', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=3, 
		@on_fail_action=4, 
		@on_fail_step_id=3, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'use GB
go
-- Job Step 2: Alert Failed Logins
DECLARE @Result INT;
DECLARE @FailureMessage NVARCHAR(MAX); -- Variable to hold the message output

-- 1. Execute the procedure, capturing the return code AND the message
EXEC @Result = dbo.AlertFailedLogins @AlertMessage = @FailureMessage OUTPUT; 
 
-- 2. If the procedure succeeded (Result = 0) BUT generated a message:
IF @Result = 0 AND @FailureMessage IS NOT NULL
BEGIN
    -- Log the summary message as an ERROR (Severity 16)
    RAISERROR(@FailureMessage, 16, 1) with Log;
    -- This RAISERROR is guaranteed to be captured by the Cloud Logs 
    -- and will show up as a high-severity error.
END
-- 3. If the procedure FAILED (Result <> 0), halt the job
ELSE IF @Result <> 0
BEGIN
    RAISERROR(''CRITICAL: AlertFailedLogins procedure returned error code %d. Job Halted.'', 16, 1, @Result);
END', 
		@database_name=N'GB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [UnauthorizedAccess]    Script Date: 23-11-2025 02:39:09 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'UnauthorizedAccess', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE GB
GO
-- Job Step 3: Unauthorized Logins
DECLARE @Result INT;
DECLARE @FailureMessage NVARCHAR(MAX); -- Variable to hold the message output

-- 1. Execute the procedure, capturing the return code AND the message
EXEC @Result = dbo.AlertUnauthorizedAccess @AlertingMessage = @FailureMessage OUTPUT; 
 
-- 2. If the procedure succeeded (Result = 0) BUT generated a message:
IF @Result = 0 AND @FailureMessage IS NOT NULL
BEGIN
    -- Log the summary message as a WARNING (Severity 10)
    RAISERROR(@FailureMessage, 10, 1) WITH LOG;
END
-- 3. If the procedure FAILED (Result <> 0), halt the job
ELSE IF @Result <> 0
BEGIN
    --  Action: This alert should NOT halt the entire job.
    RAISERROR(''WARNING: AlertUnauthorozedAccess procedure returned error code %d. Alert incomplete.'', 10, 1, @Result);
END', 
		@database_name=N'GB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


