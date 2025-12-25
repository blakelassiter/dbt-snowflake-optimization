/*
diagnostic-queries/analyze_query_patterns.sql

Find common query inefficiencies across your dbt project

These queries identify patterns that typically indicate
optimization opportunities.
*/


/*
1. QUERIES WITH HIGH BYTES SCANNED TO ROWS PRODUCED RATIO

High ratio suggests reading lots of data to produce little output.
Usually means filters are applied too late.
*/

SELECT 
    query_id,
    regexp_substr(query_text, 'CREATE.*TABLE.*\\.([A-Z0-9_]+)', 1, 1, 'i', 1) as model_name,
    bytes_scanned / 1e9 as gb_scanned,
    rows_produced,
    
    -- Ratio: GB per million rows produced
    round(bytes_scanned / 1e9 / nullif(rows_produced / 1e6, 0), 2) as gb_per_million_rows,
    
    total_elapsed_time / 1000 as seconds

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 7
    AND query_text ILIKE '%CREATE%TABLE%'
    AND rows_produced > 0
    AND bytes_scanned > 1e9  -- Over 1GB scanned
    AND execution_status = 'success'

ORDER BY gb_per_million_rows DESC
LIMIT 20;



/*
2. QUERIES THAT COULD BENEFIT FROM COLUMN PRUNING

Find queries scanning lots of columns. SELECT * on wide tables
shows up as high bytes scanned relative to rows.
*/

SELECT 
    query_id,
    regexp_substr(query_text, 'CREATE.*TABLE.*\\.([A-Z0-9_]+)', 1, 1, 'i', 1) as model_name,
    bytes_scanned / 1e9 as gb_scanned,
    rows_produced,
    
    -- Bytes per row (proxy for column width)
    round(bytes_scanned / nullif(rows_produced, 0), 0) as bytes_per_row,
    
    total_elapsed_time / 1000 as seconds

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 7
    AND query_text ILIKE '%CREATE%TABLE%'
    AND rows_produced > 100000  -- Meaningful row count
    AND execution_status = 'success'
    
    -- Flag queries with high bytes per row
    AND bytes_scanned / nullif(rows_produced, 0) > 10000  -- Over 10KB per row

ORDER BY bytes_per_row DESC
LIMIT 20;



/*
3. SLOWEST QUERIES BY EXECUTION TIME

Simple but effective: find what's taking the longest
*/

SELECT 
    start_time,
    regexp_substr(query_text, 'CREATE.*TABLE.*\\.([A-Z0-9_]+)', 1, 1, 'i', 1) as model_name,
    total_elapsed_time / 1000 / 60 as minutes,
    bytes_scanned / 1e9 as gb_scanned,
    rows_produced,
    warehouse_name,
    warehouse_size

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 7
    AND query_text ILIKE '%CREATE%TABLE%'
    AND execution_status = 'success'

ORDER BY total_elapsed_time DESC
LIMIT 20;



/*
4. QUERIES WITH SPILLAGE

Spillage indicates the warehouse ran out of memory and spilled to disk.
Can indicate warehouse too small OR inefficient query.
*/

SELECT 
    query_id,
    regexp_substr(query_text, 'CREATE.*TABLE.*\\.([A-Z0-9_]+)', 1, 1, 'i', 1) as model_name,
    bytes_spilled_to_local_storage / 1e9 as gb_spilled_local,
    bytes_spilled_to_remote_storage / 1e9 as gb_spilled_remote,
    total_elapsed_time / 1000 as seconds,
    warehouse_name,
    warehouse_size

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 7
    AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
    AND query_text ILIKE '%CREATE%TABLE%'
    AND execution_status = 'success'

ORDER BY (bytes_spilled_to_local_storage + bytes_spilled_to_remote_storage) DESC
LIMIT 20;



/*
5. QUERIES WITH PARTITION PRUNING ISSUES

Compare partitions scanned vs total partitions.
Low pruning = date filters not working effectively.

Note: This requires checking the query profile in the UI.
The data isn't directly available in query_history.
Use this query to identify candidates, then check profiles manually.
*/

SELECT 
    query_id,
    regexp_substr(query_text, 'CREATE.*TABLE.*\\.([A-Z0-9_]+)', 1, 1, 'i', 1) as model_name,
    partitions_scanned,
    partitions_total,
    round(partitions_scanned / nullif(partitions_total, 0) * 100, 1) as pct_partitions_scanned,
    bytes_scanned / 1e9 as gb_scanned

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 7
    AND partitions_total > 100  -- Tables with meaningful partition count
    AND query_text ILIKE '%CREATE%TABLE%'
    AND execution_status = 'success'
    
    -- Flag queries scanning most partitions
    AND partitions_scanned / nullif(partitions_total, 0) > 0.5

ORDER BY partitions_total DESC
LIMIT 20;
