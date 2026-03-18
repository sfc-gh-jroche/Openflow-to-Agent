-- Openflow Runtime Role for Regulatory Intelligence
-- Run this BEFORE creating the Openflow runtime in the UI

CREATE ROLE IF NOT EXISTS OPENFLOW_REGINTEL_ROLE 
  COMMENT = 'Openflow runtime role for Regulatory Intelligence platform';

-- Grant access to target database/schema
GRANT USAGE ON DATABASE REG_INTEL TO ROLE OPENFLOW_REGINTEL_ROLE;
GRANT USAGE ON SCHEMA REG_INTEL.RAW TO ROLE OPENFLOW_REGINTEL_ROLE;

-- Grant access to landing table (for JSON ingestion)
GRANT INSERT, SELECT ON TABLE REG_INTEL.RAW.RAW_REGULATIONS TO ROLE OPENFLOW_REGINTEL_ROLE;

-- Grant access to PDF stage (for document ingestion)
-- Note: Run sql/pdf_analysis/01_pdf_stage.sql first if you want PDF ingestion
GRANT READ, WRITE ON STAGE REG_INTEL.RAW.REGULATION_PDFS TO ROLE OPENFLOW_REGINTEL_ROLE;

-- Grant access to External Access Integration (for Federal Register API)
GRANT USAGE ON INTEGRATION REG_INTEL_FEDERAL_REGISTER_EAI TO ROLE OPENFLOW_REGINTEL_ROLE;

-- Grant warehouse for Snowpipe Streaming
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE OPENFLOW_REGINTEL_ROLE;

-- Grant role to your admin role so it appears in runtime creation UI
-- Uncomment and replace YOUR_ADMIN_ROLE with your actual admin role:
-- GRANT ROLE OPENFLOW_REGINTEL_ROLE TO ROLE YOUR_ADMIN_ROLE;

-- Or grant to yourself:
-- GRANT ROLE OPENFLOW_REGINTEL_ROLE TO USER CURRENT_USER();
