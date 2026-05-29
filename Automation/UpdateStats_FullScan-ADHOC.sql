USE [dba]
GO

/****** Object:  StoredProcedure [dbo].[usp_UpdateStats_FullScan_MultipleTables]    Script Date: 29-05-2026 12:39:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_UpdateStats_FullScan_MultipleTables]
(
    @DatabaseName SYSNAME,
    @TableList NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TableName NVARCHAR(300);
    DECLARE @SchemaName SYSNAME;
    DECLARE @OnlyTableName SYSNAME;
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @Msg NVARCHAR(1000);  -- IMPORTANT

    IF OBJECT_ID('tempdb..#Tables') IS NOT NULL 
        DROP TABLE #Tables;

    CREATE TABLE #Tables
    (
        TableFullName NVARCHAR(300)
    );

    INSERT INTO #Tables
    SELECT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(@TableList, ',');

    DECLARE table_cursor CURSOR FOR
    SELECT TableFullName FROM #Tables;

    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @TableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SchemaName = ISNULL(PARSENAME(@TableName, 2), 'dbo');
        SET @OnlyTableName = PARSENAME(@TableName, 1);

        IF @OnlyTableName IS NULL
        BEGIN
            SET @Msg = 'Invalid table format: ' + @TableName;
            RAISERROR(@Msg, 0, 1) WITH NOWAIT;

            FETCH NEXT FROM table_cursor INTO @TableName;
            CONTINUE;
        END

        SET @Msg = '=========================================';
        RAISERROR(@Msg, 0, 1) WITH NOWAIT;

        SET @Msg = 'Starting: ' + @SchemaName + '.' + @OnlyTableName;
        RAISERROR(@Msg, 0, 1) WITH NOWAIT;

        SET @Msg = 'Start Time: ' + CONVERT(VARCHAR(19), GETDATE(), 120);
        RAISERROR(@Msg, 0, 1) WITH NOWAIT;

        SET @SQL =
            'UPDATE STATISTICS '
            + QUOTENAME(@DatabaseName) + '.'
            + QUOTENAME(@SchemaName) + '.'
            + QUOTENAME(@OnlyTableName)
            + ' WITH FULLSCAN;';

        SET @Msg = 'Executing: ' + @SQL;
        RAISERROR(@Msg, 0, 1) WITH NOWAIT;

        BEGIN TRY
            EXEC sp_executesql @SQL;

            SET @Msg = 'Completed: ' + @SchemaName + '.' + @OnlyTableName;
            RAISERROR(@Msg, 0, 1) WITH NOWAIT;
        END TRY
        BEGIN CATCH
            SET @Msg = 'FAILED: ' + @SchemaName + '.' + @OnlyTableName;
            RAISERROR(@Msg, 0, 1) WITH NOWAIT;

            SET @Msg = ERROR_MESSAGE();
            RAISERROR(@Msg, 0, 1) WITH NOWAIT;
        END CATCH

        SET @Msg = 'End Time: ' + CONVERT(VARCHAR(19), GETDATE(), 120);
        RAISERROR(@Msg, 0, 1) WITH NOWAIT;

        FETCH NEXT FROM table_cursor INTO @TableName;
    END

    CLOSE table_cursor;
    DEALLOCATE table_cursor;
END
GO


