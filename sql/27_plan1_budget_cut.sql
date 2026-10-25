-- =====================================================================
-- 27_plan1_budget_cut.sql
-- Part 2 (recommendation): query-backed figures for Plan 1.
--   Query 1: Apr-Jun spend base, the 20% saving target, and Plan 1's
--            per-channel change and resulting quarterly spend.
--   Query 2: ESTIMATED customer impact per quarter of each change.
-- Plan 1 rules, all derived from data, none typed in:
--   * Base = actual Apr-Jun 2026 paid spend (latest run-rate).
--   * Saving target = 20% of the base.
--   * Google increase = headroom inside Google's OBSERVED monthly spend
--     range: 3 x its highest month in Jan-Jun, minus its Apr-Jun spend.
--   * Affiliate cut = the same amount (moved to Google: spend-neutral).
--   * Meta cut = the full saving target (because the Affiliate->Google
--     move nets to zero). Influencer unchanged.
-- Query 2 assumptions (these are ESTIMATES, not observed results):
--   * Customers per quarter lost/gained = spend change / a cost per
--     customer. Two costs for Meta give a range:
--       worst case = Meta's average CAC over Jan-Jun (as in 21)
--       best case  = Meta's incremental cost per extra customer Jan->May
--                    = (May spend - Jan spend) / (May customers - Jan
--                    customers), signup-month cohorts as in 24/25
--   * Affiliate and Google use their average Jan-Jun CAC (21): their
--     customers moved with spend month to month (25).
--   * Revenue change = customers x the channel's revenue per customer
--     (22). Delivered only; Unknown excluded; clean tables.
-- Expected result:
--   Query 1: 5 rows (4 channels + Total). Base 868,000; target 173,600;
--            Total change = -173,600 (= -20.0%).
--   Query 2: 4 rows; Meta worst ~ -214 and best ~ -26 customers;
--            Affiliate ~ -34, Google ~ +38.
-- =====================================================================

-- Query 1: base, target and Plan 1 per channel
WITH channel_spend AS (
    SELECT
        channel,
        SUM(CASE WHEN month BETWEEN '2026-04' AND '2026-06' THEN spend_inr ELSE 0 END) AS q2_spend,
        MAX(spend_inr)                                                                  AS max_monthly_spend
    FROM clean_marketing_spend
    GROUP BY channel
),
saving_target AS (
    SELECT SUM(q2_spend) AS base, 0.20 * SUM(q2_spend) AS target
    FROM channel_spend
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
        CASE c.channel
            WHEN 'Meta Ads'   THEN -t.target
            WHEN 'Affiliate'  THEN -g.shift
            WHEN 'Google Ads' THEN  g.shift
            ELSE 0
        END AS change
    FROM channel_spend c
    CROSS JOIN saving_target t
    CROSS JOIN google_headroom g
),
plan_with_total AS (
    SELECT 1 AS sort_key, channel, q2_spend, change FROM plan
    UNION ALL
    SELECT 2, 'Total', SUM(q2_spend), SUM(change) FROM plan
)
SELECT
    channel,
    CAST(q2_spend AS BIGINT)                                  AS apr_jun_spend_inr,
    CAST(ROUND(change) AS BIGINT)                             AS plan_change_inr,
    ROUND(100.0 * change / q2_spend, 1)                       AS plan_change_pct,
    CAST(ROUND(q2_spend + change) AS BIGINT)                  AS next_quarter_spend_inr,
    CAST(ROUND((q2_spend + change) / 3) AS BIGINT)            AS next_quarter_monthly_inr
FROM plan_with_total
ORDER BY sort_key, channel;

-- Query 2: estimated customer and revenue impact per quarter
WITH channel_spend AS (
    SELECT
        channel,
        SUM(spend_inr)                                                                  AS h1_spend,
        SUM(CASE WHEN month BETWEEN '2026-04' AND '2026-06' THEN spend_inr ELSE 0 END) AS q2_spend,
        MAX(spend_inr)                                                                  AS max_monthly_spend,
        MAX(CASE WHEN month = '2026-01' THEN spend_inr END)                             AS jan_spend,
        MAX(CASE WHEN month = '2026-05' THEN spend_inr END)                             AS may_spend
    FROM clean_marketing_spend
    GROUP BY channel
),
delivered_per_user AS (
    SELECT user_id, SUM(order_value) AS delivered_revenue
    FROM clean_orders
    WHERE status = 'delivered'
    GROUP BY user_id
),
channel_customers AS (               -- H1 customers and revenue, as in 22/23
    SELECT
        u.acquisition_channel                                                AS channel,
        COUNT(*)                                                             AS customers,
        SUM(d.delivered_revenue)                                             AS revenue,
        SUM(CASE WHEN date_trunc('month', u.signup_date) = DATE '2026-01-01' THEN 1 ELSE 0 END) AS jan_customers,
        SUM(CASE WHEN date_trunc('month', u.signup_date) = DATE '2026-05-01' THEN 1 ELSE 0 END) AS may_customers
    FROM clean_users u
    JOIN delivered_per_user d ON d.user_id = u.user_id
    WHERE NOT u.channel_was_blank
    GROUP BY u.acquisition_channel
),
inputs AS (
    SELECT
        s.channel,
        s.h1_spend / c.customers                                             AS avg_cac,
        c.revenue  / c.customers                                             AS revenue_per_customer,
        (s.may_spend - s.jan_spend) / NULLIF(c.may_customers - c.jan_customers, 0) AS incremental_cac_jan_to_may
    FROM channel_spend s
    JOIN channel_customers c ON c.channel = s.channel
),
plan_amounts AS (
    SELECT
        (SELECT 0.20 * SUM(q2_spend) FROM channel_spend)                                    AS meta_cut,
        (SELECT 3 * max_monthly_spend - q2_spend FROM channel_spend WHERE channel = 'Google Ads') AS shift
),
scenarios AS (
    SELECT 1 AS sort_key, 'Meta -' || CAST(CAST(p.meta_cut AS BIGINT) AS VARCHAR) || ': worst case (at Meta average CAC)' AS scenario,
           -p.meta_cut AS spend_change, i.avg_cac AS cost_per_customer, i.revenue_per_customer
    FROM plan_amounts p, inputs i WHERE i.channel = 'Meta Ads'
    UNION ALL
    SELECT 2, 'Meta -' || CAST(CAST(p.meta_cut AS BIGINT) AS VARCHAR) || ': best case (at Meta Jan->May incremental cost)',
           -p.meta_cut, i.incremental_cac_jan_to_may, i.revenue_per_customer
    FROM plan_amounts p, inputs i WHERE i.channel = 'Meta Ads'
    UNION ALL
    SELECT 3, 'Affiliate -' || CAST(CAST(p.shift AS BIGINT) AS VARCHAR) || ' (at Affiliate average CAC)',
           -p.shift, i.avg_cac, i.revenue_per_customer
    FROM plan_amounts p, inputs i WHERE i.channel = 'Affiliate'
    UNION ALL
    SELECT 4, 'Google +' || CAST(CAST(p.shift AS BIGINT) AS VARCHAR) || ' (at Google average CAC)',
           p.shift, i.avg_cac, i.revenue_per_customer
    FROM plan_amounts p, inputs i WHERE i.channel = 'Google Ads'
)
SELECT
    scenario,
    CAST(ROUND(spend_change) AS BIGINT)                               AS spend_change_inr,
    CAST(ROUND(cost_per_customer) AS BIGINT)                          AS cost_per_customer_inr,
    CAST(ROUND(spend_change / cost_per_customer) AS BIGINT)           AS est_customers_change,
    CAST(ROUND(spend_change / cost_per_customer * revenue_per_customer) AS BIGINT) AS est_revenue_change_inr
FROM scenarios
ORDER BY sort_key;
