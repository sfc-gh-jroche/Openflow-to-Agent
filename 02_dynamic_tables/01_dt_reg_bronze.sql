-- DT_REG_BRONZE: Parse raw JSON from Federal Register API

CREATE OR REPLACE DYNAMIC TABLE REG_INTEL.CURATED.DT_REG_BRONZE
  TARGET_LAG = DOWNSTREAM
  WAREHOUSE = COMPUTE_WH
  COMMENT = 'Bronze layer: parsed regulation documents from raw JSON'
AS
SELECT 
  r.value:document_number::STRING AS document_number,
  r.value:title::STRING AS title,
  r.value:abstract::STRING AS abstract,
  r.value:type::STRING AS regulation_type,
  r.value:publication_date::DATE AS publication_date,
  r.value:agencies AS agencies_json,
  r.value:html_url::STRING AS html_url,
  r.value:pdf_url::STRING AS pdf_url,
  raw._ingested_at
FROM REG_INTEL.RAW.RAW_REGULATIONS raw,
  LATERAL FLATTEN(input => raw.raw_json:results) r;
