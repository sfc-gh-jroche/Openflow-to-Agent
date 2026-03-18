# Marketplace Data Setup

This platform can optionally enrich regulations with company and SEC filing data from the **Snowflake Marketplace**.

## Required Listing

Install the free **Cybersyn** dataset:

1. Go to: **Snowsight → Data Products → Marketplace**
2. Search for: `SEC Filings & Company Characteristics (Free Sample)`
3. Provider: **Cybersyn**
4. Click **Get** and install with database name: `SNOWFLAKE_PUBLIC_DATA_FREE`

> **Important:** The database MUST be named `SNOWFLAKE_PUBLIC_DATA_FREE` for the SQL scripts to work. If you use a different name, update the references in the marketplace SQL files.

## Tables Used

The enrichment layer uses these tables from the marketplace data:

| Table | Purpose |
|-------|---------|
| `PUBLIC_DATA_FREE.COMPANY_INDEX` | Company names, tickers, CIKs |
| `PUBLIC_DATA_FREE.COMPANY_CHARACTERISTICS` | Industry classifications |
| `PUBLIC_DATA_FREE.SEC_REPORT_INDEX` | SEC filings (8-K, 10-K, 10-Q) |

## What the Enrichment Provides

Once installed, the marketplace SQL scripts create:

1. **DT_INDUSTRY_REFERENCE** - Maps regulatory categories to SEC industry groups
2. **DT_COMPANY_EXPOSURE** - Links each regulation to potentially affected companies (~115K records)
3. **DT_REG_SEC_FILINGS** - Links regulations to related SEC filings (~100K records)
4. **DT_REG_GOLD_ENRICHED** - Adds company/filing counts to the gold table
5. **Semantic Views** - Enable natural language queries about company impact

## Running Without Marketplace Data

If you skip the marketplace enrichment:
- The core pipeline (Openflow → Bronze → Silver → Gold) works normally
- Cortex Search works normally
- The basic semantic view (REG_ANALYTICS_VIEW) works normally
- The agent will have 2 tools instead of 5 (search + analyze_trends only)
- The Streamlit dashboard will show errors for company/filing tabs

To run without marketplace, simply skip step 3 in the Quick Start and modify the agent to remove the company/filing tools.
