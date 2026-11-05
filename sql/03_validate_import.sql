-- 核对各类行为的记录数
SELECT
    event_type,
    COUNT(*) AS event_count
FROM retailrocket.events_raw
GROUP BY event_type;

-- 核对总行数
SELECT COUNT(*) AS total_rows
FROM retailrocket.events_raw;