-- =====================================================================
-- 08_profile_users_test_accounts.sql
-- What:    Follow-up to 07, which found 35 emails not matching the
--          'user<user_id>@' pattern and 35 users on the company's own
--          domain urbancart.in (examples: qa.test1@urbancart.in).
--          Characterises these suspected internal QA/test accounts:
--   Query 1: do the two rules flag the SAME 35 users? ID and date range.
--   Query 2: which acquisition_channel they are attributed to.
--   Query 3: whether they placed orders, by status, and the order value
--            (this is what decides whether they can distort the metrics).
-- Assumptions:
--   * "test-like" = fails the user<id>@ pattern OR is on urbancart.in.
--     Using OR (not AND) so Query 1 can show whether the rules overlap.
--   * Query 3 reads raw_orders: duplicates NOT removed and ALL statuses
--     shown (no delivered filter), because this is profiling. It is an
--     upper bound until dedup is decided in step 4.
--   * Each query repeats the CTE because a CTE only lives for one
--     statement (same in MySQL).
-- Expected result:
--   Query 1: 1 row. If both rule columns = test_like_users = 35, the
--            rules flag exactly the same users.
--   Query 2: one row per channel (incl. NULL); users sum to Query 1 total.
--   Query 3: one row per status for orders by test-like users; empty if
--            they placed no orders.
-- =====================================================================

-- Query 1: overlap of the two rules, ID and signup range
WITH test_like_users AS (
    SELECT *
    FROM raw_users
    WHERE email NOT LIKE 'user' || CAST(user_id AS VARCHAR) || '@%'
       OR split_part(email, '@', 2) = 'urbancart.in'
)
SELECT
    COUNT(*)                                                                       AS test_like_users,
    SUM(CASE WHEN email NOT LIKE 'user' || CAST(user_id AS VARCHAR) || '@%'
             THEN 1 ELSE 0 END)                                                    AS fails_user_id_pattern,
    SUM(CASE WHEN split_part(email, '@', 2) = 'urbancart.in' THEN 1 ELSE 0 END)    AS on_urbancart_domain,
    SUM(CASE WHEN email LIKE 'qa.test%' THEN 1 ELSE 0 END)                         AS starts_with_qa_test,
    MIN(user_id)                                                                   AS min_user_id,
    MAX(user_id)                                                                   AS max_user_id,
    MIN(signup_date)                                                               AS first_signup,
    MAX(signup_date)                                                               AS last_signup
FROM test_like_users;

-- Query 2: channel attribution of test-like users
WITH test_like_users AS (
    SELECT *
    FROM raw_users
    WHERE email NOT LIKE 'user' || CAST(user_id AS VARCHAR) || '@%'
       OR split_part(email, '@', 2) = 'urbancart.in'
)
SELECT
    acquisition_channel,
    COUNT(*) AS users
FROM test_like_users
GROUP BY acquisition_channel
ORDER BY users DESC;

-- Query 3: orders placed by test-like users, by status (raw, not deduped)
WITH test_like_users AS (
    SELECT *
    FROM raw_users
    WHERE email NOT LIKE 'user' || CAST(user_id AS VARCHAR) || '@%'
       OR split_part(email, '@', 2) = 'urbancart.in'
)
SELECT
    o.status,
    COUNT(*)                   AS order_rows,
    COUNT(DISTINCT o.user_id)  AS test_users_with_orders,
    SUM(o.order_value)         AS total_order_value
FROM raw_orders o
JOIN test_like_users t ON t.user_id = o.user_id
GROUP BY o.status
ORDER BY o.status;
