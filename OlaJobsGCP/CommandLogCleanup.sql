USE [dba]
GO
WHILE 1 = 1
BEGIN
    DELETE TOP (10000)
    FROM dbo.CommandLog
    WHERE StartTime < DATEADD(DAY, -60, GETDATE());

    IF @@ROWCOUNT = 0
        BREAK;

    WAITFOR DELAY '00:00:01';
END;
