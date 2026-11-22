# sql

MySQL 8 scripts, in execution order (run by notebooks 04–05):

| Script | Purpose |
|---|---|
| `01_schema.sql` | Star schema: `dim_brand`, `dim_date` (generated), `fact_market_month`, `fact_brand_month`, with keys and CHECK constraints |
| `02_load.sql` | Loads the three validated CSVs with `LOAD DATA LOCAL INFILE`; blanks become NULL |
| `03_checks.sql` | 22 load and reconciliation checks (all PASS) |
| `04_views.sql` | 6 analytical views used by the business queries and Power BI |
| `05_business_queries.sql` | 10 business queries (Q1, Q3, Q4, Q5) |
| `06_view_checks.sql` | 28 checks of the views against the validated figures (all PASS) |
| `07_powerbi_extract.sql` | The four queries that produce `data/powerbi/*.csv` |
