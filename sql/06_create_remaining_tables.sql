USE retailrocket;

-- 商品属性原始表：保留属性变化时间
CREATE TABLE IF NOT EXISTS item_properties_raw (
    timestamp_ms   BIGINT,
    item_id        BIGINT,
    property_name  VARCHAR(64),
    property_value LONGTEXT
);

-- 商品类别关系原始表：顶层类别的父类别可以为空
CREATE TABLE IF NOT EXISTS category_tree_raw (
    category_id BIGINT,
    parent_id   BIGINT NULL
);

-- 导入前确认状态，避免重复导入
SELECT
    'events_raw' AS table_name,
    COUNT(*) AS row_count
FROM events_raw

UNION ALL

SELECT
    'item_properties_raw',
    COUNT(*)
FROM item_properties_raw

UNION ALL

SELECT
    'category_tree_raw',
    COUNT(*)
FROM category_tree_raw;