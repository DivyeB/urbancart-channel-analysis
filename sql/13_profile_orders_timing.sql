-- =====================================================================
-- 13_profile_orders_timing.sql
-- What:    Date logic of orders.
--   Query 1: orders dated BEFORE the user's signup_date (impossible in a
--            clean system), by status, with the worst gap in days.
--   Query 2: order rows per calendar month, split by status, so orders
--            outside Jan-Jun 2026 (the brief's window) are visible.
-- Assumptions:
--   * Raw tables, duplicates NOT removed; all statuses shown.
--   * Query 1 uses an INNER JOIN, so orphan orders (12) are excluded:
--     they have no signup_date to compare with.
--   * An order on the signup day itself is valid (strict <).
--   * Query 2 splits by exact status values; anything else lands in
--     other_status (11 explains what it is).
-- Expected result:
--   Query 1: one row per status; zero rows = clean.
--   Query 2: one row per month present; total_rows sums to 5684.
-- =====================================================================

-- Query 1: orders before signup
SELECT
    o.status,
    COUNT(*)                                 AS order_rows_before_signup,
    COUNT(DISTINCT o.user_id)                AS users_affected,
    SUM(o.order_value)                       AS order_value,
    MAX(u.signup_date - o.order_date)        AS max_days_before_signup
FROM raw_orders o
JOIN raw_users  u ON u.user_id = o.user_id
WHERE o.order_date < u.signup_date
GROUP BY o.status
ORDER BY o.status;

-- Query 2: order rows by month and status
SELECT
    strftime(order_date, '%Y-%m')                                     AS order_month,
    COUNT(*)                                                          AS total_rows,
    SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END)             AS delivered,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END)             AS cancelled,
    SUM(CASE WHEN status = 'returned'  THEN 1 ELSE 0 END)             AS returned,
    SUM(CASE WHEN status IS NULL
              OR status NOT IN ('delivered', 'cancelled', 'returned')
             THEN 1 ELSE 0 END)                                       AS other_status
FROM raw_orders
GROUP BY order_month
ORDER BY order_month;
