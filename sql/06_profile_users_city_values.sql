-- =====================================================================
-- 06_profile_users_city_values.sql
-- What:    Every distinct city value with its user count and the same
--          hidden-problem flags as 05 (NULL, whitespace, spacing),
--          sorted so spelling/casing variants sit together.
-- Assumptions:
--   * city does not feed any brief metric; checked because the brief
--     asks to list every data issue.
--   * Counts raw rows, duplicates included.
--   * No status filter (users has no status column).
-- Expected result: one row per distinct raw city value; users column
--   sums to 5135.
-- =====================================================================

SELECT
    city,
    '[' || city || ']'                                      AS value_in_brackets,
    CASE
        WHEN city IS NULL                 THEN 'NULL (blank in CSV)'
        WHEN TRIM(city) = ''              THEN 'whitespace only'
        WHEN city <> TRIM(city)           THEN 'leading/trailing spaces'
        ELSE 'ok'
    END                                                     AS value_flag,
    COUNT(*)                                                AS users,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)      AS pct_of_users
FROM raw_users
GROUP BY city
ORDER BY LOWER(TRIM(city)) NULLS LAST, users DESC;
