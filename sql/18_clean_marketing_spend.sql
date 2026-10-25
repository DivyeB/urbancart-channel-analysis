-- =====================================================================
-- 18_clean_marketing_spend.sql
-- What:    Builds clean_marketing_spend from raw_marketing_spend. Values
--          are unchanged (inspection found no issues, 14-15); adds a real
--          DATE column month_start (first day of the month) next to the
--          'YYYY-MM' text, so months can be joined to signup dates.
--          raw_marketing_spend is only read, never changed.
-- Assumptions:
--   * month is always 'YYYY-MM' (14: bad_month_format = 0), so
--     month || '-01' is always a valid date.
--   * PRIMARY KEY (month, channel) asserts one row per channel per month
--     (14 found no duplicate pairs); CHECK asserts spend >= 0.
-- Expected result: 24 rows, total spend_inr = 1,590,000 (same as raw).
--   Checked by 19_check_clean_reconciliation.sql.
-- =====================================================================

DROP TABLE IF EXISTS clean_marketing_spend;

CREATE TABLE clean_marketing_spend (
    month       VARCHAR        NOT NULL,   -- 'YYYY-MM', as in raw
    month_start DATE           NOT NULL,   -- e.g. 2026-01-01
    channel     VARCHAR        NOT NULL,
    spend_inr   DECIMAL(12,2)  NOT NULL CHECK (spend_inr >= 0),
    PRIMARY KEY (month, channel)
);

INSERT INTO clean_marketing_spend
SELECT
    month,
    CAST(month || '-01' AS DATE)  AS month_start,
    channel,
    spend_inr
FROM raw_marketing_spend;
