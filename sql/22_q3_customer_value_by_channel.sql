-- =====================================================================
-- 22_q3_customer_value_by_channel.sql
-- Brief Part 1, Q3: for each channel, including Organic, the revenue
-- per customer and the repeat purchase rate.
-- Definitions (DECISIONS.md, M1, M3, M4, M8):
--   * Customer = clean user with >= 1 delivered order (M1).
--   * Revenue per customer = delivered revenue of the channel's
--     customers / number of customers (not signups) (M3).
--   * Repeat rate = customers with >= 2 delivered orders / customers (M4).
-- Filters and edge cases:
--   * Clean tables only: duplicates and test accounts already removed;
--     each order_id appears once (PRIMARY KEY), so COUNT(*) of orders
--     is a count of distinct orders.
--   * Status: delivered only, for both revenue and order counts.
--     Cancelled/returned orders add no revenue and don't count towards
--     the 2 orders needed for a repeat.
--   * Unknown-channel users excluded with NOT channel_was_blank (D11).
--   * Users with no delivered order drop out at the INNER JOIN: they
--     are not customers, so they're in neither numerator nor denominator.
--   * Rounding only at display (M8): revenue_per_customer_exact is kept
--     unrounded for Q4; displayed money to nearest rupee, % to 1 dp.
-- Expected result: 5 rows (Affiliate, Google Ads, Influencer, Meta Ads,
--   then Organic). Paid customer counts = Q2 (21): 505 / 655 / 307 / 675.
--   Organic customers = 461 (predicted in DECISIONS.md from earlier
--   outputs). total_delivered_revenue over the 5 rows = clean delivered
--   total 4,961,884 - Unknown customers' 85,089 = 4,876,795.
-- =====================================================================

WITH delivered_per_user AS (        -- one row per user who has >= 1 delivered order
    SELECT
        o.user_id,
        COUNT(*)           AS delivered_orders,
        SUM(o.order_value) AS delivered_revenue
    FROM clean_orders o
    WHERE o.status = 'delivered'
    GROUP BY o.user_id
),
customers AS (                      -- attach each customer's channel
    SELECT
        u.acquisition_channel AS channel,
        d.user_id,
        d.delivered_orders,
        d.delivered_revenue
    FROM clean_users u
    JOIN delivered_per_user d ON d.user_id = u.user_id
    WHERE NOT u.channel_was_blank
)
SELECT
    channel,
    COUNT(*)                                                            AS customers,
    CAST(SUM(delivered_revenue) AS BIGINT)                              AS total_delivered_revenue,
    SUM(delivered_revenue) / COUNT(*)                                   AS revenue_per_customer_exact,
    CAST(ROUND(SUM(delivered_revenue) / COUNT(*)) AS BIGINT)            AS revenue_per_customer_inr,
    SUM(CASE WHEN delivered_orders >= 2 THEN 1 ELSE 0 END)              AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN delivered_orders >= 2 THEN 1 ELSE 0 END)
                / COUNT(*), 1)                                          AS repeat_rate_pct
FROM customers
GROUP BY channel
ORDER BY CASE WHEN channel = 'Organic' THEN 1 ELSE 0 END,   -- paid channels first, Organic last
         channel;
