USE retailrocket;

-- 1. 为后续访客路径、日期分析建立索引
ALTER TABLE events_enriched
    ADD INDEX idx_visitor_time (visitor_id, timestamp_ms),
    ADD INDEX idx_date_event (event_date_utc, event_type);

-- 2. 汇总每个访客在样本内的行为
CREATE TABLE visitor_summary AS
SELECT
    visitor_id,

    MIN(event_time_utc) AS first_seen_utc,
    MAX(event_time_utc) AS last_seen_utc,
    MIN(event_date_utc) AS first_seen_date_utc,

    COUNT(*) AS total_events,
    COUNT(DISTINCT event_date_utc) AS active_days,
    COUNT(DISTINCT item_id) AS distinct_items,

    SUM(event_type = 'view') AS view_events,
    SUM(event_type = 'addtocart') AS cart_events,
    SUM(event_type = 'transaction') AS purchase_events,

    COUNT(DISTINCT CASE
        WHEN event_type = 'transaction' THEN transaction_id
    END) AS transaction_count

FROM events_enriched
GROUP BY visitor_id;

-- 3. 每个访客只保留一行
ALTER TABLE visitor_summary
    ADD PRIMARY KEY (visitor_id);

-- 4. 核对汇总结果
SELECT
    COUNT(*) AS visitor_count,
    SUM(total_events) AS total_events,
    SUM(purchase_events > 0) AS buying_visitors,
    SUM(first_seen_utc > last_seen_utc) AS invalid_time_ranges
FROM visitor_summary;