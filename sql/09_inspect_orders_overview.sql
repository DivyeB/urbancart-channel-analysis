-- =====================================================================
-- 09_inspect_orders_overview.sql
-- What:    One-row health summary of raw_orders: row count, ID
--          uniqueness, NULLs per column, order date range, and basic
--          order_value checks (min, max, average, median, zero/negative).
--          (No formal outlier rule was applied.)
-- Assumptions:
--   * ALL statuses included and duplicates NOT removed: this describes
--     the raw file, not the analysis population.
--   * NULL = empty field in the CSV.
--   * Aggregates (MIN/MAX/AVG/MEDIAN) ignore NULL order_values.
-- Expected result: 1 row. total_rows = 5684 (step 2). If
--   distinct_order_ids < total_rows, some order_id repeats (see 10).
-- =====================================================================

SELECT
    COUNT(*)                                       AS total_rows,
    COUNT(DISTINCT order_id)                       AS distinct_order_ids,
    COUNT(DISTINCT user_id)                        AS distinct_user_ids,
    COUNT(*) - COUNT(order_id)                     AS null_order_id,
    COUNT(*) - COUNT(user_id)                      AS null_user_id,
    COUNT(*) - COUNT(order_date)                   AS null_order_date,
    COUNT(*) - COUNT(order_value)                  AS null_order_value,
    COUNT(*) - COUNT(status)                       AS null_status,
    MIN(order_date)                                AS first_order_date,
    MAX(order_date)                                AS last_order_date,
    MIN(order_value)                               AS min_order_value,
    MAX(order_value)                               AS max_order_value,
    ROUND(AVG(order_value), 2)                     AS avg_order_value,
    MEDIAN(order_value)                            AS median_order_value,
    SUM(CASE WHEN order_value <= 0 THEN 1 ELSE 0 END) AS zero_or_negative_value
FROM raw_orders;
