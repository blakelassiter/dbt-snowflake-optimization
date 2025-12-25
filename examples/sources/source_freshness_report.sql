/*
Source Freshness Analysis

These queries help analyze source freshness patterns and identify
tables that frequently miss SLAs.

Run after: dbt source freshness
Results stored in: target/sources.json
*/


/* ============================================
   Current Source Freshness Status
   
   Shows the most recent freshness check for each source.
   Requires parsing the sources.json output from dbt.
   ============================================ */

-- Note: This query works if you load sources.json into Snowflake
-- Alternatively, use dbt Cloud's built-in freshness dashboard

/*
If you've loaded freshness results to a table:

SELECT
    source_name,
    table_name,
    max_loaded_at,
    snapshotted_at,
    status,
    datediff('hour', max_loaded_at, snapshotted_at) as hours_stale
FROM {{ ref('stg_source_freshness') }}
ORDER BY hours_stale DESC;
*/


/* ============================================
   Detect Source Updates via Query History
   
   Alternative approach: infer source freshness from
   when INSERT/COPY commands last ran against source tables.
   ============================================ */

WITH source_updates AS (
    SELECT 
        database_name,
        schema_name,
        -- Extract table name from query
        regexp_substr(query_text, 'INTO\\s+([\\w\\.]+)', 1, 1, 'i', 1) as table_name,
        max(end_time) as last_updated,
        count(*) as update_count
    FROM snowflake.account_usage.query_history
    WHERE start_time >= current_date() - 7
        AND (query_type = 'INSERT' OR query_type = 'COPY')
        AND execution_status = 'success'
        AND database_name = 'RAW'  -- Adjust to your raw database
    GROUP BY database_name, schema_name, table_name
)

SELECT 
    database_name,
    schema_name,
    table_name,
    last_updated,
    datediff('hour', last_updated, current_timestamp()) as hours_since_update,
    update_count as updates_last_7_days
FROM source_updates
WHERE table_name IS NOT NULL
ORDER BY hours_since_update DESC;


/* ============================================
   Source Table Sizes
   
   Helps understand which sources are largest
   and may need freshness filter configurations.
   ============================================ */

SELECT 
    table_catalog as database_name,
    table_schema as schema_name,
    table_name,
    row_count,
    round(bytes / 1e9, 2) as size_gb,
    last_altered
FROM snowflake.account_usage.tables
WHERE table_catalog = 'RAW'  -- Adjust to your raw database
    AND deleted IS NULL
ORDER BY bytes DESC
LIMIT 50;


/* ============================================
   Freshness Check Performance
   
   If freshness checks are slow, you may need
   to add filters or use warehouse metadata.
   ============================================ */

SELECT 
    query_text,
    total_elapsed_time / 1000 as seconds,
    bytes_scanned / 1e9 as gb_scanned,
    start_time
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 7
    AND query_text ILIKE '%max(%loaded%'  -- Freshness check pattern
    AND execution_status = 'success'
ORDER BY total_elapsed_time DESC
LIMIT 20;
