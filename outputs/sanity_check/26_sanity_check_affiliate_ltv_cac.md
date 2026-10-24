|                    route                     | spend_inr | customers | delivered_revenue_inr | cac_inr | ltv_inr |  ltv_to_cac_exact   | ltv_to_cac |
|----------------------------------------------|----------:|----------:|----------------------:|--------:|--------:|--------------------:|-----------:|
| independent (raw, ROW_NUMBER, email pattern) | 346000    | 505       | 483387                | 685     | 287     | 0.41912167630057806 | 0.42       |
| original (clean tables, as in 23)            | 346000    | 505       | 483387                | 685     | 287     | 0.41912167630057806 | 0.42       |
|     component     | independent | original  | matches |
|-------------------|-------------|-----------|---------|
| spend             | 346000.00   | 346000.00 | true    |
| customers         | 505         | 505       | true    |
| delivered revenue | 483387.00   | 483387.00 | true    |
| LTV:CAC (2 dp)    | 0.42        | 0.42      | true    |
