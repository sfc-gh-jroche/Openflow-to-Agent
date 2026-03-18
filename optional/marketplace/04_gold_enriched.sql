-- Gold Enriched: Adds company/filing counts to gold table for dashboard
-- This is the main table used by the Streamlit dashboard

CREATE OR REPLACE DYNAMIC TABLE REG_INTEL.ANALYTICS.DT_REG_GOLD_ENRICHED
  TARGET_LAG = '1 day'
  WAREHOUSE = COMPUTE_WH
AS
WITH company_stats AS (
  SELECT 
    document_number,
    COUNT(DISTINCT company_id) AS affected_company_count,
    ARRAY_AGG(DISTINCT PRIMARY_TICKER) WITHIN GROUP (ORDER BY PRIMARY_TICKER) AS top_tickers
  FROM REG_INTEL.ANALYTICS.DT_COMPANY_EXPOSURE
  GROUP BY document_number
),
filing_stats AS (
  SELECT 
    document_number,
    COUNT(*) AS related_filing_count
  FROM REG_INTEL.ANALYTICS.DT_REG_SEC_FILINGS
  GROUP BY document_number
)
SELECT 
  g.*,
  COALESCE(cs.affected_company_count, 0) AS affected_company_count,
  COALESCE(fs.related_filing_count, 0) AS related_filing_count,
  ARRAY_SLICE(cs.top_tickers, 0, 10) AS top_affected_tickers
FROM REG_INTEL.ANALYTICS.DT_REG_GOLD g
LEFT JOIN company_stats cs ON g.document_number = cs.document_number
LEFT JOIN filing_stats fs ON g.document_number = fs.document_number;
