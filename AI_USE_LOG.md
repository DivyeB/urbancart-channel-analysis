# AI Use Log

## Role of AI
I used Claude Code (Claude Opus 5.5) as an assistant for repetitive work: writing SQL, drafting documentation and write-ups. I also used it as a second mind for suggestions when needed, including explanations of DuckDB (against the MySQL I know) and of GCP tooling. Claude in Chrome assisted with the chart layout in Looker Studio.

## Working rules
- No query was run without my line-by-line review and approval.
- No decision was taken by AI on its own; every suggestion was discussed with me and either accepted or overridden by me.
- Every figure in the deliverables traces back to a saved query output.

## Where I corrected or redirected the AI
- **Data types:** AI defaulted every column in the raw tables to VARCHAR. In my experience that is not good practice, so I enforced proper types (INTEGER, DATE, DECIMAL) instead.
- **Email check:** AI treated the email column as low priority and suggested skipping that check. I insisted on it, expecting malformed addresses. It found none, but it revealed 35 internal test accounts making up 61.7% of Affiliate's revenue, which were then excluded.
- **Unknown channel:** I kept users with a blank acquisition channel in the data, because blank is not necessarily wrong data, but did not attribute them to any channel or create an "Unknown" bucket, because that would invent an attribution the business never had. They are excluded from every channel metric and reported only in the data-quality log (72 users, 40 of them customers).
- **Which channel to cut:** Affiliate ranked worst on LTV:CAC, and AI's explanation of Meta's rising CAC rested on a figure it hadn't queried. I found Meta's monthly spend increase odd, so I asked for a month-on-month comparison of spend vs new customers. It showed Meta spend rising ~26% a month while new customers stayed flat, which became the core evidence for the recommendation.
