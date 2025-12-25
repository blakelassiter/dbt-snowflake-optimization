/*
diagnostic-queries/late_arriving_data.sql

Determine appropriate lookback windows for incremental models

Late-arriving data is real. Orders get entered retroactively.
Records get corrected. Upstream systems have delays.

These queries help you understand your data patterns and choose
the right lookback window for each incremental model.
*/


/*
1. BASIC LATE ARRIVAL ANALYSIS

Compare the business date (event_date/order_date) to when the
record was actually created/loaded.

Adjust column names to match your source tables.
*/

SELECT
    datediff(day, order_date, created_at) as days_late,
    count(*) as record_count,
    round(count(*) * 100.0 / sum(count(*)) over (), 2) as pct_of_total,
    sum(count(*)) over (order by datediff(day, order_date, created_at)) as cumulative_count,
    round(sum(count(*)) over (order by datediff(day, order_date, created_at)) * 100.0 
          / sum(count(*)) over (), 2) as cumulative_pct

FROM your_source_table  -- Replace with your table

WHERE created_at >= current_date() - 30  -- Last 30 days of loads

GROUP BY 1
ORDER BY 1;

/*
INTERPRETING RESULTS:
If cumulative_pct hits 99% at days_late = 3, a 3-day lookback catches 99% of data.
The remaining 1% can be caught by periodic full refreshes.
*/


/*
2. LATE ARRIVALS BY SOURCE SYSTEM

Different sources have different delay patterns.
You might need different lookback windows for different source tables.
*/

SELECT
    source_system,  -- Replace with your source identifier column
    datediff(day, event_date, loaded_at) as days_late,
    count(*) as record_count

FROM your_source_table

WHERE loaded_at >= current_date() - 30

GROUP BY 1, 2

HAVING count(*) > 100  -- Filter noise

ORDER BY source_system, days_late;


/*
3. RECOMMENDED LOOKBACK BY PERCENTILE

Calculate the lookback needed to capture different percentiles.
*/

WITH late_stats AS (
    SELECT
        datediff(day, business_date, loaded_at) as days_late
    FROM your_source_table
    WHERE loaded_at >= current_date() - 30
)

SELECT
    percentile_cont(0.95) within group (order by days_late) as p95_days_late,
    percentile_cont(0.99) within group (order by days_late) as p99_days_late,
    percentile_cont(0.999) within group (order by days_late) as p999_days_late,
    max(days_late) as max_days_late

FROM late_stats;

/*
RECOMMENDATION:
Use p99 as your lookback window for routine runs.
Schedule weekly full-refresh to catch the remaining 1%.
*/


/*
4. COST OF DIFFERENT LOOKBACK WINDOWS

Estimate how much data you'd reprocess with different windows.
*/

WITH daily_volumes AS (
    SELECT
        date_trunc('day', business_date) as business_day,
        count(*) as record_count
    FROM your_source_table
    WHERE business_date >= current_date() - 30
    GROUP BY 1
)

SELECT
    '1 day' as lookback_window,
    avg(record_count) as avg_daily_records,
    avg(record_count) * 1 as records_reprocessed
FROM daily_volumes

UNION ALL

SELECT
    '3 days' as lookback_window,
    avg(record_count) as avg_daily_records,
    avg(record_count) * 3 as records_reprocessed
FROM daily_volumes

UNION ALL

SELECT
    '7 days' as lookback_window,
    avg(record_count) as avg_daily_records,
    avg(record_count) * 7 as records_reprocessed
FROM daily_volumes

ORDER BY records_reprocessed;


/*
5. LATE ARRIVALS THAT WOULD BE MISSED

Simulate what a 3-day lookback would miss.
*/

WITH load_simulation AS (
    SELECT
        *,
        datediff(day, business_date, loaded_at) as days_late
    FROM your_source_table
    WHERE loaded_at >= current_date() - 30
)

SELECT
    date_trunc('week', loaded_at) as load_week,
    count(*) as total_records,
    count(case when days_late > 3 then 1 end) as missed_by_3day,
    round(count(case when days_late > 3 then 1 end) * 100.0 / count(*), 3) as pct_missed

FROM load_simulation
GROUP BY 1
ORDER BY 1;
