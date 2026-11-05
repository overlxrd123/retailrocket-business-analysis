USE retailrocket;

-- 1. 在共同观察样本中，查找首次浏览后7天内的首次加购
CREATE TABLE funnel_carts_7d AS
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
    AND e.timestamp_ms <= v.view_ts + 604800000

WHERE v.view_ts <= (
    SELECT MAX(timestamp_ms) - 604800000
    FROM events_enriched
)

GROUP BY v.visitor_id, v.item_id, v.view_ts;

ALTER TABLE funnel_carts_7d
ADD PRIMARY KEY (visitor_id, item_id);

-- 2. 查找加购之后、首次浏览后7天内的首次购买
CREATE TABLE funnel_purchases_7d AS
SELECT
    c.visitor_id,
    c.item_id,
    MIN(e.timestamp_ms) AS purchase_ts
FROM funnel_carts_7d AS c
JOIN events_enriched AS e
    ON e.visitor_id = c.visitor_id
    AND e.item_id = c.item_id
    AND e.event_type = 'transaction'
    AND e.timestamp_ms > c.cart_ts
    AND e.timestamp_ms <= c.view_ts + 604800000
GROUP BY c.visitor_id, c.item_id;

ALTER TABLE funnel_purchases_7d
ADD PRIMARY KEY (visitor_id, item_id);

-- 3. 在同一批起点上比较三个窗口
CREATE TABLE funnel_window_comparison AS
SELECT
    n.window_hours,
    COUNT(*) AS viewing_pairs,

    SUM(
        CASE WHEN c.cart_ts <=
            v.view_ts + n.window_hours * 3600000
        THEN 1 ELSE 0 END
    ) AS cart_pairs,

    SUM(
        CASE WHEN p.purchase_ts <=
            v.view_ts + n.window_hours * 3600000
        THEN 1 ELSE 0 END
    ) AS purchase_pairs

FROM funnel_first_views AS v

CROSS JOIN (
    SELECT 24 AS window_hours
    UNION ALL SELECT 72
    UNION ALL SELECT 168
) AS n

LEFT JOIN funnel_carts_7d AS c
    ON v.visitor_id = c.visitor_id
    AND v.item_id = c.item_id

LEFT JOIN funnel_purchases_7d AS p
    ON v.visitor_id = p.visitor_id
    AND v.item_id = p.item_id

WHERE v.view_ts <= (
    SELECT MAX(timestamp_ms) - 604800000
    FROM events_enriched
)

GROUP BY n.window_hours;

ALTER TABLE funnel_window_comparison
ADD PRIMARY KEY (window_hours);

-- 4. 查看各窗口的转化率
SELECT
    window_hours,
    viewing_pairs,
    cart_pairs,
    purchase_pairs,

    ROUND(
        100.0 * cart_pairs / NULLIF(viewing_pairs, 0),
        4
    ) AS view_to_cart_pct,

    ROUND(
        100.0 * purchase_pairs / NULLIF(viewing_pairs, 0),
        4
    ) AS view_to_purchase_pct,

    ROUND(
        100.0 * purchase_pairs / NULLIF(cart_pairs, 0),
        4
    ) AS cart_to_purchase_pct

FROM funnel_window_comparison
ORDER BY window_hours;