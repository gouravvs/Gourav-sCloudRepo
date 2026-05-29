USE [GB]
GO

/****** Object:  StoredProcedure [dbo].[AuditIngestion]    Script Date: 23-11-2025 02:32:45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE or Alter  PROCEDURE [dbo].[AuditIngestion]
AS
BEGIN
    SET NOCOUNT ON;
-- The time window for logs to process (e.g., last 12 hour)
    DECLARE @TimeWindowStart DATETIME2(7) = DATEADD(hour, -12, GETDATE());  
 -- 1. Clear the staging table  
    TRUNCATE TABLE [dbo].[Auditlogs]; -- Clear the staging table
    -- Select * from [dbo].[Auditlogs]

-- 2. Read the audit logs from source and insert into the staging table ([dbo].[Auditlogs])
    -- We are reading from the /var/opt/mssql/audit/* source location which is local to the Cloud SQL instance.
    -- The msdb.dbo.gcloudsql_fn_get_audit_file function reads the .sqlaudit files in the Cloud SQL file system.
   
    INSERT INTO [dbo].[Auditlogs] (
        [event_time], [session_id],[server_principal_name],[action_id],[succeeded],[client_ip],[host_name],
        [Application_name],[statement]
        )
    Select event_time,session_id,server_principal_name, action_id,
    succeeded, client_ip,host_name, application_name, statement
    FROM msdb.dbo.gcloudsql_fn_get_audit_file('/var/opt/mssql/audit/*', NULL, NULL) AS AuditData
    WHERE AuditData.event_time >= @TimeWindowStart -- Only process new logs since the last run 
    AND (AuditData.succeeded = 0 OR AuditData.action_id IN ('LGIS', 'LGIF'))-- Filter only sucess and failed logins
    AND action_id <> 'AUSC'; --excluded this event as its the Audit creation event
END
GO


