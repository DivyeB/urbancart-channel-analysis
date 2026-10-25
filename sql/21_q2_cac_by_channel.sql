-- =====================================================================
-- 21_q2_cac_by_channel.sql
-- Brief Part 1, Q2: for each paid channel, total spend, number of new
-- customers and CAC.
-- Definitions (see docs/Part1_Analysis.md):
--   * New customer = clean user with >= 1 order where status =
--     'delivered', counted once (COUNT DISTINCT user_id).
--   * CAC = total Jan-Jun spend / new customers.
-- Filters and edge cases:
--   * Clean tables only: duplicates and test accounts already removed.
--   * Status: delivered only. Cancelled/returned never make a customer.
--   * Unknown-channel users excluded with NOT channel_was_blank.
--     (They could not join to spend anyway; the filter is explicit so
--     the rule is visible in every metric query.)
--   * The result is driven FROM the spend table, so only paid channels
--     appear (Organic has no spend). LEFT JOIN keeps a paid channel
--     even if it had zero customers; NULLIF then makes its CAC NULL
--     instead of a divide-by-zero error.
--   * Rounding only at display: cac_exact is unrounded, cac_inr is
--     rounded to the nearest rupee.
-- Expected result:
--   Query 1: 4 rows (one per paid channel). total_spend_inr sums to
--            1,590,000 (= clean spend total, 19). Affiliate
--            new_customers should equal 505 (20, excluding test accounts).
--   Query 2 (OPTIONAL "All paid" benchmark row, pending decision):
--            1 row; spend 1,590,000; customers = sum of Query 1.
-- =====================================================================

-- Query 1: spend, new customers and CAC per paid channel
WITH channel_spend AS (
    SELECT channel, SUM(spend_inr) AS total_spend
    FROM clean_marketing_spend
    GROUP BY channel
),
channel_new_customers AS (
    SELECT u.acquisition_channel     AS channel,
           COUNT(DISTINCT u.user_id) AS new_customers
    FROM clean_users u
    WHERE NOT u.channel_was_blank
      AND EXISTS (SELECT 1
                  FROM clean_orders o
                  WHERE o.user_id = u.user_id
                    AND o.status  = 'delivered')
    GROUP BY u.acquisition_channel
)
SELECT
    s.channel,
    CAST(s.total_spend AS BIGINT)                                  AS total_spend_inr,
    n.new_customers,
    s.total_spend / NULLIF(n.new_customers, 0)                     AS cac_exact,
    CAST(ROUND(s.total_spend / NULLIF(n.new_customers, 0)) AS BIGINT) AS cac_inr
FROM channel_spend s
LEFT JOIN channel_new_customers n ON n.channel = s.channel
ORDER BY s.channel;

-- Query 2 (optional): "All paid" benchmark = total paid spend / total paid new customers
WITH channel_spend AS (
    SELECT channel, SUM(spend_inr) AS total_spend
    FROM clean_marketing_spend
    GROUP BY channel
),
channel_new_customers AS (
    SELECT u.acquisition_channel     AS channel,
           COUNT(DISTINCT u.user_id) AS new_customers
    FROM clean_users u
    WHERE NOT u.channel_was_blank
      AND EXISTS (SELECT 1
                  FROM clean_orders o
                  WHERE o.user_id = u.user_id
                    AND o.status  = 'delivered')
    GROUP BY u.acquisition_channel
)
SELECT
    'All paid'                                                         AS channel,
    CAST(SUM(s.total_spend) AS BIGINT)                                 AS total_spend_inr,
    SUM(n.new_customers)                                               AS new_customers,
    SUM(s.total_spend) / NULLIF(SUM(n.new_customers), 0)               AS cac_exact,
    CAST(ROUND(SUM(s.total_spend) / NULLIF(SUM(n.new_customers), 0)) AS BIGINT) AS cac_inr
FROM channel_spend s
LEFT JOIN channel_new_customers n ON n.channel = s.channel;
