USE retailrocket;

-- 每项 failure_count 都应为 0
SELECT
    'weekday_coverage' AS check_name,
    CASE
        WHEN COUNT(*) = 7 AND SUM(date_count) = 137
        THEN 0 ELSE 1
    END AS failure_count
FROM weekday_metrics

UNION ALL

SELECT
    'retention_bounds',
    COUNT(*)
FROM retention_metrics
WHERE returned_visitors > eligible_visitors
   OR retention_rate_pct NOT BETWEEN 0 AND 100

UNION ALL

SELECT
    'weekly_retention_bounds',
    COUNT(*)
FROM cohort_weekly_retention
WHERE active_visitors > cohort_size
   OR retention_rate_pct NOT BETWEEN 0 AND 100
   OR (active_visitors IS NULL AND retention_rate_pct IS NOT NULL)
   OR (active_visitors IS NOT NULL AND retention_rate_pct IS NULL)

UNION ALL

SELECT
    'purchase_path_order',
    COUNT(*)
FROM funnel_first_purchases
WHERE cart_ts <= view_ts
   OR purchase_ts <= cart_ts
   OR purchase_ts > view_ts + 86400000

UNION ALL

SELECT
    'window_common_denominator',
    CASE
        WHEN COUNT(*) = 3
         AND COUNT(DISTINCT viewing_pairs) = 1
        THEN 0 ELSE 1
    END
FROM funnel_window_comparison

UNION ALL

SELECT
    'window_funnel_bounds',
    COUNT(*)
FROM funnel_window_comparison
WHERE purchase_pairs > cart_pairs
   OR cart_pairs > viewing_pairs;