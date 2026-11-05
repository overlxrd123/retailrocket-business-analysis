USE retailrocket;

-- 1. 按行为发生时的商品类别汇总
-- 未知类别保留为NULL，不删除
CREATE TABLE category_metrics AS
SELECT
    category_id,
    parent_category_id,
    category_match_status,

    COUNT(*) AS total_events,
    COUNT(DISTINCT item_id) AS distinct_items,
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

    SUM(event_type = 'transaction') AS purchase_events,

    COUNT(DISTINCT CASE
        WHEN event_type = 'transaction' THEN transaction_id
    END) AS transactions

FROM events_enriched
GROUP BY
    category_id,
    parent_category_id,
    category_match_status;

-- 2. 按行为发生时的可售状态汇总
-- NULL=没有匹配到历史状态，0=不可售，1=可售
CREATE TABLE availability_metrics AS
SELECT
    available,
    COUNT(*) AS total_events,
    COUNT(DISTINCT visitor_id) AS active_visitors,

    SUM(event_type = 'view') AS view_events,
    SUM(event_type = 'addtocart') AS cart_events,
    SUM(event_type = 'transaction') AS purchase_events,

    COUNT(DISTINCT CASE
        WHEN event_type = 'transaction' THEN visitor_id
    END) AS buying_visitors

FROM events_enriched
GROUP BY available;

-- 3. 检查分组汇总是否遗漏或增加事件
SELECT
    'category_metrics' AS metric_table,
    SUM(total_events) AS total_events,
    SUM(purchase_events) AS purchase_events
FROM category_metrics

UNION ALL

SELECT
    'availability_metrics',
    SUM(total_events),
    SUM(purchase_events)
FROM availability_metrics;

-- 4. 查看各可售状态的行为分布
SELECT *
FROM availability_metrics
ORDER BY available;