USE retailrocket;

-- 1. 星期汇总：排除首尾不完整日
CREATE TABLE weekday_metrics AS
SELECT
    weekday_number,
    COUNT(*) AS date_count,

    ROUND(AVG(active_visitors), 2) AS avg_daily_active_visitors,
    ROUND(AVG(buying_visitors), 2) AS avg_daily_buying_visitors,

    SUM(active_visitors) AS active_visitor_days,
    SUM(buying_visitors) AS buying_visitor_days,

    -- 按访客日加权，不直接平均每日百分比
    ROUND(
        100.0 * SUM(buying_visitors)
        / NULLIF(SUM(active_visitors), 0),
        4
    ) AS buyer_rate_pct

FROM daily_metrics
WHERE is_boundary_date = 0
GROUP BY weekday_number;

ALTER TABLE weekday_metrics
ADD PRIMARY KEY (weekday_number);

-- 2. 每个日期、每个UTC小时的行为指标
CREATE TABLE hourly_metrics AS
SELECT
    e.event_date_utc,
    HOUR(e.event_time_utc) AS hour_utc,

    COUNT(*) AS total_events,
    COUNT(DISTINCT e.visitor_id) AS active_visitors,
    SUM(e.event_type = 'view') AS view_events,
    SUM(e.event_type = 'addtocart') AS cart_events,
    SUM(e.event_type = 'transaction') AS purchase_events,

    COUNT(DISTINCT CASE
        WHEN e.event_type = 'transaction' THEN e.visitor_id
    END) AS buying_visitors

FROM events_enriched AS e
JOIN daily_metrics AS d
    ON e.event_date_utc = d.event_date_utc

WHERE d.is_boundary_date = 0

GROUP BY
    e.event_date_utc,
    HOUR(e.event_time_utc);

ALTER TABLE hourly_metrics
ADD PRIMARY KEY (event_date_utc, hour_utc);

-- 3. 核对星期汇总天数：应为137
SELECT
    COUNT(*) AS weekday_groups,
    SUM(date_count) AS complete_dates
FROM weekday_metrics;

-- 4. 核对小时表事件数与同日期的每日表是否一致
SELECT
    (SELECT SUM(total_events) FROM hourly_metrics)
        AS hourly_event_total,

    (SELECT SUM(total_events)
     FROM daily_metrics
     WHERE is_boundary_date = 0)
        AS daily_event_total;