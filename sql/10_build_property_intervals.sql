USE retailrocket;

-- 1. 建立属性生效区间
-- 完全相同的属性记录先折叠，原始表保持不变
CREATE TABLE item_property_history AS
SELECT
    item_id,
    property_name,
    property_value,
    valid_from_ms,
    LEAD(valid_from_ms) OVER (
        PARTITION BY item_id, property_name
        ORDER BY valid_from_ms
    ) AS valid_to_ms
FROM (
    SELECT DISTINCT
        item_id,
        property_name,
        property_value,
        valid_from_ms
    FROM item_property_history_stage
) AS deduplicated;

-- 2. 建立索引，为后续按商品、属性、时间关联做准备
ALTER TABLE item_property_history
ADD PRIMARY KEY (item_id, property_name, valid_from_ms);

-- 3. 检查区间
SELECT
    property_name,
    COUNT(*) AS interval_count,
    COUNT(DISTINCT item_id) AS item_count,
    SUM(valid_to_ms IS NULL) AS open_ended_intervals,
    SUM(
        valid_to_ms IS NOT NULL
        AND valid_to_ms <= valid_from_ms
    ) AS invalid_intervals
FROM item_property_history
GROUP BY property_name;