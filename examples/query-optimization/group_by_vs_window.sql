/*
examples/query-optimization/group_by_vs_window.sql

Use GROUP BY instead of window functions (when possible)

Window functions are powerful but expensive. They require Snowflake
to partition the entire dataset and maintain state across rows.
For simple aggregations, GROUP BY is much cheaper.

Rule of thumb: If you just need an aggregate per group (not per row),
use GROUP BY. If you need the aggregate alongside original row data,
window functions might be necessary - but consider a join instead.
*/


/* ANTI-PATTERN: Window functions for simple aggregations

   This calculates customer metrics using window functions.
   Snowflake partitions 50M rows by customer_id for each window function.
*/

select
    customer_id,
    order_date,
    order_total,
    count(*) over (partition by customer_id) as total_orders,
    sum(order_total) over (partition by customer_id) as lifetime_value
from orders  -- 50M rows


/* BETTER: GROUP BY with join

   Calculate aggregates once with GROUP BY, then join back if needed.
*/

with customer_metrics as (
    -- Aggregate once per customer
    select
        customer_id,
        count(*) as total_orders,
        sum(order_total) as lifetime_value
    from orders
    group by customer_id
)

select
    o.customer_id,
    o.order_date,
    o.order_total,
    cm.total_orders,
    cm.lifetime_value
from orders o
left join customer_metrics cm 
    on o.customer_id = cm.customer_id


/* EVEN BETTER: Just use GROUP BY if you don't need row-level detail

   Often the row-level detail isn't actually needed.
   If you just want customer metrics, skip the join entirely.
*/

select
    customer_id,
    count(*) as total_orders,
    sum(order_total) as lifetime_value,
    min(order_date) as first_order_date,
    max(order_date) as last_order_date,
    avg(order_total) as average_order_value
from orders
group by customer_id


/*
WHEN WINDOW FUNCTIONS ARE APPROPRIATE

1. Running totals or moving averages
*/
select
    order_date,
    order_total,
    sum(order_total) over (
        order by order_date 
        rows between 6 preceding and current row
    ) as rolling_7_day_total
from orders

/* 2. Ranking within groups */
select
    customer_id,
    order_id,
    order_total,
    row_number() over (
        partition by customer_id 
        order by order_total desc
    ) as order_rank
from orders

/* 3. Comparing to previous/next rows */
select
    customer_id,
    order_date,
    order_total,
    lag(order_total) over (
        partition by customer_id 
        order by order_date
    ) as previous_order_total
from orders


/*
PERFORMANCE COMPARISON

50M row orders table, 1M unique customers

Window function approach: ~45 seconds
  - Partitions 50M rows by customer (expensive shuffle)
  - Calculates aggregate for each row (50M calculations)

GROUP BY + join approach: ~12 seconds
  - Aggregates 50M rows to 1M (one pass)
  - Joins 50M with 1M (much smaller operation)

GROUP BY only (no row-level detail): ~5 seconds
  - Aggregates 50M rows to 1M, done


CODE REVIEW QUESTION

When you see a window function, ask: "Do we need this value on every row,
or just once per group?" If once per group, use GROUP BY.
*/
