/*
diagnostic-queries/dev_vs_prod.sql

Compare development and production compute usage

Development can account for 30-40% of total spend without anyone
noticing, because it's spread across engineers throughout the day.
*/


/*
1. TOTAL CREDITS BY WAREHOUSE TYPE

Categorize warehouses as dev, prod, or other
*/

SELECT
    case 
        when warehouse_name ilike '%dev%' then 'Development'
        when warehouse_name ilike '%prod%' then 'Production'
        when warehouse_name ilike '%staging%' then 'Staging'
        when warehouse_name ilike '%test%' then 'Testing'
        else 'Other'
    end as warehouse_category,
    
    round(sum(credits_used), 2) as total_credits,
    round(sum(credits_used) * 100.0 / sum(sum(credits_used)) over (), 2) as pct_of_total

FROM snowflake.account_usage.warehouse_metering_history

WHERE start_time >= current_date() - 30

GROUP BY 1

ORDER BY total_credits DESC;


/*
2. DETAILED WAREHOUSE BREAKDOWN

See individual warehouse usage
*/

SELECT
    warehouse_name,
    case 
        when warehouse_name ilike '%dev%' then 'Development'
        when warehouse_name ilike '%prod%' then 'Production'
        else 'Other'
    end as category,
    round(sum(credits_used), 2) as total_credits,
    round(avg(credits_used_compute), 4) as avg_credits_per_hour

FROM snowflake.account_usage.warehouse_metering_history

WHERE start_time >= current_date() - 30

GROUP BY 1, 2

ORDER BY total_credits DESC;


/*
3. DEV USAGE BY TIME OF DAY

Development usage should correlate with work hours.
High usage outside business hours might indicate forgotten builds.
*/

SELECT
    extract(hour from start_time) as hour_of_day,
    round(sum(credits_used), 2) as credits

FROM snowflake.account_usage.warehouse_metering_history

WHERE 
    start_time >= current_date() - 30
    AND warehouse_name ILIKE '%dev%'

GROUP BY 1

ORDER BY 1;


/*
4. DEV QUERIES BY TYPE

What are devs running? Full builds? Selective? Tests?
*/

SELECT
    case
        when query_text ilike '%--select%' then 'Selective build'
        when query_text ilike '%dbt run%' then 'Full build'
        when query_text ilike '%dbt test%' then 'Testing'
        when query_text ilike '%dbt compile%' then 'Compile'
        else 'Ad-hoc query'
    end as query_type,
    
    count(*) as query_count,
    round(sum(total_elapsed_time) / 1000 / 60, 2) as total_minutes

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 7
    AND warehouse_name ILIKE '%dev%'
    AND execution_status = 'success'

GROUP BY 1

ORDER BY total_minutes DESC;


/*
5. TOP DEV USERS BY COMPUTE

Who's using the most dev compute?
Not for blame - for training opportunities.
*/

SELECT
    user_name,
    count(*) as query_count,
    round(sum(total_elapsed_time) / 1000 / 60, 2) as total_minutes,
    round(avg(total_elapsed_time) / 1000, 2) as avg_seconds

FROM snowflake.account_usage.query_history

WHERE 
    start_time >= current_date() - 7
    AND warehouse_name ILIKE '%dev%'
    AND execution_status = 'success'

GROUP BY 1

ORDER BY total_minutes DESC
LIMIT 20;


/*
6. SAVINGS OPPORTUNITY

Estimate savings if dev adopted selective builds
*/

WITH dev_stats AS (
    SELECT
        count(*) as total_queries,
        sum(case when query_text ilike '%--select%' then 1 else 0 end) as selective_queries,
        sum(total_elapsed_time) / 1000 / 60 as total_minutes
    FROM snowflake.account_usage.query_history
    WHERE start_time >= current_date() - 7
        AND warehouse_name ILIKE '%dev%'
        AND query_text ILIKE '%CREATE%TABLE%'
)

SELECT
    total_queries,
    selective_queries,
    total_queries - selective_queries as full_build_queries,
    round((total_queries - selective_queries) * 100.0 / total_queries, 1) as pct_full_builds,
    
    -- Rough estimate: full builds could be 95% cheaper with --select
    round(total_minutes * 0.95 * ((total_queries - selective_queries) * 1.0 / total_queries), 1) 
        as estimated_savings_minutes

FROM dev_stats;
