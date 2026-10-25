-- =====================================================================
-- 07_inspect_users_email.sql
-- What:    Looks for junk or inconsistent values in users.email:
--   Query 1: one-row summary of each check
--   Query 2: count of users per email domain (junk domains stand out)
--   Query 3: up to 25 example rows that fail any check
-- Checks:
--   * null_email: blank in the CSV
--   * bad_shape: not of the form something@something.something
--     (no spaces, exactly one @)
--   * has_case_or_space: differs from its lower-cased, trimmed self
--   * local_part_not_user_id: the part before @ is not 'user<user_id>'.
--     The first rows follow that pattern (user102343@yahoo.in for
--     user_id 102343); a mismatch may be a placeholder or a typo.
--   * emails_shared_by_multiple_user_ids: the same email on 2+ different
--     user_ids (possibly one person with two accounts)
-- Assumptions:
--   * NULL emails are counted ONLY in null_email. For a NULL email the
--     other checks evaluate to NULL, and CASE WHEN NULL counts as 0.
--   * Counts raw rows, duplicates included (an exact duplicate user row
--     shares an email with ITSELF, but has the same user_id, so it does
--     not count as 'shared by multiple user_ids').
--   * No status filter (users has no status column).
-- Expected result: Query 1 = 1 row with total_rows = 5135; Query 2
--   users column sums to 5135 (NULL domain row if any emails are NULL);
--   Query 3 = 0-25 rows.
-- =====================================================================

-- Query 1: summary of checks
WITH email_checks AS (
    SELECT
        user_id,
        email,
        email IS NULL                                                AS is_null,
        NOT regexp_matches(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$')         AS bad_shape,
        email <> LOWER(TRIM(email))                                  AS has_case_or_space,
        email NOT LIKE 'user' || CAST(user_id AS VARCHAR) || '@%'    AS local_part_not_user_id
    FROM raw_users
),
shared_emails AS (
    SELECT email
    FROM raw_users
    WHERE email IS NOT NULL
    GROUP BY email
    HAVING COUNT(DISTINCT user_id) > 1
)
SELECT
    COUNT(*)                                                    AS total_rows,
    SUM(CASE WHEN is_null                THEN 1 ELSE 0 END)     AS null_email,
    SUM(CASE WHEN bad_shape              THEN 1 ELSE 0 END)     AS bad_shape,
    SUM(CASE WHEN has_case_or_space      THEN 1 ELSE 0 END)     AS has_case_or_space,
    SUM(CASE WHEN local_part_not_user_id THEN 1 ELSE 0 END)     AS local_part_not_user_id,
    (SELECT COUNT(*) FROM shared_emails)                        AS emails_shared_by_multiple_user_ids
FROM email_checks;

-- Query 2: users per email domain (text after the @)
SELECT
    split_part(email, '@', 2)   AS email_domain,
    COUNT(*)                    AS users
FROM raw_users
GROUP BY email_domain
ORDER BY users DESC;

-- Query 3: examples of rows failing any check
SELECT user_id, email
FROM raw_users
WHERE email IS NULL
   OR NOT regexp_matches(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$')
   OR email <> LOWER(TRIM(email))
   OR email NOT LIKE 'user' || CAST(user_id AS VARCHAR) || '@%'
   OR email IN (SELECT email FROM raw_users WHERE email IS NOT NULL
                GROUP BY email HAVING COUNT(DISTINCT user_id) > 1)
ORDER BY email, user_id
LIMIT 25;
