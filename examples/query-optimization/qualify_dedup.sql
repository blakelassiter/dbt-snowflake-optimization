/*
examples/query-optimization/qualify_dedup.sql

Use QUALIFY for deduplication

Deduplicating rows is a common pattern - keeping the most recent
version of each record, the first occurrence, etc. The traditional
approach uses a subquery with ROW_NUMBER. Snowflake's QUALIFY clause
does the same thing more cleanly and sometimes faster.
*/


/* TRADITIONAL APPROACH: ROW_NUMBER + subquery

   Works, but requires a subquery and an extra layer.
*/

select 
    customer_id,
    email,
    name,
    updated_at
from (
    select 
        customer_id,
        email,
        name,
        updated_at,
        row_number() over (
            partition by customer_id 
            order by updated_at desc
        ) as rn
    from customer_updates
)
where rn = 1


/* BETTER: QUALIFY clause

   Same result, cleaner syntax, no subquery.
   QUALIFY filters on window function results.
*/

select 
    customer_id,
    email,
    name,
    updated_at
from customer_updates
qualify row_number() over (
    partition by customer_id 
    order by updated_at desc
) = 1


/*
COMMON DEDUPLICATION PATTERNS WITH QUALIFY
*/

-- Keep most recent record per customer
select *
from customers
qualify row_number() over (
    partition by customer_id 
    order by updated_at desc
) = 1

-- Keep first occurrence (earliest record)
select *
from events
qualify row_number() over (
    partition by user_id, event_type 
    order by event_timestamp asc
) = 1

-- Keep record with highest value
select *
from bids
qualify row_number() over (
    partition by auction_id 
    order by bid_amount desc
) = 1

-- Keep one per day (most recent within each day)
select *
from daily_snapshots
qualify row_number() over (
    partition by entity_id, date_trunc('day', snapshot_timestamp)
    order by snapshot_timestamp desc
) = 1


/*
COMBINING QUALIFY WITH WHERE

WHERE filters happen before window functions.
QUALIFY filters happen after.
*/

select *
from orders
where order_status = 'completed'  -- Applied first
qualify row_number() over (
    partition by customer_id 
    order by order_date desc
) = 1  -- Applied to filtered results


/*
QUALIFY WITH OTHER WINDOW FUNCTIONS

QUALIFY works with any window function, not just ROW_NUMBER.
*/

-- Keep customers with above-average order count
select 
    customer_id,
    order_count
from customer_summary
qualify order_count > avg(order_count) over ()

-- Keep rows where the running total exceeds threshold
select
    transaction_id,
    amount,
    sum(amount) over (order by transaction_date) as running_total
from transactions
qualify running_total <= 10000  -- Stop at $10k


/*
PERFORMANCE NOTE

QUALIFY doesn't always outperform the subquery approach, but it's
never slower and often marginally faster. The bigger benefit is
readability - one less layer of nesting makes the logic clearer.

In code review, if you see the ROW_NUMBER + subquery + WHERE rn = 1
pattern, suggest QUALIFY as a cleaner alternative.
*/
