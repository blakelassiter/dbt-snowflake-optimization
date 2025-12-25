/*
Query Tag Analysis Queries

These queries help analyze dbt model costs and performance using query tags.
They assume you're using the JSON query tag format from set_query_tag.sql.

Adjust date ranges and filters as needed for your environment.
*/


/* ============================================
   Cost by Model (Last 30 Days)
   
   Shows which models consume the most compute.
   Requires warehouse cost data - adjust credit_price for your contract.
   ============================================ */

WITH model_queries AS (
    SELECT 
        try_parse_json(query_tag):model::string as model_name,
        try_parse_json(query_tag):materialized::string as materialization,
        total_elapsed_time / 1000 as seconds,
        bytes_scanned,
        credits_used_cloud_services
    FROM snowflake.account_usage.query_history
    WHERE start_time >= current_date() - 30
        AND query_tag LIKE '{%'
        AND execution_status = 'success'
)

SELECT 
    model_name,
    materialization,
    count(*) as run_count,
    round(sum(seconds) / 60, 2) as total_minutes,
    round(avg(seconds), 2) as avg_seconds,
    round(sum(bytes_scanned) / 1e9, 2) as total_gb_scanned,
    round(sum(credits_used_cloud_services), 4) as cloud_credits
FROM model_queries
WHERE model_name IS NOT NULL
GROUP BY model_name, materialization
ORDER BY total_minutes DESC
LIMIT 50;


/* ============================================
   Incremental Model Efficiency
   
   Compares full refresh vs incremental runs.
   Large differences indicate working incremental logic.
   Small differences suggest partition pruning issues.
   ============================================ */

WITH incremental_runs AS (
    SELECT 
        try_parse_json(query_tag):model::string as model_name,
        try_parse_json(query_tag):is_incremental::boolean as is_incremental,
        total_elapsed_time / 1000 as seconds,
        bytes_scanned / 1e9 as gb_scanned
    FROM snowflake.account_usage.query_history
    WHERE start_time >= current_date() - 30
        AND query_tag LIKE '{%'
        AND try_parse_json(query_tag):materialized::string = 'incremental'
        AND execution_status = 'success'
)

SELECT 
    model_name,
    is_incremental,
    count(*) as run_count,
    round(avg(seconds), 2) as avg_seconds,
    round(avg(gb_scanned), 2) as avg_gb_scanned
FROM incremental_runs
WHERE model_name IS NOT NULL
GROUP BY model_name, is_incremental
ORDER BY model_name, is_incremental;


/* ============================================
   Cost by dbt Run (Invocation)
   
   Groups all queries from a single dbt run.
   Useful for tracking job costs over time.
   ============================================ */

SELECT 
    try_parse_json(query_tag):invocation_id::string as invocation_id,
    try_parse_json(query_tag):target::string as target_env,
    min(start_time) as run_start,
    count(*) as query_count,
    count(distinct try_parse_json(query_tag):model::string) as model_count,
    round(sum(total_elapsed_time) / 1000 / 60, 2) as total_minutes,
    round(sum(bytes_scanned) / 1e12, 4) as tb_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 7
    AND query_tag LIKE '{%'
    AND execution_status = 'success'
GROUP BY invocation_id, target_env
ORDER BY run_start DESC
LIMIT 50;


/* ============================================
   Dev vs Prod Comparison
   
   Shows compute split between environments.
   High dev usage may indicate workflow issues.
   ============================================ */

SELECT 
    try_parse_json(query_tag):target::string as target_env,
    count(*) as query_count,
    round(sum(total_elapsed_time) / 1000 / 60 / 60, 2) as total_hours,
    round(sum(bytes_scanned) / 1e12, 2) as tb_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 30
    AND query_tag LIKE '{%'
    AND execution_status = 'success'
GROUP BY target_env
ORDER BY total_hours DESC;


/* ============================================
   Materialization Distribution
   
   Shows which materialization types consume the most.
   High view compute may indicate missing tables.
   ============================================ */

SELECT 
    try_parse_json(query_tag):materialized::string as materialization,
    count(*) as query_count,
    round(sum(total_elapsed_time) / 1000 / 60, 2) as total_minutes,
    round(avg(total_elapsed_time) / 1000, 2) as avg_seconds,
    round(sum(bytes_scanned) / 1e9, 2) as total_gb_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 30
    AND query_tag LIKE '{%'
    AND execution_status = 'success'
GROUP BY materialization
ORDER BY total_minutes DESC;
