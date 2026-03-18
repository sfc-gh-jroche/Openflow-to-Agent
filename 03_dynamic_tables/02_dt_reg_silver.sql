-- DT_REG_SILVER: AI-enriched regulation documents

CREATE OR REPLACE DYNAMIC TABLE REG_INTEL.CURATED.DT_REG_SILVER
  TARGET_LAG = DOWNSTREAM
  WAREHOUSE = COMPUTE_WH
  COMMENT = 'Silver layer: AI-enriched regulation documents'
AS
SELECT 
  document_number,
  title,
  abstract,
  regulation_type,
  publication_date,
  agencies_json,
  html_url,
  pdf_url,
  _ingested_at,
  agencies_json[0]:name::STRING AS agency_name,
  SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large2',
    'Summarize this regulation abstract in 2 sentences: ' || COALESCE(abstract, 'No abstract available')
  ) AS summary,
  TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.COMPLETE(
      'mistral-large2',
      'Extract from this text and return ONLY valid JSON with keys "industry", "affected_parties", "compliance_deadline". If not found, use null. Text: ' || COALESCE(abstract, 'No abstract')
    )
  ) AS extracted_entities,
  SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
    COALESCE(abstract, 'general'),
    ['environment', 'finance', 'healthcare', 'transportation', 'technology', 'labor', 'other']
  ):label::STRING AS primary_topic
FROM REG_INTEL.CURATED.DT_REG_BRONZE;
