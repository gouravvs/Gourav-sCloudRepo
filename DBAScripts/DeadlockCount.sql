;WITH Deadlocks AS
(
    SELECT
        xevent.value('(event/@timestamp)[1]', 'datetime2') AS deadlock_time
    FROM
    (
        SELECT CAST(target_data AS XML) AS target_data
        FROM sys.dm_xe_session_targets t
        JOIN sys.dm_xe_sessions s
            ON s.address = t.event_session_address
        WHERE s.name = 'system_health'
          AND t.target_name = 'ring_buffer'
    ) AS src
    CROSS APPLY target_data.nodes('//RingBufferTarget/event[@name="xml_deadlock_report"]') AS x(xevent)
)
SELECT
    CAST(deadlock_time AS DATE) AS deadlock_date,
    COUNT(*) AS deadlock_count
FROM Deadlocks
WHERE deadlock_time >= DATEADD(DAY, -1, GETDATE())
GROUP BY CAST(deadlock_time AS DATE)
ORDER BY deadlock_date DESC;
