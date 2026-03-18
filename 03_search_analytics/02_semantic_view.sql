-- REG_ANALYTICS_VIEW: Semantic View for Cortex Analyst

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
