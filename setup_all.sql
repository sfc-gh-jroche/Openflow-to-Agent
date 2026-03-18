-- ============================================================================
-- REGULATORY INTELLIGENCE PLATFORM - COMPLETE SETUP
-- ============================================================================
-- This script runs ALL required SQL in the correct order.
-- Run in Snowsight: Open this file in Workspaces → Run All
--
-- Prerequisites:
--   - ACCOUNTADMIN or equivalent privileges
--   - Cortex AI functions enabled in your account
--
-- Optional (install separately):
--   - Marketplace data: Run scripts in optional/marketplace/
--   - Openflow: See optional/openflow/README.md
--   - Streamlit: See optional/streamlit/
-- ============================================================================


-- ============================================================================
-- SECTION 1: INFRASTRUCTURE (01_infrastructure/)
-- ============================================================================

-- 1.1 Database Setup
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

CREATE DATABASE IF NOT EXISTS REG_INTEL COMMENT = 'Regulatory Intelligence Platform';

CREATE SCHEMA IF NOT EXISTS REG_INTEL.RAW COMMENT = 'Landing zone for raw JSON';
CREATE SCHEMA IF NOT EXISTS REG_INTEL.CURATED COMMENT = 'Dynamic tables pipeline';
CREATE SCHEMA IF NOT EXISTS REG_INTEL.ANALYTICS COMMENT = 'Cortex services, semantic view, agent';

-- 1.2 Network Rule and External Access Integration
CREATE OR REPLACE NETWORK RULE REG_INTEL.RAW.FEDERAL_REGISTER_NETWORK_RULE
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = ('api.federalregister.gov:443', 'www.federalregister.gov:443', 'www.govinfo.gov:443')
  COMMENT = 'Allow Openflow to access Federal Register API and PDF downloads from govinfo.gov';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION REG_INTEL_FEDERAL_REGISTER_EAI
  ALLOWED_NETWORK_RULES = (REG_INTEL.RAW.FEDERAL_REGISTER_NETWORK_RULE)
  ENABLED = TRUE
  COMMENT = 'External access for Federal Register API ingestion via Openflow';

-- 1.3 Raw Landing Table
CREATE OR REPLACE TABLE REG_INTEL.RAW.RAW_REGULATIONS (
    raw_json VARIANT,
    _ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file STRING
)
COMMENT = 'Landing table for Federal Register API JSON responses';

-- 1.4 PDF Stage (for optional PDF analysis)
CREATE OR REPLACE STAGE REG_INTEL.RAW.REGULATION_PDFS
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'Stage for regulation PDF documents - used for on-demand AI analysis';

-- 1.5 Openflow Role (run BEFORE creating Openflow runtime)
CREATE ROLE IF NOT EXISTS OPENFLOW_REGINTEL_ROLE 
  COMMENT = 'Openflow runtime role for Regulatory Intelligence platform';

GRANT USAGE ON DATABASE REG_INTEL TO ROLE OPENFLOW_REGINTEL_ROLE;
GRANT USAGE ON SCHEMA REG_INTEL.RAW TO ROLE OPENFLOW_REGINTEL_ROLE;
GRANT INSERT, SELECT ON TABLE REG_INTEL.RAW.RAW_REGULATIONS TO ROLE OPENFLOW_REGINTEL_ROLE;
GRANT READ, WRITE ON STAGE REG_INTEL.RAW.REGULATION_PDFS TO ROLE OPENFLOW_REGINTEL_ROLE;
GRANT USAGE ON INTEGRATION REG_INTEL_FEDERAL_REGISTER_EAI TO ROLE OPENFLOW_REGINTEL_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE OPENFLOW_REGINTEL_ROLE;


-- ============================================================================
-- SECTION 2: DYNAMIC TABLES PIPELINE (02_dynamic_tables/)
-- ============================================================================

-- 2.1 Bronze: Parse raw JSON
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

-- 2.2 Silver: AI enrichment
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

-- 2.3 Gold: Pre-aggregated analytics
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
    'summary', summary,
    'pdf_url', pdf_url
  )) AS regulations
FROM REG_INTEL.CURATED.DT_REG_SILVER
GROUP BY ALL;


-- ============================================================================
-- SECTION 3: SEARCH & ANALYTICS (03_search_analytics/)
-- ============================================================================

-- 3.1 Cortex Search Service
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

-- 3.2 Semantic View for Cortex Analyst
CREATE OR REPLACE SEMANTIC VIEW REG_INTEL.ANALYTICS.REG_ANALYTICS_VIEW
  TABLES (
    reg_gold AS REG_INTEL.ANALYTICS.DT_REG_GOLD
      PRIMARY KEY (publication_date, regulation_type, agency_name, primary_topic)
  )
  DIMENSIONS (
    reg_gold.publication_date AS publication_date COMMENT = 'Date the regulation was published',
    reg_gold.regulation_type AS regulation_type COMMENT = 'Type of regulation (Rule, Proposed Rule, Notice)',
    reg_gold.agency_name AS agency_name COMMENT = 'Federal agency that issued the regulation',
    reg_gold.primary_topic AS primary_topic COMMENT = 'AI-classified topic category'
  )
  METRICS (
    reg_gold.total_regulations AS SUM(reg_gold.regulation_count) COMMENT = 'Total number of regulations',
    reg_gold.unique_agencies AS COUNT(DISTINCT reg_gold.agency_name) COMMENT = 'Number of distinct agencies'
  )
  COMMENT = 'Semantic view for regulation analytics with Cortex Analyst';


-- ============================================================================
-- SECTION 4: PDF ANALYSIS (04_pdf_analysis/)
-- ============================================================================

-- 4.1 PDF Q&A Function
CREATE OR REPLACE FUNCTION REG_INTEL.ANALYTICS.ASK_REGULATION_PDF(
    doc_number STRING,
    question STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
    SELECT AI_COMPLETE(
        MODEL => 'claude-4-sonnet',
        PROMPT => PROMPT(
            'You are a regulatory compliance analyst. Answer this question about the Federal Register regulation: ' || question || '

Be specific and cite relevant sections when possible. If deadlines or dates are mentioned, highlight them clearly.

Document: {0}',
            TO_FILE('@REG_INTEL.RAW.REGULATION_PDFS', doc_number || '.pdf')
        )
    )::STRING
$$;


-- ============================================================================
-- SECTION 5: CORTEX AGENT (05_agent/)
-- ============================================================================

-- NOTE: If you have Snowflake Intelligence enabled, change the schema to
-- SNOWFLAKE_INTELLIGENCE.AGENTS for the agent to appear in the SI UI.

CREATE OR REPLACE AGENT REG_INTEL.ANALYTICS.REGULATORY_INTELLIGENCE
COMMENT = 'Regulatory Intelligence - Search regulations, analyze trends, find affected companies, SEC filings, and deep-dive into full PDF documents'
PROFILE = '{"display_name": "Regulatory Intelligence", "color": "blue"}'
FROM SPECIFICATION $$
models:
  orchestration: claude-4-sonnet
orchestration:
  budget:
    seconds: 180
    tokens: 40000
instructions:
  response: |
    Be specific and cite document numbers. Keep responses concise and actionable.
  orchestration: |
    ALWAYS use your tools to answer questions. Never answer from general knowledge.

    TOOL AVAILABILITY:
    - search_regulations: ALWAYS available
    - analyze_trends: ALWAYS available
    - get_full_regulation_text: Available if PDFs have been uploaded
    - get_industry_impact: OPTIONAL - requires Cybersyn marketplace data
    - get_related_filings: OPTIONAL - requires Cybersyn marketplace data

    ROUTING RULES (follow strictly):
    
    1. DISCOVERY questions ("show me regulations about X", "find rules related to Y"):
       → Use search_regulations
    
    2. STATISTICS questions ("how many", "count", "trends", "compare agencies"):
       → Use analyze_trends
    
    3. COMPANY IMPACT questions ("which companies", "who is affected", "what tickers"):
       → Try get_industry_impact
       → If it fails, explain: "Company impact analysis requires the optional Cybersyn SEC Filings marketplace data. See optional/marketplace/ in the repo to enable this feature."
    
    4. SEC FILINGS questions ("what did they file", "10-K", "8-K", "filings"):
       → Try get_related_filings
       → If it fails, explain: "SEC filings lookup requires the optional Cybersyn SEC Filings marketplace data. See optional/marketplace/ in the repo to enable this feature."
    
    5. DETAILED/SPECIFIC questions about a KNOWN regulation number:
       → Use get_full_regulation_text with the document number
       → If it fails, explain: "The PDF for this regulation hasn't been uploaded yet. You can download it from the Federal Register and upload to @REG_INTEL.RAW.REGULATION_PDFS."
    
    ERROR HANDLING:
    If a tool returns an error about "object does not exist" or "invalid identifier":
    - For get_industry_impact or get_related_filings: This is expected if marketplace data isn't installed
    - For get_full_regulation_text: The specific PDF hasn't been uploaded
    - Explain what's missing and how to enable the feature, then offer alternatives

  system: |
    You are the Regulatory Intelligence Assistant. You help compliance teams monitor federal regulations.

    CORE CAPABILITIES (always available):
    1. Search regulations by topic, agency, or keyword
    2. Analyze trends (counts by category, agency, time)

    OPTIONAL CAPABILITIES:
    3. Find affected companies and stock tickers (requires Cybersyn marketplace data)
    4. Find related SEC filings (requires Cybersyn marketplace data)
    5. Read full PDF text (requires PDF upload to stage)

    When users ask about companies or SEC filings and the tool fails, gracefully explain
    that this feature requires installing free marketplace data from Cybersyn.

  sample_questions:
    - question: "What can you help me with?"
      answer: "I help compliance teams monitor federal regulations. I can search regulations by topic, analyze trends over time, and retrieve detailed information from regulation PDFs. With optional marketplace data installed, I can also identify affected companies and find related SEC filings."
    - question: "Show me recent environmental regulations"
      answer: "I'll search for environmental regulations using my search tool."
    - question: "What are the compliance deadlines in regulation 2026-05312?"
      answer: "I'll retrieve the full PDF of regulation 2026-05312 and extract the specific compliance deadlines for you."

tools:
  - tool_spec:
      type: cortex_search
      name: search_regulations
      description: "Search federal regulations by topic, agency, keyword. Returns abstracts/summaries."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyze_trends
      description: "Analyze regulation counts, trends, statistics by agency, category, or date."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: get_industry_impact
      description: "Find companies and stock tickers affected by regulations. OPTIONAL: requires Cybersyn marketplace data."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: get_related_filings
      description: "Find SEC filings (8-K, 10-K, 10-Q) from affected companies. OPTIONAL: requires Cybersyn marketplace data."
  - tool_spec:
      type: generic
      name: get_full_regulation_text
      description: "Read full PDF of a regulation. Requires the PDF to be uploaded to the stage first."
      input_schema:
        type: object
        properties:
          doc_number:
            type: string
            description: "The regulation document number (e.g., 2026-05312)"
          question:
            type: string
            description: "The specific question to answer about this regulation"
        required:
          - doc_number
          - question
tool_resources:
  search_regulations:
    name: "REG_INTEL.ANALYTICS.REG_SEARCH"
    max_results: "10"
    title_column: "title"
    id_column: "document_number"
  analyze_trends:
    semantic_view: "REG_INTEL.ANALYTICS.REG_ANALYTICS_VIEW"
  get_industry_impact:
    semantic_view: "REG_INTEL.ANALYTICS.COMPANY_EXPOSURE_VIEW"
  get_related_filings:
    semantic_view: "REG_INTEL.ANALYTICS.SEC_FILINGS_VIEW"
  get_full_regulation_text:
    type: "function"
    execution_environment:
      type: "warehouse"
      warehouse: "COMPUTE_WH"
    identifier: "REG_INTEL.ANALYTICS.ASK_REGULATION_PDF"
$$;


-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
-- Next steps:
--   1. Set up Openflow (see 02_openflow/README.md) to start data ingestion
--   2. (Optional) Install marketplace data for company/SEC enrichment (optional/marketplace/)
--   3. (Optional) Deploy Streamlit dashboard (optional/streamlit/)
--   4. (Optional) Upload PDFs for deep-dive analysis (see README.md)
--
-- Test your agent:
--   SELECT SNOWFLAKE.CORTEX.AGENT(
--     'REG_INTEL.ANALYTICS.REGULATORY_INTELLIGENCE',
--     'What can you help me with?'
--   );
-- ============================================================================
