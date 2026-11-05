USE retailrocket;

-- 1. 建立每日指标表
CREATE TABLE daily_metrics AS
SELECT
    d.*,
    WEEKDAY(d.event_date_utc) + 1 AS weekday_number,

    ROUND(
        100.0 * d.buying_visitors
        / NULLIF(d.active_visitors, 0),
        4
    ) AS daily_buyer_rate_pct,

    -- 标记首尾日期，趋势比较时排除这两个不完整日
    CASE
        WHEN d.event_date_utc IN (b.first_date, b.last_date)
        THEN 1 ELSE 0
    END AS is_boundary_date

FROM (
    SELECT
        event_date_utc,
        COUNT(*) AS total_events,
        COUNT(DISTINCT visitor_id) AS active_visitors,

        COUNT(DISTINCT CASE
            WHEN event_type = 'view' THEN visitor_id
        END) AS viewing_visitors,

        COUNT(DISTINCT CASE
            WHEN event_type = 'addtocart' THEN visitor_id
        END) AS cart_visitors,

        COUNT(DISTINCT CASE
            WHEN event_type = 'transaction' THEN visitor_id
        END) AS buying_visitors,

        COUNT(DISTINCT CASE
            WHEN event_type = 'transaction' THEN transaction_id
        END) AS transactions

    FROM events_enriched
    GROUP BY event_date_utc
) AS d

CROSS JOIN (
    SELECT
        MIN(event_date_utc) AS first_date,
        MAX(event_date_utc) AS last_date
    FROM events_enriched
) AS b;

-- 2. 保证每个日期只有一行
ALTER TABLE daily_metrics
    ADD PRIMARY KEY (event_date_utc);

-- 3. 核对汇总是否完整
SELECT
    COUNT(*) AS date_count,
    MIN(event_date_utc) AS first_date,
    MAX(event_date_utc) AS last_date,
    SUM(total_events) AS total_events,
    SUM(is_boundary_date) AS boundary_date_count
FROM daily_metrics;