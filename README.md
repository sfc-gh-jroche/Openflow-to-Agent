# Regulatory Intelligence Platform

AI-powered platform for monitoring federal regulations, built on Snowflake. Demonstrates an end-to-end pipeline from data ingestion through AI-powered analysis.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA INGESTION                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  Openflow (NiFi)              │  Manual Upload                              │
│  └── Federal Register API     │  └── PDF Documents                          │
│      ──► RAW_REGULATIONS      │      ──► @REGULATION_PDFS (Stage)           │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TRANSFORMATION LAYER                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  Dynamic Tables Pipeline                                                    │
│  ├── DT_REG_BRONZE ────► Parse JSON                                        │
│  ├── DT_REG_SILVER ────► AI enrichment (summary, category, entities)       │
│  └── DT_REG_GOLD ──────► Aggregates & final schema                         │
│                                                                             │
│  Marketplace Enrichment (SNOWFLAKE_PUBLIC_DATA_FREE)                       │
│  ├── DT_INDUSTRY_REFERENCE ──► Map categories to SEC industries            │
│  ├── DT_COMPANY_EXPOSURE ────► Link regulations to affected companies      │
│  ├── DT_REG_SEC_FILINGS ─────► Find related SEC filings                    │
│  └── DT_REG_GOLD_ENRICHED ───► Combined view for dashboard                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                             AI/ML LAYER                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  Cortex Search        │  Semantic Views (3)     │  PDF Analysis             │
│  └── REG_SEARCH       │  └── REG_ANALYTICS_VIEW │  └── ASK_REGULATION_PDF   │
│      (vector search)  │  └── COMPANY_EXPOSURE   │      (AI_COMPLETE +       │
│                       │  └── SEC_FILINGS_VIEW   │       TO_FILE)            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          APPLICATION LAYER                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  Cortex Agent (5 tools)              │  Streamlit Dashboard                 │
│  ├── search_regulations              │  ├── Overview & metrics              │
│  ├── analyze_trends                  │  ├── Regulation detail view          │
│  ├── get_industry_impact             │  ├── Company explorer                │
│  ├── get_related_filings             │  └── Charts & visualizations         │
│  └── get_full_regulation_text (PDF)  │                                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Snowflake Account** with:
   - Cortex AI functions enabled (most accounts have this)
   - Openflow (optional - can manually load sample data)
   - ACCOUNTADMIN or equivalent privileges to create databases/warehouses

2. **Snowflake Marketplace** (optional, for company enrichment):
   - Go to: Snowsight → Data Products → Marketplace
   - Search: `SEC Filings & Company Characteristics` by **Cybersyn**
   - Click **Get** and install as: `SNOWFLAKE_PUBLIC_DATA_FREE`
   - See `sql/marketplace/README.md` for details
   - **Skip this if you only want the core regulation pipeline**

3. **Snowflake Intelligence** (optional):
   - If enabled, you can move the agent to `SNOWFLAKE_INTELLIGENCE.AGENTS` for UI access

## Quick Start

Run each SQL file in **Snowsight** (Worksheets → + → SQL Worksheet → paste contents → Run All).

### 1. Infrastructure Setup

Run these files in order:
1. `sql/infrastructure/01_database_setup.sql` - Creates database, schemas, warehouse
2. `sql/infrastructure/02_network_eai.sql` - Network rule for API access
3. `sql/infrastructure/03_raw_table.sql` - Landing table for raw JSON
4. `sql/infrastructure/04_openflow_role.sql` - Role for Openflow runtime

### 2. Dynamic Tables Pipeline

Run these files in order:
1. `sql/dynamic_tables/01_dt_reg_bronze.sql` - Parse raw JSON
2. `sql/dynamic_tables/02_dt_reg_silver.sql` - AI enrichment
3. `sql/dynamic_tables/03_dt_reg_gold.sql` - Final aggregates

### 3. Marketplace Enrichment (Optional)

> **Requires:** `SNOWFLAKE_PUBLIC_DATA_FREE` from Snowflake Marketplace. Skip this section if you don't need company/SEC filing data.

Run these files in order:
1. `sql/marketplace/01_industry_reference.sql`
2. `sql/marketplace/02_company_exposure.sql`
3. `sql/marketplace/03_sec_filings.sql`
4. `sql/marketplace/04_gold_enriched.sql`
5. `sql/marketplace/05_semantic_views.sql`

### 4. Search and Analytics

Run these files:
1. `cortex_search/reg_search.sql` - Vector search service
2. `semantic_view/reg_analytics_view.sql` - Semantic view for Cortex Analyst

### 5. PDF Analysis (Optional)

This enables the agent to read full regulation PDFs and answer detailed questions about them.

**Step 1: Create the stage and function**

Run these files in order:
1. `sql/pdf_analysis/01_pdf_stage.sql` - Creates internal stage for PDFs
2. `sql/pdf_analysis/02_pdf_function.sql` - Creates AI Q&A function using `AI_COMPLETE` with `TO_FILE`

**Step 2: Upload regulation PDFs**

PDFs must be named with the document number (e.g., `2026-05312.pdf`) to match regulations in your data.

1. Find a document number:
   ```sql
   SELECT document_number, title, pdf_url 
   FROM REG_INTEL.ANALYTICS.DT_REG_GOLD 
   WHERE pdf_url IS NOT NULL 
   LIMIT 10;
   ```

2. Download the PDF from Federal Register:
   - URL format: `https://www.govinfo.gov/content/pkg/FR-YYYY-MM-DD/pdf/DOCUMENT_NUMBER.pdf`
   - Or use the `pdf_url` from the query above

3. Upload via Snowsight:
   - Navigate to: Data → Databases → REG_INTEL → RAW → Stages → REGULATION_PDFS
   - Click **+ Files** → Upload your PDF(s)
   - Ensure filename matches document number (e.g., `2026-05312.pdf`)

**Step 3: Test the function**

```sql
SELECT REG_INTEL.ANALYTICS.ASK_REGULATION_PDF(
    '2026-05312',  -- document number (must match uploaded filename)
    'What are the key compliance deadlines?'
);
```

> **Note:** The agent's `get_full_regulation_text` tool uses this function. Once PDFs are uploaded, the agent can answer questions like "What are the safety requirements in regulation 2026-05312?"

### 6. Create the Cortex Agent

Run: `cortex_agent/reg_intel_agent.sql`

> **Note:** The agent is created in `REG_INTEL.ANALYTICS`. If you have Snowflake Intelligence enabled and want the agent to appear in that UI, edit the script to use `SNOWFLAKE_INTELLIGENCE.AGENTS` instead.

### 7. Deploy Openflow (Optional)

> **Note:** Openflow is optional. You can load sample data manually using `scripts/load_sample_data.sql` instead.

1. Go to Snowsight → Data → Ingestion → Openflow
2. Create runtime: `regintel` (S node, `OPENFLOW_REGINTEL_ROLE`)
3. Click on the runtime to open it
4. Right-click canvas → **Upload Flow Definition** → select `openflow/federal_register_flow.json`
5. Enable the JsonTreeReader controller service (right-click Process Group → Controller Services)
6. Start the flow (right-click Process Group → Start)

See `openflow/README.md` for detailed instructions and troubleshooting.

### 8. Deploy Streamlit Dashboard

1. Go to Snowsight → Projects → Streamlit
2. Click **+ Streamlit App**
3. Choose database `REG_INTEL`, schema `ANALYTICS`
4. Copy contents of `streamlit/streamlit_app.py` into the editor
5. Click **Run**

## Project Structure

```
├── sql/
│   ├── infrastructure/
│   │   ├── 01_database_setup.sql      # Database, schemas, warehouse
│   │   ├── 02_network_eai.sql         # Network rule + external access
│   │   ├── 03_raw_table.sql           # Landing table for raw JSON
│   │   └── 04_openflow_role.sql       # Role for Openflow runtime
│   ├── dynamic_tables/
│   │   ├── 01_dt_reg_bronze.sql       # Parse raw JSON
│   │   ├── 02_dt_reg_silver.sql       # AI enrichment (COMPLETE, EXTRACT)
│   │   └── 03_dt_reg_gold.sql         # Final aggregated schema
│   ├── marketplace/
│   │   ├── 01_industry_reference.sql  # Category → industry mapping
│   │   ├── 02_company_exposure.sql    # Regulations → companies
│   │   ├── 03_sec_filings.sql         # Related SEC filings
│   │   ├── 04_gold_enriched.sql       # Dashboard rollup table
│   │   └── 05_semantic_views.sql      # Semantic views for Analyst
│   └── pdf_analysis/
│       ├── 01_pdf_stage.sql           # Stage for PDF documents
│       └── 02_pdf_function.sql        # AI_COMPLETE with TO_FILE
├── cortex_search/
│   └── reg_search.sql                 # Vector search service
├── semantic_view/
│   └── reg_analytics_view.sql         # Semantic view for trends
├── cortex_agent/
│   └── reg_intel_agent.sql            # 5-tool Cortex Agent
├── openflow/
│   ├── federal_register_flow.json     # Importable NiFi flow definition
│   └── README.md                      # Openflow setup guide
├── streamlit/
│   ├── streamlit_app.py               # Dashboard application
│   └── snowflake.yml                  # Deployment config
├── scripts/
│   ├── load_sample_data.sql           # Manual data loading (no Openflow)
│   └── verify_platform.sql            # Verification queries
└── setup.sql                          # Setup order reference
```

## Agent Capabilities

The Cortex Agent has 5 tools:

| Tool | Type | Description |
|------|------|-------------|
| `search_regulations` | Cortex Search | Find regulations by topic/keyword |
| `analyze_trends` | Cortex Analyst | Statistics, counts, trends over time |
| `get_industry_impact` | Cortex Analyst | Find affected companies by ticker |
| `get_related_filings` | Cortex Analyst | Find SEC filings (8-K, 10-K, 10-Q) |
| `get_full_regulation_text` | Custom (UDF) | Read full PDF and answer questions |

### Sample Questions

**Discovery:**
- "Find regulations about AI in healthcare"
- "Show me recent EPA rules"

**Analytics:**
- "How many regulations did OSHA publish this quarter?"
- "Compare regulation counts by agency"

**Company Impact:**
- "Which companies are affected by financial regulations?"
- "What tickers are exposed to healthcare rules?"

**SEC Filings:**
- "What 8-K filings relate to energy regulations?"
- "Show SEC filings from companies affected by data privacy rules"

**Deep Dive (PDF):**
- "What are the compliance deadlines in regulation 2026-05312?"
- "Explain the safety requirements in the electric aircraft rule"

## Data Source

[Federal Register API](https://www.federalregister.gov/developers/documentation/api/v1) - Free, public, no authentication required.

## Key Patterns Demonstrated

1. **Openflow Ingestion** - NiFi-based streaming from REST API
2. **Dynamic Tables** - Declarative transformation pipeline
3. **Cortex AI Functions** - AI_COMPLETE, AI_EXTRACT for enrichment
4. **Marketplace Data** - Join with SNOWFLAKE_PUBLIC_DATA_FREE
5. **Cortex Search** - Vector search over regulation text
6. **Semantic Views** - Natural language analytics with Cortex Analyst
7. **Custom Agent Tools** - UDF for on-demand PDF analysis
8. **Streamlit in Snowflake** - Interactive dashboard
