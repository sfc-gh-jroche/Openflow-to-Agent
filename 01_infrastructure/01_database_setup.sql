-- Regulatory Intelligence Platform - Database Setup
-- Creates the foundational database and schema structure

-- Create warehouse (skip if you already have one - update references in other scripts)
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

CREATE DATABASE IF NOT EXISTS REG_INTEL COMMENT = 'Regulatory Intelligence Platform';

CREATE SCHEMA IF NOT EXISTS REG_INTEL.RAW COMMENT = 'Landing zone for raw JSON';
CREATE SCHEMA IF NOT EXISTS REG_INTEL.CURATED COMMENT = 'Dynamic tables pipeline';
CREATE SCHEMA IF NOT EXISTS REG_INTEL.ANALYTICS COMMENT = 'Cortex services, semantic view, agent';
