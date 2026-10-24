-- =====================================================================
-- 16_clean_users.sql
-- What:    Builds clean_users from raw_users:
--            * excludes internal QA test accounts (U2, DECISIONS D10)
--            * replaces a blank acquisition_channel with 'Unknown' and
--              records that it was blank (U1, D11)
--          raw_users is only read, never changed.
-- Assumptions:
--   * Test account = email domain 'urbancart.in' (the company's own
--     domain). 08 showed this flags exactly the 35 qa.test* users.
--   * "Blank" = NULL or whitespace-only. Profiling found only NULLs
--     (72), but trimming makes the rule safe for future files.
--   * No duplicate user_ids exist (04), so no dedup is needed here. The
--     PRIMARY KEY enforces it: a future duplicate would fail the build.
--   * NOT NULL on every column: profiling found no NULLs (03), so these
--     act as assertions. A row with a NULL email is deliberately NOT
--     filtered out by the WHERE clause; it reaches the NOT NULL check
--     and fails loudly instead of disappearing silently.
-- Expected result: clean_users has 5,135 - 35 = 5,100 rows; rows with
--   channel_was_blank = true = the blank-channel users who are not test
--   accounts (all 35 test accounts are 'Affiliate' per 08, so 72).
--   Checked by 19_check_clean_reconciliation.sql.
-- =====================================================================

-- clean_orders references clean_users (foreign key), so it must be
-- dropped first for this script to rerun. 17 rebuilds it.
DROP TABLE IF EXISTS clean_orders;
DROP TABLE IF EXISTS clean_users;

CREATE TABLE clean_users (
    user_id             INTEGER  PRIMARY KEY,
    signup_date         DATE     NOT NULL,
    city                VARCHAR  NOT NULL,
    acquisition_channel VARCHAR  NOT NULL,   -- 'Unknown' when blank in raw
    channel_was_blank   BOOLEAN  NOT NULL,   -- lineage flag for U1
    email               VARCHAR  NOT NULL
);

INSERT INTO clean_users
SELECT
    user_id,
    signup_date,
    city,
    COALESCE(NULLIF(TRIM(acquisition_channel), ''), 'Unknown')  AS acquisition_channel,
    NULLIF(TRIM(acquisition_channel), '') IS NULL                AS channel_was_blank,
    email
FROM raw_users
WHERE email IS NULL                                       -- let NULLs through to fail NOT NULL
   OR LOWER(split_part(email, '@', 2)) <> 'urbancart.in'; -- drop test accounts
