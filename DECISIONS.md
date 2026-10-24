# Decisions & Assumptions Log

Running log of every assumption and judgment call, with the reason. Newest entries at the bottom of each section.

## Context
- **Assignment source:** Shiprocket recruitment take-home for a Data & AI Engineer (Growth & Analytics) role. "UrbanCart" is a fictional D2C brand used as the scenario.
- **Period in scope:** Jan–Jun 2026 (per brief).

## Project setup
| # | Decision | Options considered | Chosen | Why |
|---|---|---|---|---|
| D1 | Repo layout | — | `/data` (raw, untouched), `/sql` (numbered MySQL), `/outputs` (tables, charts), `/docs` (Part1_Analysis, Part2_Memo, Part3_Design, AI_Use_Note, Reflection) + README, DECISIONS, AI_USE_LOG | Matches brief's "name files by part" request; keeps raw data separate from derived work |
| D2 | Analysis engine | DuckDB (brief's suggestion), MySQL 8.0 | **DuckDB 2.0.0 CLI** (originally MySQL 8.0, changed 2026-10-24) | MySQL 8.0 is end-of-life (Apr 2026); the winget install of 8.0.43 failed with a 404 because Oracle moved the installer to its archive. DuckDB is the tool the brief suggests, needs no server or passwords, and reruns from a single file, so a reviewer can reproduce it easily. All analysis stays in SQL; Python only for charts or tiny helpers |
| D3 | SQL dialect | — | DuckDB SQL (PostgreSQL-like). CTEs and window functions available | Follows from D2. Date functions differ from MySQL (e.g. `strftime`, `date_trunc`) |
| D3a | SQL style | Use DuckDB-specific features freely vs keep to MySQL-familiar SQL | Keep to standard, MySQL-familiar SQL where possible; every DuckDB-only construct is flagged with its MySQL equivalent | Candidate knows MySQL; every query must be explainable in the live walkthrough |
| D5 | Raw table types | All-text raw (types in clean layer) vs typed raw | **Typed raw** (candidate's call): INTEGER ids, DATE dates, DECIMAL(12,2) money, VARCHAR text; `spend.month` stays VARCHAR ('YYYY-MM'). No keys on raw tables | Types documented up front. `COPY` errors on any unparseable value, so a clean load proves every value parsed. Keys would reject the duplicates we must count, so they go on the clean tables. Pre-load file checks (shell `awk`, candidate's request): all 5,135 `signup_date` and all 5,684 `order_date` values have shape `YYYY-MM-DD` with no time part, so `DATE` (not `TIMESTAMP`) is right. `email` is 19–22 chars; DuckDB `VARCHAR` has no length limit (`TEXT`/`STRING` are aliases of it), so no wider type is needed |
| D6 | Outlier check on `order_value` (step 3) | p1/p99 percentile rule; multiple-of-median rule; no formal rule | **No formal outlier rule** (candidate's call). The separate value-distribution file is dropped; min, max, average, median and the count of zero/negative `order_value` are folded into `08_profile_orders_overview.sql` | A formal outlier rule isn't needed to answer the brief. Min/max and ≤0 counts still catch impossible values (negative, zero, absurdly large) at almost no cost |
| D7 | Step 3 scope and gate | — | Profiling files `03`–`15`: users 03–08 (city and email split into separate files, kept because the candidate expects junk values in email; 08 added as a follow-up on the test accounts 07 found), orders 09–13, spend 14–15. **Approval gate per table batch**: one approval covers that table's files. Results saved to `outputs/profiling/NN_name.md` | Keeps the "nothing runs unapproved" rule while staying near the ~3-hour budget |
| D8 | Line endings in git | Default (Windows `core.autocrlf=true` converts to CRLF on checkout) vs `.gitattributes` | `.gitattributes`: `data/** -text` (no conversion), `*.sql`/`*.md` as LF | Keeps the raw CSVs byte-for-byte as delivered on any machine, honouring "never edit the raw files" |
| D4 | Database file in git | Commit `.duckdb` file vs rebuild from SQL | Not committed (`.gitignore`) | It's a build product: anyone can rebuild it from `/data` + `/sql`, which proves the pipeline is reproducible |

## Step results
- **Step 2 (raw load), 2026-10-24:** `01_load_raw.sql` ran with no conversion errors, so every id, date and amount parsed into its typed column. `02_check_raw_row_counts.sql` shows raw_users 5,135, raw_orders 5,684 and raw_marketing_spend 24, all matching file lines minus the header. `DESCRIBE` types match the DDL; the first 3 rows of each table match `head` of each CSV (integers display as e.g. `1056.00` because of DECIMAL(12,2); the value is the same). Noticed in passing, to profile in step 3: `Organic` appears as a literal `acquisition_channel` value.

- **Step 3, users batch (03–07), 2026-10-24.** Outputs in `outputs/profiling/`. Reconciled: 05, 06 and 07-domain user totals each = 5,135 = 03 total_rows; 05's NULL row (72) = 03's null_acquisition_channel (72).
  - Clean: 5,135 distinct user_ids out of 5,135 rows (04 returned no duplicate IDs); no NULLs in user_id, signup_date, city or email; signups span 2026-01-01..2026-06-30 (none outside); channel names have no spacing or casing variants; 8 cities, all clean; no malformed, mixed-case or shared emails.
  - **Issue U1:** 72 users (1.4%) have a blank `acquisition_channel`. `Organic` exists as its own value (828 users), so a blank is not obviously Organic. Treatment: step 4/5.
  - **Issue U2:** 35 users have emails on the company domain `urbancart.in` that don't follow `user<id>@` (e.g. `qa.test1@urbancart.in`), so they look like internal QA/test accounts. Characterised by `08_profile_users_test_accounts.sql`: both rules flag the **same 35 users**, all `qa.test*`, with a contiguous ID block 105101–105135 (35 IDs = 35 users) and signups 2026-01-02..2026-05-22. **All 35 are attributed to Affiliate.** Together they have **310 delivered order rows worth ₹853,172** (raw: duplicates not yet removed) and no cancelled or returned orders. If kept, they would inflate Affiliate's new customers, revenue per customer and repeat rate, and lower its CAC. Treatment: step 4 (likely exclude; to decide).
- **Step 3, orders batch (09–13), 2026-10-24.** Outputs in `outputs/profiling/`. Reconciled: 09 total 5,684 = 11 status total = 13 monthly total; 09 (5,684 − 5,478 distinct ids = 206) = 10 rows_beyond_one_per_id = 10 Q2 extra_rows (24+150+32); 11 delivered 4,949 = 13 delivered sum; 12 user buckets sum to 5,135; users with any order (360 + 2,678 = 3,038) = 09 distinct_user_ids.
  - Clean: no NULLs in any column; order dates 2026-01-01..2026-06-30 (none outside the window); order_value ₹199–₹3,991, none zero or negative, average ₹1,171.22 vs median ₹1,093 (mild right skew, no extreme values); status has exactly the 3 brief values with no variants; no conflicting duplicates (same order_id, different values); no possible double-submits (different order_ids with identical details); no orphan orders; no orders before signup.
  - **Issue O1:** 206 order_ids appear exactly twice as **exact duplicate rows** (412 rows involved, 206 extra). Extras by status: delivered 150 rows / ₹203,594, cancelled 24 / ₹24,239, returned 32 / ₹26,763. If not removed, delivered revenue is overstated by ₹203,594. Treatment: step 4 (keep one copy per order_id).
  - Context for metrics (not an issue): status mix is 87.1% delivered, 6.0% cancelled, 7.0% returned (raw rows). 2,097 users have no orders; 360 have only cancelled/returned orders; 2,678 have ≥1 delivered order (raw; includes the 35 test accounts).
  - Timing note for step 5: orders stop at 2026-06-30, the same day signups stop, so users who signed up late in the period have had less time to order (immature cohorts).
- **Step 3, spend batch (14–15), 2026-10-24.** Outputs in `outputs/profiling/`. Reconciled: 14 Q1 total_spend ₹1,590,000 = sum of the four Q2 channel totals; each channel's six monthly cells add up to its channel_total; 15 spend totals = 14 channel totals; 15 user counts = 05 counts.
  - **All clean:** 24 rows = 24 distinct (month, channel) pairs; 4 channels × 6 months (2026-01..2026-06), every cell present; no duplicate pairs, NULLs, zero/negative spend or bad month formats; channel names have no spacing/casing variants; all 4 paid channel names match `raw_users.acquisition_channel` exactly. Organic has users (828) but no spend, which is expected.
  - Total spend ₹1,590,000 reconciles with the brief's "about ₹16 lakh".
  - Observation for step 6 (not an issue): Meta Ads spend rises every month, ₹54,000 (Jan) → ₹116,000 (Jun).

## Data-quality issues found in profiling (treatments decided in step 4)
| ID | Table | Issue | Rows affected | Source query |
|---|---|---|---|---|
| U1 | users | Blank `acquisition_channel` | 72 users (1.4%) | 03, 05 |
| U2 | users / orders | Internal QA test accounts (`qa.test*@urbancart.in`), all attributed to Affiliate, all with delivered orders | 35 users; 310 raw delivered order rows, ₹853,172 | 07, 08 |
| O1 | orders | Exact duplicate order rows (each duplicated `order_id` appears twice) | 206 extra rows (150 delivered = ₹203,594) | 09, 10 |

## Fixed by the brief (not our choice)
- Successful order = `status = 'delivered'`; cancelled and returned excluded.
- Contribution margin = 30% flat for all channels.
- Monthly CAC trend groups new customers by **signup month**.
- Rounding: money to nearest rupee, percentages to 1 decimal.

## Open questions (to decide at the relevant step)
1. Blank `acquisition_channel`: Organic, Unknown, or exclude?
2. Orders dated outside Jan–Jun: include or exclude?
3. Denominator for revenue per customer / repeat rate: customers (≥1 delivered order) vs all signups.
4. Immature recent cohorts (e.g. June signups) in the CAC trend.
5. Base for the 20% cut: H1 quarterly run-rate vs Apr–Jun actual.
6. Duplicate handling: exact-duplicate rows vs same `order_id` with differing values.
7. Whether to publish `Case_Study_Brief.pdf` in the public repo (it's Shiprocket's document). Excluded from git for now.
8. ~~Raw-load method~~ → decided, see D5.
