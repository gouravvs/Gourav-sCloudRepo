
---- To get the schema information which we will use to create audit table we can use the below queries , 
--SELECT *
--INTO #audit_columns
--FROM msdb.dbo.gcloudsql_fn_get_audit_file('/var/opt/mssql/audit/*', NULL, NULL)
--WHERE 1 = 0;   -- only schema, no data

--SELECT *
--FROM tempdb.INFORMATION_SCHEMA.COLUMNS
--WHERE TABLE_NAME LIKE '#audit_columns%' and COLUMN_NAME IN ('event_time','session_id',
--    'server_principal_name','succeeded','event_time','client_ip','host_name','application_name',
--    'statement','action_id')
--Drop table #audit_column

-- To Create an Audit table on the your database 
Use [GB]
Go
Create table dbo.Auditlogs (
[AuditLogID] BIGINT IDENTITY(1,1) NOT NULL,
[Event_Time] datetime2(7) NULL,
[session_id] smallint NULL,
[server_principal_name] nvarchar(128) NOT NULL,
[action_id] varchar(4) NULL,
succeeded bit NULL,
[client_ip] nvarchar(128) NULL,
[host_name] nvarchar(128) NULL,
[application_name] nvarchar(128) NULL,
[statement] nvarchar(4000) NULL
CONSTRAINT PK_Auditlogs PRIMARY KEY NONCLUSTERED (AuditLogID)
)
-- Creating a clustered Index on the Date and time columns so that data retrial would be fast 
CREATE CLUSTERED INDEX CIX_Auditlogs_EventTime
ON dbo.Auditlogs ([Event_Time] ASC);

--drop table dbo.Auditlogs


