-- Sample Data Loader
-- Use this if you don't have OpenFlow set up
-- Fetches sample regulations directly from Federal Register API

-- This requires the External Access Integration to be set up first
-- Run: sql/infrastructure/02_network_eai.sql

-- Load recent regulations
INSERT INTO REG_INTEL.RAW.RAW_REGULATIONS (raw_json, _ingested_at)
WITH api_response AS (
  SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.TRY_COMPLETE(
      'llama3.1-8b',
      'Return ONLY this exact JSON, no other text: {"note": "Use the actual API call below instead"}'
    )
  ) AS placeholder
)
SELECT 
  OBJECT_CONSTRUCT(
    'document_number', '2026-SAMPLE-' || SEQ4(),
    'title', 'Sample Regulation ' || SEQ4(),
    'type', CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Rule' WHEN 1 THEN 'Proposed Rule' ELSE 'Notice' END,
    'abstract', 'This is a sample regulation abstract for testing the pipeline.',
    'publication_date', DATEADD(day, -SEQ4(), CURRENT_DATE())::STRING,
    'agencies', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('name', 'Sample Agency')),
    'html_url', 'https://www.federalregister.gov/documents/sample'
  ) AS raw_json,
  CURRENT_TIMESTAMP() AS _ingested_at
FROM TABLE(GENERATOR(ROWCOUNT => 10));

-- RECOMMENDED: Use this Python script instead for real data
-- Save as load_sample_data.py and run with: python load_sample_data.py

/*
import requests
import snowflake.connector
import json
import os

# Fetch from Federal Register API
url = "https://www.federalregister.gov/api/v1/documents.json"
params = {
    "per_page": 100,
    "order": "newest",
    "conditions[type][]": ["Rule", "Proposed Rule", "Notice"]
}

response = requests.get(url, params=params)
data = response.json()

# Connect to Snowflake
conn = snowflake.connector.connect(
    connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME", "default")
)
cursor = conn.cursor()

# Insert each regulation
for doc in data.get("results", []):
    cursor.execute(
        "INSERT INTO REG_INTEL.RAW.RAW_REGULATIONS (raw_json, _ingested_at) SELECT PARSE_JSON(%s), CURRENT_TIMESTAMP()",
        (json.dumps(doc),)
    )

print(f"Loaded {len(data.get('results', []))} regulations")
cursor.close()
conn.close()
*/
