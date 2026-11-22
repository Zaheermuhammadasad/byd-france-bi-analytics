-- =====================================================================
-- BYD France BI · Phase 4 · 02_load.sql              (MySQL 8.0)
-- Loads the three validated Phase 2 v2 CSVs (unchanged) into the schema.
--
-- Run from the folder that holds the CSVs, with LOCAL INFILE enabled:
--   mysql --local-infile=1 byd_france < 02_load.sql
--
-- Conversion rules
--   * Empty CSV field  -> NULL  (NULLIF(@x, '')). Never 0.
--   * '105.0' (pandas float export) -> 105 via DECIMAL, exact because every
--     count is a whole number (checked in Phase 2).
--   * 'True' / 'False' -> 1 / 0.
-- IMPORTANT: LOAD DATA LOCAL turns data errors into WARNINGS and skips the
-- bad row instead of failing. So each load is followed by a warning count,
-- and 03_checks.sql verifies every row count. Expected warnings: 0.
-- =====================================================================

USE byd_france;
SET FOREIGN_KEY_CHECKS = 1;

-- Remove previously loaded facts so the script can be re-run safely (dim_date is kept).
DELETE FROM fact_brand_month;
DELETE FROM fact_market_month;
DELETE FROM dim_brand;

-- ---------------------------------------------------------------- dim_brand
LOAD DATA LOCAL INFILE 'dim_brand.csv'
INTO TABLE dim_brand
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(brand, @origin, @owner, @owner_country, @structure,
 @cn_owned, @cn_origin, @jv, @is_byd, @note, classification_rule)
SET brand_origin_country      = NULLIF(@origin, ''),
    controlling_owner         = NULLIF(@owner, ''),
    controlling_owner_country = NULLIF(@owner_country, ''),
    ownership_structure       = NULLIF(@structure, ''),
    is_chinese_owned          = (@cn_owned  = 'True'),
    is_chinese_origin         = (@cn_origin = 'True'),
    is_joint_venture          = (@jv        = 'True'),
    is_byd                    = (@is_byd    = 'True'),
    classification_note       = NULLIF(@note, '');
SELECT 'dim_brand' AS loaded_table, ROW_COUNT() AS rows_loaded, @@warning_count AS warnings;

-- -------------------------------------------------------- fact_market_month
LOAD DATA LOCAL INFILE 'market_month.csv'
INTO TABLE fact_market_month
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@period, @date, @year, @month, @mkt_m, @mkt_ytd, @gap, value_type, source_id, source_file)
SET date_key                   = @date,
    market_registrations_month = CAST(@mkt_m   AS DECIMAL(12,1)),
    market_registrations_ytd   = CAST(@mkt_ytd AS DECIMAL(12,1)),
    ytd_revision_gap           = CAST(NULLIF(@gap, '') AS DECIMAL(12,1));
SELECT 'fact_market_month' AS loaded_table, ROW_COUNT() AS rows_loaded, @@warning_count AS warnings;

-- --------------------------------------------------------- fact_brand_month
-- The CSV also carries period/year/month and the market totals; they are
-- read into variables and not stored (dim_date and fact_market_month hold them).
LOAD DATA LOCAL INFILE 'brand_month.csv'
INTO TABLE fact_brand_month
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@period, @date, @year, @month, brand, @label, @reg_m, @reg_ytd, @gap,
 @mkt_m, @mkt_ytd, @sh_m, @sh_ytd, value_type, value_type_month, value_type_ytd,
 @listed, @in_sum, source_id, source_file, @note)
SET date_key            = @date,
    brand_label         = NULLIF(@label, ''),
    registrations_month = CAST(NULLIF(@reg_m,   '') AS DECIMAL(12,1)),
    registrations_ytd   = CAST(NULLIF(@reg_ytd, '') AS DECIMAL(12,1)),
    ytd_revision_gap    = CAST(NULLIF(@gap,     '') AS DECIMAL(12,1)),
    share_month_pct     = NULLIF(@sh_m,   ''),
    share_ytd_pct       = NULLIF(@sh_ytd, ''),
    listed_in_source    = (@listed = 'True'),
    in_market_sum       = (@in_sum = 'True'),
    note                = NULLIF(@note, '');
SELECT 'fact_brand_month' AS loaded_table, ROW_COUNT() AS rows_loaded, @@warning_count AS warnings;
