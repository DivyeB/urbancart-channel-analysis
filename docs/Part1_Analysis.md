# Part 1: Analysis

All analysis is SQL (DuckDB), run in order from [`sql/`](../sql); each result is saved in [`outputs/`](../outputs). Money is rounded to the nearest rupee and percentages to one decimal place, from unrounded values. Key assumptions are listed in the [README](../README.md#assumptions).

**Terms.** *Raw Tables* (`raw_*`) hold the CSVs exactly as delivered. *Clean Tables* (`clean_*`) hold the corrected data every metric is calculated from.

**Definitions (from the brief).** A *new customer* is a user with at least one `delivered` order, counted once under their acquisition channel. *CAC* = channel spend ÷ new customers. *Revenue per customer* = delivered revenue ÷ customers. *Repeat rate* = customers with 2+ delivered orders ÷ customers. *LTV* = revenue per customer × 30%. Period: January–June 2026. Users with a blank channel are kept in the data but excluded from every metric, because "Unknown" is not a channel.

---

## Q1. Data quality

**Issues found and how they were handled**

| # | Issue | Rows affected | Treatment | Why | Query |
|---|---|---|---|---|---|
| O1 | Exact duplicate order rows (same `order_id`, all columns identical, each twice) | 206 extra rows (150 delivered, ₹203,594) | Kept one copy per `order_id` | The copies are identical, so the second is an export artefact; nothing is lost | [09](../sql/09_inspect_orders_overview.sql), [10](../sql/10_inspect_orders_duplicates.sql) |
| U2 | Internal QA test accounts (`qa.test1…35@urbancart.in`), all credited to Affiliate | 35 users; 285 delivered orders, ₹779,790 (after de-duplication) | Excluded the users and their orders | Not real customers; they made up 61.7% of Affiliate's delivered revenue | [07](../sql/07_inspect_users_email.sql), [08](../sql/08_inspect_users_test_accounts.sql), [20](../sql/20_dq_impact.sql) |
| U1 | Blank `acquisition_channel` | 72 users (1.4%); 40 of them customers, ₹85,089 delivered revenue | Kept, labelled "Unknown" with a flag; excluded from all channel metrics | Not provably wrong, so not deleted; but not a channel, so not attributed. "Organic" already exists as its own value | [03](../sql/03_inspect_users_overview.sql), [05](../sql/05_inspect_users_channel_values.sql), [20](../sql/20_dq_impact.sql) |

*Working for U2:* 285 orders and ₹779,790 = the drop between the last two rows of the cleaning table below (4,799 − 4,514; ₹5,741,674 − ₹4,961,884). Query 20 confirms the same gap for Affiliate: ₹1,263,177 with test accounts vs ₹483,387 without. 61.7% = ₹779,790 ÷ ₹1,263,177.

**Checks that came back clean:** no duplicate `user_id`s; no NULLs in any key column; signups and orders all within 1 Jan – 30 Jun 2026; no orders dated before signup; no orders for unknown users; `status` has exactly the three valid values; `order_value` between ₹199 and ₹3,991 with none zero or negative; city, channel and spend names have no spelling or spacing variants; spend covers all 4 channels × 6 months with no gaps or duplicates (total ₹1,590,000); channel names match exactly between spend and users.

**Effect of cleaning** ([19](../sql/19_check_clean_reconciliation.sql); all 8 reconciliation checks pass)

| Stage | Users | Order rows | Delivered rows | Delivered revenue |
|---|---:|---:|---:|---:|
| Raw Tables | 5,135 | 5,684 | 4,949 | ₹5,945,268 |
| After removing duplicates | 5,135 | 5,478 | 4,799 | ₹5,741,674 |
| After removing test accounts = Clean Tables | 5,100 | 5,193 | 4,514 | ₹4,961,884 |

---

## Q2. Acquisition cost by paid channel

[21](../sql/21_q2_cac_by_channel.sql)

| Channel | Total spend | New customers | CAC |
|---|---:|---:|---:|
| Affiliate | ₹346,000 | 505 | ₹685 |
| Google Ads | ₹400,000 | 655 | ₹611 |
| Influencer | ₹297,000 | 307 | ₹967 |
| Meta Ads | ₹547,000 | 675 | ₹810 |
| **All paid** | **₹1,590,000** | **2,142** | **₹742** |

---

## Q3. Customer value by channel

[22](../sql/22_q3_customer_value_by_channel.sql)

| Channel | Customers | Delivered revenue | Revenue per customer | Repeat customers | Repeat rate |
|---|---:|---:|---:|---:|---:|
| Affiliate | 505 | ₹483,387 | ₹957 | 41 | 8.1% |
| Google Ads | 655 | ₹1,513,880 | ₹2,311 | 378 | 57.7% |
| Influencer | 307 | ₹877,469 | ₹2,858 | 224 | 73.0% |
| Meta Ads | 675 | ₹1,124,892 | ₹1,667 | 302 | 44.7% |
| Organic | 461 | ₹877,167 | ₹1,903 | 257 | 55.7% |

---

## Q4. Return on spend (LTV:CAC)

[23](../sql/23_q4_ltv_cac_by_channel.sql)

| Channel | CAC | Revenue per customer | LTV (× 30%) | LTV:CAC |
|---|---:|---:|---:|---:|
| Google Ads | ₹611 | ₹2,311 | ₹693 | **1.14** (best) |
| Influencer | ₹967 | ₹2,858 | ₹857 | 0.89 |
| Meta Ads | ₹810 | ₹1,667 | ₹500 | 0.62 |
| Affiliate | ₹685 | ₹957 | ₹287 | **0.42** (worst) |

**Best: Google Ads** (1.14), the only channel whose customers paid back their acquisition cost within January–June. **Worst: Affiliate** (0.42): cheap to acquire, but its customers spend little and rarely return. LTV covers at most six months of orders, so every ratio is a lower bound.

---

## Q5. Monthly CAC trend (new customers grouped by signup month)

[24](../sql/24_q5_monthly_cac_trend.sql)

| Channel | Jan | Feb | Mar | Apr | May | Jun | Jan → Jun |
|---|---:|---:|---:|---:|---:|---:|---|
| Affiliate | ₹709 | ₹709 | ₹728 | ₹633 | ₹667 | ₹682 | −₹27 (−3.9%) |
| Google Ads | ₹592 | ₹621 | ₹596 | ₹602 | ₹644 | ₹611 | +₹19 (+3.2%) |
| Influencer | ₹981 | ₹980 | ₹913 | ₹960 | ₹964 | ₹1,000 | +₹19 (+2.0%) |
| **Meta Ads** | **₹491** | **₹618** | **₹789** | **₹886** | **₹958** | **₹1,115** | **+₹624 (+127.2%)** |

**Meta Ads is getting more expensive:** its CAC rose every month, from ₹491 in January to ₹1,115 in June, an increase of ₹624 (+127.2%). The other channels moved by less than 10%.

**Is it real, or just June?** June signups have had at most 30 days to buy, which inflates June's CAC for every channel. Measured January → May instead, Meta's CAC still rose 95.1% (₹491 → ₹958), so the trend is real.

**Why it happened** ([25](../sql/25_mom_spend_vs_customers.sql)). Meta's spend rose 25.9%, 26.5% and 26.7% month on month in February–April, while its new customers changed by 0.0%, −0.9% and +12.8%. For every other channel, customers moved with spend. The extra Meta spend bought almost no extra customers.

---

## Q6. Sanity check

**Number checked: Affiliate LTV:CAC = 0.42** (the "worst return" verdict). It's the only result that depends on every pipeline step: spend, customers, revenue, de-duplication and test-account removal.

**How.** I recalculated it by a completely separate route ([26](../sql/26_sanity_check_affiliate_ltv_cac.sql)) that shares nothing with the original:

| Step | Original route | Independent route |
|---|---|---|
| Source | Clean Tables | Raw Tables only |
| Duplicates | `SELECT DISTINCT` | `ROW_NUMBER()`, keep one copy per `order_id` |
| Test accounts | email domain = `urbancart.in` | email doesn't follow `user<id>@` |
| Formula | LTV ÷ CAC | 0.30 × revenue ÷ spend |

**Result:** both routes give spend ₹346,000, 505 customers, ₹483,387 delivered revenue and LTV:CAC **0.42**, matching to every decimal place. A bug in any single step would have made them disagree.

**Other cross-checks along the way:**
- Organic customers were predicted as 461 from earlier outputs before Q3 was run, and Q3 returned exactly 461.
- Each query's totals reconcile with the previous ones: spend ₹1,590,000 everywhere; customer counts match between Q2, Q3 and Q5; Q4 matches Q2 and Q3.
- The step-4 reconciliation (19) proves the Clean Tables equal the Raw Tables minus exactly the removed rows.
