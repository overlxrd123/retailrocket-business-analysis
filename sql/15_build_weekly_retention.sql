USE retailrocket;

-- 1. 每个入群周的访客规模
-- 周一为一周开始；首次出现不是注册
CREATE TABLE cohort_week_summary AS
SELECT
    DATE_SUB(
        first_seen_date_utc,
        INTERVAL WEEKDAY(first_seen_date_utc) DAY
    ) AS cohort_week,
    COUNT(*) AS cohort_size,
    MAX(first_seen_date_utc) AS latest_first_date
FROM visitor_summary
GROUP BY cohort_week;

ALTER TABLE cohort_week_summary
    ADD PRIMARY KEY (cohort_week);

-- 2. 各入群周在后续年龄周的回访人数
-- 第0周：首次出现后第0～6天
-- 第1周：首次出现后第7～13天，以此类推
CREATE TABLE cohort_week_activity AS
SELECT
    DATE_SUB(
        v.first_seen_date_utc,
        INTERVAL WEEKDAY(v.first_seen_date_utc) DAY
    ) AS cohort_week,

    FLOOR(
        DATEDIFF(a.activity_date_utc, v.first_seen_date_utc) / 7
    ) AS week_index,

    COUNT(DISTINCT a.visitor_id) AS active_visitors

FROM visitor_daily_activity AS a
JOIN visitor_summary AS v
    ON a.visitor_id = v.visitor_id

WHERE DATEDIFF(
    a.activity_date_utc, v.first_seen_date_utc
) BETWEEN 0 AND 55

AND a.activity_date_utc <= (
    SELECT DATE_SUB(MAX(event_date_utc), INTERVAL 1 DAY)
    FROM daily_metrics
)

GROUP BY cohort_week, week_index;

ALTER TABLE cohort_week_activity
    ADD PRIMARY KEY (cohort_week, week_index);

-- 3. 建立完整网格：观察窗口不足的格子保留NULL
CREATE TABLE cohort_weekly_retention AS
SELECT
    c.cohort_week,
    n.week_index,
    c.cohort_size,

    CASE WHEN
        DATE_ADD(
            c.latest_first_date,
            INTERVAL (n.week_index * 7 + 6) DAY
        ) <= b.last_complete_date
    THEN COALESCE(a.active_visitors, 0)
    ELSE NULL
    END AS active_visitors,

    CASE WHEN
        DATE_ADD(
            c.latest_first_date,
            INTERVAL (n.week_index * 7 + 6) DAY
        ) <= b.last_complete_date
    THEN ROUND(
        100.0 * COALESCE(a.active_visitors, 0) / c.cohort_size,
        4
    )
    ELSE NULL
    END AS retention_rate_pct

FROM cohort_week_summary AS c

CROSS JOIN (
    SELECT 0 AS week_index
    UNION ALL SELECT 1
    UNION ALL SELECT 2
    UNION ALL SELECT 3
    UNION ALL SELECT 4
    UNION ALL SELECT 5
    UNION ALL SELECT 6
    UNION ALL SELECT 7
) AS n

CROSS JOIN (
    SELECT
        DATE_SUB(MAX(event_date_utc), INTERVAL 1 DAY)
            AS last_complete_date
    FROM daily_metrics
) AS b

LEFT JOIN cohort_week_activity AS a
    ON c.cohort_week = a.cohort_week
    AND n.week_index = a.week_index;

ALTER TABLE cohort_weekly_retention
    ADD PRIMARY KEY (cohort_week, week_index);

-- 4. 查看前几个入群周
SELECT *
FROM cohort_weekly_retention
ORDER BY cohort_week, week_index
LIMIT 24;