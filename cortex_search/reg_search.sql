-- REG_SEARCH: Cortex Search Service for semantic regulation search

CREATE OR REPLACE CORTEX SEARCH SERVICE REG_INTEL.ANALYTICS.REG_SEARCH
  ON abstract
  ATTRIBUTES agency_name, regulation_type, primary_topic, publication_date
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Semantic search over regulation abstracts'
AS 
SELECT 
  document_number, 
  title, 
  abstract, 
  summary,
  agency_name, 
  regulation_type, 
  primary_topic, 
  publication_date
FROM REG_INTEL.CURATED.DT_REG_SILVER;
