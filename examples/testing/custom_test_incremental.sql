/*
Custom Test: Validate Incremental Model

This test checks that an incremental model is actually processing
incrementally (not doing full table scans every run).

Place in tests/generic/ directory for use as a generic test,
or in tests/ directory as a singular test.

How it works:
1. Queries recent runs of the model from query_history
2. Compares bytes_scanned between runs
3. Fails if recent runs scan similar amounts to a full refresh

Usage as singular test:
  Save as tests/validate_incremental_fct_events.sql and customize.

Usage as generic test:
  Add to schema.yml:
    data_tests:
      - validate_incremental:
          model_pattern: 'fct_events'
          max_scan_ratio: 0.5
*/

{% test validate_incremental(model, model_pattern, max_scan_ratio=0.5) %}
/*
Arguments:
  model: The model reference (passed automatically)
  model_pattern: Pattern to match in query_text (e.g., 'fct_events')
  max_scan_ratio: Maximum ratio of incremental to full scan (default 0.5 = 50%)
*/

WITH recent_runs AS (
    SELECT 
        query_id,
        start_time,
        bytes_scanned,
        total_elapsed_time,
        query_text
    FROM snowflake.account_usage.query_history
    WHERE start_time >= current_date() - 7
        AND query_text ILIKE '%{{ model_pattern }}%'
        AND query_text ILIKE '%CREATE%TABLE%'
        AND execution_status = 'success'
    ORDER BY start_time DESC
    LIMIT 10
),

run_stats AS (
    SELECT
        max(bytes_scanned) as max_bytes,
        avg(bytes_scanned) as avg_bytes,
        min(bytes_scanned) as min_bytes,
        count(*) as run_count
    FROM recent_runs
)

/*
This test fails if average scan is more than max_scan_ratio of max scan.
A working incremental model should scan much less on regular runs
compared to a full refresh.
*/
SELECT 
    avg_bytes,
    max_bytes,
    round(avg_bytes / nullif(max_bytes, 0), 2) as scan_ratio,
    {{ max_scan_ratio }} as threshold
FROM run_stats
WHERE run_count >= 3
    AND avg_bytes / nullif(max_bytes, 0) > {{ max_scan_ratio }}

{% endtest %}


/*
Simpler singular test version:
Save as tests/assert_incremental_is_working.sql

This version is easier to customize for specific models.
*/

-- tests/assert_incremental_is_working.sql
/*
WITH recent_runs AS (
    SELECT 
        bytes_scanned,
        start_time
    FROM snowflake.account_usage.query_history
    WHERE start_time >= current_date() - 7
        AND query_text ILIKE '%fct_events%'
        AND query_text ILIKE '%CREATE%TABLE%'
        AND execution_status = 'success'
    ORDER BY start_time DESC
    LIMIT 5
),

stats AS (
    SELECT
        max(bytes_scanned) as max_scan,
        avg(bytes_scanned) as avg_scan
    FROM recent_runs
)

-- Returns rows (fails) if avg scan is > 50% of max scan
SELECT *
FROM stats
WHERE avg_scan > max_scan * 0.5
    AND max_scan > 1000000000  -- Only check tables > 1GB
*/
