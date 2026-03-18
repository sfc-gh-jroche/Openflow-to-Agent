-- Industry Reference: Maps SEC industry groups to regulatory categories
-- Uses Snowflake Marketplace data: SNOWFLAKE_PUBLIC_DATA_FREE

CREATE OR REPLACE DYNAMIC TABLE REG_INTEL.CURATED.DT_INDUSTRY_REFERENCE
  TARGET_LAG = '1 day'
  WAREHOUSE = COMPUTE_WH
AS
SELECT 
  CASE 
    WHEN LOWER(cc.VALUE) LIKE '%bank%' OR LOWER(cc.VALUE) LIKE '%financ%' OR LOWER(cc.VALUE) LIKE '%insurance%' 
         OR LOWER(cc.VALUE) LIKE '%invest%' OR LOWER(cc.VALUE) LIKE '%credit%' OR LOWER(cc.VALUE) LIKE '%loan%' 
         OR LOWER(cc.VALUE) LIKE '%securities%' THEN 'Financial Services'
    WHEN LOWER(cc.VALUE) LIKE '%health%' OR LOWER(cc.VALUE) LIKE '%pharma%' OR LOWER(cc.VALUE) LIKE '%medical%' 
         OR LOWER(cc.VALUE) LIKE '%hospital%' OR LOWER(cc.VALUE) LIKE '%drug%' OR LOWER(cc.VALUE) LIKE '%biotech%' THEN 'Healthcare'
    WHEN LOWER(cc.VALUE) LIKE '%oil%' OR LOWER(cc.VALUE) LIKE '%gas%' OR LOWER(cc.VALUE) LIKE '%petrol%' 
         OR LOWER(cc.VALUE) LIKE '%energy%' OR LOWER(cc.VALUE) LIKE '%electric%' OR LOWER(cc.VALUE) LIKE '%utility%' 
         OR LOWER(cc.VALUE) LIKE '%power%' THEN 'Energy'
    WHEN LOWER(cc.VALUE) LIKE '%transport%' OR LOWER(cc.VALUE) LIKE '%airline%' OR LOWER(cc.VALUE) LIKE '%railroad%' 
         OR LOWER(cc.VALUE) LIKE '%trucking%' OR LOWER(cc.VALUE) LIKE '%shipping%' OR LOWER(cc.VALUE) LIKE '%aviation%' THEN 'Transportation'
    WHEN LOWER(cc.VALUE) LIKE '%waste%' OR LOWER(cc.VALUE) LIKE '%environmental%' OR LOWER(cc.VALUE) LIKE '%chemical%' 
         OR LOWER(cc.VALUE) LIKE '%mining%' THEN 'Environmental Regulation'
    WHEN LOWER(cc.VALUE) LIKE '%software%' OR LOWER(cc.VALUE) LIKE '%computer%' OR LOWER(cc.VALUE) LIKE '%telecom%' 
         OR LOWER(cc.VALUE) LIKE '%electronic%' OR LOWER(cc.VALUE) LIKE '%semiconductor%' THEN 'Technology & Communications'
    WHEN LOWER(cc.VALUE) LIKE '%retail%' OR LOWER(cc.VALUE) LIKE '%wholesale%' OR LOWER(cc.VALUE) LIKE '%merchant%' THEN 'Trade & Commerce'
    WHEN LOWER(cc.VALUE) LIKE '%employment%' OR LOWER(cc.VALUE) LIKE '%staffing%' OR LOWER(cc.VALUE) LIKE '%personnel%' THEN 'Labor & Employment'
    WHEN LOWER(cc.VALUE) LIKE '%agricult%' OR LOWER(cc.VALUE) LIKE '%farm%' OR LOWER(cc.VALUE) LIKE '%food%' 
         OR LOWER(cc.VALUE) LIKE '%livestock%' THEN 'Agriculture'
    ELSE 'Other'
  END AS regulatory_category,
  cc.VALUE AS sec_industry_group,
  COUNT(DISTINCT cc.COMPANY_ID) AS company_count
FROM SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.COMPANY_CHARACTERISTICS cc
WHERE cc.RELATIONSHIP_TYPE = 'sec_industry_group'
GROUP BY 1, 2
HAVING regulatory_category != 'Other'
ORDER BY regulatory_category, company_count DESC;
