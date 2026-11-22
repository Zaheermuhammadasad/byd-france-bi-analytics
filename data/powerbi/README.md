# Power BI data package: BYD France BI

Everything Power BI needs, so the Windows laptop needs **no MySQL install**.

**The four CSVs are not included in the repository** (they contain figures extracted from CCFA publications). Rebuild them in two minutes: download the sources (`python scripts/download_sources.py`), run notebooks 01–02, then `python scripts/build_powerbi_package.py`. The script checks every file against `MANIFEST.sha256`.

| File | Rows | What it is |
|---|---|---|
| `dim_date.csv` | 34 | Calendar, Jan 2024 – Oct 2026 (`is_complete_year` = 1 for 2024–2025) |
| `dim_brand.csv` | 51 | Brands with ownership flags (`is_chinese_owned`, `is_chinese_origin`, `is_byd`, `is_residual` for AUTRES) |
| `v_brand_month.csv` | 1 408 | Registrations per brand per month, **comparison universe only** (Fiat/Abarth components and not-listed rows already excluded) |
| `v_market_month.csv` | 34 | Market totals, YoY change, seasonality index |
| `measures.dax` | 23 measures | Paste-ready DAX, copied unchanged from `docs/kpi_definitions.md` |
| `MANIFEST.sha256` | – | Fingerprints of the four CSVs |

**Provenance.** Produced by the four queries in [`sql/07_powerbi_extract.sql`](../../sql/07_powerbi_extract.sql), run against the views in `sql/04_views.sql`. The reference files (fingerprints in `MANIFEST.sha256`) were exported from an exact replica of the MySQL model built from the validated Phase 2 v2 files. Before export, the replica passed the same 28 view checks that passed on MySQL 8.0.46 (Notebook 05).
**Check the package at any time:** `python scripts/validate_project.py --powerbi data/powerbi`. It verifies the file fingerprints, row counts and reconciliation, and emulates the DAX prior-year logic.
**Missing values** are empty cells, never 0.

---

## Setup on the Windows laptop (about 45 minutes)

### 1 · Install Power BI Desktop
Microsoft Store → search **Power BI Desktop** → Install (free). Requires Windows 10 or 11, 64-bit. You don't need to sign in to build the report.

### 2 · Get the files
Rebuild the four CSVs as described at the top of this page (or copy them from your own working copy), and put them in one folder on the Windows laptop.

### 3 · Set the import locale BEFORE loading any file ⚠️
**File → Options and settings → Options → Current file → Regional settings → Locale for import: English (United States)**.
*Why:* the CSVs use a dot as the decimal separator. If the laptop is set to French, Power BI reads `85.392811` as 85 392 811, or as text.

### 4 · Load the four CSVs
**Home → Get data → Text/CSV**, once per file → **Transform data**, then check the column types:

| Column(s) | Type |
|---|---|
| `date_key` (all tables) | Date |
| `registrations_month`, `registrations_ytd`, `market_registrations_*`, `market_same_month_prev_year` | Whole number |
| `year`, `month`, `quarter`, `months_in_data`, all `is_*` flags | Whole number |
| `market_yoy_pct`, `seasonality_index` | Decimal number |
| everything else | Text |

Empty cells must show as `null`, not 0. Then **Close & Apply**.

### 5 · Relationships (Model view)
Delete any relationship Power BI created automatically, then create exactly these three (one-to-many, single direction):

| From (one side) | To (many side) |
|---|---|
| `dim_date[date_key]` | `v_brand_month[date_key]` |
| `dim_date[date_key]` | `v_market_month[date_key]` |
| `dim_brand[brand]` | `v_brand_month[brand]` |

**No relationship between `dim_brand` and `v_market_month`**: the market total must not change when a brand is selected.

### 6 · Create the measures
*Use the 22 Nov 2026 version of `measures.dax` (audit fixes to the prior-year and rank measures).*
**Home → Enter data** → name the table `_Measures` → Load. Select `_Measures` → **New measure** → paste the measures from `measures.dax` **one at a time, in file order**.
Formats: shares and growth → Percentage (2 and 1 decimals); `Share change pp vs LY` → Decimal, 2 decimals; registrations → Whole number with thousands separator.

### 7 · Validation page (do this before any design)
Add a page called **Validation**:
* a slicer on `dim_date[year]` (single select)
* a table with `dim_brand[brand]` plus the measures below

Then compare with the expected values. **Every number must match before building the dashboard.**

| Year slicer | Brand | Measure | Expected |
|---|---|---|---|
| 2026 | BYD | Registrations (period) | 28 086 |
| 2026 | BYD | Market share % (period) | 2.03% |
| 2026 | BYD | Growth % vs LY | +185.3% |
| 2026 | BYD | Share change pp vs LY | +1.29 |
| 2026 | BYD | Rank (period) / Brands ranked (period) | 16 / 44 |
| 2026 | BYD | Gap to Tesla (period) / Gap to MG (period) | −19 523 / −1 438 |
| 2026 | BYD | Months ahead of Tesla / Months ahead of MG | 4 / 4 |
| 2026 | BYD | Peak monthly share % / Peak share month | 3.63% / 2026-10 |
| 2026 | Tesla · MG | Growth % vs LY | +117.1% · +23.7% |
| 2026 | (any) | Chinese-owned share % (lower) / (upper) | 7.07% / 7.20% |
| 2026 | (any) | BYD part of Chinese-owned % | 28.7% |
| 2026 | (any) | Market growth % vs LY | +4.37% |
| 2025 | BYD | Registrations (period) / Growth % vs LY | 13 533 / +149.9% |
| 2025 | BYD | Rank (period) / Brands ranked (period) | 24 / 40 |
| 2025 | Xpeng | Growth % vs LY | **blank** (no 2024 figure, not −100%) |
| 2025 | (any) | Chinese-owned share % (lower) / Market growth % vs LY | 4.20% / −5.02% |
| 2024 | BYD | Registrations (period) / Rank (period) | 5 415 / 30 |
| **no year selected** | BYD | Growth % vs LY | **+185.3%** (latest Jan–Oct vs Jan–Oct; must **not** show 107.5%) |
| 2026 + slicer `dim_brand[is_chinese_owned]` = 1 | BYD | Rank (period) | **16** (rank stays market-wide) |

If a value doesn't match, take a screenshot of the table and the measure formula. Don't adjust the formula until we've found the cause.

### 8 · Save
Save as `byd_france.pbix`. It will go into the repo in the `powerbi/` folder once validated.
