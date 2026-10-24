-- =====================================================================
-- 03_profile_users_overview.sql
-- What:    One-row health summary of raw_users: row count, ID uniqueness,
--          NULLs per column, signup date range, signups outside Jan-Jun.
-- Assumptions:
--   * Brief: users.csv holds users who signed up Jan-Jun 2026, so any
--     signup_date outside 2026-01-01..2026-06-30 is flagged.
--   * NULL = empty field in the CSV (DuckDB loads empty as NULL).
--   * Duplicates are NOT removed here: COUNT(*) counts every raw row.
--   * No status filter (users has no status column).
-- Expected result: 1 row. total_rows = 5135 (from step 2). If
--   distinct_user_ids < total_rows, some user_id repeats (see 04).
-- =====================================================================

SELECT
    COUNT(*)                                  AS total_rows,
    COUNT(DISTINCT user_id)                   AS distinct_user_ids,
    COUNT(*) - COUNT(user_id)                 AS null_user_id,
    COUNT(*) - COUNT(signup_date)             AS null_signup_date,
    COUNT(*) - COUNT(city)                    AS null_city,
    COUNT(*) - COUNT(acquisition_channel)     AS null_acquisition_channel,
    COUNT(*) - COUNT(email)                   AS null_email,
    MIN(signup_date)                          AS first_signup,
    MAX(signup_date)                          AS last_signup,
    SUM(CASE WHEN signup_date <  DATE '2026-01-01'
              OR  signup_date >  DATE '2026-06-30'
             THEN 1 ELSE 0 END)               AS signups_outside_jan_jun
FROM raw_users;
