# UrbanCart Paid-Channel Review: Data & AI Engineer Case Study

Take-home case study for the Data & AI Engineer (Growth & Analytics) role at Shiprocket. UrbanCart is the fictional D2C brand in the brief. It spent ₹15.9 lakh on four paid channels in January–June 2026, and the CMO must cut paid spend by 20% next quarter without hurting growth.

**Recommendation in one line:** cut Meta Ads by ₹173,600 a quarter, move ₹23,000 from Affiliate to Google Ads, and keep Influencer. Meta's spend more than doubled while its new customers stayed flat.

## Deliverables

| Part | File |
|---|---|
| 1. Analysis (answer tables Q1–Q6) | [docs/Part1_Analysis.md](docs/Part1_Analysis.md) |
| 1. Code | [sql/](sql), run in numbered order (see below) |
| 2. Memo to the CMO | [docs/Part2_Memo.md](docs/Part2_Memo.md) |
| 2. Charts | [outputs/charts/](outputs/charts); interactive [Looker Studio report](https://datastudio.google.com/reporting/c5ab5ca3-bf17-40e4-a92a-7b85be3fed09) |
| 3. Automation & self-serve design | [docs/Part3_Design.md](docs/Part3_Design.md) (diagram: [docs/Part3_Diagram.webp](docs/Part3_Diagram.webp)) |
| AI use | [AI_USE_LOG.md](AI_USE_LOG.md) |
| Reflection | [docs/Reflection.md](docs/Reflection.md) |

## Assumptions

Set by the brief:
- A successful order is `status = 'delivered'`; cancelled and returned orders don't count.
- Contribution margin is a flat 30% for every channel (LTV = revenue per customer × 30%).
- The monthly CAC trend groups new customers by **signup month**.
- Money is rounded to the nearest rupee and percentages to one decimal place.

My assumptions:
- **Duplicates:** order rows identical in every column are export duplicates; one copy per `order_id` is kept.
- **Test accounts:** emails on the company's own domain (`urbancart.in`, all `qa.test*`) are internal test accounts, excluded with their orders.
- **Blank channels:** users with a blank acquisition channel are kept in the data but not attributed to any channel or metric.
- **Customers, not signups:** revenue per customer and repeat rate divide by customers (users with at least one delivered order).
- **LTV window:** LTV covers at most six months of orders (less for later signups), so LTV:CAC is a lower bound.
- **Cut base:** the 20% cut is measured against the latest quarter's actual spend (April–June, ₹868,000), the current run-rate.
- **Google increase:** Google's extra budget stays within its highest observed month (₹76,000), where its CAC held.
- **Impact estimates:** customer impact of the cut is a range: Meta's average CAC (worst case) vs its January–May cost per extra customer (best case).

## Repository layout

```
data/      raw CSVs, exactly as received (never edited)
sql/       numbered DuckDB queries, run in order
outputs/   saved result of every query, plus chart images and chart data
docs/      deliverables for Parts 1–3 and the reflection
```

Table naming: **Raw Tables** (`raw_*`) hold the CSVs as loaded; **Clean Tables** (`clean_*`) hold the corrected data every metric is calculated from.

## How to rebuild and rerun everything

**Requirement:** the [DuckDB CLI](https://duckdb.org/docs/installation/) (built and tested with v2.0.0). No server or password is needed; the database is a single file, `urbancart.duckdb`, created in the repo root (and git-ignored).

**Run all queries in order** from the repo root (Git Bash or any bash shell). This rebuilds the database from `data/` and rewrites every file in `outputs/`:

```bash
rm -f urbancart.duckdb
mkdir -p outputs/inspecting outputs/cleaning outputs/analysis outputs/sanity_check outputs/charts/data
for f in sql/*.sql; do
  n=$(basename "$f" .sql)
  case "$n" in
    0[3-9]_*|1[0-5]_*) out="outputs/inspecting/$n.md" ;;
    19_*|20_*)         out="outputs/cleaning/$n.md" ;;
    2[1-57]_*)         out="outputs/analysis/$n.md" ;;
    26_*)              out="outputs/sanity_check/$n.md" ;;
    *)                 out="/dev/null" ;;  # 01, 02, 16-18 build tables; 28 writes CSVs itself
  esac
  echo "running $n"
  duckdb -markdown urbancart.duckdb < "$f" > "$out" || { echo "FAILED: $n"; break; }
done
```

**What each group does:**

| Files | Purpose | Writes |
|---|---|---|
| `01`–`02` | Load the CSVs into typed Raw Tables; check row counts (5,135 / 5,684 / 24) | tables |
| `03`–`15` | Inspect the data: duplicates, NULLs, statuses, dates, orphans, spend gaps, channel names | `outputs/inspecting/` |
| `16`–`18` | Build the Clean Tables, with keys and constraints that fail the build if an issue returns | tables |
| `19`–`20` | Reconcile Clean Tables against Raw Tables; size each data-quality issue | `outputs/cleaning/` |
| `21`–`25` | Brief Q2–Q5: CAC, customer value, LTV:CAC, monthly CAC trend, month-on-month spend vs customers | `outputs/analysis/` |
| `26` | Brief Q6 sanity check: Affiliate LTV:CAC by an independent route | `outputs/sanity_check/` |
| `27` | Part 2: the Plan 1 budget figures and impact range | `outputs/analysis/` |
| `28` | Export chart data for Looker Studio | `outputs/charts/data/` |

To run a single query: `duckdb -markdown urbancart.duckdb < sql/21_q2_cac_by_channel.sql`.
