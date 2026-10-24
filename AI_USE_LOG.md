# AI Use Log

Tool: Claude Code (Claude Opus 5.5). Short running log of where AI helped and, especially, mistakes made or caught.

## Where AI helped
- **Step 1:** Extracted the brief's text from the PDF (Python `pypdf`, used only to read it), summarised the brief, listed deliverables, and flagged ambiguous definitions.
- **Step 1:** Proposed the repo layout and created the skeleton folders and logs.
- **Step 2:** Tried a MySQL 8.0 install via winget (failed: Oracle had archived the installer, 404); candidate then chose DuckDB. Drafted the load DDL and `COPY` statements and explained each against MySQL. Ran file-level shell checks (line counts, line endings, date shapes, email lengths) to set the expected row counts and confirm the types.

## Candidate overrides of AI suggestions (not errors, but judgment calls the candidate made)
- **Step 2:** AI recommended all-text (VARCHAR) raw tables with types applied in the clean layer. Candidate chose typed raw tables instead. AI revised the SQL to explicit `CREATE TABLE` plus `COPY`.
- **Step 2:** Candidate asked to verify that `signup_date` has no time part and that `email` fits a plain string type before approving. AI checked both (clean), and also checked `order_date`.

## Mistakes / corrections
| # | Step | What went wrong | Who caught it | Fix |
|---|---|---|---|---|
| 2 | 3 | **AI suggested dropping the email profiling check** ("the one I'd drop... doesn't touch any metric"). Candidate insisted on keeping it, expecting junk values. That check then found 35 internal QA test accounts (`qa.test*@urbancart.in`), which could inflate customer counts if they placed orders. | Candidate | Email check kept; follow-up query 08 added |
| 1 | 1 | Minor tooling slip: ran Python with `-I` (isolated mode), which ignores the `PYTHONIOENCODING` env var, so the ₹ symbol in the brief crashed the text extraction twice before the AI switched to `sys.stdout.reconfigure`. No effect on the analysis. | AI | Changed approach |

## Notes
- Context correction from the candidate: the assignment is from **Shiprocket**; UrbanCart is a fictional scenario company. Recorded in DECISIONS.md. (This was context the AI didn't have, not an AI error.)
