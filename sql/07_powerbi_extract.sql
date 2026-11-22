-- =====================================================================
-- BYD France BI · Phase 7 · 07_powerbi_extract.sql   (MySQL 8.0)
-- The exact queries that produce the four CSVs in data/powerbi/.
-- Run after 01-04 (schema, load, checks, views). Save each result as CSV
-- with a header row, comma separator, '.' decimal point, and empty cells
-- for NULL (MySQL Workbench: Export > CSV, or mysql -B piped through a
-- tab-to-comma conversion).
-- Then run: python scripts/validate_project.py --powerbi data/powerbi
-- =====================================================================

USE byd_france;

-- dim_date.csv  (34 rows)
SELECT date_key, period, year, month, month_name, quarter, months_in_data, is_complete_year
FROM dim_date
ORDER BY date_key;

-- dim_brand.csv  (51 rows, is_residual flags the AUTRES residual group)
SELECT brand, brand_origin_country, controlling_owner, controlling_owner_country, ownership_structure,
       is_chinese_owned, is_chinese_origin, is_joint_venture, is_byd,
       CASE WHEN brand = 'Other brands (AUTRES)' THEN 1 ELSE 0 END AS is_residual
FROM dim_brand
ORDER BY brand;

-- v_brand_month.csv  (1 408 rows: comparison universe only)
SELECT date_key, brand, registrations_month, registrations_ytd, value_type, source_id
FROM v_brand_month
ORDER BY date_key, brand;

-- v_market_month.csv  (34 rows)
SELECT date_key, market_registrations_month, market_registrations_ytd,
       market_same_month_prev_year, market_yoy_pct, seasonality_index
FROM v_market_month
ORDER BY date_key;
