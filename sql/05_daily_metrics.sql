USE retailrocket;
SET time_zone = '+00:00';

SELECT
    DATE(FROM_UNIXTIME(timestamp_ms / 1000)) AS event_date_utc,
    COUNT(*) AS total_events,
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
    COUNT(DISTINCT CASE
        WHEN event_type = 'transaction' THEN transaction_id
    END) AS transactions,
    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN event_type = 'transaction' THEN visitor_id
        END) / NULLIF(COUNT(DISTINCT visitor_id), 0),
        2
    ) AS daily_buyer_rate_pct
FROM events_raw
GROUP BY event_date_utc
ORDER BY event_date_utc;