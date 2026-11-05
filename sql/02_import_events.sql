USE retailrocket;

LOAD DATA INFILE 'D:/MySQL/MySQL Server 8.0/Uploads/events.csv'
INTO TABLE events_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(timestamp_ms, visitor_id, event_type, item_id, @transaction_id)
SET transaction_id =
    NULLIF(TRIM(TRAILING '\r' FROM @transaction_id), '');

SHOW WARNINGS LIMIT 20;