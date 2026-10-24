-- =====================================================================
-- 11_profile_orders_status_values.sql
-- What:    Every distinct status value with row count, share, and
--          order_value stats, plus flags for NULL, spacing problems and
--          values outside the brief's list (delivered/cancelled/returned).
--          Sorted so casing variants ('Delivered' vs 'delivered') sit together.
-- Assumptions:
--   * Raw rows: duplicates NOT removed (10 measures them).
--   * Exact, case-sensitive comparison to the 3 brief values, on purpose:
--     the analysis will filter status = 'delivered', so any variant
--     would be silently excluded.
-- Expected result: one row per distinct raw status; order_rows sums to
--   5684.
-- =====================================================================

SELECT
    status,
    '[' || status || ']'                                    AS value_in_brackets,
    CASE
        WHEN status IS NULL                                  THEN 'NULL (blank in CSV)'
        WHEN TRIM(status) = ''                               THEN 'whitespace only'
        WHEN status <> TRIM(status)                          THEN 'leading/trailing spaces'
        WHEN status NOT IN ('delivered', 'cancelled', 'returned')
                                                             THEN 'not one of the 3 brief values'
        ELSE 'ok'
    END                                                     AS value_flag,
    COUNT(*)                                                AS order_rows,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)      AS pct_of_rows,
    SUM(order_value)                                        AS total_order_value,
    MIN(order_value)                                        AS min_order_value,
    MAX(order_value)                                        AS max_order_value,
    MEDIAN(order_value)                                     AS median_order_value
FROM raw_orders
GROUP BY status
ORDER BY LOWER(TRIM(status)) NULLS LAST, order_rows DESC;
