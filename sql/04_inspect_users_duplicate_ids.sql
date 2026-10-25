-- =====================================================================
-- 04_inspect_users_duplicate_ids.sql
-- What:    Finds user_ids that appear on more than one row, and splits
--          them into:
--            * exact duplicates: every copy is identical in all 5 columns
--            * conflicting: the copies differ in at least one column
--              (e.g. two different acquisition_channels)
-- Assumptions:
--   * SELECT DISTINCT treats two NULLs as equal, so rows that are
--     identical including their blanks count as one version.
--   * Rows with NULL user_id are excluded (the join on user_id
--     cannot match NULL); 03 already counts them.
--   * No status filter (users has no status column).
-- Expected result:
--   Query 1: up to 2 rows (one per duplicate_type). ZERO rows means no
--            user_id repeats; that is a clean result, not an error.
--   Query 2: up to 20 raw rows belonging to conflicting user_ids, so we
--            can see what differs. Empty if there are none.
-- =====================================================================

-- Query 1: summary
WITH raw_copies_per_id AS (          -- how many raw rows each user_id has
    SELECT user_id, COUNT(*) AS raw_copies
    FROM raw_users
    WHERE user_id IS NOT NULL
    GROUP BY user_id
),
distinct_rows AS (                   -- collapse identical rows into one
    SELECT DISTINCT user_id, signup_date, city, acquisition_channel, email
    FROM raw_users
    WHERE user_id IS NOT NULL
),
versions_per_id AS (                 -- how many DIFFERENT versions each user_id has
    SELECT user_id, COUNT(*) AS distinct_versions
    FROM distinct_rows
    GROUP BY user_id
)
SELECT
    CASE WHEN v.distinct_versions = 1 THEN 'exact duplicates'
         ELSE 'conflicting' END            AS duplicate_type,
    COUNT(*)                               AS user_ids_affected,
    SUM(c.raw_copies)                      AS raw_rows_involved,
    SUM(c.raw_copies) - COUNT(*)           AS rows_beyond_one_per_id
FROM raw_copies_per_id c
JOIN versions_per_id   v ON v.user_id = c.user_id
WHERE c.raw_copies > 1
GROUP BY duplicate_type
ORDER BY duplicate_type;

-- Query 2: examples of conflicting user_ids (all their raw rows)
WITH conflicting_ids AS (
    SELECT user_id
    FROM (SELECT DISTINCT user_id, signup_date, city, acquisition_channel, email
          FROM raw_users
          WHERE user_id IS NOT NULL) d
    GROUP BY user_id
    HAVING COUNT(*) > 1
)
SELECT u.*
FROM raw_users u
JOIN conflicting_ids c ON c.user_id = u.user_id
ORDER BY u.user_id, u.signup_date
LIMIT 20;
