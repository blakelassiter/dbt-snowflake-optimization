/*
examples/warehouse-config/model_level_override.sql

Model-level warehouse override

Sometimes a specific model needs a different warehouse than its
folder default. Set it in the config block.

Use this sparingly. If many models in a folder need overrides,
consider restructuring folders instead.
*/

{{ config(
    materialized='table',
    
    -- Override the folder's default warehouse for this model only
    snowflake_warehouse='HEAVY_WH'
) }}

/*
This model does a complex aggregation across 3 large fact tables.
It needs more compute than typical models in this folder.

The folder default is TRANSFORM_WH (Medium), but this model
benefits from HEAVY_WH (Large) due to the join complexity.
*/

with fact_orders as (
    select * from {{ ref('fct_orders') }}  -- 50M rows
),

fact_shipments as (
    select * from {{ ref('fct_shipments') }}  -- 80M rows
),

fact_returns as (
    select * from {{ ref('fct_returns') }}  -- 10M rows
),

order_lifecycle as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        o.order_total,
        s.shipped_date,
        s.carrier,
        s.delivery_date,
        r.return_date,
        r.return_reason,
        r.refund_amount
    from fact_orders o
    left join fact_shipments s 
        on o.order_id = s.order_id
    left join fact_returns r 
        on o.order_id = r.order_id
)

select
    customer_id,
    count(distinct order_id) as total_orders,
    count(distinct case when shipped_date is not null then order_id end) as shipped_orders,
    count(distinct case when delivery_date is not null then order_id end) as delivered_orders,
    count(distinct case when return_date is not null then order_id end) as returned_orders,
    sum(order_total) as gross_revenue,
    sum(coalesce(refund_amount, 0)) as total_refunds,
    sum(order_total) - sum(coalesce(refund_amount, 0)) as net_revenue,
    avg(datediff(day, order_date, shipped_date)) as avg_days_to_ship,
    avg(datediff(day, shipped_date, delivery_date)) as avg_days_to_deliver
from order_lifecycle
group by customer_id


/*
WHEN TO USE MODEL-LEVEL OVERRIDES

1. A single model in a folder has very different compute needs
2. Temporary override during development/debugging
3. Models with known SLA requirements


WHEN NOT TO USE

1. Multiple models in the same folder need overrides (restructure folders)
2. "This model is slow" (optimize SQL first)
3. As a default approach (use folder-level configs instead)
*/
