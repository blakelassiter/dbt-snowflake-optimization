/*
diagnostic-queries/find_expensive_models.sql

Find your most expensive dbt models by compute time

This query identifies models that consume the most resources.
Focus optimization efforts on the top 10-20 models.
The 80/20 rule applies: a small number of models drive most costs.
*/

-- Top 20 most expensive models (last 30 days)
SELECT 
    -- Extract model name from query text
    -- dbt creates tables with pattern: CREATE TABLE schema.model_name
    regexp_substr(query_text, 'CREATE.*TABLE.*\\.([A-Z0-9_]+)', 1, 1, 'i', 1) as model_name,
    
    count(*) as run_count,
    
    -- Timing metrics
    round(avg(total_elapsed_time) / 1000, 1) as avg_seconds,
    round(max(total_elapsed_time) / 1000, 1) as max_seconds,
    round(sum(total_elapsed_time) / 1000 / 60, 1) as total_minutes,
    
    -- Data metrics
    round(avg(bytes_scanned) / 1e9, 2) as avg_gb_scanned,
    round(avg(rows_produced), 0) as avg_rows_produced,
    
    -- Warehouse used
    warehouse_name

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 30
    
    -- dbt table creation patterns
    AND (
        query_text ILIKE '%CREATE%TABLE%AS%SELECT%'
        OR query_text ILIKE '%CREATE%OR%REPLACE%TABLE%'
        OR query_text ILIKE '%MERGE%INTO%'
    )
    
    -- Exclude system/metadata queries
    AND query_text NOT ILIKE '%information_schema%'
    AND query_text NOT ILIKE '%account_usage%'
    
    -- Successful queries only
    AND execution_status = 'success'

GROUP BY model_name, warehouse_name

-- Focus on the expensive ones
HAVING sum(total_elapsed_time) / 1000 > 60  -- More than 60 seconds total

ORDER BY total_minutes DESC

LIMIT 20;


/*
WHAT TO DO WITH THESE RESULTS

For each model in your top 20:

1. Check materialization
   - Is it incremental but should be?
   - Is it a table that could be a view?

2. Check SQL efficiency
   - Are filters applied before joins?
   - Is SELECT * used on wide tables?

3. Check warehouse sizing
   - Is it on an appropriately sized warehouse?
   - Would a smaller warehouse work?

4. Check run frequency
   - Does it need to run every hour, or could it be daily?
   - Could some runs be skipped?
*/
