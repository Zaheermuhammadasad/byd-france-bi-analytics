-- =====================================================================
-- BYD France BI · Phase 4 · 03_checks.sql            (MySQL 8.0)
-- Reconciliation checks after loading. Every row must return 'PASS'.
-- The expected values come from the validated Phase 2 files and the
-- Notebook 03 results, so passing proves SQL and Python agree.
--   mysql -t byd_france < 03_checks.sql
-- =====================================================================

USE byd_france;

WITH
universe AS (                               -- comparison universe: no Fiat/Abarth components, no not_listed rows
  SELECT * FROM fact_brand_month WHERE in_market_sum = 1
),
u_month AS (
  SELECT u.date_key,
         SUM(u.registrations_month) AS u_month,
         SUM(u.registrations_ytd)   AS u_ytd
  FROM universe u
  GROUP BY u.date_key
),
checks AS (
  SELECT 'K01' AS id, 'dim_brand rows' AS check_name, 51 AS expected,
         (SELECT COUNT(*) FROM dim_brand) AS actual
  UNION ALL SELECT 'K02', 'dim_date rows (Jan 2024 - Oct 2026)', 34, (SELECT COUNT(*) FROM dim_date)
  UNION ALL SELECT 'K03', 'fact_market_month rows', 34, (SELECT COUNT(*) FROM fact_market_month)
  UNION ALL SELECT 'K04', 'fact_brand_month rows (34 x 51)', 1734, (SELECT COUNT(*) FROM fact_brand_month)
  UNION ALL SELECT 'K05', 'months without exactly 51 brand rows', 0,
         (SELECT COUNT(*) FROM (SELECT date_key FROM fact_brand_month GROUP BY date_key HAVING COUNT(*) <> 51) x)
  UNION ALL SELECT 'K06', 'months where universe <> market total (month)', 0,
         (SELECT COUNT(*) FROM fact_market_month m LEFT JOIN u_month u ON u.date_key = m.date_key
          WHERE u.u_month IS NULL OR u.u_month <> m.market_registrations_month)
  UNION ALL SELECT 'K07', 'months where universe <> market total (YTD)', 0,
         (SELECT COUNT(*) FROM fact_market_month m LEFT JOIN u_month u ON u.date_key = m.date_key
          WHERE u.u_ytd IS NULL OR u.u_ytd <> m.market_registrations_ytd)
  UNION ALL SELECT 'K08', 'Fiat / Abarth component rows in universe', 0,
         (SELECT COUNT(*) FROM universe WHERE brand IN ('Fiat', 'Abarth'))
  UNION ALL SELECT 'K09', 'not_listed rows with any figure (zero-fill)', 0,
         (SELECT COUNT(*) FROM fact_brand_month WHERE value_type = 'not_listed'
          AND (registrations_month IS NOT NULL OR registrations_ytd IS NOT NULL OR share_month_pct IS NOT NULL))
  UNION ALL SELECT 'K10', 'not_listed rows in universe', 0,
         (SELECT COUNT(*) FROM universe WHERE value_type = 'not_listed')
  UNION ALL SELECT 'K11', 'NULL monthly registrations preserved (as in CSV)', 260,
         (SELECT COUNT(*) FROM fact_brand_month WHERE registrations_month IS NULL)
  UNION ALL SELECT 'K12', 'zero registrations (CCFA-published zeros only)', 6,
         (SELECT COUNT(*) FROM fact_brand_month WHERE registrations_month = 0)
  UNION ALL SELECT 'K13', 'universe rows without an ownership classification', 0,
         (SELECT COUNT(*) FROM universe u LEFT JOIN dim_brand b ON b.brand = u.brand WHERE b.brand IS NULL)
  UNION ALL SELECT 'K14', 'Chinese-owned brands in dim_brand', 12,
         (SELECT COUNT(*) FROM dim_brand WHERE is_chinese_owned = 1)
  UNION ALL SELECT 'K15', 'complete-year months in dim_date (2024 + 2025)', 24,
         (SELECT COUNT(*) FROM dim_date WHERE is_complete_year = 1)
  UNION ALL SELECT 'K16', 'BYD full year 2024 (Dec published YTD)', 5415,
         (SELECT registrations_ytd FROM fact_brand_month WHERE brand = 'BYD' AND date_key = '2024-12-01')
  UNION ALL SELECT 'K17', 'BYD full year 2025 (Dec published YTD)', 13533,
         (SELECT registrations_ytd FROM fact_brand_month WHERE brand = 'BYD' AND date_key = '2025-12-01')
  UNION ALL SELECT 'K18', 'BYD Jan-Oct 2025 (published YTD)', 9843,
         (SELECT registrations_ytd FROM fact_brand_month WHERE brand = 'BYD' AND date_key = '2025-10-01')
  UNION ALL SELECT 'K19', 'BYD Jan-Oct 2026 (published YTD)', 28086,
         (SELECT registrations_ytd FROM fact_brand_month WHERE brand = 'BYD' AND date_key = '2026-10-01')
  UNION ALL SELECT 'K20', 'Market full year 2025 (Dec published YTD)', 1632154,
         (SELECT market_registrations_ytd FROM fact_market_month WHERE date_key = '2025-12-01')
  UNION ALL SELECT 'K21', 'Market Jan-Oct 2026 (published YTD)', 1384293,
         (SELECT market_registrations_ytd FROM fact_market_month WHERE date_key = '2026-10-01')
  UNION ALL SELECT 'K22', 'Xpeng months with figures (listed from Mar 2025)', 20,
         (SELECT COUNT(registrations_month) FROM fact_brand_month WHERE brand = 'Xpeng')
)
SELECT id, check_name, expected, actual,
       CASE WHEN actual = expected THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY id;
