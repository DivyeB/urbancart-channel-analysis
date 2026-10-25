-- =====================================================================
-- 01_load_raw.sql
-- What:    Creates typed raw_ tables and loads the three source CSVs
--          into them, row for row (no filtering, dedup or cleaning).
-- How to run (from the repo root):
--          duckdb.exe urbancart.duckdb < sql/01_load_raw.sql
-- Assumptions:
--   * Columns are typed (INTEGER / DATE / DECIMAL / VARCHAR). COPY
--     converts each value to the column type and STOPS WITH AN ERROR if
--     any value does not fit (e.g. a malformed date), so a successful
--     load proves every value parsed. Nothing is silently skipped.
--   * Dates are ISO 'YYYY-MM-DD' (seen in the file headers' first rows).
--   * spend.month stays VARCHAR: '2026-01' is a year-month, not a full
--     date. Converted in the clean layer.
--   * Money is DECIMAL(12,2), not INTEGER, so a value with paise
--     (e.g. 499.50) would load exactly instead of failing or rounding.
--   * No PRIMARY KEY / UNIQUE constraints on raw tables: a key on
--     order_id would reject the duplicate rows we need to count in
--     inspection. Keys are added on the clean tables (step 4).
--   * Empty CSV fields load as NULL (DuckDB default).
-- Expected result: raw_users 5,135 rows; raw_orders 5,684 rows;
--   raw_marketing_spend 24 rows (file line counts minus the header).
--   Confirmed by 02_check_raw_row_counts.sql.
-- =====================================================================

-- Rerunnable: drop first so a rerun starts from scratch.
DROP TABLE IF EXISTS raw_users;
DROP TABLE IF EXISTS raw_orders;
DROP TABLE IF EXISTS raw_marketing_spend;

CREATE TABLE raw_users (
    user_id             INTEGER,
    signup_date         DATE,
    city                VARCHAR,
    acquisition_channel VARCHAR,
    email               VARCHAR
);

CREATE TABLE raw_orders (
    order_id    INTEGER,
    user_id     INTEGER,
    order_date  DATE,
    order_value DECIMAL(12,2),
    status      VARCHAR
);

CREATE TABLE raw_marketing_spend (
    month     VARCHAR,          -- 'YYYY-MM'
    channel   VARCHAR,
    spend_inr DECIMAL(12,2)
);

COPY raw_users           FROM 'data/users.csv'           (HEADER true, DELIMITER ',');
COPY raw_orders          FROM 'data/orders.csv'          (HEADER true, DELIMITER ',');
COPY raw_marketing_spend FROM 'data/marketing_spend.csv' (HEADER true, DELIMITER ',');
