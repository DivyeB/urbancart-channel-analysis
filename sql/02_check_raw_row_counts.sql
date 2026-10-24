-- =====================================================================
-- 02_check_raw_row_counts.sql
-- What:    Confirms every CSV row reached its raw_ table.
-- How to run: duckdb.exe urbancart.duckdb < sql/02_check_raw_row_counts.sql
-- Assumptions: expected counts come from `wc -l` on each file minus the
--   header line (each file ends with a newline and has no quoted or
--   multi-line fields, so one line = one row).
-- Expected result: 3 rows, each with matches = true.
--   raw_users 5135 | raw_orders 5684 | raw_marketing_spend 24
-- Note: COUNT(*) counts every row, including duplicates and rows with
--   NULLs. No status filter here: this is a load check, not analysis.
-- =====================================================================

SELECT 'raw_users'           AS table_name, COUNT(*) AS loaded_rows, 5135 AS expected_rows, COUNT(*) = 5135 AS matches FROM raw_users
UNION ALL
SELECT 'raw_orders',                        COUNT(*),                5684,                  COUNT(*) = 5684            FROM raw_orders
UNION ALL
SELECT 'raw_marketing_spend',               COUNT(*),                24,                    COUNT(*) = 24              FROM raw_marketing_spend;
