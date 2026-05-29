SET NOCOUNT ON;
SELECT  
    @@SERVERNAME AS [ServerName],
    sqlserver_start_time AS [SQL_Server_Start_Time],
    GETDATE() AS [Current_Time],
    DATEDIFF(DAY, sqlserver_start_time, GETDATE()) AS [Uptime_Days],
    DATEDIFF(HOUR, sqlserver_start_time, GETDATE()) AS [Uptime_Hours],
    DATEDIFF(MINUTE, sqlserver_start_time, GETDATE()) AS [Uptime_Minutes]
FROM sys.dm_os_sys_info;
