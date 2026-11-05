USE retailrocket;

LOAD DATA INFILE 'D:/MySQL/MySQL Server 8.0/Uploads/category_tree.csv'
INTO TABLE category_tree_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(category_id, @parent_id)
SET parent_id =
    NULLIF(TRIM(TRAILING '\r' FROM @parent_id), '');

SHOW WARNINGS LIMIT 20;
LOAD DATA INFILE 'D:/MySQL/MySQL Server 8.0/Uploads/item_properties_part1.csv'
INTO TABLE retailrocket.item_properties_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(timestamp_ms, item_id, property_name, @property_value)
SET property_value =
    TRIM(TRAILING '\r' FROM @property_value);

SHOW WARNINGS LIMIT 20;

-- 以下补齐商品属性第二部分。仅在首次从空表构建项目时执行。
-- 当前数据库已导入完整，不要重复运行。
LOAD DATA INFILE 'D:/MySQL/MySQL Server 8.0/Uploads/item_properties_part2.csv'
INTO TABLE retailrocket.item_properties_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(timestamp_ms, item_id, property_name, @property_value)
SET property_value = TRIM(TRAILING '\r' FROM @property_value);
SHOW WARNINGS LIMIT 20;

SELECT COUNT(*) AS total_property_rows
FROM retailrocket.item_properties_raw;
-- 预期20,275,902行。
