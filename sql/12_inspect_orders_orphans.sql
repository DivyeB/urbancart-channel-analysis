-- =====================================================================
-- 12_inspect_orders_orphans.sql
-- What:    Referential integrity between orders and users.
--   Query 1: "orphan" orders whose user_id does not exist in raw_users
--            (they have no acquisition channel, so cannot be attributed),
--            by status.
--   Query 2: users by order activity: no orders at all / only
--            cancelled-or-returned orders / at least one delivered order.
-- Assumptions:
--   * Raw tables, duplicates NOT removed. Query 1 counts order ROWS;
--     Query 2 counts USERS, so duplicate order rows don't change it.
--   * Query 1 uses LEFT JOIN ... WHERE u.user_id IS NULL ("anti-join"):
--     keeps orders with no matching user. An order with a NULL user_id
--     would also land here (09 reports null_user_id).
--   * Query 2 uses exact status = 'delivered'. If 11 finds variants
--     (e.g. 'Delivered'), this count is provisional.
-- Expected result:
--   Query 1: one row per status; zero rows = no orphans (clean).
--   Query 2: 1 row; the three buckets sum to total_users = 5135.
-- =====================================================================

-- Query 1: orders with no matching user
SELECT
    o.status,
    COUNT(*)                   AS orphan_order_rows,
    COUNT(DISTINCT o.user_id)  AS orphan_user_ids,
    SUM(o.order_value)         AS orphan_order_value
FROM raw_orders o
LEFT JOIN raw_users u ON u.user_id = o.user_id
WHERE u.user_id IS NULL
GROUP BY o.status
ORDER BY o.status;

-- Query 2: users by order activity
WITH orders_per_user AS (
    SELECT
        u.user_id,
        COUNT(o.user_id)                                         AS any_order_rows,       -- 0 when no match
        SUM(CASE WHEN o.status = 'delivered' THEN 1 ELSE 0 END)  AS delivered_order_rows
    FROM raw_users u
    LEFT JOIN raw_orders o ON o.user_id = u.user_id
    GROUP BY u.user_id
)
SELECT
    COUNT(*)                                                                         AS total_users,
    SUM(CASE WHEN any_order_rows = 0 THEN 1 ELSE 0 END)                              AS users_no_orders,
    SUM(CASE WHEN any_order_rows > 0 AND delivered_order_rows = 0 THEN 1 ELSE 0 END) AS users_only_failed_orders,
    SUM(CASE WHEN delivered_order_rows > 0 THEN 1 ELSE 0 END)                        AS users_with_delivered_order
FROM orders_per_user;
