-- =====================================================================
-- 05_inspect_users_channel_values.sql
-- What:    Every distinct acquisition_channel value with its user count,
--          plus flags that expose hidden problems: NULL (blank in CSV),
--          whitespace-only, leading/trailing spaces. Sorted so casing
--          variants ('meta ads' vs 'Meta Ads') sit next to each other.
-- Assumptions:
--   * Counts raw rows, duplicates included (dedup is decided in step 4).
--   * '[' || value || ']' wraps the value in brackets so spaces show.
--     For a NULL value the bracketed column is also NULL.
--   * No status filter (users has no status column).
-- Expected result: one row per distinct raw value, including a NULL row
--   if blanks exist. users column sums to 5135; pct_of_users sums to
--   ~100.0 (rounding).
-- =====================================================================

SELECT
    acquisition_channel,
    '[' || acquisition_channel || ']'                       AS value_in_brackets,
    LENGTH(acquisition_channel)                             AS char_length,
    CASE
        WHEN acquisition_channel IS NULL                       THEN 'NULL (blank in CSV)'
        WHEN TRIM(acquisition_channel) = ''                    THEN 'whitespace only'
        WHEN acquisition_channel <> TRIM(acquisition_channel)  THEN 'leading/trailing spaces'
        ELSE 'ok'
    END                                                     AS value_flag,
    COUNT(*)                                                AS users,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)      AS pct_of_users
FROM raw_users
GROUP BY acquisition_channel
ORDER BY LOWER(TRIM(acquisition_channel)) NULLS LAST, users DESC;
