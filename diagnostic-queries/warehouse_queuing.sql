/*
diagnostic-queries/warehouse_queuing.sql

Detect thread/warehouse mismatches through queue analysis

When dbt threads exceed warehouse capacity, queries queue.
When threads are too low, warehouse capacity sits idle.
These queries help you find the right balance.
*/


/*
1. QUEUING SUMMARY BY WAREHOUSE

Non-zero queue time indicates resource contention.
*/

SELECT 
    warehouse_name,
    count(*) as total_queries,
    
    -- How many queries had to wait
    sum(case when queued_overload_time > 0 then 1 else 0 end) as queued_queries,
    round(sum(case when queued_overload_time > 0 then 1 else 0 end) * 100.0 
          / count(*), 2) as pct_queued,
    
    -- Queue time stats
    round(avg(queued_overload_time) / 1000, 2) as avg_queue_seconds,
    round(max(queued_overload_time) / 1000, 2) as max_queue_seconds,
    round(sum(queued_overload_time) / 1000 / 60, 2) as total_queue_minutes

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 7
    AND warehouse_name IS NOT NULL
    AND execution_status = 'success'

GROUP BY warehouse_name

ORDER BY pct_queued DESC;


/*
2. QUEUING DURING DBT RUNS

Focus specifically on dbt-related queries
*/

SELECT 
    warehouse_name,
    date_trunc('hour', start_time) as hour,
    count(*) as queries,
    sum(case when queued_overload_time > 0 then 1 else 0 end) as queued,
    round(avg(queued_overload_time) / 1000, 2) as avg_queue_seconds

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 7
    AND (
        query_text ILIKE '%dbt%'
        OR warehouse_name ILIKE '%dbt%'
        OR warehouse_name ILIKE '%transform%'
    )
    AND execution_status = 'success'

GROUP BY 1, 2
HAVING sum(case when queued_overload_time > 0 then 1 else 0 end) > 0

ORDER BY hour DESC, queued DESC;


/*
3. CONCURRENT QUERY ANALYSIS

Understand how many queries run simultaneously.
Compare to thread setting.
*/

WITH query_windows AS (
    SELECT
        query_id,
        warehouse_name,
        start_time,
        end_time
    FROM snowflake.account_usage.query_history
    WHERE 
        start_time >= current_date() - 1
        AND warehouse_name ILIKE '%dbt%'  -- Adjust to your warehouse name
        AND execution_status = 'success'
)

SELECT
    date_trunc('minute', q1.start_time) as minute,
    count(distinct q2.query_id) as concurrent_queries

FROM query_windows q1
JOIN query_windows q2
    ON q1.warehouse_name = q2.warehouse_name
    AND q2.start_time <= q1.start_time
    AND q2.end_time >= q1.start_time

GROUP BY 1

ORDER BY concurrent_queries DESC
LIMIT 20;


/*
4. QUEUE TIME BY TIME OF DAY

Find when queuing is worst (correlates with dbt run schedules)
*/

SELECT 
    extract(hour from start_time) as hour_of_day,
    warehouse_name,
    count(*) as queries,
    sum(case when queued_overload_time > 0 then 1 else 0 end) as queued,
    round(avg(queued_overload_time) / 1000, 2) as avg_queue_seconds

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 7
    AND warehouse_name IS NOT NULL
    AND queued_overload_time > 0

GROUP BY 1, 2

ORDER BY avg_queue_seconds DESC;


/*
5. RECOMMENDATIONS

Based on queuing patterns, adjust threads or warehouse size.

IF: pct_queued > 10% during dbt runs
THEN: Either reduce threads or increase warehouse size

IF: pct_queued is near 0% and warehouse utilization is low
THEN: Consider increasing threads or reducing warehouse size

Thread guidelines:
  X-Small: 1-2 threads
  Small: 2-4 threads
  Medium: 4-8 threads
  Large: 8-16 threads

Check your current thread setting in profiles.yml and compare
to the warehouse size being used.
*/
