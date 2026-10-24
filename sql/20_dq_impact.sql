-- =====================================================================
-- 20_dq_impact.sql
-- What:    Sizes the effect of two treatments, for the data-quality log.
--   Query 1 (U1): of the 'Unknown'-channel users in clean_users, how
--            many are customers (>= 1 delivered order) and how much
--            delivered revenue they bring. This bounds how much paid CAC
--            could be affected by not attributing them.
--   Query 2 (U2): Affiliate's customers and delivered revenue WITH vs
--            WITHOUT the 35 test accounts, on deduplicated orders.
-- Assumptions:
--   * "Customer" = user with >= 1 order with status = 'delivered'
--     (brief's new-customer definition; full metric definitions are
--     agreed in step 5, so no CAC is computed here).
--   * Query 1 reads clean tables (already deduped, test-free).
--   * Query 2 must include the test accounts, so it reads raw tables and
--     deduplicates orders itself with SELECT DISTINCT (as in 17).
--   * Delivered only: cancelled and returned orders excluded.
-- Expected result:
--   Query 1: 1 row; unknown_users = 72 (from 19).
--   Query 2: 2 rows; the gap between them = the test accounts' effect
--            (customer gap should be 35: all 35 had delivered orders, 08).
-- =====================================================================

-- Query 1: U1, how many Unknown-channel users are customers
WITH unknown_users AS (
    SELECT user_id
    FROM clean_users
    WHERE acquisition_channel = 'Unknown'
)
SELECT
    (SELECT COUNT(*) FROM unknown_users)                              AS unknown_users,
    COUNT(DISTINCT o.user_id)                                         AS unknown_customers,
    SUM(o.order_value)                                                AS unknown_delivered_revenue
FROM clean_orders o
JOIN unknown_users u ON u.user_id = o.user_id
WHERE o.status = 'delivered';

-- Query 2: U2, Affiliate with vs without test accounts
WITH dedup_orders AS (
    SELECT DISTINCT order_id, user_id, order_date, order_value, status
    FROM raw_orders
),
affiliate_users AS (
    SELECT user_id,
           LOWER(split_part(email, '@', 2)) = 'urbancart.in' AS is_test_account
    FROM raw_users
    WHERE acquisition_channel = 'Affiliate'
)
SELECT
    'including test accounts'        AS scenario,
    COUNT(DISTINCT o.user_id)        AS affiliate_customers,
    COUNT(*)                         AS delivered_orders,
    SUM(o.order_value)               AS delivered_revenue
FROM dedup_orders o
JOIN affiliate_users a ON a.user_id = o.user_id
WHERE o.status = 'delivered'
UNION ALL
SELECT
    'excluding test accounts',
    COUNT(DISTINCT o.user_id),
    COUNT(*),
    SUM(o.order_value)
FROM dedup_orders o
JOIN affiliate_users a ON a.user_id = o.user_id
WHERE o.status = 'delivered'
  AND NOT a.is_test_account;
