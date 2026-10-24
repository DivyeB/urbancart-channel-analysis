-- =====================================================================
-- 15_profile_channel_name_match.sql
-- What:    Lines up channel names from the two tables CAC will join:
--          raw_marketing_spend.channel and raw_users.acquisition_channel.
--          CAC = spend / new customers per channel, so the names must
--          match EXACTLY or that channel's join finds nothing.
-- Assumptions:
--   * Exact, case-sensitive match on purpose (that is how the CAC join
--     will compare them).
--   * NULL acquisition_channel excluded here (72 users, already in 05):
--     a NULL can't match anything.
--   * Expected: the 4 paid channels in both tables; Organic in users
--     only (it has no spend, which is correct, not an issue).
--   * Uses FULL OUTER JOIN (DuckDB) so names missing from EITHER side
--     appear. MySQL lacks FULL OUTER JOIN: there you would UNION a
--     LEFT JOIN and a RIGHT JOIN.
-- Expected result: one row per distinct channel name across both tables.
-- =====================================================================

WITH spend_channels AS (
    SELECT channel, SUM(spend_inr) AS total_spend
    FROM raw_marketing_spend
    GROUP BY channel
),
user_channels AS (
    SELECT acquisition_channel AS channel, COUNT(*) AS users
    FROM raw_users
    WHERE acquisition_channel IS NOT NULL
    GROUP BY acquisition_channel
)
SELECT
    COALESCE(s.channel, u.channel)        AS channel,
    s.total_spend,
    u.users,
    CASE
        WHEN s.channel IS NOT NULL AND u.channel IS NOT NULL THEN 'in both'
        WHEN s.channel IS NULL                               THEN 'users only (no spend)'
        ELSE                                                      'spend only (no users)'
    END                                   AS match_status
FROM spend_channels s
FULL OUTER JOIN user_channels u ON u.channel = s.channel
ORDER BY channel;
