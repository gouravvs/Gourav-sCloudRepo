SET NOCOUNT ON;
SELECT  
    servicename,
    startup_type_desc AS [Startup_Type],
    status_desc AS [Current_Status],
    last_startup_time,
    service_account
FROM sys.dm_server_services
where servicename like '%Agent%'
ORDER BY servicename;
