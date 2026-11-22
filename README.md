# BYD France: Business Intelligence & Market Analytics

End-to-end BI project measuring **BYD's performance in the French new passenger-car market** against its competitors, built on 34 monthly registration reports from CCFA (data: AAA-DATA), January 2024 – October 2026.

**Status (22 November 2026):** data pipeline, SQL model and KPI specification complete and validated. The Power BI dashboard is in progress: the data package and DAX measures exist, but the report hasn't been built yet. No Tableau dashboard yet.

## Headline findings (descriptive)

| Measure | Value |
|---|---|
| BYD registrations, Jan–Oct 2026 | **28 086** (Jan–Oct 2025: 9 843) |
| BYD growth, Jan–Oct 2026 vs Jan–Oct 2025 | **+185.3%** (market: +4.4%) |
| BYD market share, Jan–Oct 2026 | **2.03%** (October 2026 alone: 3.63%) |
| BYD rank among listed brands | **32nd of 40** (Jan–Oct 2024) → **16th of 44** (Jan–Oct 2026) |
| Competitors, Jan–Oct 2026 | Tesla 47 609 (+117.1%) · MG 29 524 (+23.7%) · Leapmotor 7 292 (+172.6%) · Xpeng 6 254 (+154.1%) |
| Chinese-owned brands' combined share, Jan–Oct 2026 | **7.07%–7.20%** (range explained in the KPI definitions) |

These are **registrations, not retail sales**. They include fleet, rental and demonstration cars. The data doesn't contain the reasons behind any trend (pricing, incentives, fleet deals), so none are claimed. All CCFA figures are provisional.

## Business questions and coverage

| # | Question | Covered? |
|---|---|---|
| Q1 | How is BYD performing in France? | ✅ Notebook 03, SQL Q1.1–Q1.2 |
| Q2 | Which BYD models contribute most? | ❌ Not possible with this data. CCFA's monthly tables are by brand only; there's no model-level source in the repo yet |
| Q3 | How is BYD growing over time? | ✅ Notebook 03, SQL Q3.1–Q3.2 |
| Q4 | How does BYD compare with competitors? | ✅ Notebook 03, SQL Q4.1–Q4.3 |
| Q5 | What opportunities exist? | ◑ Descriptive only: the rise of Chinese-owned brands and the competitive positioning (SQL Q5.1–Q5.3) |
| Q6 | What commercial recommendations can we make? | ⏳ Phase 8, not started |

**Scope note:** the data has **no powertrain split by brand** (BEV/PHEV), so this project doesn't measure BYD's share of the electric market.

## Project phases (verified against the files and commit history)

| Phase | Description | Status | Evidence |
|---|---|---|---|
| 1 | Data sourcing and verification | ✅ Complete | 34 CCFA PDFs in `data/raw/`; every file registered with its URL in `docs/source_register.csv`; `notebooks/01_data_extraction.ipynb` |
| 2 | Data cleaning (Python) | ✅ Complete | `notebooks/02_data_cleaning.ipynb` → `data/processed/` |
| 3 | Exploratory data analysis | ✅ Complete | `notebooks/03_eda.ipynb` (executed, 8 charts, validation checks) |
| 4 | SQL model and business queries (MySQL 8) | ✅ Complete | `sql/01`–`06`; notebooks 04–05 executed on MySQL 8.0.46 |
| 5 | KPI definitions | ✅ Complete | `docs/kpi_definitions.md`: 12 KPIs in SQL and DAX |
| 6 | Tableau dashboard | ⏳ Not started | – |
| 7 | Power BI dashboard | 🔶 In progress | `data/powerbi/`: data package, 23 DAX measures, setup guide. No `.pbix` yet; the DAX hasn't been run in Power BI yet |
| 8 | Insights and recommendations | 🔶 Partial | Descriptive findings in notebook 03; no recommendations yet |
| 9 | Documentation and publication | 🔶 In progress | This README; independent technical audit, 22 Nov 2026 (results under Validation) |

## Validation

Every published figure is reproducible. After rebuilding the data (see *How to reproduce*), **`python scripts/validate_project.py --pdf --powerbi data/powerbi` runs 29 automated checks**:

* **Extraction:** an independent re-extraction of all 34 PDFs with a second tool (`pdftotext`) matches every monthly and year-to-date count. CCFA's printed market shares match registrations ÷ market for all 1 474 rows (≤ 0.0005 pp, rounding only).
* **Reconciliation:** the brands in the comparison universe add up to CCFA's market total every month. Every year-to-date discrepancy is logged as a CCFA revision. AUTRES restatements are fully explained by brands entering or leaving CCFA's list.
* **Growth cross-check:** our year-on-year growth equals **CCFA's own printed growth** for all 852 comparable brand rows (≤ 0.1 pp).
* **Reproducibility:** re-running notebooks 01 and 02 on the raw PDFs reproduces the committed CSVs byte for byte.
* **SQL:** 22 load checks and 28 view checks pass on MySQL 8.0.46 (notebooks 04–05).

## Data integrity rules

Only traceable sources are used. Each value is labelled `actual`, `aggregated` (Fiat + Abarth) or `imputed` (one cell: Jaguar's year-to-date for January 2025, blank in the source PDF). Missing observations stay empty, never 0. Published year-to-date figures are never recalculated. The raw files are never edited.

## Repository structure

```
data/raw/          source PDFs: NOT included, downloaded by scripts/download_sources.py
data/processed/    extracted and cleaned CSVs: NOT included, rebuilt by notebooks 01-02
data/powerbi/      DAX measures, setup and validation guide, MANIFEST (CSVs rebuilt by script)
notebooks/         01 extraction · 02 cleaning · 03 EDA · 04 SQL model · 05 SQL views and queries
sql/               01 schema · 02 load · 03 load checks · 04 views · 05 business queries · 06 view checks · 07 Power BI extract
scripts/           download_sources.py · build_powerbi_package.py · validate_project.py
docs/              source_register.csv · raw_files.sha256 · kpi_definitions.md
```

## How to reproduce

1. **Get the sources:** `python scripts/download_sources.py` downloads the 35 files from CCFA's website into `data/raw/` and verifies each fingerprint.
2. **Extraction and cleaning:** run `notebooks/01` then `02` (Google Colab: zip the repo folder, including `data/raw/`, and upload it when asked). They rebuild `data/processed/` byte for byte.
3. **EDA:** run `notebooks/03` with the three files from `data/processed/`.
4. **SQL:** run `notebooks/04` and `05` in Colab. They install MySQL 8 inside the session and run `sql/01`–`06`.
5. **Power BI inputs:** `python scripts/build_powerbi_package.py` (checked against `data/powerbi/MANIFEST.sha256`).
6. **Check everything:** `pip install pandas`, then `python scripts/validate_project.py --powerbi data/powerbi` (add `--pdf` if poppler's `pdftotext` is installed).

## Known limitations

* No official dataset splits registrations by brand **and** powertrain, so BEV/PHEV shares by brand can't be measured.
* Brands that CCFA doesn't list separately sit inside "AUTRES". The Chinese-owned share is therefore a range, from listed brands only up to listed brands plus AUTRES.
* Ownership flags (`dim_brand.csv`) reflect general industry knowledge as of November 2026, not CCFA data. One judgement call: Leapmotor is classified by its parent company (Chinese). In Europe it is distributed through Leapmotor International, a joint venture with Stellantis.
* 2026 covers January–October only. Full-year 2026 isn't estimated.

## Sources and licensing

Registration data: **CCFA (Comité des Constructeurs Français d'Automobiles), data AAA-DATA**, monthly "Immatriculations VP" reports. Every file and URL is listed in [`docs/source_register.csv`](docs/source_register.csv).

CCFA reserves all reproduction rights to its publications, including electronic reproduction of downloadable documents. **This repository therefore contains neither the PDFs nor the tables extracted from them**, only code, SQL, documentation and aggregated results. The scripts download the files from CCFA's website. Code and documentation: MIT licence (see `LICENSE`). The data remains © CCFA / AAA-DATA.

## Author

Muhammad Asad Zaheer, MSc Data & Business Analytics, Rennes School of Business · [LinkedIn](https://www.linkedin.com/in/asadzaheerportfolio)
