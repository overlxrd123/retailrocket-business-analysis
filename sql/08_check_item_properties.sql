USE retailrocket;
SET time_zone = '+00:00';

-- 1. 检查整张属性表的字段质量和时间范围
SELECT
    COUNT(*) AS total_rows,
    SUM(timestamp_ms IS NULL) AS missing_timestamp,
    SUM(item_id IS NULL) AS missing_item,
    SUM(property_name IS NULL OR property_name = '') AS missing_property,
    SUM(property_value IS NULL OR property_value = '') AS missing_value,
    FROM_UNIXTIME(MIN(timestamp_ms) / 1000) AS first_record_utc,
    FROM_UNIXTIME(MAX(timestamp_ms) / 1000) AS last_record_utc
FROM item_properties_raw;

-- 2. 检查本次整合需要的两种属性
SELECT
    property_name,
    COUNT(*) AS record_count,
    COUNT(DISTINCT item_id) AS item_count,

    -- categoryid 应是数字编号
    SUM(
        CASE
            WHEN property_name = 'categoryid'
             AND (
                 property_value IS NULL
                 OR property_value NOT REGEXP '^[0-9]+$'
             )
            THEN 1 ELSE 0
        END
    ) AS invalid_category_values,

    -- available 应为 0 或 1
    SUM(
        CASE
            WHEN property_name = 'available'
             AND (
                 property_value IS NULL
                 OR property_value NOT IN ('0', '1')
             )
            THEN 1 ELSE 0
        END
    ) AS invalid_available_values
FROM item_properties_raw
WHERE property_name IN ('categoryid', 'available')
GROUP BY property_name;