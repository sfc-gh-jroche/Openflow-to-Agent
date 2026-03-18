# Openflow Flow Definitions

This directory contains **importable** NiFi flow definitions for the Regulatory Intelligence platform.

## Flows

| Flow | File | Purpose | Runtime |
|------|------|---------|---------|
| Federal Register Ingestion | `federal_register_flow.json` | Ingest regulations from Federal Register API | `regintel` |
| PDF Download | `pdf_download_flow.json` | Download regulation PDFs | `regintel_pdf_runtime` |

## Flow 1: Federal Register Ingestion

Fetches regulations from the Federal Register API and streams them to Snowflake.

```
┌─────────────────────┐
│  Trigger            │  GenerateFlowFile (every 1 min)
│  (Timer-driven)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Call Federal       │  InvokeHTTP
│  Register API       │  GET federalregister.gov/api/v1/documents.json
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Wrap as RAW_JSON   │  JoltTransformJSON
│                     │  Wraps entire response in {"RAW_JSON": ...}
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Write to Snowflake │  PutSnowpipeStreaming
│                     │  → REG_INTEL.RAW.RAW_REGULATIONS
└─────────────────────┘
```

## Flow 2: PDF Download

Downloads regulation PDFs from govinfo.gov and uploads them directly to a Snowflake stage.

```
┌─────────────────────┐
│  Trigger Daily      │  GenerateFlowFile (every 1 day)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Get Regulations    │  InvokeHTTP
│                     │  GET federalregister.gov/api/v1/documents.json
│                     │  (fetches RULE and PRORULE types with pdf_url)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Split Results      │  SplitJson → $.results[*]
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Extract Fields     │  EvaluateJsonPath
│                     │  pdf_url, document_number, title → attributes
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Filter Has PDF     │  RouteOnAttribute
│                     │  ${pdf_url:isEmpty():not()}
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Download PDF       │  InvokeHTTP
│                     │  GET ${pdf_url} (from www.govinfo.gov)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Set Filename       │  UpdateAttribute
│                     │  filename = ${document_number}.pdf
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Upload to Stage    │  PutSnowflakeInternalStageFile
│                     │  → @REG_INTEL.RAW.REGULATION_PDFS
└─────────────────────┘
```

**Requirements:**
- Network rule must include `www.govinfo.gov:443` (PDF download host)
- Stage `@REG_INTEL.RAW.REGULATION_PDFS` must grant READ, WRITE to `OPENFLOW_REGINTEL_ROLE`
- Runtime uses `SNOWFLAKE_SESSION_TOKEN` authentication

## Prerequisites

Before importing the flows, ensure you have:

1. **Run the infrastructure SQL** (`setup_all.sql` or `01_infrastructure/`)

2. **Created Openflow runtimes** in Snowsight:
   - Go to: Data → Ingestion → Openflow
   - Click **+ Runtime**
   
   For Federal Register flow:
   - Name: `regintel`
   - Size: **S**
   - Role: `OPENFLOW_REGINTEL_ROLE`
   
   For PDF Download flow:
   - Name: `regintel_pdf_runtime`
   - Size: **S**
   - Role: `OPENFLOW_REGINTEL_ROLE`

## Import Instructions

### Via Snowsight UI

1. Go to: Data → Ingestion → Openflow
2. Click on your runtime to open it
3. Right-click on the canvas → **Upload Flow Definition**
4. Select the appropriate `.json` file
5. The flow will be created as a new Process Group

### Via nipyapi CLI

```bash
nipyapi --profile <your-profile> ci import_flow_definition \
  --file_path 02_openflow/federal_register_flow.json
```

## Post-Import Configuration

After importing, you may need to:

1. **Enable Controller Services:**
   - Right-click on the Process Group → **Controller Services**
   - Enable the `JsonTreeReader` service (click lightning bolt icon)

2. **Start the flow:**
   - Right-click on the Process Group → **Start**

## Troubleshooting

### Flow won't start - invalid configuration

Check that the JsonTreeReader controller service is enabled:
1. Right-click Process Group → Controller Services
2. Click the lightning bolt icon to enable

### No data appearing in Snowflake

1. Check for bulletins (error messages) on processors
2. Verify the role has INSERT privileges on the table
3. Check the InvokeHTTP response - the API may be rate-limiting

### Authentication errors

The flows use `SNOWFLAKE_SESSION_TOKEN` which inherits credentials from the Openflow runtime. Ensure:
- The runtime role (`OPENFLOW_REGINTEL_ROLE`) has necessary grants
- The runtime is running and healthy
