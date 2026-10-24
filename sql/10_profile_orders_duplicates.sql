-- =====================================================================
-- 10_profile_orders_duplicates.sql
-- What:    Duplicate orders, in three flavours:
--   Query 1: order_ids on more than one row, split into
--              * exact duplicates (all 5 columns identical)
--              * conflicting (same order_id, some column differs)
--   Query 2: for EXACT duplicates, the extra rows and extra order value
--            they add, by status (shows how much revenue they inflate)
--   Query 3: up to 20 raw rows of conflicting order_ids (empty if none)
--   Query 4: possible double-submits: DIFFERENT order_ids with the same
--            user_id, order_date, order_value and status. Informational:
--            these may be genuine repeat purchases.
-- Assumptions:
--   * SELECT DISTINCT treats NULLs as equal.
--   * Rows with NULL order_id excluded from Queries 1-3 (09 counts them).
--   * All statuses included; no dedup applied (this IS the dedup check).
-- Expected result:
--   Query 1: 0-2 rows (zero rows = no repeated order_id).
--   Query 2: one row per status; extra_rows sums to Query 1's
--            rows_beyond_one_per_id for 'exact duplicates'.
--   Query 3: 0-20 rows.  Query 4: 1 row.
-- =====================================================================

-- Query 1: summary by duplicate type
WITH raw_copies_per_id AS (          -- how many raw rows each order_id has
    SELECT order_id, COUNT(*) AS raw_copies
    FROM raw_orders
    WHERE order_id IS NOT NULL
    GROUP BY order_id
),
distinct_rows AS (                   -- collapse identical rows into one
    SELECT DISTINCT order_id, user_id, order_date, order_value, status
    FROM raw_orders
    WHERE order_id IS NOT NULL
),
versions_per_id AS (                 -- how many DIFFERENT versions each order_id has
    SELECT order_id, COUNT(*) AS distinct_versions
    FROM distinct_rows
    GROUP BY order_id
)
SELECT
    CASE WHEN v.distinct_versions = 1 THEN 'exact duplicates'
         ELSE 'conflicting' END            AS duplicate_type,
    COUNT(*)                               AS order_ids_affected,
    SUM(c.raw_copies)                      AS raw_rows_involved,
    SUM(c.raw_copies) - COUNT(*)           AS rows_beyond_one_per_id,
    MAX(c.raw_copies)                      AS max_copies_of_one_id
FROM raw_copies_per_id c
JOIN versions_per_id   v ON v.order_id = c.order_id
WHERE c.raw_copies > 1
GROUP BY duplicate_type
ORDER BY duplicate_type;

-- Query 2: what the exact duplicates add, by status
WITH raw_copies_per_id AS (
    SELECT order_id, COUNT(*) AS raw_copies
    FROM raw_orders
    WHERE order_id IS NOT NULL
    GROUP BY order_id
),
distinct_rows AS (
    SELECT DISTINCT order_id, user_id, order_date, order_value, status
    FROM raw_orders
    WHERE order_id IS NOT NULL
),
versions_per_id AS (
    SELECT order_id, COUNT(*) AS distinct_versions
    FROM distinct_rows
    GROUP BY order_id
)
SELECT
    d.status,
    COUNT(*)                                   AS duplicated_order_ids,
    SUM(c.raw_copies - 1)                      AS extra_rows,
    SUM((c.raw_copies - 1) * d.order_value)    AS extra_order_value
FROM raw_copies_per_id c
JOIN versions_per_id   v ON v.order_id = c.order_id
JOIN distinct_rows     d ON d.order_id = c.order_id   -- exactly 1 row per id when versions = 1
WHERE c.raw_copies > 1
  AND v.distinct_versions = 1
GROUP BY d.status
ORDER BY d.status;

-- Query 3: examples of conflicting order_ids (all their raw rows)
WITH conflicting_ids AS (
    SELECT order_id
    FROM (SELECT DISTINCT order_id, user_id, order_date, order_value, status
          FROM raw_orders
          WHERE order_id IS NOT NULL) d
    GROUP BY order_id
    HAVING COUNT(*) > 1
)
SELECT o.*
FROM raw_orders o
JOIN conflicting_ids c ON c.order_id = o.order_id
ORDER BY o.order_id
LIMIT 20;

-- Query 4: possible double-submits (different order_ids, otherwise identical)
WITH same_details AS (
    SELECT user_id, order_date, order_value, status,
           COUNT(DISTINCT order_id) AS distinct_order_ids
    FROM raw_orders
    GROUP BY user_id, order_date, order_value, status
    HAVING COUNT(DISTINCT order_id) > 1
)
SELECT
    COUNT(*)                     AS detail_groups,
    SUM(distinct_order_ids)      AS order_ids_involved
FROM same_details;
