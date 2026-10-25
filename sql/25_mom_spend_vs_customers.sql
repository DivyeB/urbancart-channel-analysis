-- =====================================================================
-- 25_mom_spend_vs_customers.sql
-- Supporting analysis for Q5 (not a brief question): month on month,
-- how did each paid channel's spend change compared with its new
-- customers? Shows whether extra spend bought extra customers.
-- Definitions: same as 24:
--   * new customers = users who signed up in that month and have >= 1
--     delivered order (by 2026-06-30), grouped by SIGNUP month.
--   * MoM change % = (this month - previous month) / previous month.
-- Filters and edge cases:
--   * Clean tables only; delivered only; Unknown excluded
--     (NOT channel_was_blank).
--   * Driven from clean_marketing_spend: 4 channels x 6 months = 24 rows.
--   * LAG(...) OVER (PARTITION BY channel ORDER BY month_start) reads the
--     previous month of the SAME channel. January has no previous month,
--     so its MoM changes are NULL (by design, not missing data).
--   * NULLIF guards a previous month of 0.
--   * June's customer count is from an immature cohort (at most 30 days
--     to buy), so June's customer change is understated; flagged in
--     cohort_note.
-- Expected result: 24 rows. spend_inr and new_customers equal 24 Query 1
--   cell for cell (e.g. Meta Jan Rs 54,000 / 110, May Rs 114,000 / 119).
-- =====================================================================

WITH customer_ids AS (              -- every user with >= 1 delivered order
    SELECT DISTINCT user_id
    FROM clean_orders
    WHERE status = 'delivered'
),
signup_cohorts AS (                 -- new customers per channel and signup month
    SELECT
        u.acquisition_channel                            AS channel,
        CAST(date_trunc('month', u.signup_date) AS DATE) AS signup_month,
        COUNT(c.user_id)                                 AS new_customers
    FROM clean_users u
    LEFT JOIN customer_ids c ON c.user_id = u.user_id
    WHERE NOT u.channel_was_blank
    GROUP BY u.acquisition_channel, signup_month
),
monthly AS (                        -- spend and customers side by side, with previous month
    SELECT
        s.channel,
        s.month,
        s.spend_inr,
        k.new_customers,
        LAG(s.spend_inr)     OVER (PARTITION BY s.channel ORDER BY s.month_start) AS prev_spend,
        LAG(k.new_customers) OVER (PARTITION BY s.channel ORDER BY s.month_start) AS prev_customers
    FROM clean_marketing_spend s
    LEFT JOIN signup_cohorts k
           ON k.channel      = s.channel
          AND k.signup_month = s.month_start
)
SELECT
    channel,
    month,
    CAST(spend_inr AS BIGINT)                                                     AS spend_inr,
    ROUND(100.0 * (spend_inr - prev_spend) / NULLIF(prev_spend, 0), 1)            AS spend_mom_change_pct,
    new_customers,
    ROUND(100.0 * (new_customers - prev_customers) / NULLIF(prev_customers, 0), 1) AS customers_mom_change_pct,
    CASE WHEN month = '2026-06' THEN 'immature cohort' END                        AS cohort_note
FROM monthly
ORDER BY channel, month;   -- 'YYYY-MM' text sorts chronologically (format checked in 14)
