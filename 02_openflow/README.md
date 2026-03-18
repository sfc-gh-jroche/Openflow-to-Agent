# Openflow Flow Definition

This directory contains an **importable** NiFi flow definition for ingesting Federal Register regulations into Snowflake.

## Flow Overview

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

## Prerequisites

Before importing the flow, ensure you have:

1. **Created the database and table** by running `01_infrastructure/` scripts (or `setup_all.sql`)

2. **Created an Openflow runtime** in Snowsight:
   - Go to: Data → Ingestion → Openflow
   - Click **+ Runtime**
   - Name: `regintel` (or your choice)
   - Size: S
   - Role: `OPENFLOW_REGINTEL_ROLE` (created in step 1)

## Import Instructions

### Option 1: Import via Snowsight UI

1. Go to: Data → Ingestion → Openflow
2. Click on your runtime to open it
3. Right-click on the canvas → **Upload Flow Definition**
4. Select `federal_register_flow.json`
5. The flow will be created as a new Process Group

### Option 2: Import via nipyapi CLI

```bash
nipyapi --profile <your-profile> ci import_flow_definition \
  --file_path openflow/federal_register_flow.json
```

## Post-Import Configuration

After importing, you may need to:

1. **Verify the PutSnowpipeStreaming processor settings:**
   - Database: `REG_INTEL`
   - Schema: `RAW`
   - Table: `RAW_REGULATIONS`
   - Role: `OPENFLOW_REGINTEL_ROLE`
   - Authentication Strategy: `SNOWFLAKE_SESSION_TOKEN`

2. **Enable the JsonTreeReader controller service:**
   - Right-click on the Process Group → **Controller Services**
   - Enable the `JsonTreeReader` service

3. **Start the flow:**
   - Right-click on the Process Group → **Start**

## Flow Components

| Processor | Type | Purpose |
|-----------|------|---------|
| Trigger | GenerateFlowFile | Triggers API call every 1 minute |
| Call Federal Register API | InvokeHTTP | Fetches latest 100 regulations |
| Wrap as RAW_JSON | JoltTransformJSON | Wraps response for VARIANT storage |
| Write to Snowflake | PutSnowpipeStreaming | Streams to Snowflake table |

| Controller Service | Type | Purpose |
|-------------------|------|---------|
| JsonTreeReader | JsonTreeReader | Parses JSON with schema inference |

## Customization

### Change the polling frequency

Edit the **Trigger** processor:
- `Scheduling Period`: Default is `1 min`
- For daily polling, change to `1 day` or use CRON: `0 0 6 * * ?` (6 AM daily)

### Change the API query

Edit the **Call Federal Register API** processor:
- `HTTP URL`: Modify query parameters as needed
- See [Federal Register API docs](https://www.federalregister.gov/developers/documentation/api/v1)

### Change the destination table

Edit the **Write to Snowflake** processor:
- `Database`, `Schema`, `Table`: Your target location
- `Role`: A role with write access to the table

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

The flow uses `SNOWFLAKE_SESSION_TOKEN` which inherits credentials from the Openflow runtime. Ensure:
- The runtime role (`OPENFLOW_REGINTEL_ROLE`) has necessary grants
- The runtime is running and healthy
