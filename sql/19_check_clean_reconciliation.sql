-- =====================================================================
-- 19_check_clean_reconciliation.sql
-- What:    Proves the clean tables equal "raw minus exactly what we
--          decided to remove", and nothing else.
--   Query 1: pass/fail checks. Each EXPECTED value is recomputed
--            directly from the raw tables; each ACTUAL value is read
--            from the clean tables.
--   Query 2: the orders chain for the data-quality log:
--            raw -> after dedup -> after test-account removal.
--   Query 3: the users chain: raw -> after test-account removal, and
--            how many clean users are 'Unknown'.
-- Assumptions:
--   * Test account rule = email domain 'urbancart.in' (D10).
--   * The expected side deliberately uses DIFFERENT SQL from 16-17
--     (NOT IN instead of NOT EXISTS; DISTINCT in a CTE), so this is an
--     independent recomputation, not the same logic run twice. NOT IN
--     is safe here: raw user_id has no NULLs (03).
--   * Delivered value = SUM(order_value) WHERE status = 'delivered'.
-- Expected result:
--   Query 1: 8 rows, all passes = true.
--   Query 2: 3 rows; step 1 = 5,684 rows, step 2 = 5,478 rows.
--   Query 3: 2 rows; 5,135 -> 5,100.
-- =====================================================================

-- Query 1: pass/fail checks
WITH test_users AS (
    SELECT user_id
    FROM raw_users
    WHERE LOWER(split_part(email, '@', 2)) = 'urbancart.in'
),
dedup_orders AS (
    SELECT DISTINCT order_id, user_id, order_date, order_value, status
    FROM raw_orders
),
checks AS (
    SELECT 'clean_users rows = raw users - test accounts'      AS check_name,
           (SELECT COUNT(*) FROM raw_users)
         - (SELECT COUNT(*) FROM test_users)                    AS expected,
           (SELECT COUNT(*) FROM clean_users)                   AS actual
    UNION ALL
    SELECT 'no test-domain emails left in clean_users',
           0,
           (SELECT COUNT(*) FROM clean_users
            WHERE LOWER(split_part(email, '@', 2)) = 'urbancart.in')
    UNION ALL
    SELECT 'Unknown users = raw blank-channel non-test users',
           (SELECT COUNT(*) FROM raw_users
            WHERE NULLIF(TRIM(acquisition_channel), '') IS NULL
              AND user_id NOT IN (SELECT user_id FROM test_users)),
           (SELECT COUNT(*) FROM clean_users WHERE acquisition_channel = 'Unknown')
    UNION ALL
    SELECT 'Unknown users = channel_was_blank flag',
           (SELECT COUNT(*) FROM clean_users WHERE channel_was_blank),
           (SELECT COUNT(*) FROM clean_users WHERE acquisition_channel = 'Unknown')
    UNION ALL
    SELECT 'clean_orders rows = deduped raw orders of non-test users',
           (SELECT COUNT(*) FROM dedup_orders
            WHERE user_id NOT IN (SELECT user_id FROM test_users)),
           (SELECT COUNT(*) FROM clean_orders)
    UNION ALL
    SELECT 'clean delivered value = deduped raw delivered value of non-test users',
           (SELECT SUM(order_value) FROM dedup_orders
            WHERE status = 'delivered'
              AND user_id NOT IN (SELECT user_id FROM test_users)),
           (SELECT SUM(order_value) FROM clean_orders WHERE status = 'delivered')
    UNION ALL
    SELECT 'clean spend rows = raw spend rows',
           (SELECT COUNT(*) FROM raw_marketing_spend),
           (SELECT COUNT(*) FROM clean_marketing_spend)
    UNION ALL
    SELECT 'clean spend total = raw spend total',
           (SELECT SUM(spend_inr) FROM raw_marketing_spend),
           (SELECT SUM(spend_inr) FROM clean_marketing_spend)
)
SELECT check_name, expected, actual, expected = actual AS passes
FROM checks;

-- Query 2: orders chain (rows and delivered value at each stage)
SELECT 1 AS step, 'raw_orders' AS stage,
       COUNT(*) AS order_rows,
       SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END)           AS delivered_rows,
       SUM(CASE WHEN status = 'delivered' THEN order_value ELSE 0 END) AS delivered_value
FROM raw_orders
UNION ALL
SELECT 2, 'after removing exact duplicates (O1)',
       COUNT(*),
       SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END),
       SUM(CASE WHEN status = 'delivered' THEN order_value ELSE 0 END)
FROM (SELECT DISTINCT order_id, user_id, order_date, order_value, status
      FROM raw_orders) d
UNION ALL
SELECT 3, 'after removing test-account orders (U2) = clean_orders',
       COUNT(*),
       SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END),
       SUM(CASE WHEN status = 'delivered' THEN order_value ELSE 0 END)
FROM clean_orders
ORDER BY step;

-- Query 3: users chain
SELECT 1 AS step, 'raw_users' AS stage,
       COUNT(*) AS user_rows,
       SUM(CASE WHEN NULLIF(TRIM(acquisition_channel), '') IS NULL THEN 1 ELSE 0 END) AS blank_or_unknown_channel
FROM raw_users
UNION ALL
SELECT 2, 'after removing test accounts (U2) = clean_users',
       COUNT(*),
       SUM(CASE WHEN acquisition_channel = 'Unknown' THEN 1 ELSE 0 END)
FROM clean_users
ORDER BY step;
