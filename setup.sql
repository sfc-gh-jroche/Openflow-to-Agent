-- Master Setup Script for Regulatory Intelligence Platform
-- Run these scripts in order using Snowflake CLI or Snowsight

-- =============================================================================
-- PHASE 1: Infrastructure (run first)
-- =============================================================================

-- 1. Create database, schemas, and warehouse
-- snow sql -f sql/infrastructure/01_database_setup.sql

-- 2. Create network rule and external access integration
-- snow sql -f sql/infrastructure/02_network_eai.sql

-- 3. Create landing table for raw JSON
-- snow sql -f sql/infrastructure/03_raw_table.sql

-- 4. Create OpenFlow runtime role (run before creating runtime in UI)
-- snow sql -f sql/infrastructure/04_openflow_role.sql

-- =============================================================================
-- PHASE 2: Dynamic Tables Pipeline
-- =============================================================================

-- 5. Bronze layer - parse raw JSON
-- snow sql -f sql/dynamic_tables/01_dt_reg_bronze.sql

-- 6. Silver layer - AI enrichment
-- snow sql -f sql/dynamic_tables/02_dt_reg_silver.sql

-- 7. Gold layer - aggregates
-- snow sql -f sql/dynamic_tables/03_dt_reg_gold.sql

-- =============================================================================
-- PHASE 3: Marketplace Enrichment (requires SNOWFLAKE_PUBLIC_DATA_FREE)
-- =============================================================================

-- 8. Industry reference mapping
-- snow sql -f sql/marketplace/01_industry_reference.sql

-- 9. Company exposure table
-- snow sql -f sql/marketplace/02_company_exposure.sql

-- 10. SEC filings linkage
-- snow sql -f sql/marketplace/03_sec_filings.sql

-- 11. Enriched gold table for dashboard
-- snow sql -f sql/marketplace/04_gold_enriched.sql

-- 12. Semantic views for Cortex Analyst
-- snow sql -f sql/marketplace/05_semantic_views.sql

-- =============================================================================
-- PHASE 4: Cortex Services
-- =============================================================================

-- 13. Cortex Search Service
-- snow sql -f cortex_search/reg_search.sql

-- 14. Semantic View for Cortex Analyst (basic analytics)
-- snow sql -f semantic_view/reg_analytics_view.sql

-- =============================================================================
-- PHASE 5: PDF Analysis (Optional)
-- =============================================================================

-- 15. PDF stage
-- snow sql -f sql/pdf_analysis/01_pdf_stage.sql

-- 16. PDF Q&A function
-- snow sql -f sql/pdf_analysis/02_pdf_function.sql

-- =============================================================================
-- PHASE 6: Cortex Agent
-- =============================================================================

-- 17. Create the agent with all 5 tools
-- snow sql -f cortex_agent/reg_intel_agent.sql

-- =============================================================================
-- PHASE 7: Verification
-- =============================================================================

-- snow sql -f scripts/verify_platform.sql

-- =============================================================================
-- PHASE 8: Streamlit Dashboard
-- =============================================================================

-- cd streamlit && snow streamlit deploy
