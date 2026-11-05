USE retailrocket;

-- 1. 每位访客每天只保留一条活跃记录
CREATE TABLE visitor_daily_activity AS
SELECT DISTINCT
    visitor_id,
    event_date_utc AS activity_date_utc
FROM events_enriched;

ALTER TABLE visitor_daily_activity
    ADD PRIMARY KEY (visitor_id, activity_date_utc);

-- 2. 核对访客日数量
SELECT
    COUNT(*) AS actual_visitor_days,
    (SELECT SUM(active_days) FROM visitor_summary)
        AS expected_visitor_days
FROM visitor_daily_activity;

-- 3. 计算精确第1、7、30日回访率
CREATE TABLE retention_metrics AS
SELECT
    n.day_n,
    b.last_complete_date,

    COUNT(*) AS eligible_visitors,
    COUNT(a.visitor_id) AS returned_visitors,

    ROUND(
        100.0 * COUNT(a.visitor_id) / COUNT(*),
        4
    ) AS retention_rate_pct

FROM visitor_summary AS v

CROSS JOIN (
    SELECT 1 AS day_n
    UNION ALL SELECT 7
    UNION ALL SELECT 30
) AS n

CROSS JOIN (
    -- 最后一个日期不完整，使用其前一天作为观察截止日
    SELECT
        DATE_SUB(MAX(event_date_utc), INTERVAL 1 DAY)
            AS last_complete_date
    FROM daily_metrics
) AS b

LEFT JOIN visitor_daily_activity AS a
    ON a.visitor_id = v.visitor_id
    AND a.activity_date_utc =
        DATE_ADD(v.first_seen_date_utc, INTERVAL n.day_n DAY)

-- 只有具备完整第N日观察窗口的访客，才能进入分母
WHERE DATE_ADD(v.first_seen_date_utc, INTERVAL n.day_n DAY)
      <= b.last_complete_date

GROUP BY n.day_n, b.last_complete_date;

ALTER TABLE retention_metrics
    ADD PRIMARY KEY (day_n);

-- 4. 查看留存结果
SELECT *
FROM retention_metrics
ORDER BY day_n;