-- =====================================================================
-- 17_clean_orders.sql
-- What:    Builds clean_orders from raw_orders:
--            * keeps one copy of each exact-duplicate row (O1, D9)
--            * excludes orders placed by QA test accounts (U2, D10)
--            * keeps ALL statuses; the delivered-only filter is applied
--              in each analysis query, where it is visible (D12)
--          raw_orders is only read, never changed.
-- Assumptions:
--   * Run after 16 (needs clean_users for the foreign key).
--   * SELECT DISTINCT removes exact duplicates. Profiling found only
--     exact ones (10). If a future file had a CONFLICTING duplicate
--     (same order_id, different values), DISTINCT would keep both and
--     the PRIMARY KEY would fail the build. That is intended.
--   * Test-account orders are removed with NOT EXISTS against the same
--     domain rule as 16. NOT EXISTS (not NOT IN) because NOT IN returns
--     nothing at all if the subquery ever yields a NULL user_id.
--   * Orphan orders are NOT filtered: the FOREIGN KEY to clean_users
--     makes any orphan fail the build (profiling found none, 12).
--   * CHECK constraints assert the profiled facts: status is one of the
--     3 brief values (11); order_value > 0 (09).
-- Expected result: clean_orders = 5,478 deduplicated orders minus the
--   deduplicated orders of the 35 test accounts. Exact figure and the
--   full chain are produced by 19_check_clean_reconciliation.sql.
-- =====================================================================

DROP TABLE IF EXISTS clean_orders;

CREATE TABLE clean_orders (
    order_id    INTEGER        PRIMARY KEY,
    user_id     INTEGER        NOT NULL REFERENCES clean_users (user_id),
    order_date  DATE           NOT NULL,
    order_value DECIMAL(12,2)  NOT NULL CHECK (order_value > 0),
    status      VARCHAR        NOT NULL CHECK (status IN ('delivered', 'cancelled', 'returned'))
);

INSERT INTO clean_orders
SELECT DISTINCT
    o.order_id,
    o.user_id,
    o.order_date,
    o.order_value,
    o.status
FROM raw_orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM raw_users t
    WHERE t.user_id = o.user_id
      AND LOWER(split_part(t.email, '@', 2)) = 'urbancart.in'
);
