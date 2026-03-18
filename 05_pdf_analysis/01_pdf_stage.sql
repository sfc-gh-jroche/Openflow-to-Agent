-- PDF Stage: Server-side encrypted stage for regulation PDFs
-- IMPORTANT: Must use SNOWFLAKE_SSE for AI_COMPLETE compatibility

CREATE OR REPLACE STAGE REG_INTEL.RAW.REGULATION_PDFS
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'Stage for regulation PDF documents - used for on-demand AI analysis';

-- Grant Openflow role access to upload PDFs
GRANT READ, WRITE ON STAGE REG_INTEL.RAW.REGULATION_PDFS TO ROLE OPENFLOW_REGINTEL_ROLE;

-- Manual upload (if needed):
-- PUT file:///path/to/2026-XXXXX.pdf @REG_INTEL.RAW.REGULATION_PDFS;
