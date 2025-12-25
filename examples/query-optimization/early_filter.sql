/*
examples/query-optimization/early_filter.sql

Push filters before joins

The order of operations matters. Joining first then filtering means
Snowflake processes the full join before discarding rows. Filtering
first means the join operates on fewer rows.

This is one of the highest-impact patterns. A query joining 50M orders
with 10M customers, then filtering to today, can become 1000x cheaper
by filtering first.
*/


/* ANTI-PATTERN: Filter after join
   
   Snowflake joins all 50M orders with all 10M customers,
   then throws away everything except today's orders.
*/

with all_orders as (
    select * from orders  -- 50M rows
),

all_customers as (
    select * from customers  -- 10M rows
),

joined as (
    select 
        o.order_id,
        o.order_date,
        o.total,
        c.customer_name,
        c.segment
    from all_orders o
    left join all_customers c 
        on o.customer_id = c.customer_id
)

-- Filter AFTER processing the entire join
select * from joined
where order_date = current_date()


/* BETTER: Filter before join
   
   Filter orders to today first (maybe 20k rows), then join.
   The join now processes 20k rows instead of 50M.
*/

with todays_orders as (
    -- Filter to today BEFORE joining
    select 
        order_id,
        customer_id,
        order_date,
        total
    from orders
    where order_date = current_date()  -- 20k rows
),

relevant_customers as (
    -- Only load customers who have orders today
    select 
        customer_id,
        customer_name,
        segment
    from customers
    where customer_id in (
        select customer_id from todays_orders
    )
)

select 
    o.order_id,
    o.order_date,
    o.total,
    c.customer_name,
    c.segment
from todays_orders o
left join relevant_customers c 
    on o.customer_id = c.customer_id


/*
WHY THIS WORKS

1. Date filters enable partition pruning. Snowflake skips partitions
   that don't contain today's date without reading them.

2. Smaller inputs mean smaller joins. Join complexity scales with
   input size. Joining 20k x 15k is much faster than 50M x 10M.

3. Less data movement. Snowflake shuffles data between nodes for joins.
   Moving 20k rows is faster than moving 50M rows.


IDENTIFYING FILTER-LATE PATTERNS IN CODE REVIEW

Look for:
  - WHERE clauses at the end of long CTEs
  - Date filters applied after joins
  - Subqueries that select * then filter in outer query

Ask: "Could this filter be pushed into an earlier CTE?"
*/
