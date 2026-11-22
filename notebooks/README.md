# notebooks

Google Colab notebooks, in execution order:

| Notebook | What it does | Inputs → outputs |
|---|---|---|
| `01_data_extraction.ipynb` | Extracts the brand tables from the 34 CCFA PDFs (pdfplumber) and reconciles every month with CCFA's printed totals | `data/raw/*.pdf` → `brand_month_raw.csv`, `extraction_checks.csv`, `ytd_revisions_log.csv` |
| `02_data_cleaning.ipynb` | Maps brand labels, adds value types, ownership flags and YTD revision gaps; star-schema tables | `brand_month_raw.csv` → `brand_month.csv`, `market_month.csv`, `dim_brand.csv` |
| `03_eda.ipynb` | Exploratory analysis: market, BYD, competitors, Chinese-owned brands, rankings (executed, 8 charts) | the three v2 CSVs |
| `04_sql_model.ipynb` | Builds the MySQL 8 star schema inside Colab, loads the data, runs 22 load checks | `sql/01`–`03` |
| `05_sql_views_queries.ipynb` | Creates the 6 analytical views, runs 28 view checks and 10 business queries | `sql/01`–`06` |

Notebooks 01 and 02 are committed without outputs. Re-running them reproduces the committed CSVs byte for byte (verified 22 Nov 2026). Notebooks 03–05 are committed with their executed outputs.
