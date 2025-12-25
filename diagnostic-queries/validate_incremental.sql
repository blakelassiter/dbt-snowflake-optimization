/*
diagnostic-queries/validate_incremental.sql

Verify that incremental models are actually incremental

Many models are configured as incremental but scan the full table
on every run. This query compares bytes_scanned to expected values.

Replace 'your_model_name' with your actual model name
Run this after a normal (non-full-refresh) dbt run
*/


/*
1. RECENT RUNS FOR A SPECIFIC MODEL

Compare bytes_scanned across runs. For a working incremental,
non-full-refresh runs should scan much less than full-refresh runs.
*/

SELECT 
    start_time,
    query_text,
    bytes_scanned / 1e9 as gb_scanned,
    rows_produced,
    total_elapsed_time / 1000 as seconds,
    
    -- Check if this looks like a full refresh
    -- (will show CREATE OR REPLACE TABLE instead of MERGE)
    case 
        when query_text ilike '%MERGE INTO%' then 'incremental'
        when query_text ilike '%CREATE%REPLACE%' then 'full_refresh'
        else 'unknown'
    end as run_type

FROM snowflake.account_usage.query_history

WHERE 
    query_text ILIKE '%your_model_name%'  -- Replace with your model
    AND start_time >= current_date() - 7
    AND query_type IN ('CREATE_TABLE_AS_SELECT', 'MERGE')
    AND execution_status = 'success'

ORDER BY start_time DESC
LIMIT 20;



/*
2. COMPARE TO TABLE SIZE

Get the actual table size to understand what 100% looks like
*/

SELECT 
    table_schema,
    table_name,
    row_count,
    bytes / 1e9 as gb_size

FROM snowflake.information_schema.tables

WHERE table_name = 'YOUR_MODEL_NAME'  -- Replace with your model (uppercase)
  AND table_schema = 'YOUR_SCHEMA';   -- Replace with your schema



/*
3. EFFICIENCY RATIO

For all incremental models, compare average scan size to table size.
Ratio close to 1.0 = not actually incremental
*/

WITH model_runs AS (
    SELECT 
        regexp_substr(query_text, 'MERGE INTO.*\\.([A-Z0-9_]+)', 1, 1, 'i', 1) as model_name,
        avg(bytes_scanned) as avg_bytes_scanned
    FROM snowflake.account_usage.query_history
    WHERE query_type = 'MERGE'
        AND start_time >= current_date() - 7
        AND execution_status = 'success'
    GROUP BY 1
),

table_sizes AS (
    SELECT 
        table_name as model_name,
        bytes as table_bytes
    FROM snowflake.information_schema.tables
    WHERE table_schema = 'YOUR_SCHEMA'  -- Replace with your schema
)

SELECT 
    mr.model_name,
    round(mr.avg_bytes_scanned / 1e9, 2) as avg_gb_scanned,
    round(ts.table_bytes / 1e9, 2) as table_gb,
    round(mr.avg_bytes_scanned / nullif(ts.table_bytes, 0), 2) as scan_ratio,
    
    case 
        when mr.avg_bytes_scanned / nullif(ts.table_bytes, 0) > 0.8 
            then 'NOT INCREMENTAL - scanning full table'
        when mr.avg_bytes_scanned / nullif(ts.table_bytes, 0) > 0.3 
            then 'PARTIAL - may need optimization'
        else 'GOOD - scanning small portion'
    end as status

FROM model_runs mr
LEFT JOIN table_sizes ts ON upper(mr.model_name) = upper(ts.model_name)

WHERE ts.table_bytes > 1e9  -- Only tables > 1GB

ORDER BY scan_ratio DESC;
