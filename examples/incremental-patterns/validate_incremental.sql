/*
examples/incremental-patterns/validate_incremental.sql

Queries to verify your incremental model is actually incremental

Many models are configured as incremental but scan the full table
on every run. These queries help you detect that.
*/


/*
1. CHECK BYTES SCANNED ON RECENT RUNS

Replace 'your_model_name' with your actual model name.
Compare bytes_scanned to your total table size.
If they're roughly equal, the incremental isn't working.
*/

SELECT 
    start_time,
    query_text,
    bytes_scanned / 1e9 as gb_scanned,
    rows_produced,
    total_elapsed_time / 1000 as seconds
FROM snowflake.account_usage.query_history
WHERE query_text ILIKE '%your_model_name%'
    AND query_type = 'CREATE_TABLE_AS_SELECT'
    AND start_time >= current_date() - 7
ORDER BY start_time DESC
LIMIT 20;


/*
2. COMPARE INCREMENTAL VS FULL REFRESH

Run your model both ways and compare.
The incremental run should scan significantly less data.

First, do a normal run:
  dbt run --select your_model

Then check the query history (query above).
Note the bytes_scanned.

Then do a full refresh:
  dbt run --select your_model --full-refresh

Check query history again.
Full refresh should scan much more data.

If both scans are similar, your is_incremental() block isn't filtering effectively.
*/


/*
3. CHECK YOUR MODEL'S TABLE SIZE

Know what 100% looks like so you can recognize when you're scanning it.
*/

SELECT 
    table_name,
    row_count,
    bytes / 1e9 as gb_size
FROM snowflake.information_schema.tables
WHERE table_name = 'YOUR_MODEL_NAME'
    AND table_schema = 'YOUR_SCHEMA';


/*
4. VERIFY PARTITION PRUNING IS HAPPENING

Look at the query profile in Snowflake's web UI for your incremental runs.
Check the TableScan node for "Partitions scanned" vs "Partitions total".

Good: "Partitions scanned: 3 of 500"
Bad: "Partitions scanned: 500 of 500"

If you're scanning all partitions, your date filter isn't enabling pruning.
Common causes:
  - Filtering on a non-date column
  - Date column isn't aligned with partition boundaries
  - Complex filter conditions that Snowflake can't optimize
*/


/*
5. TRACK INCREMENTAL EFFICIENCY OVER TIME

Weekly summary of how your incremental models are performing.
*/

SELECT 
    date_trunc('day', start_time) as run_date,
    count(*) as runs,
    avg(bytes_scanned / 1e9) as avg_gb_scanned,
    avg(total_elapsed_time / 1000) as avg_seconds
FROM snowflake.account_usage.query_history
WHERE query_text ILIKE '%your_model_name%'
    AND query_type = 'CREATE_TABLE_AS_SELECT'
    AND start_time >= current_date() - 30
GROUP BY 1
ORDER BY 1 DESC;

/*
Watch for:
  - Sudden jumps in avg_gb_scanned (something broke the incremental logic)
  - Gradual increases over time (table growth, may need to revisit strategy)
*/
