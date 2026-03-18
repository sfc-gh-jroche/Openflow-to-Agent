# Regulatory Intelligence Platform

AI-powered platform for monitoring federal regulations, built on Snowflake. Demonstrates an end-to-end pipeline from data ingestion through AI-powered analysis.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA INGESTION                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  OpenFlow (NiFi)                                                            │
│  ├── Federal Register API ──► RAW_REGULATIONS (JSON)                       │
│  └── PDF Documents ──────────► @REGULATION_PDFS (Stage)                    │
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
   - OpenFlow (optional - can manually load sample data)
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

### 1. Run Infrastructure Setup

```bash
snow sql -f sql/infrastructure/01_database_setup.sql
snow sql -f sql/infrastructure/02_network_eai.sql
snow sql -f sql/infrastructure/03_raw_table.sql
snow sql -f sql/infrastructure/04_openflow_role.sql
```

### 2. Create Dynamic Tables Pipeline

```bash
snow sql -f sql/dynamic_tables/01_dt_reg_bronze.sql
snow sql -f sql/dynamic_tables/02_dt_reg_silver.sql
snow sql -f sql/dynamic_tables/03_dt_reg_gold.sql
```

### 3. Add Marketplace Enrichment (Optional)

> **Requires:** `SNOWFLAKE_PUBLIC_DATA_FREE` from Snowflake Marketplace. Skip this section if you don't need company/SEC filing data.

```bash
snow sql -f sql/marketplace/01_industry_reference.sql
snow sql -f sql/marketplace/02_company_exposure.sql
snow sql -f sql/marketplace/03_sec_filings.sql
snow sql -f sql/marketplace/04_gold_enriched.sql
snow sql -f sql/marketplace/05_semantic_views.sql
```

### 4. Set Up Search and Analytics

```bash
snow sql -f cortex_search/reg_search.sql
snow sql -f semantic_view/reg_analytics_view.sql
```

### 5. Set Up PDF Analysis (Optional)

```bash
snow sql -f sql/pdf_analysis/01_pdf_stage.sql
snow sql -f sql/pdf_analysis/02_pdf_function.sql
```

Download and upload regulation PDFs:
```bash
# Download a PDF from Federal Register (replace YYYY-NNNNN with any document number)
curl -o 2026-05312.pdf "https://www.govinfo.gov/content/pkg/FR-2026-03-18/pdf/2026-05312.pdf"

# Upload to Snowflake stage (from SnowSQL or Snowsight)
PUT file://2026-05312.pdf @REG_INTEL.RAW.REGULATION_PDFS AUTO_COMPRESS=FALSE;
```

> **Tip:** Find document numbers by querying `REG_INTEL.ANALYTICS.DT_REG_GOLD` or browsing [federalregister.gov](https://www.federalregister.gov)

### 6. Create the Cortex Agent

```bash
snow sql -f cortex_agent/reg_intel_agent.sql
```

> **Note:** The agent is created in `REG_INTEL.ANALYTICS`. If you have Snowflake Intelligence enabled and want the agent to appear in that UI, edit the script to use `SNOWFLAKE_INTELLIGENCE.AGENTS` instead.

### 7. Deploy OpenFlow (Optional)

> **Note:** OpenFlow is optional. You can load sample data manually using `scripts/load_sample_data.sql` instead.

1. Go to Snowsight → Ingestion → OpenFlow
2. Create runtime: `regintel` (XS node, `OPENFLOW_REGINTEL_ROLE`)
3. Import `openflow/federal_register_flow.json` (or recreate from reference - see `openflow/README.md`)
4. Configure Snowflake credentials in the flow
5. Start the flow

### 8. Deploy Streamlit Dashboard

```bash
cd streamlit
snow streamlit deploy --database REG_INTEL --schema ANALYTICS
```

## Project Structure

```
├── sql/
│   ├── infrastructure/
│   │   ├── 01_database_setup.sql      # Database, schemas, warehouse
│   │   ├── 02_network_eai.sql         # Network rule + external access
│   │   ├── 03_raw_table.sql           # Landing table for raw JSON
│   │   └── 04_openflow_role.sql       # Role for OpenFlow runtime
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
│   ├── federal_register_flow.json     # NiFi flow definition
│   └── README.md                       # OpenFlow setup guide
├── streamlit/
│   ├── streamlit_app.py               # Dashboard application
│   └── snowflake.yml                  # Deployment config
├── scripts/
│   └── verify_platform.sql            # Verification queries
├── setup.sql                          # Master setup script
└── README.md
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

1. **OpenFlow Ingestion** - NiFi-based streaming from REST API
2. **Dynamic Tables** - Declarative transformation pipeline
3. **Cortex AI Functions** - AI_COMPLETE, AI_EXTRACT for enrichment
4. **Marketplace Data** - Join with SNOWFLAKE_PUBLIC_DATA_FREE
5. **Cortex Search** - Vector search over regulation text
6. **Semantic Views** - Natural language analytics with Cortex Analyst
7. **Custom Agent Tools** - UDF for on-demand PDF analysis
8. **Streamlit in Snowflake** - Interactive dashboard

## License

MIT
