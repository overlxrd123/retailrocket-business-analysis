USE retailrocket;

-- 从原始表提取两种关键属性，并将值转换成数字
-- 原始表不修改
CREATE TABLE item_property_history_stage AS
SELECT
    item_id,
    property_name,
    timestamp_ms AS valid_from_ms,
    CAST(property_value AS UNSIGNED) AS property_value
FROM item_properties_raw
WHERE property_name IN ('categoryid', 'available');

-- 1. 核对提取后的规模
SELECT
    property_name,
    COUNT(*) AS record_count,
    COUNT(DISTINCT item_id) AS item_count
FROM item_property_history_stage
GROUP BY property_name;

-- 2. 检查同商品、同属性、同时间是否存在不同值
-- 如果有冲突，需要先处理，不能直接选择其中一个
SELECT
    item_id,
    property_name,
    valid_from_ms,
    COUNT(*) AS record_count,
    COUNT(DISTINCT property_value) AS value_count
FROM item_property_history_stage
GROUP BY item_id, property_name, valid_from_ms
HAVING COUNT(DISTINCT property_value) > 1
LIMIT 20;