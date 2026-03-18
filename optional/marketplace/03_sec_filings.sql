-- SEC Filings: Links regulations to related SEC filings (8-K, 10-K, 10-Q)
-- Finds filings within 3 months of regulation publication date

CREATE OR REPLACE DYNAMIC TABLE REG_INTEL.ANALYTICS.DT_REG_SEC_FILINGS
  TARGET_LAG = '1 day'
  WAREHOUSE = COMPUTE_WH
AS
SELECT 
  ce.document_number,
  ce.regulation_title,
  ce.regulatory_category,
  ce.publication_date AS regulation_date,
  sf.CIK,
  sf.COMPANY_NAME AS filing_company,
  sf.FORM_TYPE,
  sf.FILED_DATE,
  sf.FISCAL_YEAR,
  sf.FISCAL_PERIOD,
  ce.PRIMARY_TICKER
FROM REG_INTEL.ANALYTICS.DT_COMPANY_EXPOSURE ce
JOIN SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.SEC_REPORT_INDEX sf
  ON ce.CIK = LPAD(sf.CIK, 10, '0')
WHERE sf.FILED_DATE >= DATEADD(month, -3, ce.publication_date)
  AND sf.FILED_DATE <= DATEADD(month, 3, ce.publication_date)
  AND sf.FORM_TYPE IN ('8-K', '10-K', '10-Q');
