/*
models/marts/dim_customers.sql

Table materialization example

Use tables when:
  - Transformation involves joins, aggregations, or complex logic
  - Downstream queries are frequent (more than a few per hour)
  - Data size is moderate (1M-10M rows typically)
  - Slight staleness between dbt runs is acceptable

This customer dimension joins multiple sources and calculates
lifetime metrics. Expensive to compute, queried constantly.
Table materialization computes once, serves many reads.
*/

{{ config(
    materialized='table'
) }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_orders as (
    select
        customer_id,
        count(*) as total_orders,
        sum(order_total) as lifetime_spend,
        min(order_date) as first_order_date,
        max(order_date) as most_recent_order_date,
        avg(order_total) as average_order_value
    from orders
    where order_status = 'completed'
    group by customer_id
),

customer_segments as (
    select
        customer_id,
        case
            when lifetime_spend >= 10000 then 'enterprise'
            when lifetime_spend >= 1000 then 'growth'
            when lifetime_spend >= 100 then 'standard'
            else 'starter'
        end as spend_segment,
        case
            when total_orders >= 50 then 'power_user'
            when total_orders >= 10 then 'regular'
            when total_orders >= 3 then 'occasional'
            else 'new'
        end as frequency_segment
    from customer_orders
)

select
    c.customer_id,
    c.email,
    c.company_name,
    c.created_at as customer_since,
    
    -- Order metrics
    coalesce(co.total_orders, 0) as total_orders,
    coalesce(co.lifetime_spend, 0) as lifetime_spend,
    co.first_order_date,
    co.most_recent_order_date,
    round(coalesce(co.average_order_value, 0), 2) as average_order_value,
    
    -- Segments
    coalesce(cs.spend_segment, 'starter') as spend_segment,
    coalesce(cs.frequency_segment, 'new') as frequency_segment,
    
    -- Days since last order (useful for churn analysis)
    datediff(day, co.most_recent_order_date, current_date()) as days_since_last_order

from customers c
left join customer_orders co on c.customer_id = co.customer_id
left join customer_segments cs on c.customer_id = cs.customer_id
