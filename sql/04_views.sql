-- =====================================================================
-- BYD France BI · Phase 4 · 04_views.sql             (MySQL 8.0)
-- Reusable analytical views. Power BI connects to these, so every
-- business rule is defined once, in the database.
--
--   v_brand_month           comparison universe + calendar + market + ownership
--   v_market_month          market totals, same-month YoY, seasonality index
--   v_brand_period          full-year and Jan-Oct totals, share, rank, growth
--   v_brand_rank_month      monthly registration rank (AUTRES excluded)
--   v_chinese_owned_month   Chinese-owned share: lower bound + AUTRES upper bound
--   v_chinese_owned_period  same, per full year / Jan-Oct (published YTD)
--
-- Rules carried over from Phases 2-3
--   * Universe = in_market_sum = 1 (no Fiat/Abarth components, no not_listed rows).
--   * Period totals use CCFA published YTD at the period end (Dec or Oct).
--   * Growth compares the SAME period one year earlier through a join on
--     year - 1, never LAG(): if a brand is missing in the earlier period,
--     growth is NULL instead of silently comparing with an older year.
--   * Missing stays missing: no COALESCE(..., 0) on brand registrations.
-- Requires 01_schema.sql and 02_load.sql. Safe to re-run.
-- =====================================================================

USE byd_france;

-- ---------------------------------------------------------------------
-- v_brand_month: one row per brand per month, comparison universe only
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_brand_month;
CREATE VIEW v_brand_month AS
SELECT f.date_key,
       d.period,
       d.year,
       d.month,
       d.is_complete_year,
       f.brand,
       b.is_chinese_owned,
       b.is_chinese_origin,
       b.is_byd,
       CASE WHEN f.brand = 'Other brands (AUTRES)' THEN 1 ELSE 0 END AS is_residual,
       f.registrations_month,
       f.registrations_ytd,
       m.market_registrations_month,
       m.market_registrations_ytd,
       f.registrations_month * 100.0 / m.market_registrations_month AS share_month_pct,
       f.registrations_ytd   * 100.0 / m.market_registrations_ytd   AS share_ytd_pct,
       f.value_type,
       f.source_id
FROM fact_brand_month  f
JOIN dim_date          d ON d.date_key = f.date_key
JOIN fact_market_month m ON m.date_key = f.date_key
JOIN dim_brand         b ON b.brand    = f.brand
WHERE f.in_market_sum = 1;

-- ---------------------------------------------------------------------
-- v_market_month: market totals with same-month YoY and seasonality
-- (the market is present every month, so LAG(..., 12) is safe here)
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_market_month;
CREATE VIEW v_market_month AS
SELECT d.date_key,
       d.period,
       d.year,
       d.month,
       d.is_complete_year,
       m.market_registrations_month,
       m.market_registrations_ytd,
       LAG(m.market_registrations_month, 12) OVER (ORDER BY d.date_key) AS market_same_month_prev_year,
       m.market_registrations_month * 100.0
         / LAG(m.market_registrations_month, 12) OVER (ORDER BY d.date_key) - 100 AS market_yoy_pct,
       CASE WHEN d.is_complete_year = 1
            THEN m.market_registrations_month * 100.0
                 / AVG(m.market_registrations_month) OVER (PARTITION BY d.year)
       END AS seasonality_index      -- complete years only; 100 = average month
FROM fact_market_month m
JOIN dim_date d ON d.date_key = m.date_key;

-- ---------------------------------------------------------------------
-- v_brand_period: full years (Dec YTD) and like-for-like Jan-Oct (Oct YTD)
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_brand_period;
CREATE VIEW v_brand_period AS
WITH period_end AS (
  SELECT CASE WHEN v.month = 12 THEN 'full_year' ELSE 'jan_oct' END AS period_type,
         v.year,
         v.brand,
         v.is_chinese_owned,
         v.is_chinese_origin,
         v.is_byd,
         v.is_residual,
         v.registrations_ytd         AS registrations,
         v.market_registrations_ytd  AS market_registrations
  FROM v_brand_month v
  WHERE (v.month = 12 AND v.is_complete_year = 1)
     OR  v.month = 10
)
SELECT c.period_type,
       CONCAT(CASE c.period_type WHEN 'full_year' THEN 'FY ' ELSE 'Jan-Oct ' END, c.year) AS period_label,
       c.year,
       c.brand,
       c.is_chinese_owned,
       c.is_chinese_origin,
       c.is_byd,
       c.is_residual,
       c.registrations,
       c.market_registrations,
       c.registrations * 100.0 / c.market_registrations                    AS share_pct,
       p.registrations                                                     AS registrations_prev_year,
       c.registrations * 100.0 / NULLIF(p.registrations, 0) - 100          AS growth_pct,  -- NULL if no prior figure
       CASE WHEN c.is_residual = 0
            THEN RANK() OVER (PARTITION BY c.period_type, c.year, c.is_residual ORDER BY c.registrations DESC)
       END                                                                 AS rank_in_period,
       CASE WHEN c.is_residual = 0
            THEN COUNT(*) OVER (PARTITION BY c.period_type, c.year, c.is_residual)
       END                                                                 AS brands_ranked
FROM period_end c
LEFT JOIN period_end p
       ON p.period_type = c.period_type
      AND p.brand       = c.brand
      AND p.year        = c.year - 1;

-- ---------------------------------------------------------------------
-- v_brand_rank_month: monthly rank among listed brands (AUTRES excluded)
-- A brand not listed that month has no row, so it is never ranked as 0.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_brand_rank_month;
CREATE VIEW v_brand_rank_month AS
SELECT v.date_key,
       v.period,
       v.year,
       v.month,
       v.brand,
       v.registrations_month,
       v.share_month_pct,
       RANK()   OVER (PARTITION BY v.date_key ORDER BY v.registrations_month DESC) AS rank_month,
       COUNT(*) OVER (PARTITION BY v.date_key)                                     AS brands_ranked
FROM v_brand_month v
WHERE v.is_residual = 0;

-- ---------------------------------------------------------------------
-- v_chinese_owned_month: lower bound (listed Chinese-owned brands) and
-- upper bound (+ AUTRES, which may hide unlisted Chinese brands)
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_chinese_owned_month;
CREATE VIEW v_chinese_owned_month AS
SELECT a.date_key,
       a.period,
       a.year,
       a.month,
       a.cn_brands_listed,
       a.cn_registrations,
       a.byd_registrations,
       a.autres_registrations,
       a.market_registrations,
       a.cn_registrations * 100.0 / a.market_registrations                           AS cn_share_lower_pct,
       a.autres_registrations * 100.0 / a.market_registrations                       AS autres_share_pct,
       (a.cn_registrations + a.autres_registrations) * 100.0 / a.market_registrations AS cn_share_upper_pct,
       a.byd_registrations * 100.0 / NULLIF(a.cn_registrations, 0)                   AS byd_part_of_cn_pct
FROM (
  SELECT v.date_key, v.period, v.year, v.month,
         SUM(CASE WHEN v.is_chinese_owned = 1 THEN 1 ELSE 0 END)                    AS cn_brands_listed,
         SUM(CASE WHEN v.is_chinese_owned = 1 THEN v.registrations_month ELSE 0 END) AS cn_registrations,
         SUM(CASE WHEN v.is_byd = 1           THEN v.registrations_month END)        AS byd_registrations,
         SUM(CASE WHEN v.is_residual = 1      THEN v.registrations_month END)        AS autres_registrations,
         MAX(v.market_registrations_month)                                          AS market_registrations
  FROM v_brand_month v
  GROUP BY v.date_key, v.period, v.year, v.month
) a;

-- ---------------------------------------------------------------------
-- v_chinese_owned_period: Chinese-owned share per full year / Jan-Oct
-- Note: a brand listed earlier in the year but not at the period end has
-- no published YTD and is excluded (Skyworth, Jan-Oct 2026: 74 cars).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_chinese_owned_period;
CREATE VIEW v_chinese_owned_period AS
SELECT p.period_type,
       p.period_label,
       p.year,
       SUM(CASE WHEN p.is_chinese_owned = 1 THEN 1 ELSE 0 END)                         AS cn_brands_counted,
       SUM(CASE WHEN p.is_chinese_owned = 1 THEN p.registrations ELSE 0 END)           AS cn_registrations,
       MAX(p.market_registrations)                                                    AS market_registrations,
       SUM(CASE WHEN p.is_chinese_owned = 1 THEN p.registrations ELSE 0 END) * 100.0
         / MAX(p.market_registrations)                                                AS cn_share_lower_pct,
       SUM(CASE WHEN p.is_chinese_owned = 1 AND p.is_chinese_origin = 1 THEN p.registrations ELSE 0 END) * 100.0
         / MAX(p.market_registrations)                                                AS cn_origin_share_pct,
       (SUM(CASE WHEN p.is_chinese_owned = 1 THEN p.registrations ELSE 0 END)
        + SUM(CASE WHEN p.is_residual = 1 THEN p.registrations ELSE 0 END)) * 100.0
         / MAX(p.market_registrations)                                                AS cn_share_upper_pct,
       SUM(CASE WHEN p.is_byd = 1 THEN p.registrations END) * 100.0
         / SUM(CASE WHEN p.is_chinese_owned = 1 THEN p.registrations ELSE 0 END)      AS byd_part_of_cn_pct
FROM v_brand_period p
GROUP BY p.period_type, p.period_label, p.year;
