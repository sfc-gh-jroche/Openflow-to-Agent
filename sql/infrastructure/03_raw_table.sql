-- RAW_REGULATIONS landing table for OpenFlow ingestion

CREATE OR REPLACE TABLE REG_INTEL.RAW.RAW_REGULATIONS (
    raw_json VARIANT,
    _ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file STRING
)
COMMENT = 'Landing table for Federal Register API JSON responses';
