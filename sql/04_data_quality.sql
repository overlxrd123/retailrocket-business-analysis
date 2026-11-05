USE retailrocket;

-- 统一使用 UTC，避免时间转换受电脑时区影响
SET time_zone = '+00:00';

-- 1. 数据规模与时间范围
SELECT
    COUNT(*) AS total_events,
    COUNT(DISTINCT visitor_id) AS unique_visitors,
    COUNT(DISTINCT item_id) AS unique_items,
    FROM_UNIXTIME(MIN(timestamp_ms) / 1000) AS first_event_utc,
    FROM_UNIXTIME(MAX(timestamp_ms) / 1000) AS last_event_utc
FROM events_raw;

-- 2. 核心字段缺失情况
SELECT
    SUM(timestamp_ms IS NULL) AS missing_timestamp,
    SUM(visitor_id IS NULL) AS missing_visitor,
    SUM(event_type IS NULL OR event_type = '') AS missing_event_type,
    SUM(item_id IS NULL) AS missing_item
FROM events_raw;

-- 3. 每类行为的事件数、访客数、交易编号情况
SELECT
    event_type,
    COUNT(*) AS event_count,
    COUNT(DISTINCT visitor_id) AS visitor_count,
    COUNT(transaction_id) AS rows_with_transaction_id,
    COUNT(DISTINCT transaction_id) AS unique_transactions
FROM events_raw
GROUP BY event_type
ORDER BY event_count DESC;
-- 哪些交易编号对应多条购买事件？
SELECT
    transaction_id,
    COUNT(*) AS event_rows,
    COUNT(DISTINCT item_id) AS item_count,
    COUNT(DISTINCT visitor_id) AS visitor_count,
    COUNT(DISTINCT timestamp_ms) AS timestamp_count
FROM events_raw
WHERE event_type = 'transaction'
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY event_rows DESC
LIMIT 20;

-- 购买事件中是否存在五个字段完全相同的重复记录？
SELECT
    timestamp_ms,
    visitor_id,
    event_type,
    item_id,
    transaction_id,
    COUNT(*) AS duplicate_count
FROM events_raw
WHERE event_type = 'transaction'
GROUP BY
    timestamp_ms, visitor_id, event_type, item_id, transaction_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;
SELECT
    transaction_id,
    COUNT(DISTINCT visitor_id) AS visitor_count
FROM retailrocket.events_raw
WHERE event_type = 'transaction'
GROUP BY transaction_id
HAVING COUNT(DISTINCT visitor_id) > 1;
SET time_zone = '+00:00';
SELECT
    COUNT(DISTINCT visitor_id) AS unique_visitors,
    COUNT(DISTINCT item_id) AS unique_items,
    FROM_UNIXTIME(MIN(timestamp_ms) / 1000) AS first_event_utc,
    FROM_UNIXTIME(MAX(timestamp_ms) / 1000) AS last_event_utc,
    SUM(timestamp_ms IS NULL) AS missing_timestamp,
    SUM(visitor_id IS NULL) AS missing_visitor,
    SUM(event_type IS NULL OR event_type = '') AS missing_event_type,
    SUM(item_id IS NULL) AS missing_item
FROM retailrocket.events_raw;