# AI Use Log

Tool: Claude Code (Claude Opus 5.5). Short running log of where AI helped and, especially, mistakes made or caught.

## Where AI helped
- **Step 1:** Extracted the brief's text from the PDF (Python `pypdf`, used only to read it), summarised the brief, listed deliverables, and flagged ambiguous definitions.
- **Step 1:** Proposed the repo layout and created the skeleton folders and logs.
- **Step 2:** Tried a MySQL 8.0 install via winget (failed: Oracle had archived the installer, 404); candidate then chose DuckDB. Drafted the load DDL and `COPY` statements and explained each against MySQL. Ran file-level shell checks (line counts, line endings, date shapes, email lengths) to set the expected row counts and confirm the types.

- **Step 3:** Drafted 13 profiling queries (03–15), ran them after approval, and reconciled totals across files.
- **Step 4:** Drafted the clean tables with constraints (16–18), an independent reconciliation (19) and an impact sizing (20). Used Python only as a calculator for percentages and ratios on query outputs (no `bc` on this machine).

- **Steps 5–8:** Drafted metric definitions (M1–M8) for the candidate to choose from; drafted analysis queries 21–27 and the chart export 28, each run only after approval; laid out cut options; drafted memo section options for the candidate to choose from and reword.
- **Step 8, charts:** At the candidate's request, drafted a prompt for Claude in Chrome to build the Looker Studio report (C1–C3) from the CSVs exported by `28_export_chart_data.sql`. The chart data and all calculations come from SQL; Claude in Chrome only lays out the charts.

## Candidate overrides of AI suggestions (not errors, but judgment calls the candidate made)
- **Step 2:** AI recommended all-text (VARCHAR) raw tables with types applied in the clean layer. Candidate chose typed raw tables instead. AI revised the SQL to explicit `CREATE TABLE` plus `COPY`.
- **Step 2:** Candidate asked to verify that `signup_date` has no time part and that `email` fits a plain string type before approving. AI checked both (clean), and also checked `order_date`.

## Mistakes / corrections
| # | Step | What went wrong | Who caught it | Fix |
|---|---|---|---|---|
| 3 | 6 | **AI stated "Meta new customers fell 5.5%" as a driver of Meta's CAC rise.** It was (a) computed outside SQL with Python as a calculator, not by a query, against the candidate's rule, and (b) based on the June cohort (104), which is the immature cohort we had just shown to be understated. Like-for-like Jan→May, Meta customers actually *rose* 8.2% (110 → 119) while spend rose 111.1%. Same conclusion (diminishing returns), but the specific claim was wrong. | Candidate (asked where the number came from) | Reframed with Jan→May figures; derived figures to be put into a query before use in the memo |
| 2 | 3 | **AI suggested dropping the email profiling check** ("the one I'd drop... doesn't touch any metric"). Candidate insisted on keeping it, expecting junk values. That check then found 35 internal QA test accounts (`qa.test*@urbancart.in`), which could inflate customer counts if they placed orders. | Candidate | Email check kept; follow-up query 08 added |
| 1 | 1 | Minor tooling slip: ran Python with `-I` (isolated mode), which ignores the `PYTHONIOENCODING` env var, so the ₹ symbol in the brief crashed the text extraction twice before the AI switched to `sys.stdout.reconfigure`. No effect on the analysis. | AI | Changed approach |

## Notes
- Context correction from the candidate: the assignment is from **Shiprocket**; UrbanCart is a fictional scenario company. Recorded in DECISIONS.md. (This was context the AI didn't have, not an AI error.)
