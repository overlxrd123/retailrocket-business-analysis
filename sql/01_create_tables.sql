-- 创建项目数据库
CREATE DATABASE IF NOT EXISTS retailrocket
    DEFAULT CHARACTER SET utf8mb4;

USE retailrocket;

-- 创建原始行为表
CREATE TABLE IF NOT EXISTS events_raw (
    timestamp_ms   BIGINT,
    visitor_id     BIGINT,
    event_type     VARCHAR(32),
    item_id        BIGINT,
    transaction_id BIGINT NULL
);

-- 查看 MySQL 允许从哪个目录导入文件
SHOW VARIABLES LIKE 'secure_file_priv';
