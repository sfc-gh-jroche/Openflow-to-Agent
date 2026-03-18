-- Network Rule and External Access Integration for Federal Register API

CREATE OR REPLACE NETWORK RULE REG_INTEL.RAW.FEDERAL_REGISTER_NETWORK_RULE
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = ('api.federalregister.gov:443', 'www.federalregister.gov:443', 'www.govinfo.gov:443')
  COMMENT = 'Allow Openflow to access Federal Register API and PDF downloads from govinfo.gov';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION REG_INTEL_FEDERAL_REGISTER_EAI
  ALLOWED_NETWORK_RULES = (REG_INTEL.RAW.FEDERAL_REGISTER_NETWORK_RULE)
  ENABLED = TRUE
  COMMENT = 'External access for Federal Register API ingestion via Openflow';
