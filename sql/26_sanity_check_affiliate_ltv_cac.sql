-- =====================================================================
-- 26_sanity_check_affiliate_ltv_cac.sql
-- Brief Part 1, Q6 (sanity check): verify Affiliate LTV:CAC = 0.42
-- (the "worst return" verdict from 23) by an INDEPENDENT route.
-- Why this number: it is the only one that depends on every pipeline
-- step: spend, customer count, revenue, de-duplication AND test-account
-- exclusion (all 35 test accounts were Affiliate).
--
-- How the independent route differs from the original (16, 17, 23):
--   step              original                    independent (this file)
--   source            clean tables                RAW tables only
--   de-duplication    SELECT DISTINCT             ROW_NUMBER() per order_id, keep row 1
--   test accounts     email domain = urbancart.in email does NOT match 'user<id>@'
--   formula           LTV / CAC via per-customer  0.30 x revenue / spend
-- Assumptions:
--   * ROW_NUMBER keeps an arbitrary copy when an order_id repeats. That
--     is safe only because 10 proved every duplicate is EXACT (all 5
--     columns identical), so any copy is the same.
--   * The user<id>@ rule flags the same 35 users as the domain rule (08),
--     but it's a different test, so it is evaluated afresh here.
--   * Delivered only. Unknown channel not relevant (filter is
--     channel = 'Affiliate').
-- Expected result:
--   Query 1: 2 rows (independent, original) with identical spend
--            346,000, customers 505, revenue 483,387, LTV:CAC 0.42.
--   Query 2: 4 rows, all matches = true.
-- =====================================================================

-- Query 1: both routes side by side
WITH numbered_orders AS (           -- independent route: number the copies of each order_id
    SELECT
        order_id, user_id, order_date, order_value, status,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_id) AS copy_number
    FROM raw_orders
),
dedup_orders AS (                   -- keep the first copy of each order
    SELECT order_id, user_id, order_value, status
    FROM numbered_orders
    WHERE copy_number = 1
),
real_affiliate_users AS (           -- Affiliate users whose email follows user<id>@ (i.e. not test)
    SELECT user_id
    FROM raw_users
    WHERE acquisition_channel = 'Affiliate'
      AND email LIKE 'user' || CAST(user_id AS VARCHAR) || '@%'
),
independent AS (
    SELECT
        'independent (raw, ROW_NUMBER, email pattern)'                         AS route,
        (SELECT SUM(spend_inr) FROM raw_marketing_spend WHERE channel = 'Affiliate') AS spend,
        COUNT(DISTINCT d.user_id)                                               AS customers,
        SUM(d.order_value)                                                      AS revenue
    FROM dedup_orders d
    JOIN real_affiliate_users a ON a.user_id = d.user_id
    WHERE d.status = 'delivered'
),
original AS (                       -- the original pipeline's figures (clean tables, as in 23)
    SELECT
        'original (clean tables, as in 23)'                                     AS route,
        (SELECT SUM(spend_inr) FROM clean_marketing_spend WHERE channel = 'Affiliate') AS spend,
        COUNT(DISTINCT o.user_id)                                               AS customers,
        SUM(o.order_value)                                                      AS revenue
    FROM clean_orders o
    JOIN clean_users u ON u.user_id = o.user_id
    WHERE o.status = 'delivered'
      AND u.acquisition_channel = 'Affiliate'
      AND NOT u.channel_was_blank
),
both_routes AS (
    SELECT * FROM independent
    UNION ALL
    SELECT * FROM original
)
SELECT
    route,
    CAST(spend AS BIGINT)                          AS spend_inr,
    customers,
    CAST(revenue AS BIGINT)                        AS delivered_revenue_inr,
    CAST(ROUND(spend / customers) AS BIGINT)       AS cac_inr,
    CAST(ROUND(0.30 * revenue / customers) AS BIGINT) AS ltv_inr,
    0.30 * revenue / spend                         AS ltv_to_cac_exact,
    ROUND(0.30 * revenue / spend, 2)               AS ltv_to_cac
FROM both_routes;

-- Query 2: pass/fail, component by component
WITH numbered_orders AS (
    SELECT order_id, user_id, order_value, status,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_id) AS copy_number
    FROM raw_orders
),
dedup_orders AS (
    SELECT order_id, user_id, order_value, status
    FROM numbered_orders
    WHERE copy_number = 1
),
real_affiliate_users AS (
    SELECT user_id
    FROM raw_users
    WHERE acquisition_channel = 'Affiliate'
      AND email LIKE 'user' || CAST(user_id AS VARCHAR) || '@%'
),
ind AS (
    SELECT (SELECT SUM(spend_inr) FROM raw_marketing_spend WHERE channel = 'Affiliate') AS spend,
           COUNT(DISTINCT d.user_id) AS customers,
           SUM(d.order_value)        AS revenue
    FROM dedup_orders d
    JOIN real_affiliate_users a ON a.user_id = d.user_id
    WHERE d.status = 'delivered'
),
orig AS (
    SELECT (SELECT SUM(spend_inr) FROM clean_marketing_spend WHERE channel = 'Affiliate') AS spend,
           COUNT(DISTINCT o.user_id) AS customers,
           SUM(o.order_value)        AS revenue
    FROM clean_orders o
    JOIN clean_users u ON u.user_id = o.user_id
    WHERE o.status = 'delivered'
      AND u.acquisition_channel = 'Affiliate'
      AND NOT u.channel_was_blank
)
SELECT 'spend' AS component, CAST(ind.spend AS VARCHAR) AS independent, CAST(orig.spend AS VARCHAR) AS original,
       ind.spend = orig.spend AS matches FROM ind, orig
UNION ALL
SELECT 'customers', CAST(ind.customers AS VARCHAR), CAST(orig.customers AS VARCHAR),
       ind.customers = orig.customers FROM ind, orig
UNION ALL
SELECT 'delivered revenue', CAST(ind.revenue AS VARCHAR), CAST(orig.revenue AS VARCHAR),
       ind.revenue = orig.revenue FROM ind, orig
UNION ALL
SELECT 'LTV:CAC (2 dp)', CAST(ROUND(0.30 * ind.revenue / ind.spend, 2) AS VARCHAR),
       CAST(ROUND(0.30 * orig.revenue / orig.spend, 2) AS VARCHAR),
       ROUND(0.30 * ind.revenue / ind.spend, 2) = ROUND(0.30 * orig.revenue / orig.spend, 2) FROM ind, orig;
