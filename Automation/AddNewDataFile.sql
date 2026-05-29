USE [dba]
GO

/****** Object:  StoredProcedure [dbo].[usp_AddNewDataFile]    Script Date: 29-05-2026 12:32:09 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[usp_AddNewDataFile]
(
    @DatabaseName SYSNAME
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @SQL NVARCHAR(MAX),
        @BaseName SYSNAME,
        @NewFileName SYSNAME,
        @FilePath NVARCHAR(4000),
        @NextFileNumber INT,
        @PhysicalName NVARCHAR(4000);

    ------------------------------------------------------------
    -- Step 1: Get Primary Data File (to derive base name + path)
    ------------------------------------------------------------
    SET @SQL = '
    SELECT TOP 1 
        name,
        physical_name
    FROM [' + @DatabaseName + '].sys.database_files
    WHERE type_desc = ''ROWS''
    ORDER BY file_id;
    ';

    DECLARE @FileTable TABLE
    (
        name SYSNAME,
        physical_name NVARCHAR(4000)
    );

    INSERT INTO @FileTable
    EXEC(@SQL);

    IF NOT EXISTS (SELECT 1 FROM @FileTable)
    BEGIN
        RAISERROR('No data files found in database.', 16, 1);
        RETURN;
    END

    SELECT 
        @BaseName = name,
        @PhysicalName = physical_name
    FROM @FileTable;

    ------------------------------------------------------------
    -- Step 2: Extract base name (remove numbering if exists)
    ------------------------------------------------------------
    -- Example: Test, Test1, Test_2 → Base = Test
    SET @BaseName = 
        LEFT(@BaseName,
            CASE 
                WHEN PATINDEX('%[0-9]%', @BaseName) > 0 
                THEN PATINDEX('%[0-9]%', @BaseName) - 1
                WHEN CHARINDEX('_', @BaseName) > 0
                THEN CHARINDEX('_', @BaseName) - 1
                ELSE LEN(@BaseName)
            END
        );

    ------------------------------------------------------------
    -- Step 3: Extract file path (same as existing)
    ------------------------------------------------------------
    SELECT 
        @FilePath = LEFT(@PhysicalName, LEN(@PhysicalName) - CHARINDEX('\', REVERSE(@PhysicalName)));

    ------------------------------------------------------------
    -- Step 4: Find next available file number
    ------------------------------------------------------------
SET @SQL = '
SELECT @NextFileNumber = ISNULL(MAX(
    TRY_CAST(
        SUBSTRING(name, LEN(''' + @BaseName + ''') + 1, LEN(name))
    AS INT)
), 0) + 1
FROM [' + @DatabaseName + '].sys.database_files
WHERE name LIKE ''' + @BaseName + '%''
AND TRY_CAST(
        SUBSTRING(name, LEN(''' + @BaseName + ''') + 1, LEN(name))
    AS INT) IS NOT NULL;';

    EXEC sp_executesql 
        @SQL,
        N'@NextFileNumber INT OUTPUT',
        @NextFileNumber OUTPUT;

    ------------------------------------------------------------
    -- Step 5: Construct new file name
    ------------------------------------------------------------
    SET @NewFileName = @BaseName + CAST(@NextFileNumber AS VARCHAR);

    ------------------------------------------------------------
    -- Step 6: Add new file (2 TB, 50 GB growth)
    ------------------------------------------------------------
    SET @SQL = '
    ALTER DATABASE [' + @DatabaseName + '] ADD FILE
    (
        NAME = [' + @NewFileName + '],
        FILENAME = ''' + @FilePath + '\' + @NewFileName + '.ndf'',
        SIZE = 20MB,       -- 2 TB
        FILEGROWTH = 5MB    -- 50 GB
    ) TO FILEGROUP [PRIMARY];';

    EXEC(@SQL);

END
GO


