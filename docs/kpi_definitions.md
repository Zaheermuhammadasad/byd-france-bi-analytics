# KPI definitions: BYD France BI

**Phase 5 · Single source of truth for every measure in the dashboards.**
Each KPI is defined once, in SQL (the MySQL views in `sql/04_views.sql`) and in DAX (Power BI), with the rule that decides edge cases and the value the definition must reproduce.

| | |
|---|---|
| Data | CCFA / AAA-DATA monthly registrations by brand, January 2024 – October 2026 (provisional) |
| Validated by | `sql/06_view_checks.sql` (28 checks, all PASS on MySQL 8.0.46) and Notebook 03 |
| Status of DAX | Written to this spec; **validated in Phase 7** by reproducing the "Validated value" column in Power BI |
| Last updated | 22 November 2026 (audit fixes: prior-year logic, market-wide rank) |

---

## 1 · Rules that apply to every KPI

| # | Rule | Why |
|---|---|---|
| R1 | **Comparison universe** = `in_market_sum = 1` (view `v_brand_month`). Excludes the separate Fiat and Abarth rows (they are inside "Fiat + Abarth") and every not-listed row. | The universe adds up exactly to CCFA's market total every month; nothing is double-counted. |
| R2 | **Period totals use CCFA's published YTD at the period end**: December YTD for a full year, October YTD for January–October. Never a re-summed total. | Published YTD includes CCFA's revisions of earlier months. |
| R3 | **Like for like only.** Full year vs full year (2024, 2025); January–October vs January–October (2024, 2025, 2026). 2026 is never compared with a full year. | 2026 data stops in October. |
| R4 | **Missing stays missing.** A brand not listed in a month or period has no value, never 0. Growth with no prior-year figure is blank. | A zero would be an invented observation. |
| R5 | **Growth compares the same period one year earlier**, matched on year − 1 (not "the previous available row"). | If a brand is missing in a period, the comparison must not silently jump to an older year. |
| R6 | **Rankings exclude "Other brands (AUTRES)"**, a residual group, not a brand. Only brands with a value in that period are ranked. | The number ranked therefore varies (40–44); it is always shown as "n of N". |
| R7 | **Registrations ≠ sales.** They include fleet, rental and demonstration cars. No KPI implies a cause (pricing, incentives, fleet deals). | The dataset does not contain causes. |

### Power BI model these DAX measures assume
Import from MySQL: `dim_date`, `dim_brand`, `v_brand_month`, `v_market_month`.
Relationships (one-to-many, single direction): `dim_date[date_key]` → `v_brand_month[date_key]` and `v_market_month[date_key]`; `dim_brand[brand]` → `v_brand_month[brand]`.
`v_market_month` has **no** relationship to `dim_brand`, so the market total is never filtered by a brand selection.
Boolean flags arrive from MySQL as 1 / 0.
**Period measures use the last date in context as the period end** (Dec for 2024–2025, Oct for 2026). Use a single-year slicer for full-year vs Jan–Oct comparisons. With several years selected, the measures report the latest year to date.

---

## 2 · KPI catalogue

| ID | KPI | Business question | Unit | Grain |
|---|---|---|---|---|
| K01 | Registrations | Q1 | cars | brand × period / month |
| K02 | Market registrations | context | cars | period / month |
| K03 | Market share | Q1, Q4 | % | brand × period / month |
| K04 | Registration growth vs same period last year | Q3, Q4 | % | brand × period |
| K05 | Share change vs same period last year | Q3, Q4 | percentage points | brand × period |
| K06 | Rank in market | Q1, Q4 | rank, "n of N" | brand × period / month |
| K07 | Volume gap to a competitor | Q4 | cars | brand pair × period |
| K08 | Months ahead of a competitor | Q4 | months | brand pair × year |
| K09 | Peak monthly share | Q1 | % and month | brand |
| K10 | Chinese-owned share (lower and upper bound) | Q5 | % | period / month |
| K11 | BYD part of Chinese-owned volume | Q5 | % | period / month |
| K12 | Market growth and seasonality index | context, Q5 | %, index | period / month |

Not KPIs here: **Q2 (model mix)** needs model-level registrations, which the CCFA brand tables don't contain. **Q6 (recommendations)** is derived from these KPIs in Phase 8, not measured.

---

## 3 · Definitions

### K01 · Registrations
**Definition.** New passenger cars registered in France for a brand. Period value = CCFA published YTD at the period end (R2); month value = the month's registrations.

```sql
-- period: v_brand_period.registrations      month: v_brand_month.registrations_month
SELECT period_label, registrations FROM v_brand_period WHERE brand = 'BYD';
```
```dax
Registrations (month) := SUM ( v_brand_month[registrations_month] )

Registrations (period) :=
    -- CCFA published YTD at the last month in the current date filter
    CALCULATE ( SUM ( v_brand_month[registrations_ytd] ), LASTDATE ( dim_date[date_key] ) )
```
**Edge cases.** Brand not listed at the period end → blank (R4). Example: Skyworth has 74 registrations Jan–Sep 2026 but is not listed in October 2026, so it has no Jan–Oct 2026 value.
**Validated value.** BYD: FY 2024 **5 415** · FY 2025 **13 533** · Jan–Oct 2024 **2 968** · Jan–Oct 2025 **9 843** · Jan–Oct 2026 **28 086**.

### K02 · Market registrations
**Definition.** Total French new passenger-car registrations (CCFA), same period logic as K01.

```sql
SELECT period, market_registrations_month, market_registrations_ytd FROM v_market_month;
```
```dax
Market registrations (month)  := SUM ( v_market_month[market_registrations_month] )
Market registrations (period) :=
    CALCULATE ( SUM ( v_market_month[market_registrations_ytd] ), LASTDATE ( dim_date[date_key] ) )
```
**Validated value.** FY 2024 **1 718 416** · FY 2025 **1 632 154** · Jan–Oct 2025 **1 326 303** · Jan–Oct 2026 **1 384 293**.

### K03 · Market share
**Definition.** K01 ÷ K02 for the same period, × 100. Calculated from registrations (not CCFA's printed share, which is rounded to 3 decimals; differences ≤ 0.0005 pp).

```sql
SELECT period_label, share_pct FROM v_brand_period WHERE brand = 'BYD';     -- period
SELECT period, share_month_pct FROM v_brand_month WHERE brand = 'BYD';      -- month
```
```dax
Market share % (period) := DIVIDE ( [Registrations (period)], [Market registrations (period)] )
Market share % (month)  := DIVIDE ( [Registrations (month)],  [Market registrations (month)] )
```
**Format.** Percentage, 2 decimals.
**Validated value.** BYD: FY 2024 **0.32%** · FY 2025 **0.83%** · Jan–Oct 2026 **2.03%** · October 2026 (month) **3.63%**. Tesla Jan–Oct 2026 **3.44%**, MG **2.13%**.

### K04 · Registration growth vs same period last year
**Definition.** (K01 this period ÷ K01 same period one year earlier) − 1. Like for like only (R3). Blank when the earlier figure is missing or zero (R4, R5).

```sql
SELECT period_label, registrations_prev_year, growth_pct FROM v_brand_period WHERE brand = 'BYD';
```
```dax
Registrations (same period LY) :=
VAR last_date = MAX ( dim_date[date_key] )   -- period end: Dec for a full year, Oct for 2026
VAR y = YEAR ( last_date )
VAR m = MONTH ( last_date )
RETURN
    CALCULATE ( [Registrations (period)],
                REMOVEFILTERS ( dim_date ), dim_date[year] = y - 1, dim_date[month] = m )

Growth % vs LY :=
VAR ratio = DIVIDE ( [Registrations (period)], [Registrations (same period LY)] )
RETURN IF ( ISBLANK ( ratio ), BLANK (), ratio - 1 )   -- never "-100%" when last year is missing
```
**Common mistakes avoided.**
* `DIVIDE(cur, prev) - 1` returns −100% when `prev` is blank, because BLANK − 1 = −1. The `IF(ISBLANK(...))` guard keeps it blank.
* Taking `MAX(year)` and `MAX(month)` separately breaks when several years are in context (no year slicer). Max year = 2026 and max month = 12 would compare Jan–Oct 2026 with **full-year 2025** (BYD: 107.5% instead of 185.3%). The year and month are therefore read from the **last date** in context, the same date `LASTDATE` uses for the current period. *(Fixed after the 22 Nov 2026 audit.)*
**Validated value.** BYD: FY 2025 **+149.9%** · Jan–Oct 2025 **+231.6%** · Jan–Oct 2026 **+185.3%**. Jan–Oct 2026: Tesla **+117.1%**, MG **+23.7%**, Leapmotor **+172.6%**, Xpeng **+154.1%**. Xpeng Jan–Oct 2025: **blank** (no 2024 figure).

### K05 · Share change vs same period last year
**Definition.** K03 this period − K03 same period one year earlier, in **percentage points** (not %).

```sql
SELECT c.brand, c.share_pct - p.share_pct AS change_pp
FROM v_brand_period c
JOIN v_brand_period p ON p.brand = c.brand AND p.period_type = c.period_type AND p.year = c.year - 1;
```
```dax
Market share % (same period LY) :=
VAR last_date = MAX ( dim_date[date_key] )
VAR y = YEAR ( last_date )
VAR m = MONTH ( last_date )
VAR mkt_ly = CALCULATE ( [Market registrations (period)],
                         REMOVEFILTERS ( dim_date ), dim_date[year] = y - 1, dim_date[month] = m )
RETURN DIVIDE ( [Registrations (same period LY)], mkt_ly )

Share change pp vs LY :=
VAR cur  = [Market share % (period)]
VAR prev = [Market share % (same period LY)]
RETURN IF ( ISBLANK ( cur ) || ISBLANK ( prev ), BLANK (), ( cur - prev ) * 100 )
```
**Why it matters.** Growth % flatters small brands; share points show who actually took market. Use both.
**Validated value.** BYD Jan–Oct 2026 vs 2025: **+1.29 pp** (0.74% → 2.03%). Largest gain: Tesla **+1.79 pp**.

### K06 · Rank in market
**Definition.** Position by registrations among brands with a value in that period, AUTRES excluded (R6). Ties share a rank (standard competition ranking). Always displayed with the number ranked.

```sql
SELECT period_label, rank_in_period, brands_ranked FROM v_brand_period WHERE brand = 'BYD';
SELECT period, rank_month, brands_ranked FROM v_brand_rank_month WHERE brand = 'BYD';
```
```dax
Rank (period) :=
VAR cur = [Registrations (period)]
RETURN
IF ( NOT HASONEVALUE ( dim_brand[brand] )
     || ISBLANK ( cur )
     || SELECTEDVALUE ( dim_brand[brand] ) = "Other brands (AUTRES)",
     BLANK (),
     RANKX ( FILTER ( ALL ( dim_brand ),
                      dim_brand[brand] <> "Other brands (AUTRES)"
                      && NOT ISBLANK ( [Registrations (period)] ) ),
             [Registrations (period)], cur, DESC, SKIP ) )

Brands ranked (period) :=
COUNTROWS ( FILTER ( ALL ( dim_brand ),
                     dim_brand[brand] <> "Other brands (AUTRES)"
                     && NOT ISBLANK ( [Registrations (period)] ) ) )
```
The monthly rank uses the same pattern with `[Registrations (month)]`.
`ALL ( dim_brand )` (not only the brand column) keeps the rank market-wide even when another brand slicer is active, for example "Chinese-owned only". That matches the SQL definition. *(Changed after the 22 Nov 2026 audit.)*
**Validated value.** BYD: FY 2024 **30 of 40** · FY 2025 **24 of 40** · Jan–Oct 2024 **32 of 40** · Jan–Oct 2026 **16 of 44**. Monthly: January 2024 **29**, October 2026 **7 of 44**.

### K07 · Volume gap to a competitor
**Definition.** BYD registrations − competitor registrations, same period. Negative = BYD behind.

```sql
SELECT b.registrations - c.registrations AS gap
FROM v_brand_period b JOIN v_brand_period c
  ON c.period_type = b.period_type AND c.year = b.year AND c.brand = 'Tesla'
WHERE b.brand = 'BYD';
```
```dax
Gap to Tesla (period) :=
VAR byd   = CALCULATE ( [Registrations (period)], REMOVEFILTERS ( dim_brand ), dim_brand[brand] = "BYD" )
VAR comp  = CALCULATE ( [Registrations (period)], REMOVEFILTERS ( dim_brand ), dim_brand[brand] = "Tesla" )
RETURN IF ( ISBLANK ( byd ) || ISBLANK ( comp ), BLANK (), byd - comp )
```
(Same measure with "MG", or driven by a disconnected competitor slicer.)
**Validated value.** Jan–Oct 2026: vs Tesla **−19 523**, vs MG **−1 438**. October 2026 (month): vs Tesla **+3 009**, vs MG **+1 445**.

### K08 · Months ahead of a competitor
**Definition.** Number of months in the selected year in which BYD registered more cars than the competitor. Months where either brand is missing are not counted.

```sql
SELECT SUM(b.registrations_month > t.registrations_month) AS months_ahead, COUNT(*) AS months
FROM v_brand_month b JOIN v_brand_month t ON t.date_key = b.date_key AND t.brand = 'Tesla'
WHERE b.brand = 'BYD' AND b.year = 2026;
```
```dax
Months ahead of Tesla :=
COUNTROWS (
    FILTER ( VALUES ( dim_date[date_key] ),
        VAR byd  = CALCULATE ( [Registrations (month)], REMOVEFILTERS ( dim_brand ), dim_brand[brand] = "BYD" )
        VAR comp = CALCULATE ( [Registrations (month)], REMOVEFILTERS ( dim_brand ), dim_brand[brand] = "Tesla" )
        RETURN NOT ISBLANK ( byd ) && NOT ISBLANK ( comp ) && byd > comp ) )
```
**Validated value.** 2026 (10 months): ahead of Tesla in **4** months (Jan, Apr, Jul, Oct); ahead of MG in **4** (Jun, Aug, Sep, Oct); ahead of both only in **October**.

### K09 · Peak monthly share
**Definition.** The highest monthly K03 in the selected range, and the month it occurred.

```sql
SELECT period, share_month_pct FROM v_brand_month WHERE brand = 'BYD' ORDER BY share_month_pct DESC LIMIT 1;
```
```dax
Peak monthly share % := MAXX ( VALUES ( dim_date[date_key] ), [Market share % (month)] )

Peak share month :=
CONCATENATEX ( TOPN ( 1, VALUES ( dim_date[period] ), [Market share % (month)], DESC ),
               dim_date[period], ", " )
```
**Validated value.** BYD: **3.63%** in **2026-10** (5 419 registrations).

### K10 · Chinese-owned share (lower and upper bound)
**Definition.**
* **Chinese-owned** = the brand's controlling owner (> 50% or sole control) is headquartered in China (`dim_brand.is_chinese_owned`). Volvo and MG count; Smart (50/50 JV) does not. Ownership is general industry knowledge as of November 2026, not CCFA data.
* **Lower bound** = registrations of Chinese-owned brands **listed separately** by CCFA ÷ market.
* **Upper bound** = lower bound + the AUTRES share, which may contain unlisted Chinese brands.
* Always reported as a **range**, with the number of brands counted, because part of any rise comes from more Chinese brands being listed.

```sql
SELECT period_label, cn_brands_counted, cn_share_lower_pct, cn_share_upper_pct FROM v_chinese_owned_period;
SELECT period, cn_share_lower_pct, cn_share_upper_pct FROM v_chinese_owned_month;
```
```dax
Chinese-owned share % (lower) :=
DIVIDE ( CALCULATE ( [Registrations (period)], REMOVEFILTERS ( dim_brand ), dim_brand[is_chinese_owned] = 1 ),
         [Market registrations (period)] )

Chinese-owned share % (upper) :=
DIVIDE ( CALCULATE ( [Registrations (period)], REMOVEFILTERS ( dim_brand ), dim_brand[is_chinese_owned] = 1 )
         + CALCULATE ( [Registrations (period)], REMOVEFILTERS ( dim_brand ), dim_brand[brand] = "Other brands (AUTRES)" ),
         [Market registrations (period)] )
```
**Validated value.**

| Period | Brands counted | Lower | Upper |
|---|---|---|---|
| FY 2024 | 5 | **2.95%** | 3.06% |
| FY 2025 | 7 | **4.20%** | 4.31% |
| Jan–Oct 2026 | 11 | **7.07%** | 7.20% |

Chinese-origin brands only, Jan–Oct 2026: **4.21%**. Monthly lower bound, October 2026: **11.53%**.

### K11 · BYD part of Chinese-owned volume
**Definition.** BYD registrations ÷ registrations of all listed Chinese-owned brands, same period.

```sql
SELECT period_label, byd_part_of_cn_pct FROM v_chinese_owned_period;
```
```dax
BYD part of Chinese-owned % :=
DIVIDE ( CALCULATE ( [Registrations (period)], REMOVEFILTERS ( dim_brand ), dim_brand[is_byd] = 1 ),
         CALCULATE ( [Registrations (period)], REMOVEFILTERS ( dim_brand ), dim_brand[is_chinese_owned] = 1 ) )
```
**Validated value.** FY 2024 **10.7%** · FY 2025 **19.7%** · Jan–Oct 2026 **28.7%**.

### K12 · Market growth and seasonality index
**Definitions.**
* **Market growth** = K02 this period ÷ K02 same period last year − 1 (like for like).
* **Seasonality index** = month's market registrations ÷ that year's monthly average × 100, **complete years only** (2024, 2025), then averaged across the two years. 100 = an average month. Used to read brand months in context; use share (K03), not volume, for month-to-month performance.

```sql
SELECT period, market_yoy_pct, seasonality_index FROM v_market_month;
```
```dax
Market growth % vs LY :=
VAR last_date = MAX ( dim_date[date_key] )
VAR y = YEAR ( last_date )
VAR m = MONTH ( last_date )
VAR prev = CALCULATE ( [Market registrations (period)], REMOVEFILTERS ( dim_date ),
                       dim_date[year] = y - 1, dim_date[month] = m )
VAR ratio = DIVIDE ( [Market registrations (period)], prev )
RETURN IF ( ISBLANK ( ratio ), BLANK (), ratio - 1 )

Seasonality index := AVERAGE ( v_market_month[seasonality_index] )   -- blank for 2026 by design
```
**Validated value.** Market growth: FY 2025 **−5.02%** · Jan–Oct 2026 **+4.37%**. Seasonality index (2024–25 average): Jan 85 · Feb 102 · Mar 119 · Apr 102 · May 95 · **Jun 126** · Jul 87 · **Aug 62** · Sep 100 · Oct 99 · Nov 95 · **Dec 128**.
*Note:* Notebook 03's table shows Mar 120 and Nov 96 because it averaged per-year indices that were already rounded; the figures above average the unrounded values. August, the key reading, is 62 either way.

---

## 4 · Where each KPI appears (dashboard plan)

| Page | KPIs |
|---|---|
| 1 · BYD overview (Q1, Q3) | K01, K03, K04, K05, K06, K09 |
| 2 · Competitors (Q4) | K01, K03, K04, K05, K06, K07, K08 for BYD, Tesla, MG, Xpeng, Leapmotor |
| 3 · Chinese-owned brands (Q5) | K10 (always as a range with brands counted), K11 |
| 4 · Market context | K02, K12 |

Every page carries the footnote: *"Source: CCFA / AAA-DATA, provisional. Registrations, not sales. 2026 = January–October."*

## 5 · Formatting conventions

| Measure type | Format | Example |
|---|---|---|
| Registrations | whole number, thin-space thousands separator | 28 086 |
| Share | %, 2 decimals | 2.03% |
| Growth | signed %, 1 decimal | +185.3% |
| Share change | signed, 2 decimals, "pp" | +1.29 pp |
| Rank | "n of N" | 16 of 44 |
| Blank (missing) | shown as "–" with a tooltip "not listed separately by CCFA", never 0 | – |
