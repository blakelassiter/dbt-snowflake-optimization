/*
diagnostic-queries/weekly_trend.sql

Track compute usage trends over time

Use this to monitor optimization impact and catch regressions.
Run weekly or after major changes.
*/


/*
1. WEEKLY COMPUTE HOURS BY WAREHOUSE

Track total compute over time to see optimization impact
*/

SELECT
    date_trunc('week', start_time) as week,
    warehouse_name,
    round(sum(total_elapsed_time) / 1000 / 60 / 60, 2) as compute_hours,
    count(*) as query_count,
    round(avg(total_elapsed_time) / 1000, 2) as avg_seconds

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 90
    AND warehouse_name IS NOT NULL
    AND execution_status = 'success'

GROUP BY 1, 2

ORDER BY week DESC, compute_hours DESC;


/*
2. WEEKLY COST TREND (CREDITS)

Convert compute hours to credits for cost tracking
*/

SELECT
    date_trunc('week', start_time) as week,
    warehouse_name,
    round(sum(credits_used), 2) as credits

FROM snowflake.account_usage.warehouse_metering_history

WHERE start_time >= current_date() - 90

GROUP BY 1, 2

ORDER BY week DESC, credits DESC;


/*
3. TOP MODELS BY WEEK

Track which models drive the most compute each week.
Watch for new entries or sudden increases.
*/

SELECT
    date_trunc('week', start_time) as week,
    regexp_substr(query_text, 'CREATE.*TABLE.*\\.([A-Z0-9_]+)', 1, 1, 'i', 1) as model_name,
    round(sum(total_elapsed_time) / 1000 / 60, 2) as total_minutes,
    count(*) as run_count

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 30
    AND query_text ILIKE '%CREATE%TABLE%'
    AND execution_status = 'success'

GROUP BY 1, 2

HAVING sum(total_elapsed_time) / 1000 > 60  -- Over 1 minute total

ORDER BY week DESC, total_minutes DESC;


/*
4. WEEK-OVER-WEEK CHANGE

Highlight significant changes in compute
*/

WITH weekly_totals AS (
    SELECT
        date_trunc('week', start_time) as week,
        warehouse_name,
        sum(total_elapsed_time) / 1000 / 60 / 60 as compute_hours
    FROM snowflake.account_usage.query_history
    WHERE start_time >= current_date() - 30
        AND warehouse_name IS NOT NULL
    GROUP BY 1, 2
)

SELECT
    curr.week,
    curr.warehouse_name,
    round(curr.compute_hours, 2) as current_hours,
    round(prev.compute_hours, 2) as previous_hours,
    round(curr.compute_hours - coalesce(prev.compute_hours, 0), 2) as change_hours,
    round((curr.compute_hours - coalesce(prev.compute_hours, curr.compute_hours)) 
          / nullif(prev.compute_hours, 0) * 100, 1) as pct_change

FROM weekly_totals curr
LEFT JOIN weekly_totals prev
    ON curr.warehouse_name = prev.warehouse_name
    AND curr.week = dateadd(week, 1, prev.week)

WHERE curr.week >= current_date() - 14

ORDER BY abs(curr.compute_hours - coalesce(prev.compute_hours, 0)) DESC;


/*
5. MONTHLY ROLLUP

Higher-level view for reporting
*/

SELECT
    date_trunc('month', start_time) as month,
    sum(credits_used) as total_credits,
    lag(sum(credits_used)) over (order by date_trunc('month', start_time)) as prev_month_credits,
    round((sum(credits_used) - lag(sum(credits_used)) over (order by date_trunc('month', start_time)))
          / nullif(lag(sum(credits_used)) over (order by date_trunc('month', start_time)), 0) * 100, 1)
        as pct_change

FROM snowflake.account_usage.warehouse_metering_history

WHERE start_time >= current_date() - 180

GROUP BY 1

ORDER BY month DESC;
