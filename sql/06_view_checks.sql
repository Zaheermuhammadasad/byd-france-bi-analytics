-- =====================================================================
-- BYD France BI · Phase 4 · 06_view_checks.sql       (MySQL 8.0)
-- Verifies the views against the figures validated in Notebook 03.
-- Every row must return 'PASS'. Tolerance covers rounding only.
--   mysql -t byd_france < 06_view_checks.sql
-- =====================================================================

USE byd_france;

WITH checks AS (
  SELECT 'V01' AS id, 'BYD growth Jan-Oct 2026 vs 2025 (%)' AS check_name, 185.3 AS expected, 0.05 AS tolerance,
         (SELECT growth_pct FROM v_brand_period WHERE brand = 'BYD' AND period_type = 'jan_oct' AND year = 2026) AS actual
  UNION ALL SELECT 'V02', 'BYD growth FY 2025 vs FY 2024 (%)', 149.9, 0.05,
         (SELECT growth_pct FROM v_brand_period WHERE brand = 'BYD' AND period_type = 'full_year' AND year = 2025)
  UNION ALL SELECT 'V03', 'BYD share Jan-Oct 2026 (%)', 2.03, 0.005,
         (SELECT share_pct FROM v_brand_period WHERE brand = 'BYD' AND period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V04', 'BYD rank Jan-Oct 2026', 16, 0,
         (SELECT rank_in_period FROM v_brand_period WHERE brand = 'BYD' AND period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V05', 'Brands ranked Jan-Oct 2026 (AUTRES excluded)', 44, 0,
         (SELECT brands_ranked FROM v_brand_period WHERE brand = 'BYD' AND period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V06', 'BYD rank Jan-Oct 2024', 32, 0,
         (SELECT rank_in_period FROM v_brand_period WHERE brand = 'BYD' AND period_type = 'jan_oct' AND year = 2024)
  UNION ALL SELECT 'V07', 'BYD monthly rank Jan 2024', 29, 0,
         (SELECT rank_month FROM v_brand_rank_month WHERE brand = 'BYD' AND period = '2024-01')
  UNION ALL SELECT 'V08', 'BYD monthly rank Oct 2026', 7, 0,
         (SELECT rank_month FROM v_brand_rank_month WHERE brand = 'BYD' AND period = '2026-10')
  UNION ALL SELECT 'V09', 'BYD monthly share Oct 2026 (%)', 3.63, 0.005,
         (SELECT share_month_pct FROM v_brand_month WHERE brand = 'BYD' AND period = '2026-10')
  UNION ALL SELECT 'V10', 'Market growth Jan-Oct 2026 vs 2025 (%)', 4.37, 0.005,
         (SELECT market_registrations_ytd * 100.0
                 / (SELECT market_registrations_ytd FROM v_market_month WHERE period = '2025-10') - 100
          FROM v_market_month WHERE period = '2026-10')
  UNION ALL SELECT 'V11', 'August seasonality index (2024-25 average)', 62, 0.5,
         (SELECT AVG(seasonality_index) FROM v_market_month WHERE month = 8 AND is_complete_year = 1)
  UNION ALL SELECT 'V12', 'Tesla growth Jan-Oct 2026 (%)', 117.1, 0.05,
         (SELECT growth_pct FROM v_brand_period WHERE brand = 'Tesla' AND period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V13', 'MG growth Jan-Oct 2026 (%)', 23.7, 0.05,
         (SELECT growth_pct FROM v_brand_period WHERE brand = 'MG' AND period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V14', 'Leapmotor growth Jan-Oct 2026 (%)', 172.6, 0.05,
         (SELECT growth_pct FROM v_brand_period WHERE brand = 'Leapmotor' AND period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V15', 'Xpeng growth Jan-Oct 2026 (%)', 154.1, 0.05,
         (SELECT growth_pct FROM v_brand_period WHERE brand = 'Xpeng' AND period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V16', 'Xpeng Jan-Oct 2025 growth is NULL (no 2024 figure; 1 = yes)', 1, 0,
         (SELECT CASE WHEN growth_pct IS NULL THEN 1 ELSE 0 END FROM v_brand_period
          WHERE brand = 'Xpeng' AND period_type = 'jan_oct' AND year = 2025)
  UNION ALL SELECT 'V17', 'Chinese-owned share FY 2024 (%)', 2.95, 0.005,
         (SELECT cn_share_lower_pct FROM v_chinese_owned_period WHERE period_type = 'full_year' AND year = 2024)
  UNION ALL SELECT 'V18', 'Chinese-owned share FY 2025 (%)', 4.20, 0.005,
         (SELECT cn_share_lower_pct FROM v_chinese_owned_period WHERE period_type = 'full_year' AND year = 2025)
  UNION ALL SELECT 'V19', 'Chinese-owned share Jan-Oct 2026 (%)', 7.07, 0.005,
         (SELECT cn_share_lower_pct FROM v_chinese_owned_period WHERE period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V20', 'Chinese-owned brands counted Jan-Oct 2026', 11, 0,
         (SELECT cn_brands_counted FROM v_chinese_owned_period WHERE period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V21', 'Chinese-origin only share Jan-Oct 2026 (%)', 4.21, 0.005,
         (SELECT cn_origin_share_pct FROM v_chinese_owned_period WHERE period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V22', 'BYD part of Chinese-owned volume FY 2024 (%)', 10.7, 0.05,
         (SELECT byd_part_of_cn_pct FROM v_chinese_owned_period WHERE period_type = 'full_year' AND year = 2024)
  UNION ALL SELECT 'V23', 'BYD part of Chinese-owned volume Jan-Oct 2026 (%)', 28.7, 0.05,
         (SELECT byd_part_of_cn_pct FROM v_chinese_owned_period WHERE period_type = 'jan_oct' AND year = 2026)
  UNION ALL SELECT 'V24', 'Months where lower bound > upper bound', 0, 0,
         (SELECT COUNT(*) FROM v_chinese_owned_month WHERE cn_share_lower_pct > cn_share_upper_pct)
  UNION ALL SELECT 'V25', 'Months where upper - lower <> AUTRES share', 0, 0,
         (SELECT COUNT(*) FROM v_chinese_owned_month
          WHERE ABS(cn_share_upper_pct - cn_share_lower_pct - autres_share_pct) > 0.000001 OR autres_share_pct IS NULL)
  UNION ALL SELECT 'V26', 'Brands with >= 5 000 regs Jan-Oct 2025', 28, 0,
         (SELECT COUNT(*) FROM v_brand_period WHERE period_type = 'jan_oct' AND year = 2026
          AND is_residual = 0 AND registrations_prev_year >= 5000)
  UNION ALL SELECT 'V27', 'Monthly ranking rows with missing registrations', 0, 0,
         (SELECT COUNT(*) FROM v_brand_rank_month WHERE registrations_month IS NULL)
  UNION ALL SELECT 'V28', 'Universe rows in v_brand_month (in_market_sum = 1, incl. AUTRES)', 1408, 0,
         (SELECT COUNT(*) FROM v_brand_month)
)
SELECT id, check_name, expected, ROUND(actual, 3) AS actual,
       CASE WHEN actual IS NOT NULL AND ABS(actual - expected) <= tolerance THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY id;
