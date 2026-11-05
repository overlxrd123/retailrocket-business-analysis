USE retailrocket;

-- 1. 加速同访客、同商品的行为查找
ALTER TABLE events_enriched
ADD INDEX idx_visitor_item_event_time (
    visitor_id, item_id, event_type, timestamp_ms
);

-- 2. 每个访客—商品对在样本中的首次浏览
-- 86400000毫秒 = 24小时
CREATE TABLE funnel_first_views AS
SELECT
    visitor_id,
    item_id,
    MIN(timestamp_ms) AS view_ts
FROM events_enriched
WHERE event_type = 'view'
GROUP BY visitor_id, item_id
HAVING MIN(timestamp_ms) <= (
    SELECT MAX(timestamp_ms) - 86400000
    FROM events_enriched
);

ALTER TABLE funnel_first_views
ADD PRIMARY KEY (visitor_id, item_id);

-- 3. 首次浏览之后、24小时窗口内的首次加购
CREATE TABLE funnel_first_carts AS
SELECT
    v.visitor_id,
    v.item_id,
    v.view_ts,
    MIN(e.timestamp_ms) AS cart_ts
FROM funnel_first_views AS v
JOIN events_enriched AS e
    ON e.visitor_id = v.visitor_id
    AND e.item_id = v.item_id
    AND e.event_type = 'addtocart'
    AND e.timestamp_ms > v.view_ts
    AND e.timestamp_ms <= v.view_ts + 86400000
GROUP BY v.visitor_id, v.item_id, v.view_ts;

ALTER TABLE funnel_first_carts
ADD PRIMARY KEY (visitor_id, item_id);

-- 4. 加购之后、仍在首次浏览24小时窗口内的首次购买
CREATE TABLE funnel_first_purchases AS
SELECT
    c.visitor_id,
    c.item_id,
    c.view_ts,
    c.cart_ts,
    MIN(e.timestamp_ms) AS purchase_ts
FROM funnel_first_carts AS c
JOIN events_enriched AS e
    ON e.visitor_id = c.visitor_id
    AND e.item_id = c.item_id
    AND e.event_type = 'transaction'
    AND e.timestamp_ms > c.cart_ts
    AND e.timestamp_ms <= c.view_ts + 86400000
GROUP BY
    c.visitor_id, c.item_id, c.view_ts, c.cart_ts;

ALTER TABLE funnel_first_purchases
ADD PRIMARY KEY (visitor_id, item_id);

-- 5. 保存各阶段指标
CREATE TABLE funnel_metrics AS
SELECT
    counts.*,

    ROUND(
        100.0 * pair_count
        / NULLIF(
            FIRST_VALUE(pair_count) OVER (ORDER BY stage_order),
            0
        ),
        4
    ) AS pct_of_start,

    ROUND(
        100.0 * pair_count
        / NULLIF(
            LAG(pair_count) OVER (ORDER BY stage_order),
            0
        ),
        4
    ) AS pct_of_previous

FROM (
    SELECT
        1 AS stage_order,
        'view' AS stage_name,
        COUNT(*) AS pair_count
    FROM funnel_first_views

    UNION ALL

    SELECT 2, 'addtocart', COUNT(*)
    FROM funnel_first_carts

    UNION ALL

    SELECT 3, 'purchase', COUNT(*)
    FROM funnel_first_purchases
) AS counts;

-- 6. 查看最终结果
SELECT *
FROM funnel_metrics
ORDER BY stage_order;