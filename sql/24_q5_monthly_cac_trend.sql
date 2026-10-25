-- =====================================================================
-- 24_q5_monthly_cac_trend.sql
-- Brief Part 1, Q5: CAC by month for each paid channel, grouping new
-- customers by their SIGNUP month. Which channel is getting more
-- expensive, and by how much from January to June?
-- Definitions (see docs/Part1_Analysis.md):
--   * Monthly CAC = spend in month m / new customers who signed up in
--     month m (and had >= 1 delivered order by 2026-06-30).
--   * Jan->Jun change reported in rupees and %.
--   * Sensitivity check: the same change Jan->May. June signups
--     have had at most 30 days to order, so June CAC is inflated by
--     timing alone. If the trend holds Jan->May, it's real.
-- Filters and edge cases:
--   * Delivered only (a customer = >= 1 delivered order).
--   * Unknown excluded (NOT channel_was_blank).
--   * Driven from clean_marketing_spend, so 4 paid channels x 6 months
--     = 24 rows. LEFT JOIN keeps a month even if it had no signups;
--     NULLIF makes its CAC NULL instead of a divide-by-zero error.
--   * signup month = date_trunc('month', signup_date), cast to DATE so
--     it matches month_start (e.g. 2026-03-17 -> 2026-03-01).
--   * signups and conversion_pct are DIAGNOSTIC columns, not brief
--     metrics: they show whether a CAC change comes from spend or from
--     a lower share of signups buying.
--   * Changes are calculated from unrounded CACs, so a displayed
--     change can differ by Rs 1 from subtracting the rounded CACs.
-- Expected result:
--   Query 1: 24 rows. Per channel, spend sums to its 21 total and
--            new_customers sum to its 21 count (505 / 655 / 307 / 675).
--   Query 2: 4 rows, sorted by Jan->Jun % change, highest first.
-- =====================================================================

-- Query 1: monthly CAC grid
WITH customer_ids AS (              -- every user with >= 1 delivered order
    SELECT DISTINCT user_id
    FROM clean_orders
    WHERE status = 'delivered'
),
signup_cohorts AS (                 -- per channel and signup month: signups and customers
    SELECT
        u.acquisition_channel                            AS channel,
        CAST(date_trunc('month', u.signup_date) AS DATE) AS signup_month,
        COUNT(*)                                         AS signups,
        COUNT(c.user_id)                                 AS new_customers   -- NULL (no match) not counted
    FROM clean_users u
    LEFT JOIN customer_ids c ON c.user_id = u.user_id
    WHERE NOT u.channel_was_blank
    GROUP BY u.acquisition_channel, signup_month
)
SELECT
    s.channel,
    s.month,
    CAST(s.spend_inr AS BIGINT)                                        AS spend_inr,
    k.signups,
    k.new_customers,
    ROUND(100.0 * k.new_customers / NULLIF(k.signups, 0), 1)           AS conversion_pct,
    s.spend_inr / NULLIF(k.new_customers, 0)                           AS cac_exact,
    CAST(ROUND(s.spend_inr / NULLIF(k.new_customers, 0)) AS BIGINT)    AS cac_inr
FROM clean_marketing_spend s
LEFT JOIN signup_cohorts k
       ON k.channel      = s.channel
      AND k.signup_month = s.month_start
ORDER BY s.channel, s.month_start;

-- Query 2: Jan->Jun change (brief) and Jan->May change (sensitivity check)
WITH customer_ids AS (
    SELECT DISTINCT user_id
    FROM clean_orders
    WHERE status = 'delivered'
),
signup_cohorts AS (
    SELECT
        u.acquisition_channel                            AS channel,
        CAST(date_trunc('month', u.signup_date) AS DATE) AS signup_month,
        COUNT(c.user_id)                                 AS new_customers
    FROM clean_users u
    LEFT JOIN customer_ids c ON c.user_id = u.user_id
    WHERE NOT u.channel_was_blank
    GROUP BY u.acquisition_channel, signup_month
),
monthly_cac AS (
    SELECT
        s.channel,
        s.month,
        s.spend_inr / NULLIF(k.new_customers, 0) AS cac
    FROM clean_marketing_spend s
    LEFT JOIN signup_cohorts k
           ON k.channel      = s.channel
          AND k.signup_month = s.month_start
),
endpoints AS (                       -- pivot the three months we compare
    SELECT
        channel,
        MAX(CASE WHEN month = '2026-01' THEN cac END) AS jan_cac,
        MAX(CASE WHEN month = '2026-05' THEN cac END) AS may_cac,
        MAX(CASE WHEN month = '2026-06' THEN cac END) AS jun_cac
    FROM monthly_cac
    GROUP BY channel
)
SELECT
    channel,
    CAST(ROUND(jan_cac) AS BIGINT)                          AS jan_cac_inr,
    CAST(ROUND(jun_cac) AS BIGINT)                          AS jun_cac_inr,
    CAST(ROUND(jun_cac - jan_cac) AS BIGINT)                AS jan_to_jun_change_inr,
    ROUND(100.0 * (jun_cac - jan_cac) / jan_cac, 1)         AS jan_to_jun_change_pct,
    CAST(ROUND(may_cac) AS BIGINT)                          AS may_cac_inr,
    CAST(ROUND(may_cac - jan_cac) AS BIGINT)                AS jan_to_may_change_inr,
    ROUND(100.0 * (may_cac - jan_cac) / jan_cac, 1)         AS jan_to_may_change_pct
FROM endpoints
ORDER BY jan_to_jun_change_pct DESC NULLS LAST;
