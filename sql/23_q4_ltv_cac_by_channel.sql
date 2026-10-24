-- =====================================================================
-- 23_q4_ltv_cac_by_channel.sql
-- Brief Part 1, Q4: LTV:CAC for each paid channel, and which channel
-- gives the best and worst return.
-- Definitions (DECISIONS.md, M1-M3, M5, M6, M8):
--   * CAC = channel spend / new customers                       (M2)
--   * Revenue per customer = delivered revenue / new customers  (M3)
--   * LTV = revenue per customer x 0.30 (brief's flat margin)   (M5)
--   * LTV:CAC = LTV / CAC                                        (M6)
-- Filters and edge cases:
--   * Recomputed from the clean tables, NOT from the rounded outputs of
--     21/22, so no rounding error carries through (M8).
--   * Status: delivered only. Unknown excluded (NOT channel_was_blank).
--   * Driven from the spend table, so only the 4 paid channels appear
--     (Organic has no CAC, so no LTV:CAC).
--   * NULLIF guards against a channel with zero customers.
--   * Best/worst = highest/lowest LTV:CAC via RANK(); ties would share
--     a label. NULLS LAST so a NULL ratio could never rank as "best".
--   * Check column: LTV:CAC simplifies algebraically to
--       (0.30 x revenue / customers) / (spend / customers)
--     = 0.30 x revenue / spend   (customers cancel out).
--     ltv_to_cac_shortcut computes it that way; it must equal
--     ltv_to_cac_exact.
-- Expected result: 4 rows, sorted best to worst. cac_inr equals 21;
--   revenue_per_customer_inr equals 22; ltv_to_cac_exact =
--   ltv_to_cac_shortcut on every row; exactly one 'best', one 'worst'.
-- =====================================================================

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
    SELECT u.acquisition_channel    AS channel,
           COUNT(*)                 AS customers,
           SUM(d.delivered_revenue) AS revenue
    FROM clean_users u
    JOIN delivered_per_user d ON d.user_id = u.user_id
    WHERE NOT u.channel_was_blank
    GROUP BY u.acquisition_channel
),
metrics AS (
    SELECT
        s.channel,
        s.total_spend,
        c.customers,
        c.revenue,
        s.total_spend / NULLIF(c.customers, 0)          AS cac,
        c.revenue     / NULLIF(c.customers, 0)          AS revenue_per_customer,
        0.30 * c.revenue / NULLIF(c.customers, 0)       AS ltv
    FROM channel_spend s
    LEFT JOIN channel_customers c ON c.channel = s.channel
)
SELECT
    channel,
    CAST(ROUND(cac) AS BIGINT)                          AS cac_inr,
    CAST(ROUND(revenue_per_customer) AS BIGINT)         AS revenue_per_customer_inr,
    CAST(ROUND(ltv) AS BIGINT)                          AS ltv_inr,
    ltv / cac                                           AS ltv_to_cac_exact,
    0.30 * revenue / total_spend                        AS ltv_to_cac_shortcut,
    ROUND(ltv / cac, 2)                                 AS ltv_to_cac,
    CASE
        WHEN RANK() OVER (ORDER BY ltv / cac DESC NULLS LAST) = 1 THEN 'best'
        WHEN RANK() OVER (ORDER BY ltv / cac ASC  NULLS LAST) = 1 THEN 'worst'
    END                                                 AS verdict
FROM metrics
ORDER BY ltv / cac DESC NULLS LAST;
