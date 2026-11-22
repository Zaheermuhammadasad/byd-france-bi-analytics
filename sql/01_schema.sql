-- =====================================================================
-- BYD France BI · Phase 4 · 01_schema.sql            (MySQL 8.0.16+)
-- Star schema for the validated Phase 2 v2 datasets.
--
--   dim_brand  (51)     dim_date (34)
--        \               /
--      fact_brand_month (1 734 = 34 months x 51 brands)
--                 |
--      fact_market_month (34)   <- market totals, one row per month
--
-- Design rules
--   * Missing stays missing: registrations are NULL when CCFA did not list
--     the brand that month (value_type = 'not_listed'). Never 0.
--   * The market total lives only in fact_market_month (not repeated on
--     every brand row); join on date_key when a share is needed.
--   * CHECK constraints encode the Phase 2 rules, so bad rows are rejected.
-- Re-running this script drops and rebuilds everything.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS byd_france
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE byd_france;

DROP TABLE IF EXISTS fact_brand_month;
DROP TABLE IF EXISTS fact_market_month;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_brand;

-- ---------------------------------------------------------------------
-- dim_brand: one row per brand label used in the CCFA tables
-- ---------------------------------------------------------------------
CREATE TABLE dim_brand (
  brand                      VARCHAR(40)  NOT NULL,
  brand_origin_country       VARCHAR(40)  NULL,      -- NULL only for AUTRES (residual group)
  controlling_owner          VARCHAR(80)  NULL,
  controlling_owner_country  VARCHAR(40)  NULL,
  ownership_structure        VARCHAR(40)  NULL,
  is_chinese_owned           BOOLEAN      NOT NULL,  -- controlling owner (>50% / sole control) HQ in China
  is_chinese_origin          BOOLEAN      NOT NULL,  -- brand heritage, separate from ownership
  is_joint_venture           BOOLEAN      NOT NULL,
  is_byd                     BOOLEAN      NOT NULL,
  classification_note        VARCHAR(255) NULL,
  classification_rule        VARCHAR(255) NOT NULL,
  PRIMARY KEY (brand)
);

-- ---------------------------------------------------------------------
-- dim_date: one row per reporting month (CCFA publishes monthly)
-- ---------------------------------------------------------------------
CREATE TABLE dim_date (
  date_key          DATE        NOT NULL,   -- first day of the month
  period            CHAR(7)     NOT NULL,   -- 'YYYY-MM'
  year              SMALLINT    NOT NULL,
  month             TINYINT     NOT NULL,
  month_name        CHAR(3)     NOT NULL,
  quarter           TINYINT     NOT NULL,
  months_in_data    TINYINT     NOT NULL,   -- months of that year present in the dataset
  is_complete_year  BOOLEAN     NOT NULL,   -- TRUE for 2024 and 2025; FALSE for 2026 (Jan-Oct)
  PRIMARY KEY (date_key),
  UNIQUE KEY uq_period (period),
  CONSTRAINT chk_month CHECK (month BETWEEN 1 AND 12),
  CONSTRAINT chk_first_day CHECK (DAY(date_key) = 1)
);

-- Generate Jan 2024 .. Oct 2026 with a recursive CTE (no hard-coded rows).
INSERT INTO dim_date (date_key, period, year, month, month_name, quarter, months_in_data, is_complete_year)
WITH RECURSIVE m AS (
  SELECT DATE('2024-01-01') AS d
  UNION ALL
  SELECT d + INTERVAL 1 MONTH FROM m WHERE d < '2026-10-01'
)
SELECT d,
       DATE_FORMAT(d, '%Y-%m'),
       YEAR(d),
       MONTH(d),
       DATE_FORMAT(d, '%b'),
       QUARTER(d),
       COUNT(*) OVER (PARTITION BY YEAR(d)),
       COUNT(*) OVER (PARTITION BY YEAR(d)) = 12
FROM m;

-- ---------------------------------------------------------------------
-- fact_market_month: CCFA total French new passenger-car registrations
-- ---------------------------------------------------------------------
CREATE TABLE fact_market_month (
  date_key                    DATE         NOT NULL,
  market_registrations_month  INT          NOT NULL,
  market_registrations_ytd    INT          NOT NULL,   -- CCFA published YTD (never re-summed)
  ytd_revision_gap            INT          NULL,       -- published YTD - (previous YTD + month)
  value_type                  VARCHAR(12)  NOT NULL,
  source_id                   VARCHAR(10)  NOT NULL,   -- -> docs/source_register.csv
  source_file                 VARCHAR(80)  NOT NULL,
  PRIMARY KEY (date_key),
  CONSTRAINT fk_mkt_date FOREIGN KEY (date_key) REFERENCES dim_date (date_key),
  CONSTRAINT chk_mkt_positive CHECK (market_registrations_month > 0 AND market_registrations_ytd > 0)
);

-- ---------------------------------------------------------------------
-- fact_brand_month: one row per brand per month (grain = date_key x brand)
-- ---------------------------------------------------------------------
CREATE TABLE fact_brand_month (
  date_key             DATE          NOT NULL,
  brand                VARCHAR(40)   NOT NULL,
  brand_label          VARCHAR(40)   NULL,       -- label exactly as printed by CCFA
  registrations_month  INT           NULL,       -- NULL = not listed (unknown), never 0
  registrations_ytd    INT           NULL,       -- CCFA published YTD
  ytd_revision_gap     INT           NULL,
  share_month_pct      DECIMAL(6,3)  NULL,       -- CCFA published share, %
  share_ytd_pct        DECIMAL(6,3)  NULL,
  value_type           VARCHAR(12)   NOT NULL,   -- least reliable of the two below
  value_type_month     VARCHAR(12)   NOT NULL,
  value_type_ytd       VARCHAR(12)   NOT NULL,
  listed_in_source     BOOLEAN       NOT NULL,
  in_market_sum        BOOLEAN       NOT NULL,   -- TRUE = part of the comparison universe
  source_id            VARCHAR(10)   NOT NULL,
  source_file          VARCHAR(80)   NOT NULL,
  note                 VARCHAR(255)  NULL,
  PRIMARY KEY (date_key, brand),
  KEY ix_brand (brand),
  KEY ix_universe (in_market_sum, date_key),
  CONSTRAINT fk_fbm_date  FOREIGN KEY (date_key) REFERENCES dim_date (date_key),
  CONSTRAINT fk_fbm_brand FOREIGN KEY (brand)    REFERENCES dim_brand (brand),
  CONSTRAINT chk_value_type CHECK (
        value_type       IN ('actual','aggregated','imputed','not_listed')
    AND value_type_month IN ('actual','aggregated','imputed','not_listed')
    AND value_type_ytd   IN ('actual','aggregated','imputed','not_listed')),
  -- missing stays missing: not_listed <=> no registration figures
  CONSTRAINT chk_not_listed_is_null CHECK (
        (value_type =  'not_listed' AND registrations_month IS NULL AND registrations_ytd IS NULL AND share_month_pct IS NULL)
     OR (value_type <> 'not_listed' AND registrations_month IS NOT NULL)),
  CONSTRAINT chk_universe_listed CHECK (in_market_sum = FALSE OR value_type <> 'not_listed'),
  CONSTRAINT chk_non_negative CHECK (registrations_month >= 0 AND registrations_ytd >= 0)
);
