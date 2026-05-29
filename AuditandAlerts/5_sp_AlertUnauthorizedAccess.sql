USE [GB]
GO

/****** Object:  StoredProcedure [dbo].[AlertUnauthorizedAccess]    Script Date: 23-11-2025 02:38:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




 -- 4. Alert Filtering Logic B: SUCCESSFUL LOGIN FROM NON-WHITELISTED IP UnauthorozedAccess (Critical)
CREATE  or Alter  PROCEDURE [dbo].[AlertUnauthorizedAccess]
@AlertingMessage NVARCHAR(MAX) OUTPUT -- New OUTPUT Parameter

AS
BEGIN
    SET NOCOUNT ON;
     
    -- Define  internal whitelist of allowed/expected IP ranges for successful logins
    DECLARE @InternalIPs TABLE (ClientIP NVARCHAR(128));
    INSERT INTO @InternalIPs (ClientIP) 
    VALUES ('49.47.%'); -- Add your actual internal IP patterns
    
    DECLARE @UnauthorizedSuccessCount INT = 0;
    SELECT @UnauthorizedSuccessCount = COUNT(A.client_ip)  
    FROM [dbo].[Auditlogs] AS A
    WHERE A.succeeded = 1 AND A.action_id IN ('LGIS', 'LGS') -- Successful Login event codes
      -- Exclude IPs that match your internal/whitelisted IP patterns
    AND NOT EXISTS (
          SELECT 1 FROM @InternalIPs AS I
          WHERE A.client_ip LIKE I.ClientIP
      );
        
    -- Initialize the OUTPUT parameter
    SET @AlertingMessage = NULL;
    IF @UnauthorizedSuccessCount > 0
    BEGIN
        DECLARE @UnauthorizedLoginMsg NVARCHAR(MAX)=N'Unauthorized Access Summary:'
        DECLARE @NewLine CHAR(2) = CHAR(13) + CHAR(10);
        
        SELECT TOP 100 @UnauthorizedLoginMsg = 
            @UnauthorizedLoginMsg + @NewLine +  -- This inserts the line break
            'User: ' + ISNULL(server_principal_name, 'N/A') +  
            ', Time: ' + CONVERT(NVARCHAR(30), event_time, 120) +
            ', HostName: ' + ISNULL(host_name , 'N/A') +
            ', Application: ' + ISNULL(application_name , 'N/A')
        FROM [dbo].[Auditlogs] AS A
        WHERE A.succeeded = 1 AND A.action_id IN ('LGIS', 'LGS')
        AND NOT EXISTS (
              SELECT 1 FROM @InternalIPs AS I
              WHERE A.client_ip LIKE I.ClientIP
          )
        ORDER BY event_time DESC;

    -- *** Pass the completed message back via the OUTPUT parameter ***
        SET @AlertingMessage = @UnauthorizedLoginMsg;

       RETURN 0; -- Success, and message is ready

    END
    -- If no failures, ensure the message is NULL
    RETURN 0;
END
GO


