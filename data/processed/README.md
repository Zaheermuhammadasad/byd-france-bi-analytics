# data/processed

**Not included in the repository** (the tables are extracted from CCFA publications). Rebuild them from the source PDFs with notebook 01 (extraction) and notebook 02 (cleaning). The rebuild is deterministic: it was verified to reproduce the original files byte for byte.

| File | Rows | Content |
|---|---|---|
| `brand_month_raw.csv` | 1 475 | Every brand row and Total row exactly as printed in the 34 PDFs |
| `extraction_checks.csv` | 34 | Per PDF: brand rows found; sum of brands vs printed total (month and YTD) |
| `ytd_revisions_log.csv` | 52 | Months where published YTD ≠ previous YTD + month (CCFA revisions: 37 brand, 15 market) |
| `brand_month.csv` | 1 734 | 51 brands × 34 months; `value_type` actual / aggregated / imputed / not_listed; `in_market_sum` defines the comparison universe |
| `market_month.csv` | 34 | CCFA market totals (month and published YTD) |
| `dim_brand.csv` | 51 | Brand ownership and origin flags, with the classification rule |

Missing observations are empty (NULL), never 0. Then run `python scripts/validate_project.py` to check everything.
