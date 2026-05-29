SET NOCOUNT ON;
;WITH JobLastRun AS
(
    SELECT
        j.job_id,
        j.name AS job_name,
        j.enabled,
        h.run_status,
        h.run_date,
        h.run_time,
        ROW_NUMBER() OVER (PARTITION BY j.job_id ORDER BY h.instance_id DESC) AS rn
    FROM msdb.dbo.sysjobs j
    LEFT JOIN msdb.dbo.sysjobhistory h
        ON j.job_id = h.job_id
        AND h.step_id = 0   -- job outcome
)
SELECT
    job_name,
    CASE enabled
        WHEN 1 THEN 'Enabled'
        ELSE 'Disabled'
    END AS job_status,
    CASE run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
        ELSE 'Never Run'
    END AS last_run_result,
    run_date,
    run_time
FROM JobLastRun
WHERE rn = 1
  AND (
        enabled = 0          -- disabled jobs
        OR run_status IN (0,2,4)  -- failed, retry, in-progress
      )
ORDER BY job_name;
