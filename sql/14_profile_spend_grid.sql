-- =====================================================================
-- 14_profile_spend_grid.sql
-- What:    Completeness and sanity of raw_marketing_spend.
--   Query 1: one-row overview: rows, distinct (month, channel) pairs,
--            NULLs, month range and format, spend range, total spend.
--   Query 2: channel x month grid (Jan-Jun 2026). A missing month shows
--            as NULL; a duplicated month shows up as rows > months.
--   Query 3: (month, channel) pairs that appear more than once.
--   Query 4: every distinct channel value with spacing/casing flags.
-- Assumptions:
--   * 4 paid channels x 6 months = 24 rows if complete. 24 rows alone
--     does not prove completeness (one duplicate + one gap = 24 too),
--     hence Queries 2-3.
--   * month is VARCHAR 'YYYY-MM'; Query 1 checks the format.
--   * Brief: total spend is "about Rs 16 lakh" (1,600,000) for Jan-Jun.
--   * Raw rows; nothing deduplicated.
--   * Query 2's grid uses SUM(CASE ... END) with NO 'ELSE 0', so an
--     absent month stays NULL (visible) instead of looking like 0 spend.
-- Expected result: Q1 1 row; Q2 one row per channel value; Q3 zero rows
--   if no duplicate pairs; Q4 one row per channel value.
-- =====================================================================

-- Query 1: overview
SELECT
    COUNT(*)                                                     AS total_rows,
    COUNT(DISTINCT month || '|' || channel)                      AS distinct_month_channel_pairs,
    COUNT(DISTINCT month)                                        AS distinct_months,
    COUNT(DISTINCT channel)                                      AS distinct_channels,
    COUNT(*) - COUNT(month)                                      AS null_month,
    COUNT(*) - COUNT(channel)                                    AS null_channel,
    COUNT(*) - COUNT(spend_inr)                                  AS null_spend,
    MIN(month)                                                   AS first_month,
    MAX(month)                                                   AS last_month,
    SUM(CASE WHEN NOT regexp_matches(month, '^[0-9]{4}-[0-9]{2}$')
             THEN 1 ELSE 0 END)                                  AS bad_month_format,
    MIN(spend_inr)                                               AS min_spend,
    MAX(spend_inr)                                               AS max_spend,
    SUM(CASE WHEN spend_inr <= 0 THEN 1 ELSE 0 END)              AS zero_or_negative_spend,
    SUM(spend_inr)                                               AS total_spend
FROM raw_marketing_spend;

-- Query 2: channel x month grid
SELECT
    channel,
    COUNT(*)                                                     AS rows_for_channel,
    COUNT(DISTINCT month)                                        AS months_present,
    SUM(CASE WHEN month = '2026-01' THEN spend_inr END)          AS jan,
    SUM(CASE WHEN month = '2026-02' THEN spend_inr END)          AS feb,
    SUM(CASE WHEN month = '2026-03' THEN spend_inr END)          AS mar,
    SUM(CASE WHEN month = '2026-04' THEN spend_inr END)          AS apr,
    SUM(CASE WHEN month = '2026-05' THEN spend_inr END)          AS may,
    SUM(CASE WHEN month = '2026-06' THEN spend_inr END)          AS jun,
    SUM(CASE WHEN month NOT BETWEEN '2026-01' AND '2026-06'
             THEN spend_inr END)                                 AS outside_jan_jun,
    SUM(spend_inr)                                               AS channel_total
FROM raw_marketing_spend
GROUP BY channel
ORDER BY channel;

-- Query 3: duplicated (month, channel) pairs
SELECT
    month,
    channel,
    COUNT(*)        AS copies,
    SUM(spend_inr)  AS combined_spend
FROM raw_marketing_spend
GROUP BY month, channel
HAVING COUNT(*) > 1
ORDER BY month, channel;

-- Query 4: channel values with hidden-problem flags
SELECT
    channel,
    '[' || channel || ']'                                  AS value_in_brackets,
    CASE
        WHEN channel IS NULL               THEN 'NULL (blank in CSV)'
        WHEN TRIM(channel) = ''            THEN 'whitespace only'
        WHEN channel <> TRIM(channel)      THEN 'leading/trailing spaces'
        ELSE 'ok'
    END                                                    AS value_flag,
    COUNT(*)                                               AS spend_rows
FROM raw_marketing_spend
GROUP BY channel
ORDER BY LOWER(TRIM(channel)) NULLS LAST;
