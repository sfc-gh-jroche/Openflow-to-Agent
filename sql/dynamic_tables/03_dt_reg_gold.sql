-- DT_REG_GOLD: Pre-aggregated regulation analytics

CREATE OR REPLACE DYNAMIC TABLE REG_INTEL.ANALYTICS.DT_REG_GOLD
  TARGET_LAG = '1 hour'
  WAREHOUSE = COMPUTE_WH
  COMMENT = 'Gold layer: pre-aggregated regulation analytics'
AS
SELECT 
  publication_date,
  regulation_type,
  primary_topic,
  agency_name,
  COUNT(*) AS regulation_count,
  ARRAY_AGG(OBJECT_CONSTRUCT(
    'document_number', document_number,
    'title', title, 
    'summary', summary
  )) AS regulations
FROM REG_INTEL.CURATED.DT_REG_SILVER
GROUP BY ALL;
