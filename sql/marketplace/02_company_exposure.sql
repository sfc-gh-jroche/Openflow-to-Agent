-- Company Exposure: Links regulations to affected companies via industry mapping
-- Joins regulation categories to SEC industry groups to company data

CREATE OR REPLACE DYNAMIC TABLE REG_INTEL.ANALYTICS.DT_COMPANY_EXPOSURE
  TARGET_LAG = '1 day'
  WAREHOUSE = COMPUTE_WH
AS
SELECT 
  g.document_number,
  g.title AS regulation_title,
  g.regulatory_category,
  g.publication_date,
  ci.COMPANY_ID,
  ci.COMPANY_NAME,
  ci.PRIMARY_TICKER,
  ci.PRIMARY_EXCHANGE_CODE,
  ci.CIK,
  ir.sec_industry_group
FROM REG_INTEL.ANALYTICS.DT_REG_GOLD g
JOIN REG_INTEL.CURATED.DT_INDUSTRY_REFERENCE ir 
  ON g.regulatory_category = ir.regulatory_category
JOIN SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.COMPANY_CHARACTERISTICS cc
  ON cc.VALUE = ir.sec_industry_group 
  AND cc.RELATIONSHIP_TYPE = 'sec_industry_group'
JOIN SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.COMPANY_INDEX ci
  ON cc.COMPANY_ID = ci.COMPANY_ID
WHERE g.document_number IS NOT NULL
  AND ci.PRIMARY_TICKER IS NOT NULL;
