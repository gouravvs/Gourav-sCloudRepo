USE [GB]
GO

/****** Object:  StoredProcedure [dbo].[AlertFailedLogins]    Script Date: 23-11-2025 02:34:21 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- 3. Alert Filtering Logic A: ALL LOGIN FAILURES (Critical)
CREATE  or Alter  PROCEDURE [dbo].[AlertFailedLogins]
@AlertMessage NVARCHAR(MAX) OUTPUT -- New OUTPUT Parameter
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FailCount INT = 0;
    SELECT @FailCount = COUNT(*)  
    FROM [dbo].[Auditlogs]
    WHERE succeeded = 0 AND action_id IN ('LGIF', 'LGF'); -- Ensure to capture common failed login codes 

-- Initialize the OUTPUT parameter
    SET @AlertMessage = NULL;

    IF @FailCount > 0
    BEGIN
        DECLARE @FailedLoginsMsg NVARCHAR(MAX)= N'Failed Login Summary:';
        DECLARE @NewLine CHAR(2) = CHAR(13) + CHAR(10);
     -- a summary message with details of the latest login failures
        SELECT TOP 1000 @FailedLoginsMsg =  
            @FailedLoginsMsg + @NewLine +  
            'User: ' + ISNULL(server_principal_name, 'N/A') +  
            ', Time: ' + CONVERT(NVARCHAR(30), event_time, 120) +
            ', HostName: ' + ISNULL(host_name , 'N/A') +
            ', Application: ' + ISNULL(application_name , 'N/A') +
            ', ErrorMsg: ' + ISNULL(statement, 'N/A')
        FROM [dbo].[Auditlogs]
        WHERE succeeded = 0 AND action_id IN ('LGIF', 'LGF')
        ORDER BY event_time DESC;

        -- *** Pass the completed message back via the OUTPUT parameter ***
        SET @AlertMessage = @FailedLoginsMsg;

       RETURN 0; -- Success, and message is ready

    END
    -- If no failures, ensure the message is NULL
    RETURN 0;
END
GO


