SELECT TOP 25

    qsq.query_id,

    qsqt.query_sql_text,

    ws.wait_category_desc,

    SUM(ws.total_query_wait_time_ms) AS total_wait_ms,

    SUM(ws.avg_query_wait_time_ms * ws.total_query_wait_time_ms) / NULLIF(SUM(ws.total_query_wait_time_ms),0) AS weighted_avg_wait_ms,

    MAX(rsi.end_time) AS last_seen

FROM sys.query_store_wait_stats ws

JOIN sys.query_store_plan qsp ON ws.plan_id = qsp.plan_id

JOIN sys.query_store_query qsq ON qsp.query_id = qsq.query_id

JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id

JOIN sys.query_store_runtime_stats_interval rsi ON ws.runtime_stats_interval_id = rsi.runtime_stats_interval_id

WHERE ws.wait_category_desc = 'Buffer IO'

  AND rsi.start_time >= DATEADD(HOUR, -1, GETUTCDATE())

GROUP BY qsq.query_id, qsqt.query_sql_text, ws.wait_category_desc

ORDER BY total_wait_ms DESC;
 