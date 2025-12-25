# Slim CI Setup Guide

This guide covers setting up Slim CI for dbt Core with Snowflake. For dbt Cloud, most of this is handled automatically.

## Prerequisites

1. Production job that generates `manifest.json`
2. Storage location for artifacts (S3, GCS, or similar)
3. CI environment with dbt installed

## Step 1: Store Production Artifacts

After each production run, save the manifest:

```bash
# In your production job
dbt build
aws s3 cp target/manifest.json s3://your-bucket/dbt-artifacts/manifest.json
```

Or with environment-specific paths:
```bash
aws s3 cp target/manifest.json s3://your-bucket/dbt-artifacts/prod/manifest.json
```

## Step 2: Configure CI Job

Your CI job should:
1. Download production manifest
2. Run builds with state comparison
3. Use defer for upstream models

```bash
#!/bin/bash
set -e

# Download production artifacts
mkdir -p ./prod-state
aws s3 cp s3://your-bucket/dbt-artifacts/manifest.json ./prod-state/

# Install dependencies
dbt deps

# Run modified models with deferral
dbt build \
    --select state:modified+ \
    --defer \
    --state ./prod-state \
    --target ci
```

## Step 3: Configure profiles.yml for CI

Create a CI target that builds to an isolated schema:

```yaml
# profiles.yml
my_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      database: analytics
      warehouse: transforming
      schema: dev_{{ env_var('USER') }}

    ci:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_CI_USER') }}"
      password: "{{ env_var('SNOWFLAKE_CI_PASSWORD') }}"
      database: analytics_ci
      warehouse: ci_warehouse
      schema: pr_{{ env_var('PR_NUMBER', 'default') }}
```

## Step 4: Handle Incremental Models

Incremental models in CI can be tricky because the CI schema starts empty. Two approaches:

### Option A: Clone First

```bash
# Clone incremental models from production
dbt clone --select state:modified+,config.materialized:incremental,state:old

# Then build (incrementals will run in incremental mode)
dbt build --select state:modified+
```

### Option B: Full Refresh in CI

```bash
# Just full refresh incrementals in CI
dbt build --select state:modified+ --full-refresh
```

Option A is more accurate but requires clone permissions. Option B is simpler but won't catch incremental-specific bugs.

## Step 5: Optimize for Speed

### Use --fail-fast

Stop on first error to get faster feedback:
```bash
dbt build --select state:modified+ --fail-fast
```

### Parallelize with Threads

CI environments often have dedicated compute:
```bash
dbt build --select state:modified+ --threads 8
```

### Skip Unchanged Tests

Only run tests for modified models:
```bash
dbt build --select state:modified+
# vs
dbt run --select state:modified+
dbt test  # Tests everything
```

## Troubleshooting

### "No nodes selected"

The manifest might be stale or the comparison failed:
```bash
# Check what would be selected
dbt ls --select state:modified+ --state ./prod-state
```

### Defer Errors

If unmodified upstream models don't exist:
1. Ensure production manifest is current
2. Check that production objects exist
3. Verify CI user has SELECT access to production schema

### State Comparison Mismatches

If too many models are selected:
```bash
# See detailed comparison
dbt ls --select state:modified+ --state ./prod-state --output json
```
