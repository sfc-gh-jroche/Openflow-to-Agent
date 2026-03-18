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
│  Marketplace Enrichment (optional)                                          │
│  ├── DT_INDUSTRY_REFERENCE ──► Map categories to SEC industries            │
│  ├── DT_COMPANY_EXPOSURE ────► Link regulations to affected companies      │
│  └── DT_REG_SEC_FILINGS ─────► Find related SEC filings                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                             AI/ML LAYER                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  Cortex Search        │  Semantic Views         │  PDF Analysis             │
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
   - Openflow enabled
   - ACCOUNTADMIN or equivalent privileges

2. **Snowflake Marketplace** (optional, for company enrichment):
   - Go to: Snowsight → Data Products → Marketplace
   - Search: `SEC Filings & Company Characteristics` by **Cybersyn**
   - Click **Get** and install as: `SNOWFLAKE_PUBLIC_DATA_FREE`

## Quick Start

### Option A: Run Everything at Once

1. Open `setup_all.sql` in **Snowsight Workspaces** and click **Run All**
2. Set up Openflow (see Step 2 below)

### Option B: Run Step by Step

Use Workspaces to run files in numbered order:

```
01_infrastructure/     ← Run first (database, schemas, roles)
02_openflow/           ← Create runtime + import flow (see instructions below)
03_dynamic_tables/     ← Run third (Bronze → Silver → Gold pipeline)
04_search_analytics/   ← Run fourth (Cortex Search + Semantic View)
05_pdf_analysis/       ← Run fifth (PDF stage + AI function)
06_agent/              ← Run sixth (Cortex Agent)
```

## Step 2: Set Up Openflow

After running infrastructure SQL, set up the data ingestion flow:

1. **Create Openflow Runtime**
   - Go to: Snowsight → Data → Ingestion → Openflow
   - Click **+ Runtime**
   - Name: `regintel`
   - Size: **S**
   - Role: `OPENFLOW_REGINTEL_ROLE`

2. **Import the Flow**
   - Click on the runtime to open it
   - Right-click canvas → **Upload Flow Definition**
   - Select `02_openflow/federal_register_flow.json`

3. **Enable Controller Service**
   - Right-click the Process Group → **Controller Services**
   - Enable `JsonTreeReader` (click lightning bolt icon)

4. **Start the Flow**
   - Right-click the Process Group → **Start**

Data will begin flowing into `REG_INTEL.RAW.RAW_REGULATIONS` within 1 minute.

## Project Structure

```
├── setup_all.sql              # ⭐ Master SQL script (run first)
├── 01_infrastructure/         # Database, schemas, roles, network rules
│   ├── 01_database_setup.sql
│   ├── 02_network_eai.sql
│   ├── 03_raw_table.sql
│   └── 04_openflow_role.sql
├── 02_openflow/               # ⭐ Data ingestion (import into runtime)
│   ├── federal_register_flow.json
│   └── README.md
├── 03_dynamic_tables/         # Bronze → Silver → Gold pipeline
│   ├── 01_dt_reg_bronze.sql
│   ├── 02_dt_reg_silver.sql
│   └── 03_dt_reg_gold.sql
├── 04_search_analytics/       # Cortex Search + Semantic View
│   ├── 01_cortex_search.sql
│   └── 02_semantic_view.sql
├── 05_pdf_analysis/           # PDF stage + AI Q&A function
│   ├── 01_pdf_stage.sql
│   └── 02_pdf_function.sql
├── 06_agent/                  # Cortex Agent definition
│   └── 01_cortex_agent.sql
└── optional/
    ├── marketplace/           # Company/SEC enrichment (requires Cybersyn)
    ├── streamlit/             # Dashboard application
    └── scripts/               # Sample data loader, verification
```

## Optional: PDF Analysis

Upload regulation PDFs to enable deep-dive questions like "What are the compliance deadlines?"

1. Find a document number:
   ```sql
   SELECT document_number, title, pdf_url 
   FROM REG_INTEL.CURATED.DT_REG_SILVER
   WHERE pdf_url IS NOT NULL LIMIT 10;
   ```

2. Download the PDF from Federal Register

3. Upload via Snowsight:
   - Navigate to: Data → Databases → REG_INTEL → RAW → Stages → REGULATION_PDFS
   - Click **+ Files** → Upload your PDF
   - Filename must match document number (e.g., `2026-05312.pdf`)

4. Test:
   ```sql
   SELECT REG_INTEL.ANALYTICS.ASK_REGULATION_PDF(
       '2026-05312',
       'What are the key compliance deadlines?'
   );
   ```

## Optional: Marketplace Enrichment

For company impact analysis and SEC filings:

1. Install **Cybersyn SEC Filings & Company Characteristics** from Snowflake Marketplace as `SNOWFLAKE_PUBLIC_DATA_FREE`
2. Run scripts in `optional/marketplace/` in order

This enables two additional agent tools:
- `get_industry_impact` - Find affected companies by ticker
- `get_related_filings` - Find SEC filings from affected companies

## Optional: Streamlit Dashboard

1. Go to Snowsight → Projects → Streamlit
2. Click **+ Streamlit App**
3. Choose database `REG_INTEL`, schema `ANALYTICS`
4. Copy contents of `optional/streamlit/streamlit_app.py`
5. Click **Run**

## Test the Agent

```sql
-- Basic test
SELECT SNOWFLAKE.CORTEX.AGENT(
    'REG_INTEL.ANALYTICS.REGULATORY_INTELLIGENCE',
    'What can you help me with?'
);

-- Search regulations
SELECT SNOWFLAKE.CORTEX.AGENT(
    'REG_INTEL.ANALYTICS.REGULATORY_INTELLIGENCE',
    'Find regulations about environmental protection'
);

-- PDF deep-dive (requires uploaded PDF)
SELECT SNOWFLAKE.CORTEX.AGENT(
    'REG_INTEL.ANALYTICS.REGULATORY_INTELLIGENCE',
    'What are the compliance deadlines in regulation 2026-05312?'
);
```

## Agent Capabilities

| Tool | Type | Description | Requires |
|------|------|-------------|----------|
| `search_regulations` | Cortex Search | Find regulations by topic/keyword | Core |
| `analyze_trends` | Cortex Analyst | Statistics, counts, trends | Core |
| `get_full_regulation_text` | Custom (UDF) | Read full PDF and answer questions | PDF upload |
| `get_industry_impact` | Cortex Analyst | Find affected companies | Marketplace |
| `get_related_filings` | Cortex Analyst | Find SEC filings | Marketplace |

## Data Source

[Federal Register API](https://www.federalregister.gov/developers/documentation/api/v1) - Free, public, no authentication required.

## Key Patterns Demonstrated

1. **Openflow Ingestion** - NiFi-based streaming from REST API
2. **Dynamic Tables** - Declarative transformation pipeline
3. **Cortex AI Functions** - AI_COMPLETE, AI_EXTRACT, CLASSIFY_TEXT
4. **Marketplace Data** - Join with SNOWFLAKE_PUBLIC_DATA_FREE
5. **Cortex Search** - Vector search over regulation text
6. **Semantic Views** - Natural language analytics with Cortex Analyst
7. **Custom Agent Tools** - UDF for on-demand PDF analysis
8. **Streamlit in Snowflake** - Interactive dashboard
