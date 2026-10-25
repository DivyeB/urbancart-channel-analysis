-- =====================================================================
-- 28_export_chart_data.sql
-- What:    Writes the data behind memo charts C1-C3 to CSV files in
--          outputs/charts/data/, for upload to Looker Studio.
--          All calculation happens here in SQL; Looker Studio only draws.
--   C1 -> c1_spend_vs_customers_index.csv
--         per paid channel and month: spend, new customers, and both
--         indexed to that channel's January = 100. All 4 channels are
--         included so the report can filter by channel (memo shows Meta).
--   C2 -> c2_ltv_cac_by_channel.csv
--         per paid channel: CAC, LTV, LTV:CAC (same logic as 23).
--   C3 -> c3_plan1_spend.csv
--         per paid channel: Apr-Jun actual and Plan 1 next-quarter spend,
--         in LONG format (one row per channel per period) so Looker
--         Studio can draw grouped bars with "period" as the breakdown.
-- How to run (from the repo root; creates no tables):
--   duckdb.exe urbancart.duckdb < sql/28_export_chart_data.sql
-- Assumptions:
--   * Same definitions as 21-27: clean tables, delivered only, Unknown
--     excluded, signup-month cohorts; Plan 1 rules as in 27.
--   * Values are rounded for display (money to the rupee, index and
--     LTV:CAC to 1 / 2 dp) only at the final SELECT.
--   * month_start is written as YYYYMMDD text (e.g. 20260101): Looker
--     Studio's CSV File Upload only converts that pattern to a Date
--     type; it rejected ISO 2026-01-01 ("can't convert to date").
--   * The outputs/charts/data/ folder must exist before running.
-- Expected result: 3 CSV files with headers.
--   C1: 24 rows; Meta Jan = 100 / 100, Meta May spend_index = 211.1,
--       customers_index = 108.2 (matches 25's Jan->May figures).
--   C2: 4 rows; LTV:CAC 1.14 / 0.89 / 0.62 / 0.42 (matches 23).
--   C3: 8 rows; Meta 339,000 -> 165,400, Google 205,000 -> 228,000,
--       Affiliate 170,000 -> 147,000, Influencer 154,000 (matches 27).
-- =====================================================================

-- C1: spend vs new customers, indexed to January = 100
COPY (
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
    monthly AS (
        SELECT s.channel, s.month_start, s.spend_inr, k.new_customers
        FROM clean_marketing_spend s
        LEFT JOIN signup_cohorts k
               ON k.channel      = s.channel
              AND k.signup_month = s.month_start
    )
    SELECT
        channel,
        strftime(month_start, '%Y%m%d')                                               AS month_start,  -- Looker date format
        CAST(spend_inr AS BIGINT)                                                     AS spend_inr,
        new_customers,
        ROUND(100.0 * spend_inr
              / FIRST_VALUE(spend_inr)     OVER (PARTITION BY channel ORDER BY month_start), 1) AS spend_index,
        ROUND(100.0 * new_customers
              / FIRST_VALUE(new_customers) OVER (PARTITION BY channel ORDER BY month_start), 1) AS customers_index
    FROM monthly
    ORDER BY channel, month_start
) TO 'outputs/charts/data/c1_spend_vs_customers_index.csv' (HEADER, DELIMITER ',');

-- C2: LTV:CAC per paid channel
COPY (
    WITH channel_spend AS (
        SELECT channel, SUM(spend_inr) AS total_spend
        FROM clean_marketing_spend
        GROUP BY channel
    ),
    delivered_per_user AS (
        SELECT user_id, SUM(order_value) AS delivered_revenue
        FROM clean_orders
        WHERE status = 'delivered'
        GROUP BY user_id
    ),
    channel_customers AS (
        SELECT u.acquisition_channel AS channel,
               COUNT(*)              AS customers,
               SUM(d.delivered_revenue) AS revenue
        FROM clean_users u
        JOIN delivered_per_user d ON d.user_id = u.user_id
        WHERE NOT u.channel_was_blank
        GROUP BY u.acquisition_channel
    )
    SELECT
        s.channel,
        CAST(ROUND(s.total_spend / c.customers) AS BIGINT)        AS cac_inr,
        CAST(ROUND(0.30 * c.revenue / c.customers) AS BIGINT)     AS ltv_inr,
        ROUND((0.30 * c.revenue / c.customers) / (s.total_spend / c.customers), 2) AS ltv_to_cac
    FROM channel_spend s
    JOIN channel_customers c ON c.channel = s.channel
    ORDER BY ltv_to_cac DESC
) TO 'outputs/charts/data/c2_ltv_cac_by_channel.csv' (HEADER, DELIMITER ',');

-- C3: Plan 1 spend per channel, Apr-Jun actual vs next quarter (long format)
COPY (
    WITH channel_spend AS (
        SELECT
            channel,
            SUM(CASE WHEN month BETWEEN '2026-04' AND '2026-06' THEN spend_inr ELSE 0 END) AS q2_spend,
            MAX(spend_inr)                                                                  AS max_monthly_spend
        FROM clean_marketing_spend
        GROUP BY channel
    ),
    saving_target AS (
        SELECT 0.20 * SUM(q2_spend) AS target FROM channel_spend
    ),
    google_headroom AS (
        SELECT 3 * max_monthly_spend - q2_spend AS shift
        FROM channel_spend
        WHERE channel = 'Google Ads'
    ),
    plan AS (
        SELECT
            c.channel,
            c.q2_spend,
            c.q2_spend + CASE c.channel
                             WHEN 'Meta Ads'   THEN -t.target
                             WHEN 'Affiliate'  THEN -g.shift
                             WHEN 'Google Ads' THEN  g.shift
                             ELSE 0
                         END AS next_quarter_spend
        FROM channel_spend c
        CROSS JOIN saving_target t
        CROSS JOIN google_headroom g
    )
    SELECT channel, 'Apr-Jun actual' AS period, 1 AS period_order,
           CAST(ROUND(q2_spend) AS BIGINT) AS spend_inr
    FROM plan
    UNION ALL
    SELECT channel, 'Next quarter (Plan 1)', 2,
           CAST(ROUND(next_quarter_spend) AS BIGINT)
    FROM plan
    ORDER BY channel, period_order
) TO 'outputs/charts/data/c3_plan1_spend.csv' (HEADER, DELIMITER ',');
