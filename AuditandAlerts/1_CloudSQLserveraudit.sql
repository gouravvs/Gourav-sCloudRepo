-- 1. Create the Server Audit object

CREATE SERVER AUDIT [Audit_login] --- give the name of the Audit 
TO FILE 
(	FILEPATH = N'/var/opt/mssql/audit/' -- This is the internal Cloud SQL path which we have to always use 
	,MAXSIZE = 50 MB
	,MAX_ROLLOVER_FILES = UNLIMITED
	,RESERVE_DISK_SPACE = OFF
) WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE ) -- will flush the logs in every 1000ms or  1 sec 
-- exclude these below system logins to avoid the logs cluttering 
WHERE (NOT [server_principal_name] like 'NT SERV%' 
AND NOT [server_principal_name] like '##MS_Pol%' 
AND NOT [server_principal_name] like 'BUILTIN\%' 
AND NOT [server_principal_name] like 'CloudDbSql%' 
AND NOT [server_principal_name] like 'NT AUTHORITY\%')
GO

-- 2. Enable the Server Audit
ALTER SERVER AUDIT [Audit_login] WITH (STATE = ON);
GO

-- 3. Create the Server Audit Specification
CREATE SERVER AUDIT SPECIFICATION [Login_Alerts]
FOR SERVER AUDIT [Audit_login] -- Links to the audit created above
ADD (SUCCESSFUL_LOGIN_GROUP), -- for sucessfull logins 
ADD (FAILED_LOGIN_GROUP),       -- for failed logins
ADD (LOGOUT_GROUP)             -- for logouts 
WITH (STATE = OFF); --- to enable give state ON 
GO

-- to check the full logs recorded 

--SELECT * FROM msdb.dbo.gcloudsql_fn_get_audit_file('/var/opt/mssql/audit/*', NULL, NULL) 

--- To read the events from the outout file 
/*
 Select
    session_id,
    server_principal_name,
   CASE
        WHEN action_id = 'LGIS' THEN 'SUCCESSFUL LOGIN'
        WHEN action_id = 'LGIF' THEN 'FAILED LOGIN'
        WHEN action_id = 'LGO' THEN 'LOGOUT'
        ELSE 'OTHER EVENT (' + action_id + ')'
    END AS [Event Type],
    succeeded,
    event_time,
    client_ip,
    host_name,
    application_name,
    statement
    FROM msdb.dbo.gcloudsql_fn_get_audit_file('/var/opt/mssql/audit/*', NULL, NULL)
    WHERE action_id <> 'AUSC'--excluded this event as its the Audit creation event
ORDER BY
    event_time DESC;
    */