--1. Logging Table (Mandatory)
IF OBJECT_ID('dbo.FileGrowthAudit') IS NULL
BEGIN
    CREATE TABLE dbo.FileGrowthAudit
    (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        DatabaseName SYSNAME,
        FileName SYSNAME,
        FileSizeGB DECIMAL(18,2),
        ActionTaken VARCHAR(100),
        NewFileName SYSNAME NULL,
        ExecutionTime DATETIME DEFAULT GETDATE(),
        Remarks VARCHAR(500)
    );
END
GO
--2. Stored Procedure (Core Logic)

CREATE OR ALTER PROCEDURE dbo.usp_ManageFileRollover
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @DBName SYSNAME = DB_NAME(),
        @ThresholdGB BIGINT = 5120, -- 5 TB
        @FileName SYSNAME,
        @SizeGB DECIMAL(18,2),
        @FilePath NVARCHAR(4000),
        @NewFileName SYSNAME,
        @SQL NVARCHAR(MAX),
        @FileID INT;

    ---------------------------------------------------
    -- Step 1: Get largest ACTIVE file (autogrowth ON)
    ---------------------------------------------------
    SELECT TOP 1
        @FileName = name,
        @SizeGB = size * 8.0 / 1024 / 1024,
        @FileID = file_id
    FROM sys.database_files
    WHERE type_desc = 'ROWS'
      AND growth > 0  -- only active growing file
    ORDER BY size DESC;

    IF @FileName IS NULL
        RETURN;

    ---------------------------------------------------
    -- Step 2: Check threshold
    ---------------------------------------------------
    IF @SizeGB < @ThresholdGB
    BEGIN
        INSERT INTO dbo.FileGrowthAudit
        VALUES (@DBName, @FileName, @SizeGB, 'NO_ACTION', NULL, DEFAULT, 'Below threshold');

        RETURN;
    END

    ---------------------------------------------------
    -- Step 3: Get file path (Cloud SQL safe)
    ---------------------------------------------------
    SELECT TOP 1 
        @FilePath = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)))
    FROM sys.database_files
    WHERE name = @FileName;

    ---------------------------------------------------
    -- Step 4: Disable autogrowth
    ---------------------------------------------------
    SET @SQL = '
    ALTER DATABASE [' + @DBName + '] 
    MODIFY FILE (NAME = [' + @FileName + '], FILEGROWTH = 0)';
    
    EXEC(@SQL);

    ---------------------------------------------------
    -- Step 5: Generate next file name (sequential)
    ---------------------------------------------------
    DECLARE @NextFileNumber INT;

    SELECT @NextFileNumber = ISNULL(MAX(
        TRY_CAST(REPLACE(name, 'IFM_IDB_', '') AS INT)
    ), 1) + 1
    FROM sys.database_files
    WHERE name LIKE 'IFM_IDB_%';

    SET @NewFileName = 'IFM_IDB_' + CAST(@NextFileNumber AS VARCHAR);

    ---------------------------------------------------
    -- Step 6: Add new file
    ---------------------------------------------------
    SET @SQL = '
    ALTER DATABASE [' + @DBName + '] ADD FILE
    (
        NAME = [' + @NewFileName + '],
        FILENAME = ''' + @FilePath + '\' + @NewFileName + '.ndf'',
        SIZE = 10240MB,
        FILEGROWTH = 512MB
    ) TO FILEGROUP [PRIMARY]';

    EXEC(@SQL);

    ---------------------------------------------------
    -- Step 7: Log success
    ---------------------------------------------------
    INSERT INTO dbo.FileGrowthAudit
    VALUES (@DBName, @FileName, @SizeGB, 'ROLLOVER_DONE', @NewFileName, DEFAULT, 'New file added successfully');

END

--#. SQL Agent Job
EXEC dbo.usp_ManageFileRollover;