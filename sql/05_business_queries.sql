-- =====================================================================
-- BYD France BI · Phase 4 · 05_business_queries.sql  (MySQL 8.0)
-- Business questions answered in SQL, on top of 04_views.sql.
-- Each query is preceded by a marker comment (@query, an id, a question) so the
-- notebook can run and display them one by one.
-- Descriptive only: registrations, not retail sales; no causes asserted.
-- =====================================================================

USE byd_france;

-- @query Q1.1 | How is BYD performing? Registrations, share, rank and growth by period
SELECT period_label,
       registrations,
       ROUND(share_pct, 2)                       AS share_pct,
       CONCAT(rank_in_period, ' of ', brands_ranked) AS rank_in_market,
       registrations_prev_year,
       ROUND(growth_pct, 1)                      AS growth_vs_prev_year_pct
FROM v_brand_period
WHERE brand = 'BYD'
ORDER BY period_type, year;

-- @query Q1.2 | BYD's five strongest months by market share
SELECT period,
       registrations_month,
       ROUND(share_month_pct, 2)                 AS share_month_pct,
       CONCAT(rank_month, ' of ', brands_ranked) AS rank_in_month
FROM v_brand_rank_month
WHERE brand = 'BYD'
ORDER BY share_month_pct DESC
LIMIT 5;

-- @query Q3.1 | BYD growth month by month: 2026 vs the same month of 2025
SELECT cur.period,
       cur.registrations_month                   AS registrations_2026,
       prv.registrations_month                   AS registrations_2025,
       ROUND(cur.registrations_month * 100.0 / NULLIF(prv.registrations_month, 0) - 100, 1) AS byd_yoy_pct,
       ROUND(mk.market_yoy_pct, 1)               AS market_yoy_pct
FROM v_brand_month cur
LEFT JOIN v_brand_month prv
       ON prv.brand = cur.brand AND prv.year = cur.year - 1 AND prv.month = cur.month
JOIN v_market_month mk ON mk.date_key = cur.date_key
WHERE cur.brand = 'BYD' AND cur.year = 2026
ORDER BY cur.month;

-- @query Q3.2 | BYD cumulative 2026: running total of monthly figures vs CCFA published YTD
SELECT period,
       registrations_month,
       SUM(registrations_month) OVER (PARTITION BY year ORDER BY month) AS running_total,
       registrations_ytd                                                AS published_ytd,
       registrations_ytd
         - SUM(registrations_month) OVER (PARTITION BY year ORDER BY month) AS ccfa_revision_effect
FROM v_brand_month
WHERE brand = 'BYD' AND year = 2026
ORDER BY month;

-- @query Q4.1 | BYD vs competitors, like-for-like January-October
SELECT p.brand,
       MAX(CASE WHEN p.year = 2024 THEN p.registrations END) AS jan_oct_2024,
       MAX(CASE WHEN p.year = 2025 THEN p.registrations END) AS jan_oct_2025,
       MAX(CASE WHEN p.year = 2026 THEN p.registrations END) AS jan_oct_2026,
       ROUND(MAX(CASE WHEN p.year = 2026 THEN p.growth_pct END), 1)    AS growth_2026_pct,
       ROUND(MAX(CASE WHEN p.year = 2026 THEN p.share_pct END), 2)     AS share_2026_pct,
       MAX(CASE WHEN p.year = 2026 THEN p.rank_in_period END)          AS rank_2026
FROM v_brand_period p
WHERE p.period_type = 'jan_oct'
  AND p.brand IN ('BYD', 'Tesla', 'MG', 'Xpeng', 'Leapmotor')
GROUP BY p.brand
ORDER BY jan_oct_2026 DESC;

-- @query Q4.2 | Head to head in 2026: months in which BYD out-registered Tesla and MG
SELECT b.period,
       b.registrations_month                       AS byd,
       t.registrations_month                       AS tesla,
       g.registrations_month                       AS mg,
       CASE WHEN b.registrations_month > t.registrations_month THEN 'yes' ELSE 'no' END AS byd_above_tesla,
       CASE WHEN b.registrations_month > g.registrations_month THEN 'yes' ELSE 'no' END AS byd_above_mg
FROM v_brand_month b
JOIN v_brand_month t ON t.date_key = b.date_key AND t.brand = 'Tesla'
JOIN v_brand_month g ON g.date_key = b.date_key AND g.brand = 'MG'
WHERE b.brand = 'BYD' AND b.year = 2026
ORDER BY b.period;

-- @query Q4.3 | Competitive positioning: brands with >= 5 000 registrations in Jan-Oct 2025, ranked by growth
WITH mkt AS (
  SELECT MAX(CASE WHEN year = 2026 THEN market_registrations END) * 100.0
         / MAX(CASE WHEN year = 2025 THEN market_registrations END) - 100 AS market_growth_pct
  FROM v_brand_period WHERE period_type = 'jan_oct'
)
SELECT p.brand,
       p.registrations_prev_year                    AS jan_oct_2025,
       p.registrations                              AS jan_oct_2026,
       ROUND(p.growth_pct, 1)                       AS growth_pct,
       ROUND(p.share_pct, 2)                        AS share_2026_pct,
       CASE WHEN p.growth_pct > mkt.market_growth_pct THEN 'faster' ELSE 'slower' END AS vs_market,
       ROUND(mkt.market_growth_pct, 2)              AS market_growth_pct
FROM v_brand_period p
CROSS JOIN mkt
WHERE p.period_type = 'jan_oct' AND p.year = 2026
  AND p.is_residual = 0
  AND p.registrations_prev_year >= 5000
ORDER BY p.growth_pct DESC
LIMIT 10;

-- @query Q5.1 | Chinese-owned brands: combined share by period (lower bound, upper bound incl. AUTRES)
SELECT period_label,
       cn_brands_counted,
       cn_registrations,
       ROUND(cn_share_lower_pct, 2)   AS cn_share_lower_pct,
       ROUND(cn_share_upper_pct, 2)   AS cn_share_upper_pct,
       ROUND(cn_origin_share_pct, 2)  AS cn_origin_only_pct,
       ROUND(byd_part_of_cn_pct, 1)   AS byd_part_of_cn_pct
FROM v_chinese_owned_period
ORDER BY period_type, year;

-- @query Q5.2 | Chinese-owned share by month in 2026, with the AUTRES uncertainty band
SELECT period,
       cn_brands_listed,
       cn_registrations,
       ROUND(cn_share_lower_pct, 2)   AS lower_bound_pct,
       ROUND(cn_share_upper_pct, 2)   AS upper_bound_pct,
       ROUND(byd_part_of_cn_pct, 1)   AS byd_part_of_cn_pct
FROM v_chinese_owned_month
WHERE year = 2026
ORDER BY period;

-- @query Q5.3 | Largest share gains, Jan-Oct 2026 vs Jan-Oct 2025 (percentage points)
SELECT c.brand,
       CASE WHEN c.is_chinese_owned = 1 THEN 'yes' ELSE 'no' END AS chinese_owned,
       ROUND(p.share_pct, 2)                         AS share_2025_pct,
       ROUND(c.share_pct, 2)                         AS share_2026_pct,
       ROUND(c.share_pct - p.share_pct, 2)           AS change_pp
FROM v_brand_period c
JOIN v_brand_period p
  ON p.brand = c.brand AND p.period_type = c.period_type AND p.year = c.year - 1
WHERE c.period_type = 'jan_oct' AND c.year = 2026 AND c.is_residual = 0
ORDER BY change_pp DESC
LIMIT 10;
