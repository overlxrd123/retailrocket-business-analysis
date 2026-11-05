USE retailrocket;
SET time_zone = '+00:00';

-- 每条行为匹配当时的类别、可售状态和父类别
CREATE TABLE events_enriched AS
SELECT
    e.timestamp_ms,
    FROM_UNIXTIME(e.timestamp_ms / 1000) AS event_time_utc,
    DATE(FROM_UNIXTIME(e.timestamp_ms / 1000)) AS event_date_utc,
    e.visitor_id,
    e.event_type,
    e.item_id,
    e.transaction_id,

    c.property_value AS category_id,
    t.parent_id AS parent_category_id,
    a.property_value AS available,

    -- 区分类别没有历史记录，还是类别编号未匹配到类别树
    CASE
        WHEN c.item_id IS NULL THEN 'no_history'
        WHEN t.category_id IS NULL THEN 'not_in_tree'
        ELSE 'matched'
    END AS category_match_status

FROM events_raw AS e

LEFT JOIN item_property_history AS c
    ON e.item_id = c.item_id
    AND c.property_name = 'categoryid'
    AND e.timestamp_ms >= c.valid_from_ms
    AND (
        e.timestamp_ms < c.valid_to_ms
        OR c.valid_to_ms IS NULL
    )

LEFT JOIN item_property_history AS a
    ON e.item_id = a.item_id
    AND a.property_name = 'available'
    AND e.timestamp_ms >= a.valid_from_ms
    AND (
        e.timestamp_ms < a.valid_to_ms
        OR a.valid_to_ms IS NULL
    )

LEFT JOIN category_tree_raw AS t
    ON c.property_value = t.category_id;

-- 检查关联有没有使行为记录意外膨胀
SELECT
    (SELECT COUNT(*) FROM events_raw) AS raw_rows,
    COUNT(*) AS enriched_rows,
    SUM(category_id IS NULL) AS events_without_category_history,
    SUM(available IS NULL) AS events_without_available_history,
    SUM(category_match_status = 'not_in_tree') AS events_category_not_in_tree
FROM events_enriched;