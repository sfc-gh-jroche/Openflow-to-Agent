# OpenFlow: Federal Register Ingestion

## Overview
This flow ingests federal regulation documents from the Federal Register API into Snowflake.

## Flow Pattern
```
┌──────────────┐    ┌─────────────┐    ┌──────────────┐    ┌───────────────────┐
│ GenerateFlow │───►│ InvokeHTTP  │───►│  SplitJson   │───►│ EvaluateJsonPath  │
│    (cron)    │    │  (GET API)  │    │  (results)   │    │ (extract fields)  │
└──────────────┘    └─────────────┘    └──────────────┘    └─────────┬─────────┘
                                                                     │
                                        ┌────────────────────────────┼────────────────────────────┐
                                        ▼                                                         ▼
                              ┌───────────────────┐                                    ┌──────────────────┐
                              │ PutSnowpipeStream │                                    │   InvokeHTTP     │
                              │ (RAW_REGULATIONS) │                                    │   (fetch PDF)    │
                              └───────────────────┘                                    └────────┬─────────┘
                                                                                                │
                                                                                                ▼
                                                                                     ┌──────────────────┐
                                                                                     │ PutSnowflakeStage│
                                                                                     │ (REGULATION_PDFS)│
                                                                                     └──────────────────┘
```

## Important: Flow Template

The `federal_register_flow.json` file is a **reference template** showing the flow structure and configuration. Depending on your OpenFlow version, you may need to:

1. **Import directly** - Try importing the JSON; if the format is compatible, it will work
2. **Recreate manually** - Use the JSON as a guide to build the flow in the OpenFlow UI
3. **Adjust processor versions** - Bundle versions may differ in your environment

## Configuration Required After Import

You **must** configure these settings after importing (they use environment variables as placeholders):

| Setting | Placeholder | What to Set |
|---------|-------------|-------------|
| Account URL | `${SNOWFLAKE_ACCOUNT_URL}` | Your account URL (e.g., `abc123.snowflakecomputing.com`) |
| User | `${SNOWFLAKE_USER}` | Service account username |
| Private Key | `${SNOWFLAKE_PRIVATE_KEY}` | RSA private key for authentication |

## Hardcoded Values (match setup scripts)

These are hardcoded to match the SQL setup scripts. Change both if you use different names:

| Setting | Value | SQL Script |
|---------|-------|------------|
| Database | `REG_INTEL` | `01_database_setup.sql` |
| Schema | `RAW` | `01_database_setup.sql` |
| Table | `RAW_REGULATIONS` | `03_raw_table.sql` |
| Stage | `REGULATION_PDFS` | `pdf_analysis/01_pdf_stage.sql` |
| Warehouse | `COMPUTE_WH` | `01_database_setup.sql` |
| Role | `OPENFLOW_REGINTEL_ROLE` | `04_openflow_role.sql` |

## Schedule
Default: Every 6 hours (`0 */6 * * *`)

## Deployment Steps

1. **Create OpenFlow Runtime** in Snowsight:
   - Go to: Data → Ingestion → OpenFlow
   - Create runtime named `regintel`
   - Size: XS (sufficient for this workload)
   - Role: `OPENFLOW_REGINTEL_ROLE`

2. **Import or Recreate Flow**:
   - Try importing `federal_register_flow.json`
   - If import fails, recreate using the JSON as reference

3. **Configure Credentials**:
   - Set your Snowflake account URL
   - Set service account user
   - Upload/paste RSA private key

4. **Grant External Access** (already done if you ran setup scripts):
   ```sql
   GRANT USAGE ON INTEGRATION REG_INTEL_FEDERAL_REGISTER_EAI 
     TO ROLE OPENFLOW_REGINTEL_ROLE;
   ```

5. **Start the Flow**

## Alternative: Manual Data Loading

If you don't have OpenFlow or prefer not to use it, see `scripts/load_sample_data.sql` for alternative data loading methods.

## API Documentation
- Federal Register API: https://www.federalregister.gov/developers/documentation/api/v1
- No authentication required
- Free, public data
